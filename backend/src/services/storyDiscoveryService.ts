import OpenAI from "openai";
import { analytics } from "../lib/analytics.js";
import type { Env } from "../lib/env.js";
import { AppError } from "../lib/errors.js";
import { logLifecycle } from "../lib/lifecycle.js";
import type { RequestContext } from "../lib/requestContext.js";
import { withRetry } from "../lib/retry.js";
import type { DiscoveryRequest, DiscoveryResult } from "../types.js";
import { containsBannedTheme } from "./policyService.js";
import { ModerationService } from "./moderationService.js";

export const DISCOVERY_SLOT_KEYS = [
  "theme",
  "characters",
  "setting",
  "tone",
  "episode_intent"
] as const;

export type DiscoverySlotKey = (typeof DISCOVERY_SLOT_KEYS)[number];

export type DiscoverySlotState = {
  theme?: string;
  characters: string[];
  setting?: string;
  tone?: string;
  episode_intent?: string;
};

const DISCOVERY_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    slot_state: {
      type: "object",
      additionalProperties: false,
      properties: {
        theme: { type: ["string", "null"] },
        characters: {
          type: "array",
          maxItems: 6,
          items: { type: "string" }
        },
        setting: { type: ["string", "null"] },
        tone: { type: ["string", "null"] },
        episode_intent: { type: ["string", "null"] }
      },
      required: ["theme", "characters", "setting", "tone", "episode_intent"]
    },
    ready_to_generate: { type: "boolean" },
    next_focus_slot: {
      type: ["string", "null"],
      enum: ["theme", "characters", "setting", "tone", "episode_intent", null]
    },
    assistant_message: { type: "string" }
  },
  required: ["slot_state", "ready_to_generate", "next_focus_slot", "assistant_message"]
} as const;

type DiscoveryPayload = {
  slot_state: DiscoverySlotState;
  ready_to_generate: boolean;
  next_focus_slot: DiscoverySlotKey | null;
  assistant_message: string;
};

export class StoryDiscoveryService {
  constructor(
    private readonly openai: OpenAI,
    private readonly env: Env,
    private readonly moderation: ModerationService
  ) {}

  async analyzeTurn(request: DiscoveryRequest, context?: RequestContext): Promise<DiscoveryResult> {
    const startedAt = Date.now();
    logLifecycle(context, {
      component: "story_discovery",
      action: "analyze_turn",
      phase: "started",
      details: {
        mode: request.mode,
        question_count: request.question_count,
        has_previous_episode_recap: Boolean(request.previous_episode_recap)
      }
    });

    try {
      const transcript = request.transcript.trim();
      const priorState = normalizeDiscoverySlotState(request.slot_state, request.mode);
      const moderation = await this.moderation.moderateText(transcript, context);

      if (moderation.flagged || containsBannedTheme(transcript)) {
        const result: DiscoveryResult = {
          blocked: true,
          safe_message: "Let's make it a gentle and happy story. Tell me about a kind adventure instead.",
          data: {
            slot_state: priorState,
            question_count: Math.min(3, request.question_count),
            ready_to_generate: false,
            assistant_message: "Let's choose a friendly adventure with kind characters. What should the story be about?",
            transcript
          }
        };
        logLifecycle(context, {
          component: "story_discovery",
          action: "analyze_turn",
          phase: "blocked",
          details: {
            mode: request.mode,
            blocked_reason: "unsafe_transcript"
          },
          durationMs: Date.now() - startedAt
        });
        return result;
      }

      const questionCount = Math.min(3, request.question_count);
      if (questionCount >= 3) {
        const result: DiscoveryResult = {
          blocked: false,
          data: {
            slot_state: priorState,
            question_count: 3,
            ready_to_generate: true,
            assistant_message: "Thanks. I have enough details to make the story now.",
            transcript
          }
        };
        logLifecycle(context, {
          component: "story_discovery",
          action: "analyze_turn",
          phase: "completed",
          details: {
            mode: request.mode,
            ready_to_generate: true,
            used_model: false,
            question_count: result.data.question_count
          },
          durationMs: Date.now() - startedAt
        });
        return result;
      }

      const payload = await this.extractDiscoveryState(
        {
          ...request,
          slot_state: priorState
        },
        context
      );

      const mergedState = mergeDiscoverySlotState(priorState, payload.slot_state, request.mode);
      const missingSlots = missingDiscoverySlots(mergedState);

      if (missingSlots.length === 0) {
        const result: DiscoveryResult = {
          blocked: false,
          data: {
            slot_state: mergedState,
            question_count: questionCount,
            ready_to_generate: true,
            assistant_message: "Thanks. I have enough details to make the story now.",
            transcript
          }
        };
        logLifecycle(context, {
          component: "story_discovery",
          action: "analyze_turn",
          phase: "completed",
          details: {
            mode: request.mode,
            ready_to_generate: true,
            used_model: true,
            question_count: result.data.question_count
          },
          durationMs: Date.now() - startedAt
        });
        return result;
      }

      const nextFocus = sanitizeNextFocusSlot(payload.next_focus_slot, missingSlots);
      const result: DiscoveryResult = {
        blocked: false,
        data: {
          slot_state: mergedState,
          question_count: questionCount + 1,
          ready_to_generate: false,
          assistant_message: buildFollowUpQuestion(
            nextFocus,
            payload.assistant_message.trim(),
            request.mode,
            request.previous_episode_recap
          ),
          transcript
        }
      };
      logLifecycle(context, {
        component: "story_discovery",
        action: "analyze_turn",
        phase: "completed",
        details: {
          mode: request.mode,
          ready_to_generate: false,
          used_model: true,
          question_count: result.data.question_count
        },
        durationMs: Date.now() - startedAt
      });
      return result;
    } catch (error) {
      logLifecycle(context, {
        component: "story_discovery",
        action: "analyze_turn",
        phase: "failed",
        details: {
          mode: request.mode,
          question_count: request.question_count
        },
        durationMs: Date.now() - startedAt,
        error
      });
      throw error;
    }
  }

  private async extractDiscoveryState(request: DiscoveryRequest, context?: RequestContext): Promise<DiscoveryPayload> {
    const systemPrompt = [
      "You help collect story setup details for a kid-safe voice storytelling app for ages 3-8.",
      "You are not writing the story yet.",
      "Update the slot_state from the child's latest transcript.",
      "Track these slots: theme, characters, setting, tone, episode_intent.",
      "Theme means what the story is mainly about.",
      "Tone means the feeling or style, like funny, gentle, magical, sleepy, brave, or silly.",
      "Episode intent means whether the child wants a fresh story, a sequel, a continuation, a side quest, or a recap-inspired next episode.",
      "If enough detail is present, set ready_to_generate to true and next_focus_slot to null.",
      "If more detail is needed, set next_focus_slot to exactly one missing slot and assistant_message to one short follow-up question about only that slot.",
      "Never ask for more than one follow-up question at a time.",
      "Keep everything gentle, friendly, and simple for a child."
    ].join(" ");

    const userPrompt = JSON.stringify({
      transcript: request.transcript,
      question_count: request.question_count,
      mode: request.mode,
      previous_episode_recap: request.previous_episode_recap,
      slot_state: request.slot_state
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
                name: "story_discovery_turn",
                schema: DISCOVERY_SCHEMA,
                strict: true
              }
            }
          } as any),
        {
          retries: this.env.OPENAI_MAX_RETRIES,
          baseDelayMs: this.env.OPENAI_RETRY_BASE_MS,
          onRetry: (error, attempt, nextDelayMs) => {
            logLifecycle(context, {
              component: "story_discovery",
              action: "analyze_turn",
              phase: "retrying",
              details: {
                retry_attempt: attempt,
                retry_in_ms: nextDelayMs,
                retry_source: "openai"
              },
              error
            });
          }
        }
      );
      attempts = usedAttempts;

      this.recordUsage(context, attempts, Date.now() - startedAt, true);
      const jsonText = extractOutputText(result);
      if (!jsonText) {
        throw new AppError("Model returned empty response for discovery", 502, "model_empty_output");
      }

      return JSON.parse(jsonText) as DiscoveryPayload;
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
      operation: "responses.discovery",
      runtimeStage: "discovery",
      provider: "openai",
      model: this.env.OPENAI_RESPONSES_MODEL,
      region: context.region,
      installHash: context.installHash,
      attempts,
      durationMs,
      success
    });
  }
}

export function normalizeDiscoverySlotState(
  input: Partial<DiscoverySlotState> | undefined,
  mode: DiscoveryRequest["mode"]
): DiscoverySlotState {
  const base: DiscoverySlotState = {
    theme: sanitizeString(input?.theme),
    characters: sanitizeCharacters(input?.characters ?? [], []),
    setting: sanitizeString(input?.setting),
    tone: sanitizeString(input?.tone),
    episode_intent: sanitizeString(input?.episode_intent) ?? defaultEpisodeIntentForMode(mode)
  };

  return base;
}

export function mergeDiscoverySlotState(
  existing: DiscoverySlotState,
  next: Partial<DiscoverySlotState>,
  mode: DiscoveryRequest["mode"]
): DiscoverySlotState {
  return normalizeDiscoverySlotState(
    {
      theme: sanitizeString(next.theme) ?? existing.theme,
      characters: sanitizeCharacters(next.characters ?? [], existing.characters),
      setting: sanitizeString(next.setting) ?? existing.setting,
      tone: sanitizeString(next.tone) ?? existing.tone,
      episode_intent: sanitizeString(next.episode_intent) ?? existing.episode_intent
    },
    mode
  );
}

export function missingDiscoverySlots(state: DiscoverySlotState): DiscoverySlotKey[] {
  return DISCOVERY_SLOT_KEYS.filter((slot) => {
    if (slot === "characters") {
      return state.characters.length === 0;
    }

    const value = state[slot];
    return typeof value !== "string" || value.trim().length === 0;
  });
}

export function defaultEpisodeIntentForMode(mode: DiscoveryRequest["mode"]): string | undefined {
  if (mode === "extend") {
    return "continue the series with a new episode";
  }

  return undefined;
}

export function buildFallbackQuestionForSlot(
  slot: DiscoverySlotKey,
  mode: DiscoveryRequest["mode"],
  previousEpisodeRecap?: string
): string {
  switch (slot) {
    case "theme":
      return mode === "extend"
        ? "What should happen next in this adventure?"
        : "What should the story be mainly about?";
    case "characters":
      return "Who should be in the story?";
    case "setting":
      return "Where should the story happen?";
    case "tone":
      return "Should it feel funny, cozy, magical, sleepy, or brave?";
    case "episode_intent":
      if (mode === "extend" || (previousEpisodeRecap ?? "").trim().length > 0) {
        return "Should this feel like the next episode, a side adventure, or a brand new chapter?";
      }
      return "Do you want a brand new story or something that continues an earlier adventure?";
  }
}

function buildFollowUpQuestion(
  focusSlot: DiscoverySlotKey,
  candidateQuestion: string,
  mode: DiscoveryRequest["mode"],
  previousEpisodeRecap?: string
): string {
  const questionMarkCount = [...candidateQuestion].filter((character) => character === "?").length;
  if (candidateQuestion.length > 0 && questionMarkCount <= 1 && candidateQuestion.endsWith("?")) {
    return candidateQuestion;
  }

  return buildFallbackQuestionForSlot(focusSlot, mode, previousEpisodeRecap);
}

function sanitizeNextFocusSlot(
  value: DiscoverySlotKey | null,
  missingSlots: DiscoverySlotKey[]
): DiscoverySlotKey {
  if (value && missingSlots.includes(value)) {
    return value;
  }

  return missingSlots[0];
}

function sanitizeCharacters(next: string[], fallback: string[]): string[] {
  const cleaned = next
    .map((value) => value.trim())
    .filter(Boolean)
    .slice(0, 6);

  if (cleaned.length > 0) {
    return cleaned;
  }

  return fallback;
}

function sanitizeString(value: string | undefined): string | undefined {
  const cleaned = value?.trim();
  return cleaned ? cleaned : undefined;
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
