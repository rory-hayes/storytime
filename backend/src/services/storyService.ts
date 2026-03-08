import OpenAI from "openai";
import { v4 as uuidv4 } from "uuid";
import { analytics } from "../lib/analytics.js";
import type { Env } from "../lib/env.js";
import { AppError } from "../lib/errors.js";
import { logLifecycle } from "../lib/lifecycle.js";
import type { RequestContext } from "../lib/requestContext.js";
import { withRetry } from "../lib/retry.js";
import type {
  GenerateStoryRequest,
  GenerateStoryResponse,
  ReviseStoryRequest,
  ReviseStoryResponse,
  StoryEngine,
  StoryScript
} from "../types.js";
import { StoryScriptSchema } from "../types.js";
import {
  buildGenerateSystemPrompt,
  buildReviseSystemPrompt,
  containsBannedTheme,
  estimateSceneCount,
  safeFallbackStory
} from "./policyService.js";
import { ModerationService } from "./moderationService.js";
import {
  buildEngineMetadata,
  buildRevisionPlan,
  buildStoryPlan,
  evaluateStoryQuality,
  type StoryPlan
} from "./storyPlannerService.js";
import { StoryContinuityService } from "./storyContinuityService.js";

const STORY_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: { type: "string" },
    scenes: {
      type: "array",
      minItems: 1,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          scene_id: { type: "string" },
          text: { type: "string" },
          duration_sec: { type: "integer", minimum: 10, maximum: 180 }
        },
        required: ["scene_id", "text", "duration_sec"]
      }
    }
  },
  required: ["title", "scenes"]
} as const;

const SCENE_LIST_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    scenes: {
      type: "array",
      minItems: 1,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          scene_id: { type: "string" },
          text: { type: "string" },
          duration_sec: { type: "integer", minimum: 10, maximum: 180 }
        },
        required: ["scene_id", "text", "duration_sec"]
      }
    }
  },
  required: ["scenes"]
} as const;

type StoryGenerateResult = {
  blocked: boolean;
  safe_message?: string;
  data: GenerateStoryResponse;
};

type StoryReviseResult = {
  blocked: boolean;
  safe_message?: string;
  data: ReviseStoryResponse;
};

export class StoryService {
  constructor(
    private readonly openai: OpenAI,
    private readonly env: Env,
    private readonly moderation: ModerationService,
    private readonly continuity: StoryContinuityService
  ) {}

  async generateStory(request: GenerateStoryRequest, context?: RequestContext): Promise<StoryGenerateResult> {
    const startedAt = Date.now();
    logLifecycle(context, {
      component: "story_generate",
      action: "generate_story",
      phase: "started",
      details: {
        length_minutes: request.length_minutes,
        scene_target: estimateSceneCount(request.length_minutes),
        continuity_fact_count: request.continuity_facts.length
      }
    });

    try {
      const inputNarrative = this.inputNarrative(request);
      const plan = buildStoryPlan({
        titleHint: undefined,
        theme: request.story_brief.theme,
        characters: request.story_brief.characters,
        setting: request.story_brief.setting,
        tone: request.story_brief.tone,
        episodeIntent: request.story_brief.episode_intent,
        lengthMinutes: request.length_minutes,
        continuityFacts: request.continuity_facts
      });

      if (containsBannedTheme(inputNarrative)) {
        const result: StoryGenerateResult = {
          blocked: true,
          safe_message: "Let's pick a gentler story idea with friendly characters and a happy ending.",
          data: this.toGenerateResponse(
            request,
            safeFallbackStory(request.length_minutes),
            "flagged",
            "pass",
            buildEngineMetadata(
              plan,
              evaluateStoryQuality(
                safeFallbackStory(request.length_minutes),
                plan,
                request.length_minutes * 60,
                estimateSceneCount(request.length_minutes)
              )
            )
          )
        };
        logLifecycle(context, {
          component: "story_generate",
          action: "generate_story",
          phase: "blocked",
          details: {
            blocked_reason: "unsafe_input"
          },
          durationMs: Date.now() - startedAt
        });
        return result;
      }

      const inputModeration = await this.moderation.moderateText(inputNarrative, context);
      if (inputModeration.flagged) {
        const result: StoryGenerateResult = {
          blocked: true,
          safe_message: "Let's choose a different idea and make a kind, cozy story instead.",
          data: this.toGenerateResponse(
            request,
            safeFallbackStory(request.length_minutes),
            "flagged",
            "pass",
            buildEngineMetadata(
              plan,
              evaluateStoryQuality(
                safeFallbackStory(request.length_minutes),
                plan,
                request.length_minutes * 60,
                estimateSceneCount(request.length_minutes)
              )
            )
          )
        };
        logLifecycle(context, {
          component: "story_generate",
          action: "generate_story",
          phase: "blocked",
          details: {
            blocked_reason: "input_moderation"
          },
          durationMs: Date.now() - startedAt
        });
        return result;
      }

      let lastQualityIssues: string[] = [];
      for (let attempt = 0; attempt < 3; attempt += 1) {
        const story = await this.generateStoryFromModel(request, plan, attempt > 0, lastQualityIssues, context);
        const quality = evaluateStoryQuality(
          story,
          plan,
          request.length_minutes * 60,
          estimateSceneCount(request.length_minutes)
        );
        if (!quality.passed) {
          lastQualityIssues = quality.issues;
          if (attempt < 2) {
            continue;
          }

          const result: StoryGenerateResult = {
            blocked: true,
            safe_message: "I made a softer story version so we can keep things smooth and fun.",
            data: this.toGenerateResponse(
              request,
              safeFallbackStory(request.length_minutes),
              "pass",
              "flagged",
              buildEngineMetadata(
                plan,
                evaluateStoryQuality(
                  safeFallbackStory(request.length_minutes),
                  plan,
                  request.length_minutes * 60,
                  estimateSceneCount(request.length_minutes)
                )
              )
            )
          };
          logLifecycle(context, {
            component: "story_generate",
            action: "generate_story",
            phase: "blocked",
            details: {
              blocked_reason: "quality_gate",
              quality_attempts: attempt + 1
            },
            durationMs: Date.now() - startedAt
          });
          return result;
        }

        const outputModeration = await this.moderation.moderateManyText(story.scenes.map((scene) => scene.text), context);
        if (!outputModeration.flagged) {
          const continuity = await this.continuity.enrichEngine(story.title, story.scenes, plan, context);
          const result: StoryGenerateResult = {
            blocked: false,
            data: this.toGenerateResponse(
              request,
              story,
              "pass",
              "pass",
              {
                ...buildEngineMetadata(plan, quality),
                ...continuity
              }
            )
          };
          logLifecycle(context, {
            component: "story_generate",
            action: "generate_story",
            phase: "completed",
            details: {
              quality_attempts: attempt + 1,
              scene_count: story.scenes.length
            },
            durationMs: Date.now() - startedAt
          });
          return result;
        }
      }

      const result: StoryGenerateResult = {
        blocked: true,
        safe_message: "I made a softer story version so we can keep things safe and fun.",
        data: this.toGenerateResponse(
          request,
          safeFallbackStory(request.length_minutes),
          "pass",
          "flagged",
          buildEngineMetadata(
            plan,
            evaluateStoryQuality(
              safeFallbackStory(request.length_minutes),
              plan,
              request.length_minutes * 60,
              estimateSceneCount(request.length_minutes)
            )
          )
        )
      };
      logLifecycle(context, {
        component: "story_generate",
        action: "generate_story",
        phase: "blocked",
        details: {
          blocked_reason: "output_moderation"
        },
        durationMs: Date.now() - startedAt
      });
      return result;
    } catch (error) {
      logLifecycle(context, {
        component: "story_generate",
        action: "generate_story",
        phase: "failed",
        details: {
          length_minutes: request.length_minutes
        },
        durationMs: Date.now() - startedAt,
        error
      });
      throw error;
    }
  }

  async reviseStory(request: ReviseStoryRequest, context?: RequestContext): Promise<StoryReviseResult> {
    const startedAt = Date.now();
    logLifecycle(context, {
      component: "story_revise",
      action: "revise_story",
      phase: "started",
      details: {
        current_scene_index: request.current_scene_index,
        remaining_scene_count: request.remaining_scenes.length
      }
    });

    try {
      const plan = buildRevisionPlan({
        titleHint: request.story_title,
        completedScenes: request.completed_scenes,
        remainingScenes: request.remaining_scenes,
        userUpdate: request.user_update
      });

      const inputModeration = await this.moderation.moderateText(request.user_update, context);
      if (inputModeration.flagged || containsBannedTheme(request.user_update)) {
        const result: StoryReviseResult = {
          blocked: true,
          safe_message: "Let's keep the adventure gentle. Tell me a happy change instead.",
          data: {
            story_id: request.story_id,
            revised_from_scene_index: request.current_scene_index,
            scenes: request.remaining_scenes,
            safety: {
              input_moderation: "flagged",
              output_moderation: "pass"
            },
            engine: buildEngineMetadata(
              plan,
              evaluateStoryQuality(
                { title: request.story_title ?? "StoryTime", scenes: request.remaining_scenes },
                plan,
                Math.max(60, request.remaining_scenes.reduce((sum, scene) => sum + scene.duration_sec, 0)),
                request.remaining_scenes.length
              )
            )
          }
        };
        logLifecycle(context, {
          component: "story_revise",
          action: "revise_story",
          phase: "blocked",
          details: {
            blocked_reason: "unsafe_input",
            remaining_scene_count: request.remaining_scenes.length
          },
          durationMs: Date.now() - startedAt
        });
        return result;
      }

      let previousQualityIssues: string[] = [];
      for (let attempt = 0; attempt < 3; attempt += 1) {
        const revisedScenes = await this.reviseRemainingScenesFromModel(
          request,
          plan,
          attempt > 0,
          previousQualityIssues,
          context
        );
        const quality = evaluateStoryQuality(
          { title: request.story_title ?? "StoryTime", scenes: revisedScenes },
          plan,
          Math.max(60, request.remaining_scenes.reduce((sum, scene) => sum + scene.duration_sec, 0)),
          request.remaining_scenes.length
        );
        if (!quality.passed) {
          previousQualityIssues = quality.issues;
          if (attempt < 2) {
            continue;
          }

          const result: StoryReviseResult = {
            blocked: true,
            safe_message: "I kept the finished part of the story and avoided a rough rewrite.",
            data: {
              story_id: request.story_id,
              revised_from_scene_index: request.current_scene_index,
              scenes: request.remaining_scenes,
              safety: {
                input_moderation: "pass",
                output_moderation: "flagged"
              },
              engine: buildEngineMetadata(
                plan,
                evaluateStoryQuality(
                  { title: request.story_title ?? "StoryTime", scenes: request.remaining_scenes },
                  plan,
                  Math.max(60, request.remaining_scenes.reduce((sum, scene) => sum + scene.duration_sec, 0)),
                  request.remaining_scenes.length
                )
              )
            }
          };
          logLifecycle(context, {
            component: "story_revise",
            action: "revise_story",
            phase: "blocked",
            details: {
              blocked_reason: "quality_gate",
              quality_attempts: attempt + 1,
              remaining_scene_count: request.remaining_scenes.length
            },
            durationMs: Date.now() - startedAt
          });
          return result;
        }

        const outputModeration = await this.moderation.moderateManyText(revisedScenes.map((scene) => scene.text), context);
        if (!outputModeration.flagged) {
          const continuity = await this.continuity.enrichEngine(
            request.story_title ?? "StoryTime",
            revisedScenes,
            plan,
            context
          );
          const result: StoryReviseResult = {
            blocked: false,
            data: {
              story_id: request.story_id,
              revised_from_scene_index: request.current_scene_index,
              scenes: revisedScenes,
              safety: {
                input_moderation: "pass",
                output_moderation: "pass"
              },
              engine: {
                ...buildEngineMetadata(plan, quality),
                ...continuity
              }
            }
          };
          logLifecycle(context, {
            component: "story_revise",
            action: "revise_story",
            phase: "completed",
            details: {
              quality_attempts: attempt + 1,
              revised_scene_count: revisedScenes.length,
              remaining_scene_count: request.remaining_scenes.length
            },
            durationMs: Date.now() - startedAt
          });
          return result;
        }

        if (attempt < 2) {
          previousQualityIssues = ["Keep the rewrite calmer and cleaner."];
        }
      }

      const result: StoryReviseResult = {
        blocked: true,
        safe_message: "I kept your story safe and continued with the original ending.",
        data: {
          story_id: request.story_id,
          revised_from_scene_index: request.current_scene_index,
          scenes: request.remaining_scenes,
          safety: {
            input_moderation: "pass",
            output_moderation: "flagged"
          },
          engine: buildEngineMetadata(
            plan,
            evaluateStoryQuality(
              { title: request.story_title ?? "StoryTime", scenes: request.remaining_scenes },
              plan,
              Math.max(60, request.remaining_scenes.reduce((sum, scene) => sum + scene.duration_sec, 0)),
              request.remaining_scenes.length
            )
          )
        }
      };
      logLifecycle(context, {
        component: "story_revise",
        action: "revise_story",
        phase: "blocked",
        details: {
          blocked_reason: "output_moderation",
          remaining_scene_count: request.remaining_scenes.length
        },
        durationMs: Date.now() - startedAt
      });
      return result;
    } catch (error) {
      logLifecycle(context, {
        component: "story_revise",
        action: "revise_story",
        phase: "failed",
        details: {
          current_scene_index: request.current_scene_index,
          remaining_scene_count: request.remaining_scenes.length
        },
        durationMs: Date.now() - startedAt,
        error
      });
      throw error;
    }
  }

  private async generateStoryFromModel(
    request: GenerateStoryRequest,
    plan: StoryPlan,
    stricter: boolean,
    qualityIssues: string[],
    context?: RequestContext
  ): Promise<StoryScript> {
    const sceneCount = estimateSceneCount(request.length_minutes);
    const systemPrompt = buildGenerateSystemPrompt(request, stricter);
    const userPrompt = [
      `Theme: ${request.story_brief.theme}`,
      `Characters: ${request.story_brief.characters.join(", ")}`,
      `Setting: ${request.story_brief.setting}`,
      `Tone: ${request.story_brief.tone}`,
      request.story_brief.episode_intent ? `Episode intent: ${request.story_brief.episode_intent}` : null,
      request.story_brief.lesson ? `Lesson: ${request.story_brief.lesson}` : null,
      `Voice style hint: ${request.voice}`,
      `Target length: ${request.length_minutes} minutes.`,
      `Required scenes: ${sceneCount}.`,
      `Story engine plan: ${JSON.stringify(plan)}`,
      qualityIssues.length ? `Quality fixes from last attempt: ${qualityIssues.join(" | ")}` : null
    ]
      .filter(Boolean)
      .join("\n");

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
                name: "story_script",
                schema: STORY_SCHEMA,
                strict: true
              }
            }
          } as any),
        {
          retries: this.env.OPENAI_MAX_RETRIES,
          baseDelayMs: this.env.OPENAI_RETRY_BASE_MS,
          onRetry: (error, attempt, nextDelayMs) => {
            logLifecycle(context, {
              component: "story_generate",
              action: "generate_story",
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

      this.recordUsage(context, "responses.story_generate", "story_generation", attempts, Date.now() - startedAt, true);
      const jsonText = extractOutputText(result);
      if (!jsonText) {
        throw new AppError("Model returned empty response for story generation", 502, "model_empty_output");
      }

      return normalizeStory(JSON.parse(jsonText));
    } catch (error) {
      this.recordUsage(context, "responses.story_generate", "story_generation", attempts, Date.now() - startedAt, false);
      throw error;
    }
  }

  private async reviseRemainingScenesFromModel(
    request: ReviseStoryRequest,
    plan: StoryPlan,
    stricter: boolean,
    qualityIssues: string[],
    context?: RequestContext
  ): Promise<StoryScript["scenes"]> {
    const systemPrompt = buildReviseSystemPrompt(request, stricter);
    const userPrompt = JSON.stringify({
      story_title: request.story_title,
      user_update: request.user_update,
      completed_scenes: request.completed_scenes,
      revision_plan: plan,
      quality_fixes: qualityIssues,
      remaining_scenes: request.remaining_scenes
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
                name: "remaining_scene_revision",
                schema: SCENE_LIST_SCHEMA,
                strict: true
              }
            }
          } as any),
        {
          retries: this.env.OPENAI_MAX_RETRIES,
          baseDelayMs: this.env.OPENAI_RETRY_BASE_MS,
          onRetry: (error, attempt, nextDelayMs) => {
            logLifecycle(context, {
              component: "story_revise",
              action: "revise_story",
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

      this.recordUsage(context, "responses.story_revise", "revise_future_scenes", attempts, Date.now() - startedAt, true);
      const jsonText = extractOutputText(result);
      if (!jsonText) {
        throw new AppError("Model returned empty response for story revision", 502, "model_empty_output");
      }

      const parsed = JSON.parse(jsonText) as { scenes: StoryScript["scenes"] };
      if (!Array.isArray(parsed.scenes) || parsed.scenes.length === 0) {
        throw new AppError("Model returned invalid revised scenes", 502, "invalid_revision_output");
      }

      return parsed.scenes;
    } catch (error) {
      this.recordUsage(context, "responses.story_revise", "revise_future_scenes", attempts, Date.now() - startedAt, false);
      throw error;
    }
  }

  private recordUsage(
    context: RequestContext | undefined,
    operation: string,
    runtimeStage: string,
    attempts: number,
    durationMs: number,
    success: boolean
  ) {
    if (!context || (!this.env.ENABLE_STRUCTURED_ANALYTICS && !this.env.ENABLE_USAGE_METERING)) {
      return;
    }

    analytics.recordOpenAI({
      requestId: context.requestId,
      route: context.route,
      operation,
      runtimeStage,
      provider: "openai",
      model: this.env.OPENAI_RESPONSES_MODEL,
      region: context.region,
      installHash: context.installHash,
      attempts,
      durationMs,
      success
    });
  }

  private toGenerateResponse(
    request: GenerateStoryRequest,
    story: StoryScript,
    inputModeration: "pass" | "flagged",
    outputModeration: "pass" | "flagged",
    engine: StoryEngine
  ): GenerateStoryResponse {
    return {
      story_id: uuidv4(),
      title: story.title,
      estimated_duration_sec: Math.max(60, request.length_minutes * 60),
      scenes: story.scenes,
      safety: {
        input_moderation: inputModeration,
        output_moderation: outputModeration
      },
      engine
    };
  }

  private inputNarrative(request: GenerateStoryRequest): string {
    return [
      request.story_brief.theme,
      request.story_brief.setting,
      request.story_brief.tone,
      request.story_brief.episode_intent ?? "",
      request.story_brief.lesson ?? "",
      request.story_brief.characters.join(" "),
      request.continuity_facts.join(" ")
    ].join("\n");
  }
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

function normalizeStory(payload: unknown): StoryScript {
  const raw = StoryScriptSchema.parse(payload);
  return {
    title: raw.title,
    scenes: raw.scenes.map((scene, index) => ({
      scene_id: scene.scene_id || `${index + 1}`,
      text: scene.text.trim(),
      duration_sec: Math.max(10, Math.min(180, Math.round(scene.duration_sec)))
    }))
  };
}
