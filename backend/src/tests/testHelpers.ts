import type { Request } from "express";
import os from "node:os";
import path from "node:path";
import type { Env } from "../lib/env.js";
import { logger } from "../lib/logger.js";
import type { RequestContext } from "../lib/requestContext.js";
import type pino from "pino";

export type CapturedLogEntry = {
  level: "info" | "warn" | "error";
  message: string;
  bindings: Record<string, unknown>;
};

export function makeTestEnv(overrides: Partial<Env> = {}): Env {
  return {
    NODE_ENV: "test",
    PORT: 8787,
    OPENAI_API_KEY: "test-key-12345678901234567890",
    OPENAI_RESPONSES_MODEL: "gpt-4.1",
    OPENAI_MODERATION_MODEL: "omni-moderation-latest",
    OPENAI_EMBEDDINGS_MODEL: "text-embedding-3-small",
    OPENAI_REALTIME_MODEL: "gpt-realtime",
    OPENAI_REALTIME_TRANSCRIPTION_MODEL: "gpt-4o-mini-transcribe",
    SESSION_SIGNING_SECRET: "storytime-test-signing-secret-123456789",
    AUTH_TOKEN_SECRET: "storytime-test-auth-secret-1234567890",
    REALTIME_TICKET_TTL_SECONDS: 90,
    SESSION_TOKEN_TTL_SECONDS: 86_400,
    SESSION_TOKEN_REFRESH_SECONDS: 1_800,
    REALTIME_RATE_LIMIT_WINDOW_MS: 60_000,
    REALTIME_RATE_LIMIT_MAX: 20,
    GENERAL_RATE_LIMIT_WINDOW_MS: 60_000,
    GENERAL_RATE_LIMIT_MAX: 120,
    MODERATION_RATE_LIMIT_MAX: 60,
    DISCOVERY_RATE_LIMIT_MAX: 40,
    STORY_RATE_LIMIT_MAX: 12,
    EMBEDDINGS_RATE_LIMIT_MAX: 40,
    ALLOWED_ORIGIN: "*",
    ALLOWED_REGIONS: ["US", "EU"],
    DEFAULT_REGION: "US",
    TRUST_PROXY: false,
    API_AUTH_REQUIRED: false,
    OPENAI_MAX_RETRIES: 0,
    OPENAI_RETRY_BASE_MS: 10,
    OPENAI_TIMEOUT_MS: 5_000,
    ENABLE_USAGE_METERING: true,
    ENABLE_STRUCTURED_ANALYTICS: true,
    ANALYTICS_PERSIST_PATH: path.join(os.tmpdir(), "storytime-launch-telemetry-test.json"),
    STARTER_MAX_CHILD_PROFILES: 1,
    STARTER_MAX_STORY_STARTS_PER_PERIOD: 3,
    STARTER_MAX_CONTINUATIONS_PER_PERIOD: 3,
    STARTER_MAX_STORY_LENGTH_MINUTES: 10,
    STARTER_USAGE_WINDOW_DURATION_SECONDS: 604_800,
    PLUS_MAX_CHILD_PROFILES: 3,
    PLUS_MAX_STORY_STARTS_PER_PERIOD: 12,
    PLUS_MAX_CONTINUATIONS_PER_PERIOD: 12,
    PLUS_MAX_STORY_LENGTH_MINUTES: 10,
    PLUS_USAGE_WINDOW_DURATION_SECONDS: 604_800,
    APP_VERSION: "test",
    ...overrides
  };
}

export function makeRequestContext(overrides: Partial<RequestContext> = {}): RequestContext {
  return {
    requestId: "req-test-1",
    startedAt: Date.now(),
    ip: "127.0.0.1",
    route: "/v1/test",
    region: "US",
    installId: "install-123",
    installHash: "install-hash-123",
    sessionId: "session-123",
    authLevel: "verified_session",
    client: "test-suite",
    logger,
    ...overrides
  };
}

export function makeRequest(options?: {
  headers?: Record<string, string | undefined>;
  body?: Record<string, unknown>;
  ip?: string;
}): Request {
  const normalizedHeaders = Object.fromEntries(
    Object.entries(options?.headers ?? {}).map(([key, value]) => [key.toLowerCase(), value])
  );

  return {
    headers: normalizedHeaders,
    body: options?.body ?? {},
    ip: options?.ip ?? "127.0.0.1",
    header(name: string) {
      return normalizedHeaders[name.toLowerCase()];
    }
  } as unknown as Request;
}

export function responseWithJSON(payload: unknown) {
  return {
    output_text: JSON.stringify(payload)
  };
}

export function makeCapturedLogger() {
  const entries: CapturedLogEntry[] = [];

  const buildLogger = (baseBindings: Record<string, unknown>): pino.Logger =>
    ({
      child(bindings: Record<string, unknown>) {
        return buildLogger({ ...baseBindings, ...bindings });
      },
      info(payload: Record<string, unknown>, message: string) {
        entries.push({ level: "info", message, bindings: { ...baseBindings, ...(payload ?? {}) } });
      },
      warn(payload: Record<string, unknown>, message: string) {
        entries.push({ level: "warn", message, bindings: { ...baseBindings, ...(payload ?? {}) } });
      },
      error(payload: Record<string, unknown>, message: string) {
        entries.push({ level: "error", message, bindings: { ...baseBindings, ...(payload ?? {}) } });
      }
    }) as unknown as pino.Logger;

  return {
    logger: buildLogger({}),
    entries
  };
}
