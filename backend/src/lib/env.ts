import os from "node:os";
import path from "node:path";
import { z } from "zod";

const RegionSchema = z.enum(["US", "EU"]);

const booleanish = z
  .union([z.boolean(), z.string()])
  .optional()
  .transform((value) => {
    if (typeof value === "boolean") {
      return value;
    }

    if (typeof value === "string") {
      const normalized = value.trim().toLowerCase();
      if (["1", "true", "yes", "on"].includes(normalized)) {
        return true;
      }
      if (["0", "false", "no", "off", ""].includes(normalized)) {
        return false;
      }
    }

    return undefined;
  });

const stringList = z
  .string()
  .optional()
  .transform((value) =>
    (value ?? "")
      .split(",")
      .map((entry) => entry.trim())
      .filter(Boolean)
  );

const RawEnvSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8787),
  OPENAI_API_KEY: z.string().min(20),
  OPENAI_RESPONSES_MODEL: z.string().default("gpt-4.1"),
  OPENAI_MODERATION_MODEL: z.string().default("omni-moderation-latest"),
  OPENAI_EMBEDDINGS_MODEL: z.string().default("text-embedding-3-small"),
  OPENAI_REALTIME_MODEL: z.string().default("gpt-realtime"),
  OPENAI_REALTIME_TRANSCRIPTION_MODEL: z.string().default("gpt-4o-mini-transcribe"),
  SESSION_SIGNING_SECRET: z.string().min(24).default("storytime-dev-signing-secret-change-me"),
  AUTH_TOKEN_SECRET: z.string().min(24).default("storytime-dev-auth-secret-change-me"),
  REALTIME_TICKET_TTL_SECONDS: z.coerce.number().int().min(30).max(600).default(90),
  SESSION_TOKEN_TTL_SECONDS: z.coerce.number().int().min(300).max(604800).default(86400),
  SESSION_TOKEN_REFRESH_SECONDS: z.coerce.number().int().min(30).max(86400).default(1800),
  REALTIME_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().min(1_000).max(3_600_000).default(60_000),
  REALTIME_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(200).default(20),
  GENERAL_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().min(1_000).max(3_600_000).default(60_000),
  GENERAL_RATE_LIMIT_MAX: z.coerce.number().int().min(10).max(1000).default(120),
  MODERATION_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(500).default(60),
  DISCOVERY_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(500).default(40),
  STORY_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(200).default(12),
  EMBEDDINGS_RATE_LIMIT_MAX: z.coerce.number().int().min(1).max(500).default(40),
  ALLOWED_ORIGIN: z.string().default("*"),
  ALLOWED_REGIONS: stringList,
  DEFAULT_REGION: RegionSchema.default("US"),
  TRUST_PROXY: booleanish,
  API_AUTH_REQUIRED: booleanish,
  OPENAI_MAX_RETRIES: z.coerce.number().int().min(0).max(5).default(2),
  OPENAI_RETRY_BASE_MS: z.coerce.number().int().min(50).max(10_000).default(250),
  OPENAI_TIMEOUT_MS: z.coerce.number().int().min(1_000).max(120_000).default(20_000),
  ENABLE_USAGE_METERING: booleanish,
  ENABLE_STRUCTURED_ANALYTICS: booleanish,
  ANALYTICS_PERSIST_PATH: z.string().trim().min(1).optional(),
  STARTER_MAX_CHILD_PROFILES: z.coerce.number().int().min(1).max(12).default(1),
  STARTER_MAX_STORY_STARTS_PER_PERIOD: z.coerce.number().int().min(1).max(100).default(3),
  STARTER_MAX_CONTINUATIONS_PER_PERIOD: z.coerce.number().int().min(1).max(100).default(3),
  STARTER_MAX_STORY_LENGTH_MINUTES: z.coerce.number().int().min(1).max(10).default(10),
  STARTER_USAGE_WINDOW_DURATION_SECONDS: z.coerce.number().int().min(3_600).max(31_536_000).default(604_800),
  PLUS_MAX_CHILD_PROFILES: z.coerce.number().int().min(1).max(12).default(3),
  PLUS_MAX_STORY_STARTS_PER_PERIOD: z.coerce.number().int().min(1).max(500).default(12),
  PLUS_MAX_CONTINUATIONS_PER_PERIOD: z.coerce.number().int().min(1).max(500).default(12),
  PLUS_MAX_STORY_LENGTH_MINUTES: z.coerce.number().int().min(1).max(10).default(10),
  PLUS_USAGE_WINDOW_DURATION_SECONDS: z.coerce.number().int().min(3_600).max(31_536_000).default(604_800),
  APP_VERSION: z.string().default("0.1.0")
});

const EnvSchema = RawEnvSchema.transform((raw) => {
  const allowedRegions = raw.ALLOWED_REGIONS.length > 0 ? raw.ALLOWED_REGIONS : ["US", "EU"];
  const trustProxy = raw.TRUST_PROXY ?? raw.NODE_ENV !== "development";
  const apiAuthRequired = raw.API_AUTH_REQUIRED ?? false;
  const enableUsageMetering = raw.ENABLE_USAGE_METERING ?? true;
  const enableStructuredAnalytics = raw.ENABLE_STRUCTURED_ANALYTICS ?? true;

  return {
    ...raw,
    ALLOWED_REGIONS: allowedRegions.map((region) => RegionSchema.parse(region.toUpperCase())),
    TRUST_PROXY: trustProxy,
    API_AUTH_REQUIRED: apiAuthRequired,
    ENABLE_USAGE_METERING: enableUsageMetering,
    ENABLE_STRUCTURED_ANALYTICS: enableStructuredAnalytics,
    ANALYTICS_PERSIST_PATH: path.resolve(
      raw.ANALYTICS_PERSIST_PATH ?? path.join(os.tmpdir(), "storytime-launch-telemetry.json")
    )
  };
});

export type Region = z.infer<typeof RegionSchema>;
export type Env = z.infer<typeof EnvSchema>;

export function loadEnv(raw: NodeJS.ProcessEnv = process.env): Env {
  const env = EnvSchema.parse(raw);
  assertSecureEnv(env);
  return env;
}

function assertSecureEnv(env: Env) {
  if (env.SESSION_TOKEN_REFRESH_SECONDS >= env.SESSION_TOKEN_TTL_SECONDS) {
    throw new Error("SESSION_TOKEN_REFRESH_SECONDS must be lower than SESSION_TOKEN_TTL_SECONDS.");
  }

  if (env.PLUS_MAX_CHILD_PROFILES < env.STARTER_MAX_CHILD_PROFILES) {
    throw new Error("PLUS_MAX_CHILD_PROFILES must be greater than or equal to STARTER_MAX_CHILD_PROFILES.");
  }

  if (env.PLUS_MAX_STORY_STARTS_PER_PERIOD < env.STARTER_MAX_STORY_STARTS_PER_PERIOD) {
    throw new Error("PLUS_MAX_STORY_STARTS_PER_PERIOD must be greater than or equal to STARTER_MAX_STORY_STARTS_PER_PERIOD.");
  }

  if (env.PLUS_MAX_CONTINUATIONS_PER_PERIOD < env.STARTER_MAX_CONTINUATIONS_PER_PERIOD) {
    throw new Error("PLUS_MAX_CONTINUATIONS_PER_PERIOD must be greater than or equal to STARTER_MAX_CONTINUATIONS_PER_PERIOD.");
  }

  if (env.PLUS_MAX_STORY_LENGTH_MINUTES < env.STARTER_MAX_STORY_LENGTH_MINUTES) {
    throw new Error("PLUS_MAX_STORY_LENGTH_MINUTES must be greater than or equal to STARTER_MAX_STORY_LENGTH_MINUTES.");
  }

  if (env.NODE_ENV !== "production") {
    return;
  }

  const insecureSecrets = [
    env.SESSION_SIGNING_SECRET === "storytime-dev-signing-secret-change-me",
    env.AUTH_TOKEN_SECRET === "storytime-dev-auth-secret-change-me"
  ];

  if (insecureSecrets.some(Boolean)) {
    throw new Error("Production secrets are using development defaults. Set secure SESSION_SIGNING_SECRET and AUTH_TOKEN_SECRET.");
  }

  if (!env.ALLOWED_REGIONS.includes(env.DEFAULT_REGION)) {
    throw new Error("DEFAULT_REGION must be included in ALLOWED_REGIONS.");
  }

  if (env.ALLOWED_ORIGIN === "*") {
    throw new Error("ALLOWED_ORIGIN must be explicit in production.");
  }

  if (!env.API_AUTH_REQUIRED) {
    throw new Error("API_AUTH_REQUIRED must be enabled in production.");
  }
}
