import { describe, expect, it } from "vitest";
import { extractClientIp, extractInstallId, resolveSessionIdentityWithOptions, SESSION_HEADER } from "../lib/auth.js";
import { loadEnv } from "../lib/env.js";
import { AppError } from "../lib/errors.js";
import {
  FirebaseParentIdentityVerifier,
  resolveOptionalParentIdentity,
  type ParentIdentityVerifier,
  PARENT_AUTH_HEADER
} from "../lib/parentIdentity.js";
import {
  createEntitlementToken,
  createRealtimeTicket,
  createSessionToken,
  hashIdentifier,
  verifyEntitlementToken,
  verifyRealtimeTicket,
  verifySessionToken
} from "../lib/security.js";
import { makeRequest, makeTestEnv } from "./testHelpers.js";

describe("auth and security", () => {
  it("extracts install ids and client ip safely", () => {
    const request = makeRequest({
      headers: {
        "x-storytime-install-id": ` ${"a".repeat(140)} `,
        "x-forwarded-for": "203.0.113.5, 10.0.0.1"
      },
      ip: "127.0.0.1"
    });

    expect(extractInstallId(request)).toHaveLength(128);
    expect(extractClientIp(request)).toBe("203.0.113.5");
  });

  it("rejects missing install ids", () => {
    expect(() => extractInstallId(makeRequest())).toThrow(AppError);
  });

  it("issues provisional session identity when auth is not required", () => {
    const env = makeTestEnv({ API_AUTH_REQUIRED: false });
    const request = makeRequest({ headers: { "x-storytime-install-id": "install-123" } });

    const identity = resolveSessionIdentityWithOptions(request, env, "US", {});

    expect(identity.authLevel).toBe("install_header");
    expect(identity.sessionToken?.token).toBeTruthy();
    expect(identity.installHash).toBe(hashIdentifier("install-123"));
  });

  it("rejects missing session tokens when strict auth is enabled", () => {
    const env = makeTestEnv({ API_AUTH_REQUIRED: true });
    const request = makeRequest({ headers: { "x-storytime-install-id": "install-123" } });

    expect(() => resolveSessionIdentityWithOptions(request, env, "US", {})).toThrowError(
      expect.objectContaining({ code: "missing_session_token" })
    );
  });

  it("verifies session tokens and only refreshes them inside the refresh window", () => {
    const steadyEnv = makeTestEnv({ SESSION_TOKEN_TTL_SECONDS: 600, SESSION_TOKEN_REFRESH_SECONDS: 120 });
    const steadyIssued = createSessionToken(
      {
        install_id: "install-123",
        session_id: "session-abc",
        region: "US"
      },
      steadyEnv
    );

    const steadyRequest = makeRequest({
      headers: {
        "x-storytime-install-id": "install-123",
        [SESSION_HEADER]: steadyIssued.token
      }
    });

    const steadyIdentity = resolveSessionIdentityWithOptions(steadyRequest, steadyEnv, "US", {});

    expect(steadyIdentity.authLevel).toBe("verified_session");
    expect(steadyIdentity.sessionId).toBe("session-abc");
    expect(steadyIdentity.sessionToken).toBeUndefined();

    const refreshEnv = makeTestEnv({ SESSION_TOKEN_TTL_SECONDS: 60, SESSION_TOKEN_REFRESH_SECONDS: 120 });
    const refreshIssued = createSessionToken(
      {
        install_id: "install-123",
        session_id: "session-refresh",
        region: "US"
      },
      refreshEnv
    );

    const refreshRequest = makeRequest({
      headers: {
        "x-storytime-install-id": "install-123",
        [SESSION_HEADER]: refreshIssued.token
      }
    });

    const refreshIdentity = resolveSessionIdentityWithOptions(refreshRequest, refreshEnv, "US", {});

    expect(refreshIdentity.authLevel).toBe("verified_session");
    expect(refreshIdentity.sessionId).toBe("session-refresh");
    expect(refreshIdentity.sessionToken?.token).toBeTruthy();
  });

  it("creates and verifies realtime tickets and session tokens", () => {
    const env = makeTestEnv();
    const realtime = createRealtimeTicket(
      {
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        voice: "alloy",
        region: "US",
        install_id: "install-123"
      },
      env
    );
    const session = createSessionToken(
      {
        install_id: "install-123",
        session_id: "session-xyz",
        region: "US"
      },
      env
    );

    expect(verifyRealtimeTicket(realtime.ticket, "install-123", env).voice).toBe("alloy");
    expect(verifySessionToken(session.token, "install-123", env).session_id).toBe("session-xyz");
  });

  it("creates and verifies entitlement snapshot tokens", () => {
    const env = makeTestEnv();
    const issued = createEntitlementToken(
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

    const verified = verifyEntitlementToken(issued.token, "install-123", env);

    expect(verified.snapshot.tier).toBe("starter");
    expect(verified.snapshot.max_child_profiles).toBe(1);
    expect(verified.snapshot.can_replay_saved_stories).toBe(true);
    expect(verified.snapshot.expires_at).toBe(issued.expires_at);
    expect(verified.owner).toEqual({ kind: "install" });
  });

  it("returns no parent identity when the parent auth header is absent", async () => {
    const identity = await resolveOptionalParentIdentity(makeRequest(), makeTestEnv(), new StubParentIdentityVerifier());

    expect(identity).toBeNull();
  });

  it("verifies parent auth headers through the configured parent identity verifier", async () => {
    const request = makeRequest({
      headers: {
        [PARENT_AUTH_HEADER]: "parent-token-123"
      }
    });

    const identity = await resolveOptionalParentIdentity(request, makeTestEnv(), new StubParentIdentityVerifier());

    expect(identity).toEqual({
      uid: "parent-user-123",
      provider: "firebase"
    });
  });

  it("uses project-id verification when Firebase admin credentials are absent", async () => {
    const verifier = new FirebaseParentIdentityVerifier({
      verifyWithProjectID: async (token, projectID) => {
        expect(token).toBe("project-only-token");
        expect(projectID).toBe("storytime-test");
        return {
          uid: "parent-user-project-only",
          provider: "firebase"
        };
      },
      verifyWithFirebaseAdmin: async () => {
        throw new Error("firebase-admin verifier should not be used");
      }
    });

    const identity = await verifier.verifyParentToken(
      "project-only-token",
      makeTestEnv({
        FIREBASE_PROJECT_ID: "storytime-test",
        FIREBASE_CLIENT_EMAIL: undefined,
        FIREBASE_PRIVATE_KEY: undefined
      })
    );

    expect(identity).toEqual({
      uid: "parent-user-project-only",
      provider: "firebase"
    });
  });

  it("uses firebase-admin verification when full Firebase admin credentials are present", async () => {
    const verifier = new FirebaseParentIdentityVerifier({
      verifyWithFirebaseAdmin: async (token, env) => {
        expect(token).toBe("admin-token");
        expect(env.FIREBASE_PROJECT_ID).toBe("storytime-test");
        return {
          uid: "parent-user-admin",
          provider: "firebase"
        };
      },
      verifyWithProjectID: async () => {
        throw new Error("project-id verifier should not be used");
      }
    });

    const identity = await verifier.verifyParentToken(
      "admin-token",
      makeTestEnv({
        FIREBASE_PROJECT_ID: "storytime-test",
        FIREBASE_CLIENT_EMAIL: "firebase-adminsdk@test.invalid",
        FIREBASE_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\\npretend\\n-----END PRIVATE KEY-----\\n"
      })
    );

    expect(identity).toEqual({
      uid: "parent-user-admin",
      provider: "firebase"
    });
  });

  it("returns parent auth unavailable only when Firebase verification is entirely unconfigured", async () => {
    const verifier = new FirebaseParentIdentityVerifier();

    await expect(verifier.verifyParentToken("any-token", makeTestEnv())).rejects.toSatisfy(
      (error: unknown) =>
        error instanceof AppError && error.code === "parent_auth_unavailable" && error.status === 503
    );
  });

  it("rejects tampered or expired tokens", () => {
    const env = makeTestEnv();
    const issued = createSessionToken(
      {
        install_id: "install-123",
        session_id: "session-xyz",
        region: "US"
      },
      env
    );
    const tampered = `${issued.token.slice(0, -1)}x`;
    const expiredEnv = makeTestEnv({ SESSION_TOKEN_TTL_SECONDS: -1 });
    const expired = createSessionToken(
      {
        install_id: "install-123",
        session_id: "session-expired",
        region: "US"
      },
      expiredEnv
    );

    expect(() => verifySessionToken(tampered, "install-123", env)).toThrowError(
      expect.objectContaining({ code: "invalid_session_token" })
    );
    expect(() => verifySessionToken(expired.token, "install-123", expiredEnv)).toThrowError(
      expect.objectContaining({ code: "invalid_session_token_expired" })
    );
    expect(() => verifyRealtimeTicket("bad.ticket", "install-123", env)).toThrowError();
  });

  it("parses env booleans and enforces production secret hygiene", () => {
    const env = loadEnv({
      NODE_ENV: "development",
      OPENAI_API_KEY: "test-key-12345678901234567890",
      SESSION_SIGNING_SECRET: "custom-signing-secret-1234567890",
      AUTH_TOKEN_SECRET: "custom-auth-secret-1234567890",
      ALLOWED_REGIONS: "eu,us",
      TRUST_PROXY: "true",
      API_AUTH_REQUIRED: "yes"
    });

    expect(env.ALLOWED_REGIONS).toEqual(["EU", "US"]);
    expect(env.TRUST_PROXY).toBe(true);
    expect(env.API_AUTH_REQUIRED).toBe(true);

    expect(() =>
      loadEnv({
        NODE_ENV: "production",
        OPENAI_API_KEY: "test-key-12345678901234567890"
      })
    ).toThrow(/Production secrets/);
  });
});

class StubParentIdentityVerifier implements ParentIdentityVerifier {
  async verifyParentToken(token: string) {
    if (token !== "parent-token-123") {
      throw new AppError("Invalid parent account token", 401, "invalid_parent_auth");
    }

    return {
      uid: "parent-user-123",
      provider: "firebase" as const
    };
  }
}
