import { AppError } from "./errors.js";

export class SlidingWindowRateLimiter {
  private readonly hits = new Map<string, number[]>();

  constructor(
    private readonly maxHits: number,
    private readonly windowMs: number,
    private readonly errorCode = "rate_limited",
    private readonly errorMessage = "Rate limit exceeded"
  ) {}

  check(key: string) {
    const now = Date.now();
    const windowStart = now - this.windowMs;
    const entries = (this.hits.get(key) ?? []).filter((timestamp) => timestamp >= windowStart);

    if (entries.length >= this.maxHits) {
      throw new AppError(this.errorMessage, 429, this.errorCode, {
        retry_after_ms: Math.max(0, this.windowMs - (now - entries[0])),
        max_hits: this.maxHits,
        window_ms: this.windowMs
      });
    }

    entries.push(now);
    this.hits.set(key, entries);
  }
}
