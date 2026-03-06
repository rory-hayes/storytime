import crypto from "crypto";
import type { Request } from "express";
import type { Env, Region } from "./env.js";
import { AppError } from "./errors.js";
import { createSessionToken, hashIdentifier, verifySessionToken } from "./security.js";

export const SESSION_HEADER = "x-storytime-session";

export type SessionIdentity = {
  installId: string;
  installHash: string;
  sessionId: string;
  authLevel: "verified_session" | "install_header";
  sessionToken?: {
    token: string;
    expires_at: number;
    session_id: string;
  };
};

export function extractInstallId(req: Request): string {
  const value = req.header("x-storytime-install-id")?.trim();
  if (!value) {
    throw new AppError("Missing StoryTime install identifier", 400, "missing_install_id");
  }

  return value.slice(0, 128);
}

export function extractClientIp(request: Request): string {
  const forwarded = request.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) {
    return forwarded.split(",")[0].trim();
  }

  return request.ip || "unknown";
}

export function resolveSessionIdentity(req: Request, env: Env, region: Region): SessionIdentity {
  return resolveSessionIdentityWithOptions(req, env, region, {});
}

export function resolveSessionIdentityWithOptions(
  req: Request,
  env: Env,
  region: Region,
  options: { allowProvisional?: boolean }
): SessionIdentity {
  const installId = extractInstallId(req);
  const installHash = hashIdentifier(installId);
  const suppliedToken = req.header(SESSION_HEADER)?.trim();

  if (suppliedToken) {
    const payload = verifySessionToken(suppliedToken, installId, env);
    const remainingSeconds = payload.exp - Math.floor(Date.now() / 1_000);
    const sessionToken =
      remainingSeconds <= env.SESSION_TOKEN_REFRESH_SECONDS
        ? createSessionToken(
            {
              install_id: installId,
              session_id: payload.session_id,
              region: payload.region
            },
            env
          )
        : undefined;

    return {
      installId,
      installHash,
      sessionId: payload.session_id,
      authLevel: "verified_session",
      sessionToken
    };
  }

  if (env.API_AUTH_REQUIRED && !options.allowProvisional) {
    throw new AppError("Missing StoryTime session token", 401, "missing_session_token");
  }

  const sessionId = crypto.randomUUID();

  return {
    installId,
    installHash,
    sessionId,
    authLevel: "install_header",
    sessionToken: createSessionToken(
      {
        install_id: installId,
        session_id: sessionId,
        region
      },
      env
    )
  };
}
