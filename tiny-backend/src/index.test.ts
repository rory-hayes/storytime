import request from "supertest";
import { beforeAll, describe, expect, it } from "vitest";

let createApp: (envOverride?: Record<string, string | number>) => any;

beforeAll(async () => {
  process.env.OPENAI_API_KEY = "test-key-12345678901234567890";
  const module = await import("./index.js");
  createApp = module.createApp;
});

describe("tiny backend", () => {
  it("returns scenarios", async () => {
    const app = createApp({ OPENAI_API_KEY: "test-key-12345678901234567890" });
    const response = await request(app).get("/scenarios");

    expect(response.status).toBe(200);
    expect(response.body.scenarios.length).toBeGreaterThan(0);
  });

  it("accepts session metrics", async () => {
    const app = createApp({ OPENAI_API_KEY: "test-key-12345678901234567890" });
    const response = await request(app).post("/sessionMetrics").send({
      userId: "u-1",
      sessionId: "s-1",
      scenarioId: "friendly-intro",
      overallScore: 88,
      durationSec: 95,
      attempts: 1,
      appVersion: "1.0.0"
    });

    expect(response.status).toBe(202);
    expect(response.body.accepted).toBe(true);
  });
});
