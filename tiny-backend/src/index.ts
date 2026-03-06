import "dotenv/config";

import cors from "cors";
import express from "express";
import rateLimit from "express-rate-limit";
import helmet from "helmet";
import OpenAI from "openai";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { z } from "zod";

const EnvSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  OPENAI_API_KEY: z.string().min(20),
  OPENAI_ANALYSIS_MODEL: z.string().default("gpt-4o-mini"),
  OPENAI_TRANSCRIBE_MODEL: z.string().default("gpt-4o-mini-transcribe"),
  RATE_LIMIT_MAX: z.coerce.number().int().min(1).default(120),
  ALLOWED_ORIGIN: z.string().default("*"),
  SUPABASE_URL: z.string().url().optional(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().optional()
});

type Env = z.infer<typeof EnvSchema>;

const AnalyzeSpeechSchema = z
  .object({
    userId: z.string().min(1),
    sessionId: z.string().min(1),
    scenarioId: z.string().min(1),
    transcript: z.string().min(1).max(12_000).optional(),
    audioBase64: z.string().min(1).optional(),
    mimeType: z.string().default("audio/wav")
  })
  .refine((data) => Boolean(data.transcript) || Boolean(data.audioBase64), {
    message: "Either transcript or audioBase64 must be provided"
  });

const SessionMetricsSchema = z.object({
  userId: z.string().min(1),
  sessionId: z.string().min(1),
  scenarioId: z.string().min(1),
  overallScore: z.number().min(0).max(100),
  durationSec: z.number().int().min(0).max(7200),
  attempts: z.number().int().min(1).max(20).default(1),
  appVersion: z.string().min(1),
  timestamp: z.string().datetime().optional()
});

type Scenario = {
  id: string;
  title: string;
  difficulty: string;
  goal: string;
  prompt: string;
};

type SessionMetric = z.infer<typeof SessionMetricsSchema>;

function loadScenarios(): Scenario[] {
  const raw = readFileSync(join(process.cwd(), "data", "scenarios.json"), "utf8");
  return JSON.parse(raw) as Scenario[];
}

function createSupabase(env: Env): SupabaseClient | null {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    return null;
  }
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false }
  });
}

const inMemoryMetrics: SessionMetric[] = [];

export function createApp(envOverride?: Partial<Env>) {
  const env = EnvSchema.parse({ ...process.env, ...envOverride });
  const openai = new OpenAI({ apiKey: env.OPENAI_API_KEY });
  const supabase = createSupabase(env);
  const scenarios = loadScenarios();

  const app = express();
  app.use(helmet());
  app.use(cors({ origin: env.ALLOWED_ORIGIN === "*" ? true : env.ALLOWED_ORIGIN.split(",") }));
  app.use(express.json({ limit: "8mb" }));

  app.use(
    rateLimit({
      windowMs: 60_000,
      max: env.RATE_LIMIT_MAX,
      standardHeaders: true,
      legacyHeaders: false
    })
  );

  app.get("/health", (_req, res) => {
    res.json({ ok: true, service: "storytime-tiny-backend" });
  });

  app.get("/scenarios", (_req, res) => {
    res.json({ scenarios });
  });

  app.post("/analyzeSpeech", async (req, res) => {
    const parsed = AnalyzeSpeechSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: "invalid_request", details: parsed.error.flatten() });
    }

    const body = parsed.data;
    const scenario = scenarios.find((item) => item.id == body.scenarioId);
    if (!scenario) {
      return res.status(404).json({ error: "scenario_not_found" });
    }

    let transcript = body.transcript?.trim() ?? "";
    if (!transcript && body.audioBase64) {
      const audioBytes = Buffer.from(body.audioBase64, "base64");
      const audioFile = new File([audioBytes], "session-audio.wav", { type: body.mimeType });
      const transcription = await openai.audio.transcriptions.create({
        file: audioFile,
        model: env.OPENAI_TRANSCRIBE_MODEL
      });
      transcript = transcription.text;
    }

    const moderation = await openai.moderations.create({
      model: "omni-moderation-latest",
      input: transcript
    });

    const flagged = Boolean(moderation.results[0]?.flagged);
    if (flagged) {
      return res.status(422).json({
        flagged: true,
        coaching: ["Try a kinder and safer response, then attempt again."],
        score: { clarity: 0, confidence: 0, structure: 0, overall: 0 }
      });
    }

    const analysisResponse = await openai.responses.create({
      model: env.OPENAI_ANALYSIS_MODEL,
      input: [
        {
          role: "system",
          content:
            "You are a speech coach for children. Score clarity, confidence, and structure from 0-100 and give 3 short coaching tips. Return strict JSON only."
        },
        {
          role: "user",
          content: JSON.stringify({
            scenario,
            transcript
          })
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "speech_analysis",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              score: {
                type: "object",
                additionalProperties: false,
                properties: {
                  clarity: { type: "integer", minimum: 0, maximum: 100 },
                  confidence: { type: "integer", minimum: 0, maximum: 100 },
                  structure: { type: "integer", minimum: 0, maximum: 100 },
                  overall: { type: "integer", minimum: 0, maximum: 100 }
                },
                required: ["clarity", "confidence", "structure", "overall"]
              },
              coaching: {
                type: "array",
                items: { type: "string" },
                minItems: 1,
                maxItems: 3
              }
            },
            required: ["score", "coaching"]
          }
        }
      }
    } as any);

    const resultText = analysisResponse.output_text ?? "{}";
    const analysis = JSON.parse(resultText) as {
      score: { clarity: number; confidence: number; structure: number; overall: number };
      coaching: string[];
    };

    return res.json({
      userId: body.userId,
      sessionId: body.sessionId,
      scenarioId: scenario.id,
      transcript,
      flagged: false,
      score: analysis.score,
      coaching: analysis.coaching
    });
  });

  app.post("/sessionMetrics", async (req, res) => {
    const parsed = SessionMetricsSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: "invalid_request", details: parsed.error.flatten() });
    }

    const payload: SessionMetric = {
      ...parsed.data,
      timestamp: parsed.data.timestamp ?? new Date().toISOString()
    };

    if (supabase) {
      const { error } = await supabase.from("session_metrics").insert({
        user_id: payload.userId,
        session_id: payload.sessionId,
        scenario_id: payload.scenarioId,
        overall_score: payload.overallScore,
        duration_sec: payload.durationSec,
        attempts: payload.attempts,
        app_version: payload.appVersion,
        timestamp: payload.timestamp
      });

      if (error) {
        return res.status(500).json({ error: "metrics_persist_failed", detail: error.message });
      }
    } else {
      inMemoryMetrics.push(payload);
    }

    return res.status(202).json({ accepted: true });
  });

  return app;
}

const app = createApp();
export default app;

if (process.env.NODE_ENV !== "test" && !process.env.VERCEL) {
  const env = EnvSchema.parse(process.env);
  app.listen(env.PORT, () => {
    console.log(`Tiny backend listening on port ${env.PORT}`);
  });
}
