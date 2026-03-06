import { logger } from "./logger.js";
import type { Region } from "./env.js";

export type RequestMetrics = {
  requestId: string;
  route: string;
  method: string;
  status: number;
  durationMs: number;
  region: Region;
  installHash?: string;
  sessionId?: string;
  authLevel?: string;
};

export type OpenAIMetrics = {
  requestId: string;
  route: string;
  operation: string;
  provider: "openai";
  model: string;
  region: Region;
  installHash?: string;
  attempts: number;
  durationMs: number;
  success: boolean;
  fallbackUsed?: boolean;
};

export type SecurityMetrics = {
  requestId: string;
  route: string;
  event: string;
  region: Region;
  installHash?: string;
  authLevel?: string;
};

class UsageMeter {
  private readonly counters = new Map<string, number>();

  increment(key: string) {
    this.counters.set(key, (this.counters.get(key) ?? 0) + 1);
  }

  snapshot() {
    return Object.fromEntries(this.counters.entries());
  }
}

class AnalyticsSink {
  private readonly meter = new UsageMeter();

  recordRequest(metrics: RequestMetrics) {
    this.meter.increment(`http:${metrics.route}:${Math.floor(metrics.status / 100)}xx`);
    logger.info({ event_type: "http_request", ...metrics }, "request completed");
  }

  recordOpenAI(metrics: OpenAIMetrics) {
    this.meter.increment(`openai:${metrics.operation}:${metrics.success ? "success" : "failure"}`);
    logger.info({ event_type: "openai_usage", ...metrics }, "openai usage");
  }

  recordSecurity(metrics: SecurityMetrics) {
    this.meter.increment(`security:${metrics.event}`);
    logger.info({ event_type: "security_event", ...metrics }, "security event");
  }

  snapshot() {
    return this.meter.snapshot();
  }
}

export const analytics = new AnalyticsSink();
