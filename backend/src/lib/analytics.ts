import fs from "node:fs";
import path from "node:path";
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
  runtimeStage?: string;
  runtimeStageGroup?: string;
  provider: "openai";
  model: string;
  region: Region;
  installHash?: string;
  sessionId?: string;
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

export type LaunchEventMetrics = {
  requestId: string;
  route: string;
  event: "entitlement_bootstrap" | "entitlement_sync" | "entitlement_preflight" | "promo_redeem";
  outcome: "issued" | "completed" | "allowed" | "blocked";
  region: Region;
  installHash?: string;
  sessionId?: string;
  refreshReason?: string;
  action?: string;
  blockReason?: string | null;
  upgradeSurface?: string | null;
  entitlementTier?: string;
  remainingStoryStarts?: number | null;
  remainingContinuations?: number | null;
};

export type AnalyticsSessionSummary = {
  request_count: number;
  request_duration_ms: number;
  openai_call_count: number;
  openai_duration_ms: number;
  openai_success_count: number;
  openai_failure_count: number;
  routes: Record<string, number>;
  runtime_stage_groups: Record<
    string,
    {
      call_count: number;
      duration_ms: number;
      success_count: number;
      failure_count: number;
    }
  >;
  launch_events: Record<string, number>;
  last_entitlement_tier: string | null;
  remaining_story_starts: number | null;
  remaining_continuations: number | null;
};

export type AnalyticsReport = {
  counters: Record<string, number>;
  sessions: Record<string, AnalyticsSessionSummary>;
};

type PersistedAnalyticsState = {
  version: 1;
  report: AnalyticsReport;
};

class UsageMeter {
  private readonly counters = new Map<string, number>();

  increment(key: string) {
    this.counters.set(key, (this.counters.get(key) ?? 0) + 1);
  }

  snapshot() {
    return Object.fromEntries(this.counters.entries());
  }

  load(snapshot: Record<string, number>) {
    this.counters.clear();
    Object.entries(snapshot).forEach(([key, value]) => {
      this.counters.set(key, value);
    });
  }

  reset() {
    this.counters.clear();
  }
}

export class AnalyticsSink {
  private readonly meter = new UsageMeter();
  private readonly sessionSummaries = new Map<string, AnalyticsSessionSummary>();
  private persistencePath?: string;

  constructor(persistencePath?: string) {
    if (persistencePath) {
      this.configurePersistence(persistencePath);
    }
  }

  configurePersistence(persistencePath?: string) {
    this.persistencePath = persistencePath;
    this.loadPersistedState();
  }

  recordRequest(metrics: RequestMetrics) {
    this.meter.increment(`http:${metrics.route}:${Math.floor(metrics.status / 100)}xx`);
    if (metrics.sessionId) {
      const summary = this.ensureSessionSummary(metrics.sessionId);
      summary.request_count += 1;
      summary.request_duration_ms += metrics.durationMs;
      incrementCounter(summary.routes, metrics.route);
    }
    this.persistState();
    logger.info({ event_type: "http_request", ...metrics }, "request completed");
  }

  recordOpenAI(metrics: OpenAIMetrics) {
    const runtimeStageGroup = metrics.runtimeStageGroup ?? mapRuntimeStageGroup(metrics.runtimeStage);
    this.meter.increment(`openai:${metrics.operation}:${metrics.success ? "success" : "failure"}`);
    if (metrics.runtimeStage) {
      this.meter.increment(`openai_stage:${metrics.runtimeStage}:${metrics.success ? "success" : "failure"}`);
    }
    if (runtimeStageGroup) {
      this.meter.increment(`openai_stage_group:${runtimeStageGroup}:${metrics.success ? "success" : "failure"}`);
    }
    if (metrics.sessionId) {
      const summary = this.ensureSessionSummary(metrics.sessionId);
      summary.openai_call_count += 1;
      summary.openai_duration_ms += metrics.durationMs;
      if (metrics.success) {
        summary.openai_success_count += 1;
      } else {
        summary.openai_failure_count += 1;
      }

      const stageKey = runtimeStageGroup ?? "supporting";
      const stageSummary = ensureStageSummary(summary.runtime_stage_groups, stageKey);
      stageSummary.call_count += 1;
      stageSummary.duration_ms += metrics.durationMs;
      if (metrics.success) {
        stageSummary.success_count += 1;
      } else {
        stageSummary.failure_count += 1;
      }
    }
    this.persistState();
    logger.info({ event_type: "openai_usage", ...metrics, runtimeStageGroup }, "openai usage");
  }

  recordSecurity(metrics: SecurityMetrics) {
    this.meter.increment(`security:${metrics.event}`);
    this.persistState();
    logger.info({ event_type: "security_event", ...metrics }, "security event");
  }

  recordLaunchEvent(metrics: LaunchEventMetrics) {
    this.meter.increment(`launch:${metrics.event}:${metrics.outcome}`);
    if (metrics.action) {
      this.meter.increment(`launch_action:${metrics.action}:${metrics.outcome}`);
    }
    if (metrics.blockReason) {
      this.meter.increment(`launch_block:${metrics.blockReason}`);
    }
    if (metrics.refreshReason) {
      this.meter.increment(`launch_refresh:${metrics.refreshReason}:${metrics.outcome}`);
    }
    if (metrics.upgradeSurface) {
      this.meter.increment(`launch_surface:${metrics.upgradeSurface}:${metrics.outcome}`);
    }

    if (metrics.sessionId) {
      const summary = this.ensureSessionSummary(metrics.sessionId);
      incrementCounter(summary.launch_events, `${metrics.event}:${metrics.outcome}`);
      if (metrics.action) {
        incrementCounter(summary.launch_events, `action:${metrics.action}:${metrics.outcome}`);
      }
      if (metrics.blockReason) {
        incrementCounter(summary.launch_events, `block:${metrics.blockReason}`);
      }
      if (metrics.upgradeSurface) {
        incrementCounter(summary.launch_events, `surface:${metrics.upgradeSurface}:${metrics.outcome}`);
      }
      if (metrics.entitlementTier) {
        summary.last_entitlement_tier = metrics.entitlementTier;
      }
      summary.remaining_story_starts = metrics.remainingStoryStarts ?? null;
      summary.remaining_continuations = metrics.remainingContinuations ?? null;
    }

    this.persistState();
    logger.info({ event_type: "launch_event", ...metrics }, "launch event");
  }

  snapshot() {
    return this.meter.snapshot();
  }

  sessionSnapshot(): Record<string, AnalyticsSessionSummary> {
    return Object.fromEntries(
      Array.from(this.sessionSummaries.entries()).map(([sessionId, summary]) => [
        sessionId,
        cloneSessionSummary(summary)
      ])
    );
  }

  report(): AnalyticsReport {
    return {
      counters: this.snapshot(),
      sessions: this.sessionSnapshot()
    };
  }

  reset(options?: { clearPersistence?: boolean }) {
    this.meter.reset();
    this.sessionSummaries.clear();

    if (options?.clearPersistence ?? true) {
      this.clearPersistedState();
    }
  }

  private ensureSessionSummary(sessionId: string): AnalyticsSessionSummary {
    const existing = this.sessionSummaries.get(sessionId);
    if (existing) {
      return existing;
    }

    const created: AnalyticsSessionSummary = {
      request_count: 0,
      request_duration_ms: 0,
      openai_call_count: 0,
      openai_duration_ms: 0,
      openai_success_count: 0,
      openai_failure_count: 0,
      routes: {},
      runtime_stage_groups: {},
      launch_events: {},
      last_entitlement_tier: null,
      remaining_story_starts: null,
      remaining_continuations: null
    };
    this.sessionSummaries.set(sessionId, created);
    return created;
  }

  private loadPersistedState() {
    this.meter.reset();
    this.sessionSummaries.clear();

    if (!this.persistencePath) {
      return;
    }

    try {
      if (!fs.existsSync(this.persistencePath)) {
        return;
      }

      const raw = fs.readFileSync(this.persistencePath, "utf8");
      const persisted = JSON.parse(raw) as PersistedAnalyticsState;
      if (persisted.version !== 1 || !persisted.report) {
        return;
      }

      this.meter.load(persisted.report.counters);
      Object.entries(persisted.report.sessions).forEach(([sessionId, summary]) => {
        this.sessionSummaries.set(sessionId, cloneSessionSummary(summary));
      });
    } catch (error) {
      logger.warn(
        {
          event_type: "analytics_persist_load_failed",
          persistence_path: this.persistencePath,
          error_message: error instanceof Error ? error.message : String(error)
        },
        "failed to load persisted analytics state"
      );
    }
  }

  private persistState() {
    if (!this.persistencePath) {
      return;
    }

    try {
      const directory = path.dirname(this.persistencePath);
      fs.mkdirSync(directory, { recursive: true });
      const persisted: PersistedAnalyticsState = {
        version: 1,
        report: this.report()
      };
      fs.writeFileSync(this.persistencePath, JSON.stringify(persisted), "utf8");
    } catch (error) {
      logger.warn(
        {
          event_type: "analytics_persist_write_failed",
          persistence_path: this.persistencePath,
          error_message: error instanceof Error ? error.message : String(error)
        },
        "failed to persist analytics state"
      );
    }
  }

  private clearPersistedState() {
    if (!this.persistencePath) {
      return;
    }

    try {
      if (fs.existsSync(this.persistencePath)) {
        fs.unlinkSync(this.persistencePath);
      }
    } catch (error) {
      logger.warn(
        {
          event_type: "analytics_persist_clear_failed",
          persistence_path: this.persistencePath,
          error_message: error instanceof Error ? error.message : String(error)
        },
        "failed to clear persisted analytics state"
      );
    }
  }
}

export const analytics = new AnalyticsSink();

function mapRuntimeStageGroup(runtimeStage?: string): string | undefined {
  switch (runtimeStage) {
    case "interaction":
    case "discovery":
    case "answer_only_interaction":
      return "interaction";
    case "story_generation":
      return "generation";
    case "tts_generation":
      return "narration";
    case "revise_future_scenes":
      return "revision";
    default:
      return undefined;
  }
}

function incrementCounter(target: Record<string, number>, key: string) {
  target[key] = (target[key] ?? 0) + 1;
}

function ensureStageSummary(
  target: AnalyticsSessionSummary["runtime_stage_groups"],
  key: string
): AnalyticsSessionSummary["runtime_stage_groups"][string] {
  const existing = target[key];
  if (existing) {
    return existing;
  }

  const created = {
    call_count: 0,
    duration_ms: 0,
    success_count: 0,
    failure_count: 0
  };
  target[key] = created;
  return created;
}

function cloneSessionSummary(summary: AnalyticsSessionSummary): AnalyticsSessionSummary {
  return {
    ...summary,
    routes: { ...summary.routes },
    runtime_stage_groups: Object.fromEntries(
      Object.entries(summary.runtime_stage_groups).map(([stage, stageSummary]) => [stage, { ...stageSummary }])
    ),
    launch_events: { ...summary.launch_events }
  };
}
