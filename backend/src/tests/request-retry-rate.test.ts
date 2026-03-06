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
    const request = makeRequest({
      headers: {
        "x-request-id": ` ${"r".repeat(140)} `,
        "x-storytime-region": "eu"
      },
      body: { region: "US" }
    });

    expect(resolveRequestId(request)).toHaveLength(120);
    expect(resolveRequestedRegion(request, env)).toBe("EU");
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
    analytics.recordRequest({
      requestId: `req-${suffix}`,
      route: `/voice/${suffix}`,
      method: "POST",
      status: 200,
      durationMs: 12,
      region: "US"
    });
    analytics.recordOpenAI({
      requestId: `req-openai-${suffix}`,
      route: "/v1/realtime/call",
      operation: `realtime.call.${suffix}`,
      provider: "openai",
      model: "gpt-realtime",
      region: "US",
      attempts: 1,
      durationMs: 20,
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
    expect(snapshot[`security:session_issued_${suffix}`]).toBe(1);

    const client = createOpenAI(makeTestEnv());
    expect(client).toBeTruthy();
  });
});
