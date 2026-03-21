import cors from "cors";
import express, { type NextFunction, type Request, type Response } from "express";
import helmet from "helmet";
import { ZodError } from "zod";
import { loadEnv, type Env } from "./lib/env.js";
import { AppError } from "./lib/errors.js";
import { logger } from "./lib/logger.js";
import { createOpenAI } from "./lib/openaiClient.js";
import { analytics } from "./lib/analytics.js";
import { SESSION_HEADER, resolveSessionIdentityWithOptions } from "./lib/auth.js";
import {
  configureEntitlementPersistence,
  evaluatePreflightForRequest,
  issueBootstrapEntitlements,
  redeemPromoCodeEntitlements,
  issueSyncedEntitlements,
} from "./lib/entitlements.js";
import {
  FirebaseParentIdentityVerifier,
  resolveOptionalParentIdentity,
  type ParentIdentityVerifier
} from "./lib/parentIdentity.js";
import {
  attachRequestContext,
  getRequestContext,
  resolveRequestId,
  resolveRequestedRegion,
  type RequestContext
} from "./lib/requestContext.js";
import { SlidingWindowRateLimiter } from "./lib/rateLimiter.js";
import { createSessionToken } from "./lib/security.js";
import {
  DiscoveryRequestSchema,
  EntitlementPreflightRequestSchema,
  EmbeddingsCreateRequestSchema,
  EntitlementsSyncRequestSchema,
  GenerateStoryRequestSchema,
  ModerationCheckRequestSchema,
  PromoCodeRedemptionRequestSchema,
  RealtimeCallResponseSchema,
  RealtimeCallRequestSchema,
  RealtimeSessionRequestSchema,
  ReviseStoryRequestSchema
} from "./types.js";
import { EmbeddingsService } from "./services/embeddingsService.js";
import { normalizeGenerateRequest } from "./services/discoveryService.js";
import { ModerationService } from "./services/moderationService.js";
import { REALTIME_VOICES } from "./services/policyService.js";
import { RealtimeService } from "./services/realtimeService.js";
import { StoryContinuityService } from "./services/storyContinuityService.js";
import { StoryDiscoveryService } from "./services/storyDiscoveryService.js";
import { StoryService } from "./services/storyService.js";

export type AppServices = {
  moderation: Pick<ModerationService, "moderateText">;
  embeddings: Pick<EmbeddingsService, "createEmbeddings">;
  realtime: Pick<RealtimeService, "issueSessionTicket" | "createCall">;
  discovery: Pick<StoryDiscoveryService, "analyzeTurn">;
  story: Pick<StoryService, "generateStory" | "reviseStory">;
};

export function buildDefaultServices(env: Env): AppServices {
  const openai = createOpenAI(env);
  const moderation = new ModerationService(openai, env);
  const continuity = new StoryContinuityService(openai, env);

  return {
    moderation,
    embeddings: new EmbeddingsService(openai, env),
    realtime: new RealtimeService(env),
    discovery: new StoryDiscoveryService(openai, env, moderation),
    story: new StoryService(openai, env, moderation, continuity)
  };
}

export function createApp(opts?: { env?: Env; services?: AppServices; parentIdentityVerifier?: ParentIdentityVerifier }) {
  const env = opts?.env ?? loadEnv();
  const services = opts?.services ?? buildDefaultServices(env);
  const parentIdentityVerifier = opts?.parentIdentityVerifier ?? new FirebaseParentIdentityVerifier();
  const limiters = createRateLimiters(env);
  analytics.configurePersistence(
    env.ENABLE_USAGE_METERING || env.ENABLE_STRUCTURED_ANALYTICS ? env.ANALYTICS_PERSIST_PATH : undefined
  );
  configureEntitlementPersistence(env.ENTITLEMENTS_PERSIST_PATH);

  const app = express();
  app.set("trust proxy", env.TRUST_PROXY ? 1 : false);
  app.use(helmet());
  app.use(cors({ origin: env.ALLOWED_ORIGIN === "*" ? true : env.ALLOWED_ORIGIN.split(",") }));
  app.use(express.json({ limit: "1mb" }));
  app.use((req, res, next) => {
    const requestId = resolveRequestId(req);
    res.setHeader("x-request-id", requestId);
    res.setHeader("x-storytime-version", env.APP_VERSION);
    next();
  });
  app.use((req, res, next) => {
    const startedAt = Date.now();
    res.on("finish", () => {
      const context = req.context;
      if (env.ENABLE_STRUCTURED_ANALYTICS || env.ENABLE_USAGE_METERING) {
        analytics.recordRequest({
          requestId: res.getHeader("x-request-id")?.toString() ?? "unknown",
          route: req.path,
          method: req.method,
          status: res.statusCode,
          durationMs: Date.now() - startedAt,
          region: context?.region ?? env.DEFAULT_REGION,
          installHash: context?.installHash,
          sessionId: context?.sessionId,
          authLevel: context?.authLevel
        });
      }
    });
    next();
  });
  app.use((req, res, next) => {
    if (!requiresIdentity(req)) {
      return next();
    }

    void (async () => {
      const region = resolveRequestedRegion(req, env);
      const identity = resolveSessionIdentityWithOptions(req, env, region, {
        allowProvisional: req.path === "/v1/session/identity"
      });
      const client = req.header("x-storytime-client")?.trim().slice(0, 80) || "unknown";
      const requestId = res.getHeader("x-request-id")?.toString() ?? resolveRequestId(req);
      const parentIdentity = isAccountOwnedRoute(req)
        ? await resolveOptionalParentIdentity(req, env, parentIdentityVerifier)
        : null;
      const context: RequestContext = {
        requestId,
        startedAt: Date.now(),
        ip: req.ip || "unknown",
        route: req.path,
        region,
        installId: identity.installId,
        installHash: identity.installHash,
        sessionId: identity.sessionId,
        authLevel: identity.authLevel,
        parentIdentity,
        client,
        logger: logger.child({
          request_id: requestId,
          route: req.path,
          region,
          install_hash: identity.installHash,
          session_id: identity.sessionId,
          auth_level: identity.authLevel,
          parent_auth_state: parentIdentity ? "authenticated_parent" : "install_only"
        })
      };

      attachRequestContext(req, context);
      res.setHeader("x-storytime-region", region);
      limiters.general.check(`general:${context.installHash}:${context.ip}`);

      if (identity.sessionToken) {
        res.setHeader(SESSION_HEADER, identity.sessionToken.token);
        res.setHeader("x-storytime-session-expires-at", String(identity.sessionToken.expires_at));
      }

      if (env.ENABLE_STRUCTURED_ANALYTICS || env.ENABLE_USAGE_METERING) {
        analytics.recordSecurity({
          requestId: context.requestId,
          route: context.route,
          event: identity.authLevel === "verified_session" ? "session_verified" : "session_issued",
          region: context.region,
          installHash: context.installHash,
          authLevel: context.authLevel
        });
      }

      next();
    })().catch(next);
  });

  app.get("/health", (_req, res) => {
    res.json({
      ok: true,
      service: "storytime-backend",
      version: env.APP_VERSION,
      auth_required: env.API_AUTH_REQUIRED,
      default_region: env.DEFAULT_REGION,
      allowed_regions: env.ALLOWED_REGIONS,
      telemetry: env.ENABLE_USAGE_METERING ? analytics.report() : undefined
    });
  });

  app.get("/v1/voices", (_req, res) => {
    res.json({
      language: "en",
      voices: REALTIME_VOICES,
      regions: env.ALLOWED_REGIONS
    });
  });

  app.post("/v1/session/identity", (req, res, next) => {
    try {
      const context = getRequestContext(req);
      const issued = createSessionToken(
        {
          install_id: context.installId,
          session_id: context.sessionId,
          region: context.region
        },
        env
      );
      const entitlements = issueBootstrapEntitlements(req, context, env);
      res.setHeader(SESSION_HEADER, issued.token);
      res.setHeader("x-storytime-session-expires-at", String(issued.expires_at));
      res.json({
        session_id: issued.session_id,
        session_token: issued.token,
        expires_at: issued.expires_at,
        region: context.region,
        auth_level: context.authLevel,
        entitlements
      });
      if (env.ENABLE_STRUCTURED_ANALYTICS || env.ENABLE_USAGE_METERING) {
        analytics.recordLaunchEvent({
          requestId: context.requestId,
          route: context.route,
          event: "entitlement_bootstrap",
          outcome: "issued",
          region: context.region,
          installHash: context.installHash,
          sessionId: context.sessionId,
          entitlementTier: entitlements.snapshot.tier,
          remainingStoryStarts: entitlements.snapshot.remaining_story_starts,
          remainingContinuations: entitlements.snapshot.remaining_continuations
        });
      }
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/entitlements/sync", (req, res, next) => {
    try {
      const body = EntitlementsSyncRequestSchema.parse(req.body);
      const context = getRequestContext(req);
      const entitlements = issueSyncedEntitlements(body, context, env);
      if (env.ENABLE_STRUCTURED_ANALYTICS || env.ENABLE_USAGE_METERING) {
        analytics.recordLaunchEvent({
          requestId: context.requestId,
          route: context.route,
          event: "entitlement_sync",
          outcome: "completed",
          region: context.region,
          installHash: context.installHash,
          sessionId: context.sessionId,
          refreshReason: body.refresh_reason,
          entitlementTier: entitlements.snapshot.tier,
          remainingStoryStarts: entitlements.snapshot.remaining_story_starts,
          remainingContinuations: entitlements.snapshot.remaining_continuations
        });
      }
      res.json({
        entitlements
      });
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/entitlements/preflight", (req, res, next) => {
    try {
      const body = EntitlementPreflightRequestSchema.parse(req.body);
      const context = getRequestContext(req);
      const decision = evaluatePreflightForRequest(req, body, context, env);
      if (env.ENABLE_STRUCTURED_ANALYTICS || env.ENABLE_USAGE_METERING) {
        analytics.recordLaunchEvent({
          requestId: context.requestId,
          route: context.route,
          event: "entitlement_preflight",
          outcome: decision.allowed ? "allowed" : "blocked",
          region: context.region,
          installHash: context.installHash,
          sessionId: context.sessionId,
          action: body.action,
          blockReason: decision.block_reason,
          upgradeSurface: decision.recommended_upgrade_surface,
          entitlementTier: decision.snapshot.tier,
          remainingStoryStarts: decision.snapshot.remaining_story_starts,
          remainingContinuations: decision.snapshot.remaining_continuations
        });
      }
      res.json(decision);
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/entitlements/promo/redeem", (req, res, next) => {
    try {
      const body = PromoCodeRedemptionRequestSchema.parse(req.body);
      const context = getRequestContext(req);
      const entitlements = redeemPromoCodeEntitlements(body, context, env);
      if (env.ENABLE_STRUCTURED_ANALYTICS || env.ENABLE_USAGE_METERING) {
        analytics.recordLaunchEvent({
          requestId: context.requestId,
          route: context.route,
          event: "promo_redeem",
          outcome: "completed",
          region: context.region,
          installHash: context.installHash,
          sessionId: context.sessionId,
          entitlementTier: entitlements.snapshot.tier,
          remainingStoryStarts: entitlements.snapshot.remaining_story_starts,
          remainingContinuations: entitlements.snapshot.remaining_continuations
        });
      }
      res.json({
        entitlements
      });
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/realtime/session", async (req, res, next) => {
    try {
      const body = RealtimeSessionRequestSchema.parse(req.body);
      const context = getRequestContext(req);
      const session = services.realtime.issueSessionTicket(body, context);
      res.json({
        session,
        transport: "webrtc",
        endpoint: "/v1/realtime/call"
      });
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/realtime/call", async (req, res, next) => {
    try {
      const body = RealtimeCallRequestSchema.parse(req.body);
      const context = getRequestContext(req);
      const result = RealtimeCallResponseSchema.parse(await services.realtime.createCall(body, context));
      res.json(result);
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/moderation/check", useLimiter(limiters.moderation, "moderation"), async (req, res, next) => {
    try {
      const body = ModerationCheckRequestSchema.parse(req.body);
      const context = getRequestContext(req);
      const verdict = await services.moderation.moderateText(body.text, context);
      res.json(verdict);
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/story/generate", useLimiter(limiters.story, "story-generate"), async (req, res, next) => {
    try {
      const body = GenerateStoryRequestSchema.parse(req.body);
      const normalized = normalizeGenerateRequest(body);
      const context = getRequestContext(req);
      const result = await services.story.generateStory(normalized, context);
      res.status(result.blocked ? 422 : 200).json(result);
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/story/discovery", useLimiter(limiters.discovery, "story-discovery"), async (req, res, next) => {
    try {
      const body = DiscoveryRequestSchema.parse(req.body);
      const context = getRequestContext(req);
      const result = await services.discovery.analyzeTurn(body, context);
      res.status(result.blocked ? 422 : 200).json(result);
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/story/revise", useLimiter(limiters.story, "story-revise"), async (req, res, next) => {
    try {
      const body = ReviseStoryRequestSchema.parse(req.body);
      const context = getRequestContext(req);
      const result = await services.story.reviseStory(body, context);
      res.status(result.blocked ? 422 : 200).json(result);
    } catch (error) {
      next(error);
    }
  });

  app.post("/v1/embeddings/create", useLimiter(limiters.embeddings, "embeddings"), async (req, res, next) => {
    try {
      const body = EmbeddingsCreateRequestSchema.parse(req.body);
      const context = getRequestContext(req);
      const embeddings = await services.embeddings.createEmbeddings(body.inputs, context);
      res.json({ embeddings });
    } catch (error) {
      next(error);
    }
  });

  app.use((error: unknown, req: Request, res: Response, _next: NextFunction) => {
    const requestId = res.getHeader("x-request-id")?.toString() ?? "unknown";

    if (error instanceof ZodError) {
      return res.status(400).json({
        error: "invalid_request",
        details: error.flatten(),
        request_id: requestId
      });
    }

    if (error instanceof AppError) {
      req.context?.logger?.warn({ error_code: error.code, details: error.details }, error.message);
      return res.status(error.status).json({
        error: error.code,
        message: error.publicMessage,
        details: error.exposeDetails ? error.publicDetails ?? error.details : undefined,
        request_id: requestId
      });
    }

    req.context?.logger?.error({ error }, "Unhandled error");
    logger.error({ error, request_id: requestId }, "Unhandled error");
    return res.status(500).json({
      error: "internal_error",
      message: "Unexpected server error",
      request_id: requestId
    });
  });

  return app;
}

type RouteLimiters = {
  general: SlidingWindowRateLimiter;
  moderation: SlidingWindowRateLimiter;
  discovery: SlidingWindowRateLimiter;
  story: SlidingWindowRateLimiter;
  embeddings: SlidingWindowRateLimiter;
};

function createRateLimiters(env: Env): RouteLimiters {
  return {
    general: new SlidingWindowRateLimiter(
      env.GENERAL_RATE_LIMIT_MAX,
      env.GENERAL_RATE_LIMIT_WINDOW_MS,
      "rate_limited",
      "Request rate limit exceeded"
    ),
    moderation: new SlidingWindowRateLimiter(
      env.MODERATION_RATE_LIMIT_MAX,
      env.GENERAL_RATE_LIMIT_WINDOW_MS,
      "rate_limited",
      "Moderation rate limit exceeded"
    ),
    discovery: new SlidingWindowRateLimiter(
      env.DISCOVERY_RATE_LIMIT_MAX,
      env.GENERAL_RATE_LIMIT_WINDOW_MS,
      "rate_limited",
      "Discovery rate limit exceeded"
    ),
    story: new SlidingWindowRateLimiter(
      env.STORY_RATE_LIMIT_MAX,
      env.GENERAL_RATE_LIMIT_WINDOW_MS,
      "rate_limited",
      "Story generation rate limit exceeded"
    ),
    embeddings: new SlidingWindowRateLimiter(
      env.EMBEDDINGS_RATE_LIMIT_MAX,
      env.GENERAL_RATE_LIMIT_WINDOW_MS,
      "rate_limited",
      "Embeddings rate limit exceeded"
    )
  };
}

function isAccountOwnedRoute(req: Request): boolean {
  return req.path === "/v1/session/identity" || req.path.startsWith("/v1/entitlements/");
}

function requiresIdentity(req: Request) {
  return req.path !== "/health" && !(req.method === "GET" && req.path === "/v1/voices");
}

function useLimiter(limiter: SlidingWindowRateLimiter, scope: string) {
  return (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = getRequestContext(req);
      limiter.check(`${scope}:${context.installHash}:${context.ip}`);
      next();
    } catch (error) {
      next(error);
    }
  };
}
