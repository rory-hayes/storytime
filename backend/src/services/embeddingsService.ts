import OpenAI from "openai";
import { analytics } from "../lib/analytics.js";
import type { Env } from "../lib/env.js";
import type { RequestContext } from "../lib/requestContext.js";
import { withRetry } from "../lib/retry.js";

export class EmbeddingsService {
  constructor(private readonly openai: OpenAI, private readonly env: Env) {}

  async createEmbeddings(inputs: string[], context?: RequestContext): Promise<number[][]> {
    const startedAt = Date.now();
    let attempts = 1;

    try {
      const { result, attempts: usedAttempts } = await withRetry(
        () =>
          this.openai.embeddings.create({
            model: this.env.OPENAI_EMBEDDINGS_MODEL,
            input: inputs
          }),
        {
          retries: this.env.OPENAI_MAX_RETRIES,
          baseDelayMs: this.env.OPENAI_RETRY_BASE_MS
        }
      );
      attempts = usedAttempts;

      if (context && (this.env.ENABLE_STRUCTURED_ANALYTICS || this.env.ENABLE_USAGE_METERING)) {
        analytics.recordOpenAI({
          requestId: context.requestId,
          route: context.route,
          operation: "embeddings.create",
          runtimeStage: "continuity_retrieval",
          provider: "openai",
          model: this.env.OPENAI_EMBEDDINGS_MODEL,
          region: context.region,
          installHash: context.installHash,
          attempts,
          durationMs: Date.now() - startedAt,
          success: true
        });
      }

      return result.data.map((item) => item.embedding);
    } catch (error) {
      if (context && (this.env.ENABLE_STRUCTURED_ANALYTICS || this.env.ENABLE_USAGE_METERING)) {
        analytics.recordOpenAI({
          requestId: context.requestId,
          route: context.route,
          operation: "embeddings.create",
          runtimeStage: "continuity_retrieval",
          provider: "openai",
          model: this.env.OPENAI_EMBEDDINGS_MODEL,
          region: context.region,
          installHash: context.installHash,
          attempts,
          durationMs: Date.now() - startedAt,
          success: false
        });
      }
      throw error;
    }
  }
}
