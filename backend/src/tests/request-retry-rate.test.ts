import { describe, expect, it, vi } from "vitest";
import { analytics } from "../lib/analytics.js";
import { createOpenAI } from "../lib/openaiClient.js";
import { SlidingWindowRateLimiter } from "../lib/rateLimiter.js";
import {
  attachRequestContext,
  getRequestContext,
  resolveRequestId,
  resolveRequestedRegion
} from "../lib/requestContext.js";
import { defaultShouldRetry, withRetry } from "../lib/retry.js";
import { makeRequest, makeRequestContext, makeTestEnv } from "./testHelpers.js";

describe("request context, retry, rate limiting, analytics", () => {
  it("resolves request ids and regions", () => {
    const env = makeTestEnv({ DEFAULT_REGION: "EU", ALLOWED_REGIONS: ["EU"] });
    const exactRequest = makeRequest({
      headers: {
        "x-request-id": "req-client-123",
        "x-storytime-region": "eu"
      }
    });
    const request = makeRequest({
      headers: {
        "x-request-id": ` ${"r".repeat(140)} `,
        "x-storytime-region": "eu"
      },
      body: { region: "US" }
    });

    expect(resolveRequestId(exactRequest)).toBe("req-client-123");
    expect(resolveRequestId(request)).toHaveLength(120);
    expect(resolveRequestedRegion(request, env)).toBe("EU");
    expect(resolveRequestedRegion(makeRequest(), env)).toBe("EU");
    expect(() => resolveRequestedRegion(makeRequest({ body: { region: "US" } }), env)).toThrowError(
      expect.objectContaining({ code: "unsupported_region" })
    );
  });

  it("attaches and retrieves request context", () => {
    const request = makeRequest();
    const context = makeRequestContext();
    attachRequestContext(request, context);
    expect(getRequestContext(request)).toEqual(context);
    expect(() => getRequestContext(makeRequest())).toThrowError(
      expect.objectContaining({ code: "missing_request_context" })
    );
  });

  it("enforces sliding window rate limits", () => {
    const limiter = new SlidingWindowRateLimiter(2, 1_000, "too_many", "Too many requests");
    vi.spyOn(Date, "now")
      .mockReturnValueOnce(1_000)
      .mockReturnValueOnce(1_100)
      .mockReturnValueOnce(1_200);

    limiter.check("voice");
    limiter.check("voice");

    expect(() => limiter.check("voice")).toThrowError(
      expect.objectContaining({ code: "too_many", status: 429 })
    );
  });

  it("retries transient failures but stops on permanent ones", async () => {
    const onRetry = vi.fn();
    const randomSpy = vi.spyOn(Math, "random").mockReturnValue(0);
    const operation = vi
      .fn<() => Promise<string>>()
      .mockRejectedValueOnce({ status: 429 })
      .mockRejectedValueOnce({ code: "ECONNRESET" })
      .mockResolvedValue("ok");

    const result = await withRetry(operation, {
      retries: 2,
      baseDelayMs: 0,
      maxDelayMs: 0,
      onRetry
    });

    expect(result).toEqual({ result: "ok", attempts: 3 });
    expect(onRetry).toHaveBeenCalledTimes(2);
    expect(defaultShouldRetry({ status: 503 })).toBe(true);
    expect(defaultShouldRetry({ status: 400 })).toBe(false);
    expect(defaultShouldRetry({ code: "ENOTFOUND" })).toBe(true);
    randomSpy.mockRestore();
  });

  it("records analytics counters and can create an OpenAI client", () => {
    const suffix = Date.now().toString();
    const before = analytics.snapshot();
    analytics.recordRequest({
      requestId: `req-${suffix}`,
      route: `/voice/${suffix}`,
      method: "POST",
      status: 200,
      durationMs: 12,
      region: "US",
      sessionId: `session-${suffix}`
    });
    analytics.recordOpenAI({
      requestId: `req-openai-${suffix}`,
      route: "/v1/realtime/call",
      operation: `realtime.call.${suffix}`,
      runtimeStage: "interaction",
      provider: "openai",
      model: "gpt-realtime",
      region: "US",
      attempts: 1,
      durationMs: 20,
      success: true
    });
    analytics.recordOpenAI({
      requestId: `req-generate-${suffix}`,
      route: "/v1/story/generate",
      operation: `responses.story_generate.${suffix}`,
      runtimeStage: "story_generation",
      provider: "openai",
      model: "gpt-4.1-mini",
      region: "US",
      attempts: 1,
      durationMs: 22,
      success: true
    });
    analytics.recordOpenAI({
      requestId: `req-support-${suffix}`,
      route: "/v1/embeddings/create",
      operation: `embeddings.create.${suffix}`,
      runtimeStage: "continuity_retrieval",
      provider: "openai",
      model: "text-embedding-3-small",
      region: "US",
      attempts: 1,
      durationMs: 10,
      success: true
    });
    analytics.recordSecurity({
      requestId: `req-security-${suffix}`,
      route: "/v1/session/identity",
      event: `session_issued_${suffix}`,
      region: "US"
    });

    const snapshot = analytics.snapshot();
    expect(snapshot[`http:/voice/${suffix}:2xx`]).toBe(1);
    expect(snapshot[`openai:realtime.call.${suffix}:success`]).toBe(1);
    expect(snapshot[`openai:responses.story_generate.${suffix}:success`]).toBe(1);
    expect((snapshot["openai_stage:interaction:success"] ?? 0) - (before["openai_stage:interaction:success"] ?? 0)).toBe(1);
    expect((snapshot["openai_stage_group:interaction:success"] ?? 0) - (before["openai_stage_group:interaction:success"] ?? 0)).toBe(1);
    expect((snapshot["openai_stage:story_generation:success"] ?? 0) - (before["openai_stage:story_generation:success"] ?? 0)).toBe(1);
    expect((snapshot["openai_stage_group:generation:success"] ?? 0) - (before["openai_stage_group:generation:success"] ?? 0)).toBe(1);
    expect((snapshot["openai_stage:continuity_retrieval:success"] ?? 0) - (before["openai_stage:continuity_retrieval:success"] ?? 0)).toBe(1);
    expect(snapshot["openai_stage_group:narration:success"]).toBe(before["openai_stage_group:narration:success"]);
    expect(snapshot[`security:session_issued_${suffix}`]).toBe(1);

    const client = createOpenAI(makeTestEnv());
    expect(client).toBeTruthy();
  });
});
