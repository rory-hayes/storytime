import crypto from "crypto";
import type { Env, Region } from "./env.js";
import { AppError } from "./errors.js";

type RealtimeTicketPayload = {
  aud: "storytime.realtime";
  child_profile_id: string;
  voice: string;
  region: Region;
  install_id: string;
  exp: number;
  nonce: string;
};

type SessionTokenPayload = {
  aud: "storytime.session";
  install_id: string;
  session_id: string;
  region: Region;
  exp: number;
  iat: number;
  nonce: string;
};

export type EntitlementTier = "starter" | "plus";
export type EntitlementSource = "none" | "storekit_verified" | "debug_seed";
export type EntitlementOwner =
  | {
      kind: "install";
    }
  | {
      kind: "parent_user";
      parent_user_id: string;
      auth_provider: "firebase";
    };
export type EntitlementUsageWindow = {
  kind: "rolling_period";
  duration_seconds: number | null;
  resets_at: number | null;
};

export type EntitlementSnapshot = {
  tier: EntitlementTier;
  source: EntitlementSource;
  max_child_profiles: number;
  max_story_starts_per_period: number | null;
  max_continuations_per_period: number | null;
  max_story_length_minutes: number | null;
  can_replay_saved_stories: boolean;
  can_start_new_stories: boolean;
  can_continue_saved_series: boolean;
  effective_at: number;
  expires_at: number;
  usage_window: EntitlementUsageWindow;
  remaining_story_starts: number | null;
  remaining_continuations: number | null;
};

type EntitlementTokenPayload = {
  aud: "storytime.entitlement";
  install_id: string;
  owner: EntitlementOwner;
  snapshot: EntitlementSnapshot;
  exp: number;
  iat: number;
  nonce: string;
};

function base64url(input: Buffer | string): string {
  return Buffer.from(input)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function signValue(value: string, secret: string): string {
  return base64url(crypto.createHmac("sha256", secret).update(value).digest());
}

function decodeBase64url(input: string): string {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return Buffer.from(padded, "base64").toString("utf8");
}

function verifySignedToken<T extends { aud: string; exp: number; install_id: string }>(
  token: string,
  installId: string,
  secret: string,
  expectedAudience: T["aud"],
  errorCode: string
): T {
  const [encodedPayload, signature] = token.split(".");
  if (!encodedPayload || !signature) {
    throw new AppError("Invalid signed token", 401, errorCode);
  }

  const expected = signValue(encodedPayload, secret);
  const expectedBuffer = Buffer.from(expected);
  const providedBuffer = Buffer.from(signature);
  if (expectedBuffer.length !== providedBuffer.length || !crypto.timingSafeEqual(expectedBuffer, providedBuffer)) {
    throw new AppError("Invalid signed token signature", 401, errorCode);
  }

  const payload = JSON.parse(decodeBase64url(encodedPayload)) as T;
  if (payload.aud !== expectedAudience) {
    throw new AppError("Invalid signed token audience", 401, errorCode);
  }
  if (payload.exp < Math.floor(Date.now() / 1_000)) {
    throw new AppError("Signed token expired", 401, `${errorCode}_expired`);
  }
  if (payload.install_id !== installId) {
    throw new AppError("Signed token does not match this app install", 401, errorCode);
  }

  return payload;
}

export function hashIdentifier(value: string): string {
  return crypto.createHash("sha256").update(value).digest("hex");
}

export function createRealtimeTicket(
  payload: Omit<RealtimeTicketPayload, "aud" | "exp" | "nonce">,
  env: Env
): { ticket: string; expires_at: number } {
  const expiresAt = Math.floor(Date.now() / 1_000) + env.REALTIME_TICKET_TTL_SECONDS;
  const fullPayload: RealtimeTicketPayload = {
    aud: "storytime.realtime",
    exp: expiresAt,
    nonce: crypto.randomUUID(),
    ...payload
  };

  const encodedPayload = base64url(JSON.stringify(fullPayload));
  const signature = signValue(encodedPayload, env.SESSION_SIGNING_SECRET);
  return {
    ticket: `${encodedPayload}.${signature}`,
    expires_at: expiresAt
  };
}

export function verifyRealtimeTicket(ticket: string, installId: string, env: Env): RealtimeTicketPayload {
  return verifySignedToken<RealtimeTicketPayload>(
    ticket,
    installId,
    env.SESSION_SIGNING_SECRET,
    "storytime.realtime",
    "invalid_realtime_ticket"
  );
}

export function createSessionToken(
  payload: Omit<SessionTokenPayload, "aud" | "exp" | "iat" | "nonce">,
  env: Env
): { token: string; expires_at: number; session_id: string } {
  const issuedAt = Math.floor(Date.now() / 1_000);
  const expiresAt = issuedAt + env.SESSION_TOKEN_TTL_SECONDS;
  const fullPayload: SessionTokenPayload = {
    aud: "storytime.session",
    exp: expiresAt,
    iat: issuedAt,
    nonce: crypto.randomUUID(),
    ...payload
  };

  const encodedPayload = base64url(JSON.stringify(fullPayload));
  const signature = signValue(encodedPayload, env.AUTH_TOKEN_SECRET);
  return {
    token: `${encodedPayload}.${signature}`,
    expires_at: expiresAt,
    session_id: payload.session_id
  };
}

export function verifySessionToken(token: string, installId: string, env: Env): SessionTokenPayload {
  return verifySignedToken<SessionTokenPayload>(
    token,
    installId,
    env.AUTH_TOKEN_SECRET,
    "storytime.session",
    "invalid_session_token"
  );
}

export function createEntitlementToken(
  payload: {
    install_id: string;
    owner: EntitlementOwner;
    snapshot: Omit<EntitlementSnapshot, "effective_at" | "expires_at">;
  },
  env: Env
): { token: string; expires_at: number; snapshot: EntitlementSnapshot } {
  const issuedAt = Math.floor(Date.now() / 1_000);
  const expiresAt = issuedAt + Math.min(env.SESSION_TOKEN_TTL_SECONDS, 3600);
  const snapshot: EntitlementSnapshot = {
    ...payload.snapshot,
    effective_at: issuedAt,
    expires_at: expiresAt
  };
  const fullPayload: EntitlementTokenPayload = {
    aud: "storytime.entitlement",
    install_id: payload.install_id,
    owner: payload.owner,
    snapshot,
    exp: expiresAt,
    iat: issuedAt,
    nonce: crypto.randomUUID()
  };

  const encodedPayload = base64url(JSON.stringify(fullPayload));
  const signature = signValue(encodedPayload, env.AUTH_TOKEN_SECRET);
  return {
    token: `${encodedPayload}.${signature}`,
    expires_at: expiresAt,
    snapshot
  };
}

export function verifyEntitlementToken(token: string, installId: string, env: Env): EntitlementTokenPayload {
  return verifySignedToken<EntitlementTokenPayload>(
    token,
    installId,
    env.AUTH_TOKEN_SECRET,
    "storytime.entitlement",
    "invalid_entitlement_token"
  );
}
