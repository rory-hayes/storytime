import { setTimeout as delay } from "node:timers/promises";

export type RetryPolicy = {
  retries: number;
  baseDelayMs: number;
  maxDelayMs?: number;
  shouldRetry?: (error: unknown, attempt: number) => boolean;
  onRetry?: (error: unknown, attempt: number, nextDelayMs: number) => void;
};

export async function withRetry<T>(operation: () => Promise<T>, policy: RetryPolicy): Promise<{ result: T; attempts: number }> {
  let attempt = 0;
  let lastError: unknown;

  while (attempt <= policy.retries) {
    attempt += 1;
    try {
      const result = await operation();
      return { result, attempts: attempt };
    } catch (error) {
      lastError = error;
      const shouldRetry = attempt <= policy.retries && (policy.shouldRetry ? policy.shouldRetry(error, attempt) : defaultShouldRetry(error));
      if (!shouldRetry) {
        throw error;
      }

      const nextDelayMs = Math.min(policy.maxDelayMs ?? 4_000, policy.baseDelayMs * 2 ** (attempt - 1)) + Math.round(Math.random() * 100);
      policy.onRetry?.(error, attempt, nextDelayMs);
      await delay(nextDelayMs);
    }
  }

  throw lastError;
}

export function defaultShouldRetry(error: unknown): boolean {
  const status = extractStatusCode(error);
  if (typeof status === "number") {
    return status === 408 || status === 409 || status === 429 || status >= 500;
  }

  const code = typeof (error as { code?: unknown })?.code === "string" ? (error as { code: string }).code : undefined;
  return ["ETIMEDOUT", "ECONNRESET", "ENOTFOUND", "ECONNREFUSED"].includes(code ?? "");
}

function extractStatusCode(error: unknown): number | undefined {
  const status = (error as { status?: unknown })?.status;
  if (typeof status === "number") {
    return status;
  }

  const causeStatus = (error as { cause?: { status?: unknown } })?.cause?.status;
  if (typeof causeStatus === "number") {
    return causeStatus;
  }

  return undefined;
}
