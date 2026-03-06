import OpenAI from "openai";
import { analytics } from "../lib/analytics.js";
import type { Env } from "../lib/env.js";
import type { RequestContext } from "../lib/requestContext.js";
import { withRetry } from "../lib/retry.js";
import type { ModerationVerdict } from "../types.js";

export class ModerationService {
  constructor(private readonly openai: OpenAI, private readonly env: Env) {}

  async moderateText(text: string, context?: RequestContext): Promise<ModerationVerdict> {
    const startedAt = Date.now();
    let attempts = 1;

    try {
      const { result, attempts: usedAttempts } = await withRetry(
        () =>
          this.openai.moderations.create({
            model: this.env.OPENAI_MODERATION_MODEL,
            input: text
          }),
        {
          retries: this.env.OPENAI_MAX_RETRIES,
          baseDelayMs: this.env.OPENAI_RETRY_BASE_MS
        }
      );
      attempts = usedAttempts;

      const first = result.results[0];
      const categories = Object.entries(first?.categories ?? {})
        .filter(([, active]) => Boolean(active))
        .map(([name]) => name);

      this.recordUsage(context, attempts, Date.now() - startedAt, true);
      return {
        flagged: Boolean(first?.flagged),
        categories
      };
    } catch (error) {
      this.recordUsage(context, attempts, Date.now() - startedAt, false);
      throw error;
    }
  }

  async moderateManyText(chunks: string[], context?: RequestContext): Promise<ModerationVerdict> {
    const merged = chunks.join("\n\n");
    return this.moderateText(merged, context);
  }

  private recordUsage(context: RequestContext | undefined, attempts: number, durationMs: number, success: boolean) {
    if (!context || (!this.env.ENABLE_STRUCTURED_ANALYTICS && !this.env.ENABLE_USAGE_METERING)) {
      return;
    }

    analytics.recordOpenAI({
      requestId: context.requestId,
      route: context.route,
      operation: "moderation.create",
      provider: "openai",
      model: this.env.OPENAI_MODERATION_MODEL,
      region: context.region,
      installHash: context.installHash,
      attempts,
      durationMs,
      success
    });
  }
}
