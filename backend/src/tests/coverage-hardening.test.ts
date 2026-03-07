import { describe, expect, it, vi } from "vitest";
import { loadEnv } from "../lib/env.js";
import { defaultShouldRetry, withRetry } from "../lib/retry.js";
import {
  buildFallbackQuestionForSlot,
  mergeDiscoverySlotState,
  missingDiscoverySlots,
  normalizeDiscoverySlotState,
  StoryDiscoveryService
} from "../services/storyDiscoveryService.js";
import {
  buildRevisionPlan,
  buildStoryPlan,
  evaluateStoryQuality
} from "../services/storyPlannerService.js";
import { StoryContinuityService } from "../services/storyContinuityService.js";
import { StoryService } from "../services/storyService.js";
import { makeRequestContext, makeTestEnv, responseWithJSON } from "./testHelpers.js";

function makeGenerateRequest() {
  return {
    child_profile_id: "11111111-1111-1111-1111-111111111111",
    age_band: "3-8" as const,
    language: "en" as const,
    length_minutes: 3,
    voice: "alloy",
    question_count: 2,
    story_brief: {
      theme: "following a lantern clue",
      characters: ["Bunny", "Fox"],
      setting: "a sunny park",
      tone: "gentle and playful",
      episode_intent: "a complete and happy standalone adventure",
      lesson: "kindness"
    },
    continuity_facts: ["Characters: Bunny, Fox", "Last episode context: Bunny and Fox found a hidden map in the park."]
  };
}

function makeRevisionRequest() {
  return {
    story_id: "22222222-2222-2222-2222-222222222222",
    current_scene_index: 2,
    story_title: "The Friendly Dragon",
    user_update: "Make the dragon funny and keep the ending cozy.",
    completed_scenes: [
      { scene_id: "1", text: "Bunny met Dragon at the park gate.", duration_sec: 35 },
      { scene_id: "2", text: "They looked for the missing picnic basket near the castle path.", duration_sec: 35 }
    ],
    remaining_scenes: [
      { scene_id: "3", text: "The dragon looked worried by the fountain.", duration_sec: 20 },
      { scene_id: "4", text: "Bunny promised to help before sunset.", duration_sec: 50 }
    ]
  };
}

describe("coverage hardening", () => {
  it("parses env falsey flags and rejects production region mismatches", () => {
    const env = loadEnv({
      NODE_ENV: "development",
      OPENAI_API_KEY: "test-key-12345678901234567890",
      TRUST_PROXY: "no",
      API_AUTH_REQUIRED: "",
      ENABLE_USAGE_METERING: "0",
      ENABLE_STRUCTURED_ANALYTICS: "off",
      ALLOWED_REGIONS: ""
    });

    expect(env.TRUST_PROXY).toBe(false);
    expect(env.API_AUTH_REQUIRED).toBe(false);
    expect(env.ENABLE_USAGE_METERING).toBe(false);
    expect(env.ENABLE_STRUCTURED_ANALYTICS).toBe(false);
    expect(env.ALLOWED_REGIONS).toEqual(["US", "EU"]);

    expect(() =>
      loadEnv({
        NODE_ENV: "production",
        OPENAI_API_KEY: "test-key-12345678901234567890",
        SESSION_SIGNING_SECRET: "secure-signing-secret-1234567890",
        AUTH_TOKEN_SECRET: "secure-auth-secret-123456789012",
        ALLOWED_ORIGIN: "https://storytime.example.com",
        API_AUTH_REQUIRED: "true",
        ALLOWED_REGIONS: "EU",
        DEFAULT_REGION: "US"
      })
    ).toThrow(/DEFAULT_REGION/);
  });

  it("rejects invalid refresh windows and insecure production transport defaults", () => {
    expect(() =>
      loadEnv({
        NODE_ENV: "development",
        OPENAI_API_KEY: "test-key-12345678901234567890",
        SESSION_TOKEN_TTL_SECONDS: "300",
        SESSION_TOKEN_REFRESH_SECONDS: "300"
      })
    ).toThrow(/SESSION_TOKEN_REFRESH_SECONDS/);

    expect(() =>
      loadEnv({
        NODE_ENV: "production",
        OPENAI_API_KEY: "test-key-12345678901234567890",
        SESSION_SIGNING_SECRET: "secure-signing-secret-1234567890",
        AUTH_TOKEN_SECRET: "secure-auth-secret-123456789012",
        ALLOWED_ORIGIN: "*",
        API_AUTH_REQUIRED: "true"
      })
    ).toThrow(/ALLOWED_ORIGIN/);

    expect(() =>
      loadEnv({
        NODE_ENV: "production",
        OPENAI_API_KEY: "test-key-12345678901234567890",
        SESSION_SIGNING_SECRET: "secure-signing-secret-1234567890",
        AUTH_TOKEN_SECRET: "secure-auth-secret-123456789012",
        ALLOWED_ORIGIN: "https://storytime.example.com",
        API_AUTH_REQUIRED: "false"
      })
    ).toThrow(/API_AUTH_REQUIRED/);
  });

  it("covers retry decisions for cause statuses and explicit non-retry policies", async () => {
    expect(defaultShouldRetry({ cause: { status: 503 } })).toBe(true);
    expect(defaultShouldRetry({ cause: { status: 400 } })).toBe(false);

    const operation = vi.fn<() => Promise<string>>().mockRejectedValue({ status: 503 });
    const onRetry = vi.fn();

    await expect(
      withRetry(operation, {
        retries: 2,
        baseDelayMs: 0,
        maxDelayMs: 0,
        shouldRetry: () => false,
        onRetry
      })
    ).rejects.toEqual({ status: 503 });

    expect(onRetry).not.toHaveBeenCalled();
    expect(operation).toHaveBeenCalledTimes(1);
  });

  it("normalizes discovery state and provides slot fallback questions", () => {
    const normalized = normalizeDiscoverySlotState(
      {
        theme: "   ",
        characters: ["  ", "Bunny", "Fox"],
        setting: " park ",
        tone: " cozy ",
        episode_intent: " "
      },
      "new"
    );

    expect(normalized.theme).toBeUndefined();
    expect(normalized.characters).toEqual(["Bunny", "Fox"]);
    expect(normalized.setting).toBe("park");
    expect(normalized.tone).toBe("cozy");
    expect(normalized.episode_intent).toBeUndefined();
    expect(missingDiscoverySlots(normalized)).toEqual(["theme", "episode_intent"]);

    const merged = mergeDiscoverySlotState(
      {
        theme: "lantern adventure",
        characters: ["Bunny"],
        setting: undefined,
        tone: undefined,
        episode_intent: undefined
      },
      {
        characters: [],
        setting: "forest",
        tone: "funny"
      },
      "extend"
    );

    expect(merged.characters).toEqual(["Bunny"]);
    expect(merged.setting).toBe("forest");
    expect(merged.tone).toBe("funny");
    expect(merged.episode_intent).toContain("continue the series");
    expect(buildFallbackQuestionForSlot("theme", "new")).toContain("mainly about");
    expect(buildFallbackQuestionForSlot("theme", "extend")).toContain("happen next");
    expect(buildFallbackQuestionForSlot("characters", "new")).toContain("Who should");
    expect(buildFallbackQuestionForSlot("setting", "new")).toContain("Where should");
    expect(buildFallbackQuestionForSlot("tone", "new")).toContain("funny");
    expect(buildFallbackQuestionForSlot("episode_intent", "new")).toContain("brand new story");
    expect(buildFallbackQuestionForSlot("episode_intent", "extend", "Earlier recap")).toContain("next episode");
  });

  it("blocks banned discovery themes and sanitizes invalid follow-up prompts", async () => {
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;

    const blockedService = new StoryDiscoveryService({ responses: { create: vi.fn() } } as any, makeTestEnv(), moderation);
    const blocked = await blockedService.analyzeTurn(
      {
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        transcript: "I want a scary horror story in a dark cave",
        question_count: 1,
        slot_state: {},
        mode: "new"
      },
      makeRequestContext()
    );

    expect(blocked.blocked).toBe(true);
    expect(blocked.data.ready_to_generate).toBe(false);

    const openai = {
      responses: {
        create: vi.fn().mockResolvedValue({
          output_text: JSON.stringify({
            slot_state: {
              theme: "lantern chase",
              characters: ["Bunny"],
              setting: "park",
              tone: "gentle",
              episode_intent: null
            },
            ready_to_generate: false,
            next_focus_slot: "episode_intent",
            assistant_message: "Tell me more"
          })
        })
      }
    } as any;

    const service = new StoryDiscoveryService(openai, makeTestEnv(), moderation);
    const result = await service.analyzeTurn(
      {
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        transcript: "Let's keep Bunny in the park",
        question_count: 1,
        slot_state: { theme: "lantern chase", characters: ["Bunny"], setting: "park", tone: "gentle" },
        mode: "new",
        previous_episode_recap: "Last time Bunny followed a map."
      },
      makeRequestContext()
    );

    expect(result.blocked).toBe(false);
    expect(result.data.assistant_message).toContain("next episode");
  });

  it("covers planner pacing checks and revision-plan fallbacks", () => {
    const revisionPlan = buildRevisionPlan({
      titleHint: "Castle Quest",
      userUpdate: "Make it brave and cheerful in the castle",
      completedScenes: [],
      remainingScenes: [
        { scene_id: "1", text: "Bunny entered the castle hall.", duration_sec: 20 },
        { scene_id: "2", text: "Fox spotted a clue in the castle tower.", duration_sec: 20 },
        { scene_id: "3", text: "They heard a bell in the castle garden.", duration_sec: 20 },
        { scene_id: "4", text: "They chose the brave path together.", duration_sec: 20 },
        { scene_id: "5", text: "They waved and smiled at sunset.", duration_sec: 20 }
      ]
    });

    expect(revisionPlan.episodeRecap).toBeUndefined();
    expect(revisionPlan.beatPlan).toHaveLength(5);
    expect(revisionPlan.beatPlan[0].purpose).toContain("castle");
    expect(revisionPlan.characterBible.map((character) => character.name)).toContain("Bunny");

    const plan = buildStoryPlan({
      titleHint: undefined,
      theme: "helping a friend find a map",
      characters: ["Bunny"],
      setting: "a sunny park",
      tone: "gentle and playful",
      episodeIntent: "a complete and happy standalone adventure",
      lengthMinutes: 3,
      continuityFacts: [
        "Characters: Bunny, Fox",
        "Last episode context: Bunny and Fox found a secret map in the meadow."
      ]
    });

    const quality = evaluateStoryQuality(
      {
        title: "Off Balance",
        scenes: [
          {
            scene_id: "1",
            text: "A tiny bell rang by the river for a very long time without stopping.",
            duration_sec: 100
          },
          {
            scene_id: "2",
            text: "Everyone shrugged and the story just ended there.",
            duration_sec: 20
          }
        ]
      },
      plan,
      180,
      3
    );

    expect(quality.passed).toBe(false);
    expect(quality.issues.join(" ")).toContain("Expected exactly 3 scenes");
    expect(quality.issues.join(" ")).toContain("opening scene is too long");
    expect(quality.issues.join(" ")).toContain("gentle resolution");
    expect(quality.issues.join(" ")).toContain("existing series memory");
  });

  it("surfaces public story-engine failures and can enrich continuity from output_text", async () => {
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] }),
      moderateManyText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;
    const continuity = { enrichEngine: vi.fn() } as any;

    const generateService = new StoryService(
      {
        responses: {
          create: vi.fn().mockResolvedValue({ output: [] })
        }
      } as any,
      makeTestEnv(),
      moderation,
      continuity
    );

    await expect(generateService.generateStory(makeGenerateRequest(), makeRequestContext())).rejects.toMatchObject({
      code: "model_empty_output"
    });

    const reviseService = new StoryService(
      {
        responses: {
          create: vi.fn().mockResolvedValue(responseWithJSON({ scenes: [] }))
        }
      } as any,
      makeTestEnv(),
      moderation,
      continuity
    );

    await expect(reviseService.reviseStory(makeRevisionRequest(), makeRequestContext())).rejects.toMatchObject({
      code: "invalid_revision_output"
    });

    const continuityService = new StoryContinuityService(
      {
        responses: {
          create: vi.fn().mockResolvedValue(
            responseWithJSON({
              episode_recap: "Bunny found a silver bell and waved goodnight.",
              character_bible: [{ name: "Bunny", role: "main story friend", traits: ["kind", "curious"] }],
              favorite_places: ["bell garden"],
              relationship_facts: [],
              world_facts: ["Silver bells ring when friends help each other."],
              open_loops: [],
              arc_summary: "Bunny is learning where the bells lead.",
              next_episode_hook: "A new bell chimes by the pond.",
              continuity_facts: ["Silver bells ring when friends help each other."]
            })
          )
        }
      } as any,
      makeTestEnv()
    );

    const engine = await continuityService.enrichEngine(
      "Bell Garden",
      [
        { scene_id: "1", text: "Bunny listened to the bell in the garden.", duration_sec: 40 },
        { scene_id: "2", text: "Bunny smiled and walked home happy.", duration_sec: 40 }
      ],
      buildStoryPlan({
        titleHint: "Bell Garden",
        theme: "following a bell",
        characters: ["Bunny"],
        setting: "bell garden",
        tone: "gentle",
        episodeIntent: "continue the series with a new episode",
        lengthMinutes: 3,
        continuityFacts: []
      }),
      makeRequestContext()
    );

    expect(engine.series_memory.favorite_places).toContain("bell garden");
    expect(engine.series_memory.next_episode_hook).toContain("pond");
    expect(engine.character_bible).toHaveLength(1);
  });
});
