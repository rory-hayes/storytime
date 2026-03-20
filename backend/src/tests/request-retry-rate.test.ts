import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AnalyticsSink, analytics } from "../lib/analytics.js";
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
  beforeEach(() => {
    analytics.reset();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    analytics.reset();
  });

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

  it("records analytics counters session summaries and launch events", () => {
    const suffix = Date.now().toString();
    const sessionId = `session-${suffix}`;
    analytics.recordRequest({
      requestId: `req-${suffix}`,
      route: `/voice/${suffix}`,
      method: "POST",
      status: 200,
      durationMs: 12,
      region: "US",
      sessionId
    });
    analytics.recordOpenAI({
      requestId: `req-openai-${suffix}`,
      route: "/v1/realtime/call",
      operation: `realtime.call.${suffix}`,
      runtimeStage: "interaction",
      provider: "openai",
      model: "gpt-realtime",
      region: "US",
      sessionId,
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
      sessionId,
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
      sessionId,
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
    analytics.recordLaunchEvent({
      requestId: `req-launch-${suffix}`,
      route: "/v1/entitlements/preflight",
      event: "entitlement_preflight",
      outcome: "blocked",
      region: "US",
      sessionId,
      action: "new_story",
      blockReason: "story_starts_exhausted",
      upgradeSurface: "new_story_journey",
      entitlementTier: "starter",
      remainingStoryStarts: 0,
      remainingContinuations: 2
    });

    const snapshot = analytics.snapshot();
    const report = analytics.report();
    const session = report.sessions[sessionId];
    expect(snapshot[`http:/voice/${suffix}:2xx`]).toBe(1);
    expect(snapshot[`openai:realtime.call.${suffix}:success`]).toBe(1);
    expect(snapshot[`openai:responses.story_generate.${suffix}:success`]).toBe(1);
    expect(snapshot["openai_stage:interaction:success"]).toBe(1);
    expect(snapshot["openai_stage_group:interaction:success"]).toBe(1);
    expect(snapshot["openai_stage:story_generation:success"]).toBe(1);
    expect(snapshot["openai_stage_group:generation:success"]).toBe(1);
    expect(snapshot["openai_stage:continuity_retrieval:success"]).toBe(1);
    expect(snapshot["launch:entitlement_preflight:blocked"]).toBe(1);
    expect(snapshot["launch_action:new_story:blocked"]).toBe(1);
    expect(snapshot["launch_block:story_starts_exhausted"]).toBe(1);
    expect(snapshot["launch_surface:new_story_journey:blocked"]).toBe(1);
    expect(snapshot[`security:session_issued_${suffix}`]).toBe(1);
    expect(report.counters["launch:entitlement_preflight:blocked"]).toBe(1);
    expect(session.request_count).toBe(1);
    expect(session.request_duration_ms).toBe(12);
    expect(session.openai_call_count).toBe(3);
    expect(session.openai_duration_ms).toBe(52);
    expect(session.runtime_stage_groups.interaction?.call_count).toBe(1);
    expect(session.runtime_stage_groups.generation?.call_count).toBe(1);
    expect(session.runtime_stage_groups.supporting?.call_count).toBe(1);
    expect(session.launch_events["entitlement_preflight:blocked"]).toBe(1);
    expect(session.launch_events["action:new_story:blocked"]).toBe(1);
    expect(session.launch_events["block:story_starts_exhausted"]).toBe(1);
    expect(session.launch_events["surface:new_story_journey:blocked"]).toBe(1);
    expect(session.last_entitlement_tier).toBe("starter");
    expect(session.remaining_story_starts).toBe(0);
    expect(session.remaining_continuations).toBe(2);

    const client = createOpenAI(makeTestEnv());
    expect(client).toBeTruthy();
  });

  it("reloads persisted analytics state from disk", () => {
    const persistencePath = path.join(os.tmpdir(), `storytime-analytics-persist-${Date.now()}.json`);
    const firstSink = new AnalyticsSink(persistencePath);

    firstSink.recordRequest({
      requestId: "req-persist-1",
      route: "/v1/session/identity",
      method: "POST",
      status: 200,
      durationMs: 14,
      region: "US",
      sessionId: "session-persist"
    });
    firstSink.recordLaunchEvent({
      requestId: "req-persist-launch",
      route: "/v1/entitlements/preflight",
      event: "entitlement_preflight",
      outcome: "allowed",
      region: "US",
      sessionId: "session-persist",
      action: "new_story",
      entitlementTier: "starter",
      remainingStoryStarts: 2,
      remainingContinuations: 3
    });

    const secondSink = new AnalyticsSink(persistencePath);
    const report = secondSink.report();

    expect(report.counters["http:/v1/session/identity:2xx"]).toBe(1);
    expect(report.counters["launch:entitlement_preflight:allowed"]).toBe(1);
    expect(report.sessions["session-persist"]?.request_count).toBe(1);
    expect(report.sessions["session-persist"]?.launch_events["entitlement_preflight:allowed"]).toBe(1);

    secondSink.reset();
    expect(fs.existsSync(persistencePath)).toBe(false);
  });
});
