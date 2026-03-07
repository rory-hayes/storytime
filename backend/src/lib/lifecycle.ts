import { AppError } from "./errors.js";
import type { RequestContext } from "./requestContext.js";

type LifecyclePhase = "started" | "completed" | "blocked" | "retrying" | "failed";

type LifecycleDetails = Record<string, string | number | boolean | null | undefined>;

type LifecycleEvent = {
  component: string;
  action: string;
  phase: LifecyclePhase;
  details?: LifecycleDetails;
  durationMs?: number;
  attempts?: number;
  error?: unknown;
};

export function logLifecycle(context: RequestContext | undefined, event: LifecycleEvent) {
  if (!context) {
    return;
  }

  const payload: Record<string, unknown> = {
    event_type: "lifecycle_event",
    component: event.component,
    action: event.action,
    status: event.phase,
    ...event.details,
    ...safeErrorFields(event.error)
  };

  if (typeof event.durationMs === "number") {
    payload.duration_ms = event.durationMs;
  }

  if (typeof event.attempts === "number") {
    payload.attempts = event.attempts;
  }

  const message = `${event.component}.${event.action} ${event.phase}`;
  if (event.phase === "retrying" || event.phase === "failed") {
    context.logger.warn(payload, message);
    return;
  }

  context.logger.info(payload, message);
}

function safeErrorFields(error: unknown): Record<string, unknown> {
  if (!error) {
    return {};
  }

  if (error instanceof AppError) {
    return {
      error_code: error.code,
      error_status: error.status
    };
  }

  const status = (error as { status?: unknown })?.status;
  const code = (error as { code?: unknown })?.code;
  const name = error instanceof Error ? error.name : undefined;

  return {
    ...(typeof code === "string" ? { error_code: code } : {}),
    ...(typeof status === "number" ? { error_status: status } : {}),
    ...(name ? { error_name: name } : {})
  };
}
