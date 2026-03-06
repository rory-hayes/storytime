import OpenAI from "openai";
import type { Env } from "./env.js";

export function createOpenAI(env: Env): OpenAI {
  return new OpenAI({
    apiKey: env.OPENAI_API_KEY,
    maxRetries: 0,
    timeout: env.OPENAI_TIMEOUT_MS
  });
}
