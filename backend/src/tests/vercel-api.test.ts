import request from "supertest";
import { describe, expect, it } from "vitest";

describe("vercel api entrypoint", () => {
  it("exports a working app", async () => {
    process.env.OPENAI_API_KEY = "test-key-12345678901234567890";
    process.env.SESSION_SIGNING_SECRET = "storytime-test-signing-secret-123456789";
    process.env.AUTH_TOKEN_SECRET = "storytime-test-auth-secret-1234567890";
    process.env.NODE_ENV = "test";

    const { default: app } = await import("../../api/index.js");
    const response = await request(app).get("/health");
    expect(response.status).toBe(200);
    expect(response.body.ok).toBe(true);
  });
});
