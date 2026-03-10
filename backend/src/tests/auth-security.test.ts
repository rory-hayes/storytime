import { describe, expect, it } from "vitest";
import { extractClientIp, extractInstallId, resolveSessionIdentityWithOptions, SESSION_HEADER } from "../lib/auth.js";
import { loadEnv } from "../lib/env.js";
import { AppError } from "../lib/errors.js";
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
