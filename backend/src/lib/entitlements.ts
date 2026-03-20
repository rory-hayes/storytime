import type { Request } from "express";
import type { Env } from "./env.js";
import type { RequestContext } from "./requestContext.js";
import {
  createEntitlementToken,
  verifyEntitlementToken,
  type EntitlementSnapshot,
  type EntitlementSource,
  type EntitlementTier
} from "./security.js";
import type { EntitlementPreflightRequest, EntitlementsSyncRequest } from "../types.js";

const PLUS_PRODUCT_IDS = new Set(["storytime.plus.monthly", "storytime.plus.yearly"]);
export const ENTITLEMENT_HEADER = "x-storytime-entitlement";

export type EntitlementBootstrapEnvelope = {
  snapshot: EntitlementSnapshot;
  token: string;
  expires_at: number;
};

export type EntitlementPreflightBlockReason =
  | "child_profile_limit"
  | "new_story_not_allowed"
  | "continuation_not_allowed"
  | "story_length_exceeded"
  | "story_starts_exhausted"
  | "continuations_exhausted";

export type EntitlementUpgradeSurface = "new_story_journey" | "story_series_detail" | "parent_trust_center";

export type EntitlementPreflightDecision = {
  action: EntitlementPreflightRequest["action"];
  allowed: boolean;
  block_reason: EntitlementPreflightBlockReason | null;
  recommended_upgrade_surface: EntitlementUpgradeSurface | null;
  snapshot: EntitlementSnapshot;
  entitlements: EntitlementBootstrapEnvelope;
};

type UsageLedgerState = {
  new_story: number[];
  continue_story: number[];
};

const entitlementUsageLedger = new Map<string, UsageLedgerState>();

export function issueBootstrapEntitlements(req: Request, context: RequestContext, env: Env): EntitlementBootstrapEnvelope {
  const tier = resolveTierSeed(req, env);
  const source: EntitlementSource = tier === "plus" ? "debug_seed" : "none";
  return issueCurrentEntitlements(baseSnapshotForTier(env, tier, source), context, env);
}

export function issueSyncedEntitlements(
  request: EntitlementsSyncRequest,
  context: RequestContext,
  env: Env
): EntitlementBootstrapEnvelope {
  const activeProductIDs = resolveActiveProductIDs(request);
  const tier: EntitlementTier = hasPlusProduct(activeProductIDs) ? "plus" : "starter";
  const source: EntitlementSource = activeProductIDs.size > 0 ? "storekit_verified" : "none";
  return issueCurrentEntitlements(baseSnapshotForTier(env, tier, source), context, env);
}

export function resolveEntitlementSnapshot(req: Request, context: RequestContext, env: Env): EntitlementSnapshot {
  const suppliedToken = req.header(ENTITLEMENT_HEADER)?.trim();
  if (!suppliedToken) {
    return issueBootstrapEntitlements(req, context, env).snapshot;
  }

  return applyUsageLedger(verifyEntitlementToken(suppliedToken, context.installId, env).snapshot, context.installId);
}

export function evaluatePreflightForRequest(
  req: Request,
  request: EntitlementPreflightRequest,
  context: RequestContext,
  env: Env
): EntitlementPreflightDecision {
  const currentSnapshot = resolveEntitlementSnapshot(req, context, env);
  const initialDecision = evaluatePreflight(request, currentSnapshot);

  if (!initialDecision.allowed) {
    const entitlements = issueCurrentEntitlements(stripSnapshotLifetime(currentSnapshot), context, env);
    return {
      ...initialDecision,
      snapshot: entitlements.snapshot,
      entitlements
    };
  }

  recordUsage(context.installId, request.action);
  const entitlements = issueCurrentEntitlements(stripSnapshotLifetime(currentSnapshot), context, env);

  return {
    action: request.action,
    allowed: true,
    block_reason: null,
    recommended_upgrade_surface: null,
    snapshot: entitlements.snapshot,
    entitlements
  };
}

export function resetEntitlementUsageLedger(): void {
  entitlementUsageLedger.clear();
}

export function evaluatePreflight(
  request: EntitlementPreflightRequest,
  snapshot: EntitlementSnapshot
): EntitlementPreflightDecision {
  if (request.child_profile_count > snapshot.max_child_profiles) {
    return blockedDecision(request.action, "child_profile_limit", "parent_trust_center", snapshot);
  }

  if (snapshot.max_story_length_minutes !== null && request.requested_length_minutes > snapshot.max_story_length_minutes) {
    return blockedDecision(request.action, "story_length_exceeded", recommendedUpgradeSurface(request.action), snapshot);
  }

  if (request.action === "new_story") {
    if (!snapshot.can_start_new_stories) {
      return blockedDecision(request.action, "new_story_not_allowed", "new_story_journey", snapshot);
    }

    if (snapshot.remaining_story_starts !== null && snapshot.remaining_story_starts <= 0) {
      return blockedDecision(request.action, "story_starts_exhausted", "new_story_journey", snapshot);
    }

    return {
      action: request.action,
      allowed: true,
      block_reason: null,
      recommended_upgrade_surface: null,
      snapshot
    };
  }

  if (!snapshot.can_continue_saved_series) {
    return blockedDecision(request.action, "continuation_not_allowed", "story_series_detail", snapshot);
  }

  if (snapshot.remaining_continuations !== null && snapshot.remaining_continuations <= 0) {
    return blockedDecision(request.action, "continuations_exhausted", "story_series_detail", snapshot);
  }

  return {
    action: request.action,
    allowed: true,
    block_reason: null,
    recommended_upgrade_surface: null,
    snapshot
  };
}

export function resolveActiveProductIDs(request: EntitlementsSyncRequest): Set<string> {
  const normalized = new Set<string>();

  for (const productId of request.active_product_ids) {
    const trimmed = productId.trim();
    if (trimmed) {
      normalized.add(trimmed);
    }
  }

  for (const transaction of request.transactions) {
    if (
      transaction.verification_state !== "verified" ||
      !transaction.is_active ||
      transaction.revoked_at !== null ||
      (transaction.expires_at !== null && transaction.expires_at <= Date.now() / 1000)
    ) {
      continue;
    }

    const trimmed = transaction.product_id.trim();
    if (trimmed) {
      normalized.add(trimmed);
    }
  }

  return normalized;
}

function hasPlusProduct(productIDs: Set<string>): boolean {
  for (const productID of productIDs) {
    if (PLUS_PRODUCT_IDS.has(productID)) {
      return true;
    }
  }

  return false;
}

function blockedDecision(
  action: EntitlementPreflightRequest["action"],
  blockReason: EntitlementPreflightBlockReason,
  surface: EntitlementUpgradeSurface,
  snapshot: EntitlementSnapshot
): EntitlementPreflightDecision {
  return {
    action,
    allowed: false,
    block_reason: blockReason,
    recommended_upgrade_surface: surface,
    snapshot
  };
}

function issueCurrentEntitlements(
  snapshot: Omit<EntitlementSnapshot, "effective_at" | "expires_at">,
  context: RequestContext,
  env: Env
): EntitlementBootstrapEnvelope {
  return issueEntitlementEnvelope(applyUsageLedger(snapshot, context.installId), context, env);
}

function recommendedUpgradeSurface(action: EntitlementPreflightRequest["action"]): EntitlementUpgradeSurface {
  return action === "continue_story" ? "story_series_detail" : "new_story_journey";
}

function issueEntitlementEnvelope(
  snapshot: Omit<EntitlementSnapshot, "effective_at" | "expires_at">,
  context: RequestContext,
  env: Env
): EntitlementBootstrapEnvelope {
  const issued = createEntitlementToken(
    {
      install_id: context.installId,
      snapshot
    },
    env
  );

  return {
    snapshot: issued.snapshot,
    token: issued.token,
    expires_at: issued.expires_at
  };
}

function resolveTierSeed(req: Request, env: Env): EntitlementTier {
  if (env.NODE_ENV === "production") {
    return "starter";
  }

  const seed = req.header("x-storytime-entitlement-seed")?.trim().toLowerCase();
  if (seed === "plus") {
    return "plus";
  }

  return "starter";
}

function applyUsageLedger(
  snapshot: Omit<EntitlementSnapshot, "effective_at" | "expires_at"> | EntitlementSnapshot,
  installId: string
): Omit<EntitlementSnapshot, "effective_at" | "expires_at"> {
  const state = pruneUsageState(installId, snapshot.usage_window.duration_seconds);
  return {
    ...stripSnapshotLifetime(snapshot),
    remaining_story_starts: remainingCount(snapshot.max_story_starts_per_period, state.new_story.length),
    remaining_continuations: remainingCount(snapshot.max_continuations_per_period, state.continue_story.length)
  };
}

function stripSnapshotLifetime(
  snapshot: Omit<EntitlementSnapshot, "effective_at" | "expires_at"> | EntitlementSnapshot
): Omit<EntitlementSnapshot, "effective_at" | "expires_at"> {
  const { effective_at: _effectiveAt, expires_at: _expiresAt, ...rest } =
    snapshot as EntitlementSnapshot;
  return rest;
}

function recordUsage(installId: string, action: EntitlementPreflightRequest["action"]): void {
  const state = pruneUsageState(installId, null);
  state[action].push(Math.floor(Date.now() / 1_000));
  entitlementUsageLedger.set(installId, state);
}

function pruneUsageState(installId: string, durationSeconds: number | null): UsageLedgerState {
  const existing = entitlementUsageLedger.get(installId) ?? {
    new_story: [],
    continue_story: []
  };

  if (durationSeconds === null) {
    return {
      new_story: [...existing.new_story],
      continue_story: [...existing.continue_story]
    };
  }

  const now = Math.floor(Date.now() / 1_000);
  const cutoff = now - durationSeconds;
  const pruned: UsageLedgerState = {
    new_story: existing.new_story.filter((timestamp) => timestamp >= cutoff),
    continue_story: existing.continue_story.filter((timestamp) => timestamp >= cutoff)
  };

  if (pruned.new_story.length === 0 && pruned.continue_story.length === 0) {
    entitlementUsageLedger.delete(installId);
  } else {
    entitlementUsageLedger.set(installId, pruned);
  }

  return {
    new_story: [...pruned.new_story],
    continue_story: [...pruned.continue_story]
  };
}

function remainingCount(limit: number | null, used: number): number | null {
  if (limit === null) {
    return null;
  }

  return Math.max(0, limit - used);
}

function baseSnapshotForTier(
  env: Env,
  tier: EntitlementTier,
  source: EntitlementSource
): Omit<EntitlementSnapshot, "effective_at" | "expires_at"> {
  if (tier === "plus") {
    return {
      tier,
      source,
      max_child_profiles: env.PLUS_MAX_CHILD_PROFILES,
      max_story_starts_per_period: env.PLUS_MAX_STORY_STARTS_PER_PERIOD,
      max_continuations_per_period: env.PLUS_MAX_CONTINUATIONS_PER_PERIOD,
      max_story_length_minutes: env.PLUS_MAX_STORY_LENGTH_MINUTES,
      can_replay_saved_stories: true,
      can_start_new_stories: true,
      can_continue_saved_series: true,
      usage_window: {
        kind: "rolling_period",
        duration_seconds: env.PLUS_USAGE_WINDOW_DURATION_SECONDS,
        resets_at: null
      },
      remaining_story_starts: env.PLUS_MAX_STORY_STARTS_PER_PERIOD,
      remaining_continuations: env.PLUS_MAX_CONTINUATIONS_PER_PERIOD
    };
  }

  return {
    tier,
    source,
    max_child_profiles: env.STARTER_MAX_CHILD_PROFILES,
    max_story_starts_per_period: env.STARTER_MAX_STORY_STARTS_PER_PERIOD,
    max_continuations_per_period: env.STARTER_MAX_CONTINUATIONS_PER_PERIOD,
    max_story_length_minutes: env.STARTER_MAX_STORY_LENGTH_MINUTES,
    can_replay_saved_stories: true,
    can_start_new_stories: true,
    can_continue_saved_series: true,
    usage_window: {
      kind: "rolling_period",
      duration_seconds: env.STARTER_USAGE_WINDOW_DURATION_SECONDS,
      resets_at: null
    },
    remaining_story_starts: env.STARTER_MAX_STORY_STARTS_PER_PERIOD,
    remaining_continuations: env.STARTER_MAX_CONTINUATIONS_PER_PERIOD
  };
}
