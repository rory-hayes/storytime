import crypto from "crypto";
import type pino from "pino";
import type { Request } from "express";
import type { Env, Region } from "./env.js";
import { AppError } from "./errors.js";
import type { SessionIdentity } from "./auth.js";
import type { ParentIdentity } from "./parentIdentity.js";

export type RequestContext = {
  requestId: string;
  startedAt: number;
  ip: string;
  route: string;
  region: Region;
  installId: string;
  installHash: string;
  sessionId: string;
  authLevel: SessionIdentity["authLevel"];
  parentIdentity: ParentIdentity | null;
  client: string;
  logger: pino.Logger;
};

declare global {
  namespace Express {
    interface Request {
      context?: RequestContext;
    }
  }
}

export function resolveRequestId(req: Request): string {
  const existing = req.header("x-request-id")?.trim();
  return existing?.slice(0, 120) || crypto.randomUUID();
}

export function resolveRequestedRegion(req: Request, env: Env): Region {
  const headerRegion = req.header("x-storytime-region")?.trim().toUpperCase();
  const bodyRegion = typeof req.body?.region === "string" ? req.body.region.trim().toUpperCase() : undefined;
  const candidate = (headerRegion || bodyRegion || env.DEFAULT_REGION) as Region;

  if (!env.ALLOWED_REGIONS.includes(candidate)) {
    throw new AppError("Unsupported processing region", 403, "unsupported_region", {
      requested_region: candidate,
      allowed_regions: env.ALLOWED_REGIONS
    });
  }

  return candidate;
}

export function attachRequestContext(req: Request, context: RequestContext) {
  req.context = context;
}

export function getRequestContext(req: Request): RequestContext {
  if (!req.context) {
    throw new AppError("Request context unavailable", 500, "missing_request_context");
  }

  return req.context;
}
