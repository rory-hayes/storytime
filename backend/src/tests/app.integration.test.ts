import request from "supertest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createApp, type AppServices } from "../app.js";
import { analytics } from "../lib/analytics.js";
import { AppError } from "../lib/errors.js";
import { resetEntitlementUsageLedger } from "../lib/entitlements.js";
import type { ParentIdentityVerifier } from "../lib/parentIdentity.js";
import { createEntitlementToken } from "../lib/security.js";
import { makeTestEnv } from "./testHelpers.js";

const validRealtimeOfferSdp =
  "v=0\r\no=- 46117355 2 IN IP4 127.0.0.1\r\ns=StoryTime\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\na=fingerprint:sha-256 offer-test\r\n";
const validRealtimeAnswerSdp =
  "v=0\r\no=- 46117355 3 IN IP4 127.0.0.1\r\ns=StoryTime\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\na=fingerprint:sha-256 answer-test\r\n";

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
        answer_sdp: validRealtimeAnswerSdp
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

class StubParentIdentityVerifier implements ParentIdentityVerifier {
  async verifyParentToken(token: string) {
    if (token === "parent-token-alpha") {
      return {
        uid: "parent-alpha",
        provider: "firebase" as const
      };
    }

    if (token === "parent-token-beta") {
      return {
        uid: "parent-beta",
        provider: "firebase" as const
      };
    }

    throw new AppError("Invalid parent account token", 401, "invalid_parent_auth");
  }
}

describe("v1 API", () => {
  beforeEach(() => {
    analytics.reset();
    resetEntitlementUsageLedger();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    analytics.reset();
    resetEntitlementUsageLedger();
  });

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

  it("echoes requested region during session bootstrap", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-region", "EU")
      .send({});

    expect(response.status).toBe(200);
    expect(response.body.region).toBe("EU");
    expect(response.headers["x-storytime-region"]).toBe("EU");
    expect(response.headers["x-storytime-session"]).toBeTruthy();
    expect(response.body.entitlements.snapshot.tier).toBe("starter");
    expect(response.body.entitlements.snapshot.max_child_profiles).toBe(1);
    expect(response.body.entitlements.snapshot.can_replay_saved_stories).toBe(true);
    expect(response.body.entitlements.token).toBeTruthy();
    expect(response.body.entitlements.expires_at).toBeGreaterThan(response.body.entitlements.snapshot.effective_at);
  });

  it("allows non-production entitlement debug seeding during bootstrap", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-entitlement-seed", "plus")
      .send({});

    expect(response.status).toBe(200);
    expect(response.body.entitlements.snapshot.tier).toBe("plus");
    expect(response.body.entitlements.snapshot.source).toBe("debug_seed");
    expect(response.body.entitlements.snapshot.max_child_profiles).toBe(3);
  });

  it("refreshes entitlements from normalized purchase state", async () => {
    const app = createApp({
      env: makeTestEnv({ FIREBASE_PROJECT_ID: "storytime-test" }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        refresh_reason: "purchase",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.monthly",
            original_transaction_id: "original-1",
            latest_transaction_id: "latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "purchased",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    expect(response.status).toBe(200);
    expect(response.body.entitlements.snapshot.tier).toBe("plus");
    expect(response.body.entitlements.snapshot.source).toBe("storekit_verified");
    expect(response.body.entitlements.snapshot.max_child_profiles).toBe(3);
    expect(response.body.entitlements.token).toBeTruthy();
    expect(response.body.entitlements.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-alpha",
      auth_provider: "firebase"
    });
  });

  it("rejects purchase sync without an authenticated parent account", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .send({
        refresh_reason: "purchase",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.monthly",
            original_transaction_id: "original-1",
            latest_transaction_id: "latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "purchased",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    expect(response.status).toBe(401);
    expect(response.body.error).toBe("parent_auth_required");
    expect(response.body.message).toBe("Sign in to a parent account before purchasing Plus.");
  });

  it("restores entitlements to the signed-in parent account", async () => {
    const app = createApp({
      env: makeTestEnv({ FIREBASE_PROJECT_ID: "storytime-test" }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-restore-123")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-restore-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        refresh_reason: "restore",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "restore-original-1",
            latest_transaction_id: "restore-latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "family_shared",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    expect(response.status).toBe(200);
    expect(response.body.entitlements.snapshot.tier).toBe("plus");
    expect(response.body.entitlements.snapshot.source).toBe("storekit_verified");
    expect(response.body.entitlements.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-alpha",
      auth_provider: "firebase"
    });
  });

  it("rejects restore when this device was already restored for a different parent account", async () => {
    const app = createApp({
      env: makeTestEnv({ FIREBASE_PROJECT_ID: "storytime-test" }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });
    const alphaBootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-restore-conflict-123")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const firstRestore = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-restore-conflict-123")
      .set("x-storytime-session", alphaBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        refresh_reason: "restore",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "restore-original-1",
            latest_transaction_id: "restore-latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "family_shared",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    const betaBootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-restore-conflict-123")
      .set("x-storytime-parent-auth", "parent-token-beta")
      .send({});

    const secondRestore = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-restore-conflict-123")
      .set("x-storytime-session", betaBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-beta")
      .send({
        refresh_reason: "restore",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "restore-original-2",
            latest_transaction_id: "restore-latest-2",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "family_shared",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    expect(firstRestore.status).toBe(200);
    expect(secondRestore.status).toBe(409);
    expect(secondRestore.body.error).toBe("restore_parent_mismatch");
    expect(secondRestore.body.message).toBe(
      "This device already restored Plus for a different parent account. Sign back into that parent account to restore here again. StoryTime won't move restored access between parent accounts on the same device."
    );
  });

  it("rejects restore sync without an authenticated parent account", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-restore-123")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-restore-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .send({
        refresh_reason: "restore",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "restore-original-1",
            latest_transaction_id: "restore-latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "family_shared",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    expect(response.status).toBe(401);
    expect(response.body.error).toBe("parent_auth_required");
    expect(response.body.message).toBe("Sign in to a parent account before restoring Plus.");
  });

  it("redeems a configured promo code for the signed-in parent account", async () => {
    const app = createApp({
      env: makeTestEnv({
        FIREBASE_PROJECT_ID: "storytime-test",
        PROMO_CODE_GRANTS: [
          {
            code: "FRIENDS-PLUS-2026",
            tier: "plus",
            expires_at: Math.floor(Date.now() / 1_000) + 3_600
          }
        ]
      }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-promo-123")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/promo/redeem")
      .set("x-storytime-install-id", "install-promo-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        code: "friends-plus-2026"
      });

    expect(response.status).toBe(200);
    expect(response.body.entitlements.snapshot.tier).toBe("plus");
    expect(response.body.entitlements.snapshot.source).toBe("promo_grant");
    expect(response.body.entitlements.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-alpha",
      auth_provider: "firebase"
    });
  });

  it("rejects invalid promo codes", async () => {
    const app = createApp({
      env: makeTestEnv({ FIREBASE_PROJECT_ID: "storytime-test" }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-promo-123")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/promo/redeem")
      .set("x-storytime-install-id", "install-promo-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        code: "missing-code"
      });

    expect(response.status).toBe(404);
    expect(response.body.error).toBe("promo_code_invalid");
  });

  it("rejects already-used promo codes", async () => {
    const app = createApp({
      env: makeTestEnv({
        FIREBASE_PROJECT_ID: "storytime-test",
        PROMO_CODE_GRANTS: [
          {
            code: "ONE-TIME-PLUS",
            tier: "plus",
            expires_at: Math.floor(Date.now() / 1_000) + 3_600
          }
        ]
      }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });
    const alphaBootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-promo-alpha")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const firstResponse = await request(app)
      .post("/v1/entitlements/promo/redeem")
      .set("x-storytime-install-id", "install-promo-alpha")
      .set("x-storytime-session", alphaBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        code: "ONE-TIME-PLUS"
      });

    expect(firstResponse.status).toBe(200);

    const betaBootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-promo-beta")
      .set("x-storytime-parent-auth", "parent-token-beta")
      .send({});

    const secondResponse = await request(app)
      .post("/v1/entitlements/promo/redeem")
      .set("x-storytime-install-id", "install-promo-beta")
      .set("x-storytime-session", betaBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-beta")
      .send({
        code: "ONE-TIME-PLUS"
      });

    expect(secondResponse.status).toBe(409);
    expect(secondResponse.body.error).toBe("promo_code_already_redeemed");
  });

  it("rejects expired promo codes", async () => {
    const app = createApp({
      env: makeTestEnv({
        FIREBASE_PROJECT_ID: "storytime-test",
        PROMO_CODE_GRANTS: [
          {
            code: "EXPIRED-PLUS",
            tier: "plus",
            expires_at: Math.floor(Date.now() / 1_000) - 1
          }
        ]
      }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-promo-123")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/promo/redeem")
      .set("x-storytime-install-id", "install-promo-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        code: "EXPIRED-PLUS"
      });

    expect(response.status).toBe(410);
    expect(response.body.error).toBe("promo_code_expired");
  });

  it("persists authenticated parent-owned entitlements across installs for the same parent account", async () => {
    const app = createApp({
      env: makeTestEnv({ FIREBASE_PROJECT_ID: "storytime-test" }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });

    const firstInstallBootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const refreshed = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", firstInstallBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        refresh_reason: "purchase",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.monthly",
            original_transaction_id: "original-1",
            latest_transaction_id: "latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "purchased",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    const secondInstallBootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-456")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    expect(firstInstallBootstrap.status).toBe(200);
    expect(firstInstallBootstrap.body.entitlements.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-alpha",
      auth_provider: "firebase"
    });

    expect(refreshed.status).toBe(200);
    expect(refreshed.body.entitlements.snapshot.tier).toBe("plus");
    expect(refreshed.body.entitlements.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-alpha",
      auth_provider: "firebase"
    });

    expect(secondInstallBootstrap.status).toBe(200);
    expect(secondInstallBootstrap.body.entitlements.snapshot.tier).toBe("plus");
    expect(secondInstallBootstrap.body.entitlements.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-alpha",
      auth_provider: "firebase"
    });
  });

  it("reloads persisted parent-owned entitlements after backend recreation", async () => {
    const persistencePath = path.join(os.tmpdir(), `storytime-entitlements-reload-${Date.now()}.json`);
    const env = makeTestEnv({
      FIREBASE_PROJECT_ID: "storytime-test",
      ENTITLEMENTS_PERSIST_PATH: persistencePath
    });
    const firstApp = createApp({
      env,
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });

    const firstBootstrap = await request(firstApp)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-persist-alpha")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const synced = await request(firstApp)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-persist-alpha")
      .set("x-storytime-session", firstBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        refresh_reason: "purchase",
        active_product_ids: ["storytime.plus.monthly"],
        transactions: []
      });

    resetEntitlementUsageLedger({ clearPersistence: false });

    const reloadedApp = createApp({
      env,
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });

    const secondBootstrap = await request(reloadedApp)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-persist-beta")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    expect(synced.status).toBe(200);
    expect(secondBootstrap.status).toBe(200);
    expect(secondBootstrap.body.entitlements.snapshot.tier).toBe("plus");
    expect(secondBootstrap.body.entitlements.snapshot.source).toBe("storekit_verified");
    expect(secondBootstrap.body.entitlements.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-alpha",
      auth_provider: "firebase"
    });

    if (fs.existsSync(persistencePath)) {
      fs.unlinkSync(persistencePath);
    }
  });

  it("reloads persisted promo redemptions after backend recreation", async () => {
    const persistencePath = path.join(os.tmpdir(), `storytime-promo-reload-${Date.now()}.json`);
    const env = makeTestEnv({
      FIREBASE_PROJECT_ID: "storytime-test",
      ENTITLEMENTS_PERSIST_PATH: persistencePath,
      PROMO_CODE_GRANTS: [
        {
          code: "PERSIST-ONCE-PLUS",
          tier: "plus",
          expires_at: Math.floor(Date.now() / 1_000) + 3_600
        }
      ]
    });
    const firstApp = createApp({
      env,
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });

    const alphaBootstrap = await request(firstApp)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-persist-promo-alpha")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const redeemed = await request(firstApp)
      .post("/v1/entitlements/promo/redeem")
      .set("x-storytime-install-id", "install-persist-promo-alpha")
      .set("x-storytime-session", alphaBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        code: "PERSIST-ONCE-PLUS"
      });

    resetEntitlementUsageLedger({ clearPersistence: false });

    const reloadedApp = createApp({
      env,
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });

    const betaBootstrap = await request(reloadedApp)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-persist-promo-beta")
      .set("x-storytime-parent-auth", "parent-token-beta")
      .send({});

    const secondAttempt = await request(reloadedApp)
      .post("/v1/entitlements/promo/redeem")
      .set("x-storytime-install-id", "install-persist-promo-beta")
      .set("x-storytime-session", betaBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-beta")
      .send({
        code: "PERSIST-ONCE-PLUS"
      });

    expect(redeemed.status).toBe(200);
    expect(secondAttempt.status).toBe(409);
    expect(secondAttempt.body.error).toBe("promo_code_already_redeemed");

    if (fs.existsSync(persistencePath)) {
      fs.unlinkSync(persistencePath);
    }
  });

  it("reloads persisted restore claims after backend recreation", async () => {
    const persistencePath = path.join(os.tmpdir(), `storytime-restore-claim-reload-${Date.now()}.json`);
    const env = makeTestEnv({
      FIREBASE_PROJECT_ID: "storytime-test",
      ENTITLEMENTS_PERSIST_PATH: persistencePath
    });
    const firstApp = createApp({
      env,
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });

    const alphaBootstrap = await request(firstApp)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-persist-restore-claim")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const restored = await request(firstApp)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-persist-restore-claim")
      .set("x-storytime-session", alphaBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        refresh_reason: "restore",
        active_product_ids: ["storytime.plus.yearly"],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "restore-original-1",
            latest_transaction_id: "restore-latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "family_shared",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    resetEntitlementUsageLedger({ clearPersistence: false });

    const reloadedApp = createApp({
      env,
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });

    const betaBootstrap = await request(reloadedApp)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-persist-restore-claim")
      .set("x-storytime-parent-auth", "parent-token-beta")
      .send({});

    const conflictingRestore = await request(reloadedApp)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-persist-restore-claim")
      .set("x-storytime-session", betaBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-beta")
      .send({
        refresh_reason: "restore",
        active_product_ids: ["storytime.plus.yearly"],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "restore-original-2",
            latest_transaction_id: "restore-latest-2",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "family_shared",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    expect(restored.status).toBe(200);
    expect(conflictingRestore.status).toBe(409);
    expect(conflictingRestore.body.error).toBe("restore_parent_mismatch");

    if (fs.existsSync(persistencePath)) {
      fs.unlinkSync(persistencePath);
    }
  });

  it("rejects invalid parent auth tokens on account-owned entitlement routes", async () => {
    const app = createApp({
      env: makeTestEnv({ FIREBASE_PROJECT_ID: "storytime-test" }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });

    const response = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-parent-auth", "invalid-parent-token")
      .send({});

    expect(response.status).toBe(401);
    expect(response.body.error).toBe("invalid_parent_auth");
  });

  it("ignores stale install-owned entitlement tokens once a parent account is authenticated", async () => {
    const app = createApp({
      env: makeTestEnv({ FIREBASE_PROJECT_ID: "storytime-test" }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });

    const installOnlyBootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .send({});

    const refreshed = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", installOnlyBootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        refresh_reason: "purchase",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.monthly",
            original_transaction_id: "original-1",
            latest_transaction_id: "latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "purchased",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    const allowed = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", installOnlyBootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", installOnlyBootstrap.body.entitlements.token)
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 2,
        requested_length_minutes: 4
      });

    expect(refreshed.status).toBe(200);
    expect(refreshed.body.entitlements.snapshot.tier).toBe("plus");

    expect(allowed.status).toBe(200);
    expect(allowed.body.allowed).toBe(true);
    expect(allowed.body.snapshot.tier).toBe("plus");
    expect(allowed.body.entitlements.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-alpha",
      auth_provider: "firebase"
    });
  });

  it("allows blocked new-story preflight after purchase refresh updates the entitlement token", async () => {
    const app = createApp({
      env: makeTestEnv({ FIREBASE_PROJECT_ID: "storytime-test" }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const blocked = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", bootstrap.body.entitlements.token)
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 2,
        requested_length_minutes: 4
      });

    const refreshed = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        refresh_reason: "purchase",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.monthly",
            original_transaction_id: "original-1",
            latest_transaction_id: "latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 120,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "purchased",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    const allowed = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", refreshed.body.entitlements.token)
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 2,
        requested_length_minutes: 4
      });

    expect(blocked.status).toBe(200);
    expect(blocked.body.allowed).toBe(false);
    expect(blocked.body.block_reason).toBe("child_profile_limit");

    expect(refreshed.status).toBe(200);
    expect(refreshed.body.entitlements.snapshot.tier).toBe("plus");
    expect(refreshed.body.entitlements.token).toBeTruthy();

    expect(allowed.status).toBe(200);
    expect(allowed.body.allowed).toBe(true);
    expect(allowed.body.block_reason).toBeNull();
    expect(allowed.body.snapshot.tier).toBe("plus");
  });

  it("allows blocked new-story preflight after promo redemption updates the entitlement token", async () => {
    const app = createApp({
      env: makeTestEnv({
        FIREBASE_PROJECT_ID: "storytime-test",
        PROMO_CODE_GRANTS: [
          {
            code: "FAMILY-PLUS-2026",
            tier: "plus",
            expires_at: null
          }
        ]
      }),
      services: mockServices(),
      parentIdentityVerifier: new StubParentIdentityVerifier()
    });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-promo-retry-123")
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({});

    const blocked = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-promo-retry-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", bootstrap.body.entitlements.token)
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 2,
        requested_length_minutes: 4
      });

    const redeemed = await request(app)
      .post("/v1/entitlements/promo/redeem")
      .set("x-storytime-install-id", "install-promo-retry-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        code: "FAMILY-PLUS-2026"
      });

    const allowed = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-promo-retry-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", redeemed.body.entitlements.token)
      .set("x-storytime-parent-auth", "parent-token-alpha")
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 2,
        requested_length_minutes: 4
      });

    expect(blocked.status).toBe(200);
    expect(blocked.body.allowed).toBe(false);
    expect(blocked.body.block_reason).toBe("child_profile_limit");

    expect(redeemed.status).toBe(200);
    expect(redeemed.body.entitlements.snapshot.tier).toBe("plus");
    expect(redeemed.body.entitlements.snapshot.source).toBe("promo_grant");
    expect(redeemed.body.entitlements.token).toBeTruthy();

    expect(allowed.status).toBe(200);
    expect(allowed.body.allowed).toBe(true);
    expect(allowed.body.block_reason).toBeNull();
    expect(allowed.body.snapshot.tier).toBe("plus");
  });

  it("rejects invalid entitlement sync payloads", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .send({
        refresh_reason: "purchase",
        transactions: [
          {
            product_id: "",
            original_transaction_id: "original-1",
            latest_transaction_id: "latest-1",
            purchased_at: Math.floor(Date.now() / 1000),
            verification_state: "verified",
            is_active: true
          }
        ]
      });

    expect(response.status).toBe(400);
    expect(response.body.error).toBe("invalid_request");
  });

  it("returns an allowed entitlement preflight decision for starter launch intent", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", bootstrap.body.entitlements.token)
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 1,
        requested_length_minutes: 4
      });

    expect(response.status).toBe(200);
    expect(response.body.action).toBe("new_story");
    expect(response.body.allowed).toBe(true);
    expect(response.body.block_reason).toBeNull();
    expect(response.body.snapshot.tier).toBe("starter");
    expect(response.body.snapshot.max_child_profiles).toBe(1);
    expect(response.body.snapshot.max_story_starts_per_period).toBe(3);
    expect(response.body.snapshot.max_continuations_per_period).toBe(3);
    expect(response.body.snapshot.max_story_length_minutes).toBe(10);
    expect(response.body.snapshot.usage_window.duration_seconds).toBe(604800);
    expect(response.body.snapshot.remaining_story_starts).toBe(2);
    expect(response.body.snapshot.remaining_continuations).toBe(3);
    expect(response.body.entitlements.token).toBeTruthy();
    expect(response.body.entitlements.snapshot.remaining_story_starts).toBe(2);
  });

  it("blocks entitlement preflight when child profile count exceeds the current entitlement", async () => {
    const env = makeTestEnv();
    const app = createApp({ env, services: mockServices() });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .send({});
    const entitlement = createEntitlementToken(
      {
        install_id: "install-123",
        owner: {
          kind: "install"
        },
        snapshot: {
          tier: "starter",
          source: "none",
          max_child_profiles: 1,
          max_story_starts_per_period: null,
          max_continuations_per_period: null,
          max_story_length_minutes: null,
          can_replay_saved_stories: true,
          can_start_new_stories: true,
          can_continue_saved_series: true,
          usage_window: {
            kind: "rolling_period",
            duration_seconds: null,
            resets_at: null
          },
          remaining_story_starts: null,
          remaining_continuations: null
        }
      },
      env
    );

    const response = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", entitlement.token)
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 2,
        requested_length_minutes: 4
      });

    expect(response.status).toBe(200);
    expect(response.body.allowed).toBe(false);
    expect(response.body.block_reason).toBe("child_profile_limit");
    expect(response.body.recommended_upgrade_surface).toBe("parent_trust_center");
  });

  it("rejects invalid entitlement preflight tokens", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .send({});

    const response = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", "invalid.entitlement")
      .send({
        action: "continue_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 1,
        requested_length_minutes: 4,
        selected_series_id: "4bf7e64e-6f55-4bc4-9ff4-20e2043614a4"
      });

    expect(response.status).toBe(401);
    expect(response.body.error).toBe("invalid_entitlement_token");
  });

  it("blocks depleted new-story preflight attempts and returns refreshed entitlement state", async () => {
    const app = createApp({
      env: makeTestEnv({ STARTER_MAX_STORY_STARTS_PER_PERIOD: 1 }),
      services: mockServices()
    });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .send({});

    const first = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", bootstrap.body.entitlements.token)
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 1,
        requested_length_minutes: 4
      });

    const second = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", first.body.entitlements.token)
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 1,
        requested_length_minutes: 4
      });

    expect(first.status).toBe(200);
    expect(first.body.allowed).toBe(true);
    expect(first.body.snapshot.remaining_story_starts).toBe(0);

    expect(second.status).toBe(200);
    expect(second.body.allowed).toBe(false);
    expect(second.body.block_reason).toBe("story_starts_exhausted");
    expect(second.body.snapshot.remaining_story_starts).toBe(0);
    expect(second.body.entitlements.snapshot.remaining_story_starts).toBe(0);
  });

  it("restores depleted continuation allowance after the rolling window expires", async () => {
    const nowSpy = vi.spyOn(Date, "now").mockReturnValue(1_700_000_000_000);
    const app = createApp({
      env: makeTestEnv({
        STARTER_MAX_CONTINUATIONS_PER_PERIOD: 1,
        STARTER_USAGE_WINDOW_DURATION_SECONDS: 60
      }),
      services: mockServices()
    });
    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-123")
      .send({});

    const consumed = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", bootstrap.body.entitlements.token)
      .send({
        action: "continue_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 1,
        requested_length_minutes: 4,
        selected_series_id: "4bf7e64e-6f55-4bc4-9ff4-20e2043614a4"
      });

    nowSpy.mockReturnValue(1_700_000_061_000);
    const refreshed = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .send({
        refresh_reason: "foreground",
        active_product_ids: [],
        transactions: []
      });

    expect(consumed.status).toBe(200);
    expect(consumed.body.allowed).toBe(true);
    expect(consumed.body.snapshot.remaining_continuations).toBe(0);

    expect(refreshed.status).toBe(200);
    expect(refreshed.body.entitlements.snapshot.remaining_continuations).toBe(1);
  });

  it("exposes launch telemetry counters and session summaries through health", async () => {
    const app = createApp({
      env: makeTestEnv({ STARTER_MAX_STORY_STARTS_PER_PERIOD: 1 }),
      services: mockServices()
    });

    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-telemetry")
      .send({});

    const preflight = await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-telemetry")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", bootstrap.body.entitlements.token)
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 1,
        requested_length_minutes: 4
      });

    const sync = await request(app)
      .post("/v1/entitlements/sync")
      .set("x-storytime-install-id", "install-telemetry")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .send({
        refresh_reason: "restore",
        active_product_ids: [],
        transactions: []
      });

    const health = await request(app).get("/health");

    expect(bootstrap.status).toBe(200);
    expect(preflight.status).toBe(200);
    expect(sync.status).toBe(200);
    expect(health.status).toBe(200);
    expect(health.body.telemetry.counters["launch:entitlement_bootstrap:issued"]).toBe(1);
    expect(health.body.telemetry.counters["launch:entitlement_preflight:allowed"]).toBe(1);
    expect(health.body.telemetry.counters["launch_action:new_story:allowed"]).toBe(1);
    expect(health.body.telemetry.counters["launch:entitlement_sync:completed"]).toBe(1);
    expect(health.body.telemetry.counters["launch_refresh:restore:completed"]).toBe(1);

    const sessionSummary = health.body.telemetry.sessions[bootstrap.body.session_id];
    expect(sessionSummary).toBeTruthy();
    expect(sessionSummary.request_count).toBeGreaterThanOrEqual(3);
    expect(sessionSummary.routes["/v1/session/identity"]).toBe(1);
    expect(sessionSummary.routes["/v1/entitlements/preflight"]).toBe(1);
    expect(sessionSummary.routes["/v1/entitlements/sync"]).toBe(1);
    expect(sessionSummary.launch_events["entitlement_bootstrap:issued"]).toBe(1);
    expect(sessionSummary.launch_events["entitlement_preflight:allowed"]).toBe(1);
    expect(sessionSummary.launch_events["action:new_story:allowed"]).toBe(1);
    expect(sessionSummary.launch_events["entitlement_sync:completed"]).toBe(1);
    expect(sessionSummary.last_entitlement_tier).toBe("starter");
    expect(sessionSummary.remaining_story_starts).toBe(0);
    expect(sessionSummary.remaining_continuations).toBe(3);
  });

  it("reloads persisted backend launch telemetry after in-memory reset", async () => {
    const persistencePath = path.join(os.tmpdir(), `storytime-health-telemetry-${Date.now()}.json`);
    const env = makeTestEnv({
      ANALYTICS_PERSIST_PATH: persistencePath,
      STARTER_MAX_STORY_STARTS_PER_PERIOD: 1
    });
    const app = createApp({
      env,
      services: mockServices()
    });

    const bootstrap = await request(app)
      .post("/v1/session/identity")
      .set("x-storytime-install-id", "install-persisted-telemetry")
      .send({});

    await request(app)
      .post("/v1/entitlements/preflight")
      .set("x-storytime-install-id", "install-persisted-telemetry")
      .set("x-storytime-session", bootstrap.headers["x-storytime-session"])
      .set("x-storytime-entitlement", bootstrap.body.entitlements.token)
      .send({
        action: "new_story",
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        child_profile_count: 1,
        requested_length_minutes: 4
      });

    analytics.reset({ clearPersistence: false });

    const reloadedApp = createApp({
      env,
      services: mockServices()
    });
    const health = await request(reloadedApp).get("/health");

    expect(health.status).toBe(200);
    expect(health.body.telemetry.counters["launch:entitlement_bootstrap:issued"]).toBe(1);
    expect(health.body.telemetry.counters["launch:entitlement_preflight:allowed"]).toBe(1);
    expect(health.body.telemetry.sessions[bootstrap.body.session_id].launch_events["action:new_story:allowed"]).toBe(1);

    fs.unlinkSync(persistencePath);
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

  it("rejects missing install ids on the session identity startup route", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/session/identity");

    expect(response.status).toBe(400);
    expect(response.body.error).toBe("missing_install_id");
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

  it("rejects invalid session tokens on the realtime session startup route", async () => {
    const app = createApp({ env: makeTestEnv({ API_AUTH_REQUIRED: true }), services: mockServices() });
    const response = await request(app)
      .post("/v1/realtime/session")
      .set("x-storytime-install-id", "install-123")
      .set("x-storytime-session", "not-a-valid-session-token")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        voice: "alloy",
        region: "US"
      });

    expect(response.status).toBe(401);
    expect(response.body.error).toBe("invalid_session_token");
  });

  it("accepts a realtime call offer via the backend proxy", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/realtime/call")
      .set("x-storytime-install-id", "install-123")
      .send({
        ticket: "signed-ticket-value-long-enough",
        sdp: validRealtimeOfferSdp
      });

    expect(response.status).toBe(200);
    expect(response.body.answer_sdp).toContain("v=0");
  });

  it("rejects invalid realtime call offers before reaching the proxy", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/realtime/call")
      .set("x-storytime-install-id", "install-123")
      .send({
        ticket: "signed-ticket-value-long-enough",
        sdp: "not-an-sdp-offer"
      });

    expect(response.status).toBe(400);
    expect(response.body.error).toBe("invalid_request");
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

  it("echoes a caller supplied request id on discovery routes", async () => {
    const app = createApp({ env: makeTestEnv(), services: mockServices() });
    const response = await request(app)
      .post("/v1/story/discovery")
      .set("x-storytime-install-id", "install-123")
      .set("x-request-id", "req-client-discovery-123")
      .send({
        child_profile_id: "fbeafe23-42d5-4ea7-8035-5680419504e9",
        transcript: "I want a calm moonlit story",
        question_count: 1,
        slot_state: {
          theme: "a moonlit walk"
        },
        mode: "new"
      });

    expect(response.status).toBe(200);
    expect(response.headers["x-request-id"]).toBe("req-client-discovery-123");
    expect(response.body.request_id ?? response.headers["x-request-id"]).toBe("req-client-discovery-123");
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
    expect(response.body.message).toBe("Unexpected server error");
    expect(response.body.request_id).toBeTruthy();
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
      throw new AppError("No active revision", 409, "revision_conflict", undefined, {
        publicMessage: "Use a current scene before revising."
      });
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
    expect(response.body.message).toBe("Use a current scene before revising.");
    expect(response.body.request_id).toBeTruthy();
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
