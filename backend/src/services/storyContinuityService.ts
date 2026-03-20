import OpenAI from "openai";
import { analytics } from "../lib/analytics.js";
import type { Env } from "../lib/env.js";
import { AppError } from "../lib/errors.js";
import type { RequestContext } from "../lib/requestContext.js";
import { withRetry } from "../lib/retry.js";
import type {
  StoryEngine,
  StoryEngineCharacter,
  StoryScene,
  StorySeriesMemory
} from "../types.js";
import type { StoryPlan } from "./storyPlannerService.js";

const CONTINUITY_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    episode_recap: { type: "string" },
    character_bible: {
      type: "array",
      maxItems: 12,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          name: { type: "string" },
          role: { type: "string" },
          traits: {
            type: "array",
            maxItems: 6,
            items: { type: "string" }
          }
        },
        required: ["name", "role", "traits"]
      }
    },
    favorite_places: {
      type: "array",
      maxItems: 12,
      items: { type: "string" }
    },
    relationship_facts: {
      type: "array",
      maxItems: 12,
      items: { type: "string" }
    },
    world_facts: {
      type: "array",
      maxItems: 20,
      items: { type: "string" }
    },
    open_loops: {
      type: "array",
      maxItems: 12,
      items: { type: "string" }
    },
    arc_summary: { type: ["string", "null"] },
    next_episode_hook: { type: ["string", "null"] },
    continuity_facts: {
      type: "array",
      maxItems: 24,
      items: { type: "string" }
    }
  },
  required: [
    "episode_recap",
    "character_bible",
    "favorite_places",
    "relationship_facts",
    "world_facts",
    "open_loops",
    "arc_summary",
    "next_episode_hook",
    "continuity_facts"
  ]
} as const;

type ContinuityExtraction = {
  episode_recap: string;
  character_bible: StoryEngineCharacter[];
  favorite_places: string[];
  relationship_facts: string[];
  world_facts: string[];
  open_loops: string[];
  arc_summary?: string | null;
  next_episode_hook?: string | null;
  continuity_facts: string[];
};

export class StoryContinuityService {
  constructor(
    private readonly openai: OpenAI,
    private readonly env: Env
  ) {}

  async enrichEngine(
    title: string,
    scenes: StoryScene[],
    plan: StoryPlan,
    context?: RequestContext
  ): Promise<Pick<StoryEngine, "episode_recap" | "series_memory" | "character_bible" | "continuity_facts">> {
    try {
      const extracted = await this.extractContinuity(title, scenes, plan, context);
      return mergeContinuity(plan, extracted);
    } catch {
      return mergeContinuity(plan, fallbackContinuity(title, scenes, plan));
    }
  }

  private async extractContinuity(
    title: string,
    scenes: StoryScene[],
    plan: StoryPlan,
    context?: RequestContext
  ): Promise<ContinuityExtraction> {
    const systemPrompt = [
      "You extract continuity memory from a finished children's audio-story episode.",
      "Focus only on safe, reusable continuity: characters, relationships, favorite places, world facts, unresolved threads, recap, and series arc.",
      "Do not include private or sensitive personal data.",
      "Keep facts short, stable, and suitable for semantic retrieval across future episodes."
    ].join(" ");

    const userPrompt = JSON.stringify({
      title,
      scenes,
      existing_plan: plan
    });

    const startedAt = Date.now();
    let attempts = 1;

    try {
      const { result, attempts: usedAttempts } = await withRetry(
        () =>
          this.openai.responses.create({
            model: this.env.OPENAI_RESPONSES_MODEL,
            input: [
              { role: "system", content: systemPrompt },
              { role: "user", content: userPrompt }
            ],
            text: {
              format: {
                type: "json_schema",
                name: "story_continuity_extraction",
                schema: CONTINUITY_SCHEMA,
                strict: true
              }
            }
          } as any),
        {
          retries: this.env.OPENAI_MAX_RETRIES,
          baseDelayMs: this.env.OPENAI_RETRY_BASE_MS
        }
      );
      attempts = usedAttempts;

      this.recordUsage(context, attempts, Date.now() - startedAt, true);
      const jsonText = extractOutputText(result);
      if (!jsonText) {
        throw new AppError("Model returned empty response for continuity extraction", 502, "model_empty_output");
      }

      return JSON.parse(jsonText) as ContinuityExtraction;
    } catch (error) {
      this.recordUsage(context, attempts, Date.now() - startedAt, false);
      throw error;
    }
  }

  private recordUsage(context: RequestContext | undefined, attempts: number, durationMs: number, success: boolean) {
    if (!context || (!this.env.ENABLE_STRUCTURED_ANALYTICS && !this.env.ENABLE_USAGE_METERING)) {
      return;
    }

    analytics.recordOpenAI({
      requestId: context.requestId,
      route: context.route,
      operation: "responses.continuity",
      provider: "openai",
      model: this.env.OPENAI_RESPONSES_MODEL,
      region: context.region,
      installHash: context.installHash,
      sessionId: context.sessionId,
      attempts,
      durationMs,
      success
    });
  }
}

export function mergeContinuity(
  plan: StoryPlan,
  extracted: ContinuityExtraction
): Pick<StoryEngine, "episode_recap" | "series_memory" | "character_bible" | "continuity_facts"> {
  const mergedCharacters = mergeCharacters(plan.characterBible, extracted.character_bible);
  const seriesMemory: StorySeriesMemory = {
    title: plan.seriesMemory.title,
    recurring_characters: uniqueStrings([
      ...plan.seriesMemory.recurring_characters,
      ...mergedCharacters.map((character) => character.name)
    ]).slice(0, 12),
    prior_episode_recap: clampSentence(extracted.episode_recap, 400),
    world_facts: uniqueStrings([...plan.seriesMemory.world_facts, ...extracted.world_facts]).slice(0, 20),
    open_loops: uniqueStrings([...plan.seriesMemory.open_loops, ...extracted.open_loops]).slice(0, 12),
    favorite_places: uniqueStrings([
      ...plan.seriesMemory.favorite_places,
      ...extracted.favorite_places
    ]).slice(0, 12),
    relationship_facts: uniqueStrings([
      ...plan.seriesMemory.relationship_facts,
      ...extracted.relationship_facts
    ]).slice(0, 12),
    arc_summary: extracted.arc_summary?.trim() || plan.seriesMemory.arc_summary,
    next_episode_hook: extracted.next_episode_hook?.trim() || plan.seriesMemory.next_episode_hook
  };

  const continuityFacts = uniqueStrings([
    ...(extracted.continuity_facts ?? []),
    ...seriesMemory.world_facts,
    ...seriesMemory.relationship_facts,
    ...seriesMemory.favorite_places.map((place) => `Place: ${place}`),
    ...seriesMemory.open_loops.map((loop) => `Open loop: ${loop}`),
    ...(seriesMemory.arc_summary ? [`Arc summary: ${seriesMemory.arc_summary}`] : []),
    ...(seriesMemory.next_episode_hook ? [`Next episode hook: ${seriesMemory.next_episode_hook}`] : []),
    ...mergedCharacters.map((character) => `Character note: ${character.name} is ${character.traits.join(", ")}`)
  ]).slice(0, 24);

  return {
    episode_recap: clampSentence(extracted.episode_recap, 400),
    series_memory: seriesMemory,
    character_bible: mergedCharacters,
    continuity_facts: continuityFacts
  };
}

function fallbackContinuity(
  title: string,
  scenes: StoryScene[],
  plan: StoryPlan
): ContinuityExtraction {
  const combinedText = scenes.map((scene) => scene.text).join(" ");
  const places = extractPlaces(combinedText, plan);
  const relationships = buildRelationshipFacts(plan.characterBible);
  const firstScene = scenes[0]?.text ?? "";
  const lastScene = scenes[scenes.length - 1]?.text ?? "";
  const recap = clampSentence(`${title}. ${firstScene} ${lastScene}`, 320);

  return {
    episode_recap: recap,
    character_bible: plan.characterBible,
    favorite_places: places,
    relationship_facts: relationships,
    world_facts: uniqueStrings([...plan.seriesMemory.world_facts, ...places.map((place) => `${place} is part of the story world.`)]).slice(0, 20),
    open_loops: plan.seriesMemory.open_loops,
    arc_summary: plan.seriesMemory.arc_summary ?? `The series is exploring ${plan.beatPlan[0]?.purpose ?? "gentle adventures together"}.`,
    next_episode_hook: plan.seriesMemory.next_episode_hook ?? plan.seriesMemory.open_loops[0] ?? undefined,
    continuity_facts: uniqueStrings([
      recap,
      ...plan.seriesMemory.world_facts,
      ...relationships,
      ...places.map((place) => `Place: ${place}`),
      ...plan.seriesMemory.open_loops.map((loop) => `Open loop: ${loop}`)
    ]).slice(0, 24)
  };
}

function mergeCharacters(
  planned: StoryEngineCharacter[],
  extracted: StoryEngineCharacter[]
): StoryEngineCharacter[] {
  const merged = new Map<string, StoryEngineCharacter>();

  for (const character of [...planned, ...extracted]) {
    const key = character.name.trim().toLowerCase();
    if (!key) {
      continue;
    }

    const existing = merged.get(key);
    merged.set(key, {
      name: character.name.trim(),
      role: character.role.trim() || existing?.role || "story friend",
      traits: uniqueStrings([...(existing?.traits ?? []), ...character.traits]).slice(0, 6)
    });
  }

  return Array.from(merged.values()).slice(0, 12);
}

function buildRelationshipFacts(characters: StoryEngineCharacter[]): string[] {
  if (characters.length < 2) {
    return [];
  }

  return uniqueStrings(
    characters.slice(1).map((character) => `${characters[0].name} and ${character.name} are kind friends who help each other.`)
  ).slice(0, 12);
}

function extractPlaces(text: string, plan: StoryPlan): string[] {
  const lowercase = text.toLowerCase();
  const candidates = [
    ...plan.seriesMemory.favorite_places,
    "park",
    "forest",
    "garden",
    "village",
    "beach",
    "cloud village",
    "castle",
    "school",
    "meadow",
    "spaceship"
  ];

  return uniqueStrings(
    candidates.filter((candidate) => candidate && lowercase.includes(candidate.toLowerCase()))
  ).slice(0, 12);
}

function clampSentence(text: string, maxLength: number): string {
  return text.trim().slice(0, maxLength).trim();
}

function uniqueStrings(values: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const value of values) {
    const trimmed = value.trim();
    if (!trimmed) {
      continue;
    }

    const key = trimmed.toLowerCase();
    if (seen.has(key)) {
      continue;
    }

    seen.add(key);
    result.push(trimmed);
  }

  return result;
}

function extractOutputText(response: any): string {
  if (typeof response.output_text === "string" && response.output_text.trim().length > 0) {
    return response.output_text;
  }

  if (!Array.isArray(response.output)) {
    return "";
  }

  const messageParts: string[] = [];
  for (const item of response.output) {
    if (item?.type !== "message" || !Array.isArray(item?.content)) {
      continue;
    }
    for (const content of item.content) {
      if (content?.type === "output_text" && typeof content?.text === "string") {
        messageParts.push(content.text);
      }
    }
  }

  return messageParts.join("\n");
}
