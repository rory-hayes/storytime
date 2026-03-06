import request from "supertest";
import { describe, expect, it } from "vitest";
import { createApp, type AppServices } from "../app.js";
import { AppError } from "../lib/errors.js";
import { makeTestEnv } from "./testHelpers.js";

function mockServices(): AppServices {
  return {
    moderation: {
      moderateText: async () => ({ flagged: false, categories: [] })
    },
    embeddings: {
      createEmbeddings: async (inputs: string[]) => inputs.map(() => [0.01, 0.02, 0.03])
    },
    discovery: {
      analyzeTurn: async (body) => ({
        blocked: false,
        data: {
          slot_state: {
            theme: body.slot_state.theme ?? "A friendly adventure",
            characters: body.slot_state.characters ?? ["Bunny"],
            setting: body.slot_state.setting ?? "Sunny Park",
            tone: body.slot_state.tone ?? "gentle and playful",
            episode_intent: body.slot_state.episode_intent ?? "a complete and happy standalone adventure"
          },
          question_count: Math.min(3, body.question_count + 1),
          ready_to_generate: false,
          assistant_message: "Who should be in the story?",
          transcript: body.transcript
        }
      })
    },
    realtime: {
      issueSessionTicket: (requestBody) => ({
        ticket: "signed-ticket",
        expires_at: Math.floor(Date.now() / 1000) + 90,
        model: "gpt-realtime",
        voice: requestBody.voice,
        input_audio_transcription_model: "gpt-4o-mini-transcribe"
      }),
      createCall: async () => ({
        answer_sdp: "v=0\r\n"
      })
    },
    story: {
      generateStory: async () => ({
        blocked: false,
        data: {
          story_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
          title: "Luna and the Sunbeam Kite",
          estimated_duration_sec: 360,
          scenes: [{ scene_id: "1", text: "A safe scene", duration_sec: 45 }],
          safety: { input_moderation: "pass", output_moderation: "pass" }
        }
      }),
      reviseStory: async (body) => ({
        blocked: false,
        data: {
          story_id: body.story_id,
          revised_from_scene_index: body.current_scene_index,
          scenes: body.remaining_scenes,
          safety: { input_moderation: "pass", output_moderation: "pass" }
        }
      })
    }
  };
}

describe("v1 API", () => {
  it("returns backend health metadata", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.allowed_regions).toEqual(["US", "EU"]);
  });

  it("returns realtime voice catalog", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app).get("/v1/voices");

    expect(response.status).toBe(200);
    expect(response.body.voices.length).toBeGreaterThan(0);
  });



  it("returns moderation verdicts", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/moderation/check")
      .set("x-storytime-install-id", "install-123")
      .send({ text: "A kind picnic in the park" });

    expect(response.status).toBe(200);
    expect(response.body.flagged).toBe(false);
  });

  it("returns embeddings for continuity retrieval", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/embeddings/create")
      .set("x-storytime-install-id", "install-123")
      .send({ inputs: ["Bunny likes lanterns"] });

    expect(response.status).toBe(200);
    expect(response.body.embeddings).toEqual([[0.01, 0.02, 0.03]]);
  });

  it("enforces auth when configured", async () => {
    const app = createApp({ env: makeTestEnv({ API_AUTH_REQUIRED: true }), services: mockServices() });
    const response = await request(app)
      .post("/v1/realtime/session")
      .set("x-storytime-install-id", "install-123")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        voice: "alloy",
        region: "US"
      });

    expect(response.status).toBe(401);
    expect(response.body.error).toBe("missing_session_token");
  });

  it("issues a signed session identity token", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123");

    expect(response.status).toBe(200);
    expect(response.body.session_token).toBeTruthy();
    expect(response.headers["x-storytime-session"]).toBeTruthy();
  });

  it("issues a realtime session ticket without exposing an OpenAI key", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/realtime/session")
      .set("x-storytime-install-id", "install-123")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        voice: "alloy",
        region: "US"
      });

    expect(response.status).toBe(200);
    expect(response.body.session.ticket).toBeTruthy();
    expect(response.body.session.client_secret).toBeUndefined();
    expect(response.headers["x-storytime-session"]).toBeTruthy();
  });

  it("accepts a realtime call offer via the backend proxy", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/realtime/call")
      .set("x-storytime-install-id", "install-123")
      .send({
        ticket: "signed-ticket-value-long-enough",
        sdp: "v=0\r\no=- 46117355 2 IN IP4 127.0.0.1\r\ns=StoryTime\r\n"
      });

    expect(response.status).toBe(200);
    expect(response.body.answer_sdp).toContain("v=0");
  });

  it("returns a discovery follow-up for transcript analysis", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/story/discovery")
      .set("x-storytime-install-id", "install-123")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        transcript: "I want a bunny and an owl in the park",
        question_count: 1,
        slot_state: {
          theme: "a lost balloon"
        },
        mode: "new"
      });

    expect(response.status).toBe(200);
    expect(response.body.data.assistant_message).toBeTruthy();
    expect(response.body.data.transcript).toContain("bunny");
    expect(response.body.request_id ?? response.headers["x-request-id"]).toBeTruthy();
  });

  it("generates a story payload with expected shape", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });

    const response = await request(app)
      .post("/v1/story/generate")
      .set("x-storytime-install-id", "install-123")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        age_band: "3-8",
        language: "en",
        length_minutes: 6,
        voice: "alloy",
        question_count: 2,
        story_brief: {
          theme: "making new friends",
          characters: ["Milo", "Pip"],
          setting: "a cloud village",
          tone: "playful",
          lesson: "sharing"
        },
        continuity_facts: ["Milo has a blue hat"]
      });

    expect(response.status).toBe(200);
    expect(response.body.data.story_id).toBeTruthy();
    expect(response.body.data.safety.input_moderation).toBe("pass");
  });

  it("rejects invalid request with question_count above cap", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });

    const response = await request(app)
      .post("/v1/story/generate")
      .set("x-storytime-install-id", "install-123")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        age_band: "3-8",
        language: "en",
        length_minutes: 6,
        voice: "alloy",
        question_count: 9,
        story_brief: {
          theme: "making new friends",
          characters: ["Milo", "Pip"],
          setting: "a cloud village",
          tone: "playful"
        },
        continuity_facts: []
      });

    expect(response.status).toBe(400);
    expect(response.body.error).toBe("invalid_request");
    expect(response.body.request_id).toBeTruthy();
  });

  it("returns revised scenes for interruption updates", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });

    const response = await request(app)
      .post("/v1/story/revise")
      .set("x-storytime-install-id", "install-123")
      .send({
        story_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        current_scene_index: 2,
        user_update: "Can the dragon be friendly?",
        remaining_scenes: [
          {
            scene_id: "3",
            text: "Old scene",
            duration_sec: 45
          }
        ]
      });

    expect(response.status).toBe(200);
    expect(response.body.data.revised_from_scene_index).toBe(2);
    expect(response.body.data.scenes.length).toBe(1);
  });

  it("returns 422 when discovery is blocked by guardrails", async () => {
    const services = mockServices();
    services.discovery.analyzeTurn = async (body) => ({
      blocked: true,
      safe_message: "Let's keep the story gentle.",
      data: {
        slot_state: {
          theme: body.slot_state.theme,
          characters: body.slot_state.characters ?? [],
          setting: body.slot_state.setting,
          tone: body.slot_state.tone,
          episode_intent: body.slot_state.episode_intent
        },
        question_count: body.question_count,
        ready_to_generate: false,
        assistant_message: "Let's keep the story gentle.",
        transcript: body.transcript
      }
    });

    const app = createApp({ env: makeTestEnv(), services });
    const response = await request(app)
      .post("/v1/story/discovery")
      .set("x-storytime-install-id", "install-123")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        transcript: "Make it scary",
        question_count: 1,
        slot_state: {},
        mode: "new"
      });

    expect(response.status).toBe(422);
    expect(response.body.safe_message).toContain("gentle");
  });

  it("returns 500 for unexpected service failures", async () => {
    const services = mockServices();
    services.story.generateStory = async () => {
      throw new Error("boom");
    };

    const app = createApp({ env: makeTestEnv(), services });
    const response = await request(app)
      .post("/v1/story/generate")
      .set("x-storytime-install-id", "install-123")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        age_band: "3-8",
        language: "en",
        length_minutes: 6,
        voice: "alloy",
        question_count: 2,
        story_brief: {
          theme: "making new friends",
          characters: ["Milo", "Pip"],
          setting: "a cloud village",
          tone: "playful"
        },
        continuity_facts: []
      });

    expect(response.status).toBe(500);
    expect(response.body.error).toBe("internal_error");
  });

  it("enforces general rate limits across authenticated routes", async () => {
    const app = createApp({
      env: makeTestEnv({ GENERAL_RATE_LIMIT_MAX: 1 }),
      services: mockServices()
    });

    const firstResponse = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123");

    const secondResponse = await request(app)
      .post("/v1/moderation/check")
      .set("x-storytime-install-id", "install-123")
      .send({ text: "A gentle story" });

    expect(firstResponse.status).toBe(200);
    expect(secondResponse.status).toBe(429);
    expect(secondResponse.body.error).toBe("rate_limited");
  });

  it("returns explicit app errors from services", async () => {
    const services = mockServices();
    services.story.reviseStory = async () => {
      throw new AppError("No active revision", 409, "revision_conflict");
    };

    const app = createApp({ env: makeTestEnv(), services });
    const response = await request(app)
      .post("/v1/story/revise")
      .set("x-storytime-install-id", "install-123")
      .send({
        story_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        current_scene_index: 2,
        user_update: "Can the dragon be friendly?",
        remaining_scenes: [
          {
            scene_id: "3",
            text: "Old scene",
            duration_sec: 45
          }
        ]
      });

    expect(response.status).toBe(409);
    expect(response.body.error).toBe("revision_conflict");
  });

  it("rejects unsupported regions", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/realtime/session")
      .set("x-storytime-install-id", "install-123")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        voice: "alloy",
        region: "APAC"
      });

    expect(response.status).toBe(403);
  });
});
