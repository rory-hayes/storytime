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
};

export function issueBootstrapEntitlements(req: Request, context: RequestContext, env: Env): EntitlementBootstrapEnvelope {
  const tier = resolveTierSeed(req, env);
  const source: EntitlementSource = tier === "plus" ? "debug_seed" : "none";
  return issueEntitlementEnvelope(baseSnapshotForTier(tier, source), context, env);
}

export function issueSyncedEntitlements(
  request: EntitlementsSyncRequest,
  context: RequestContext,
  env: Env
): EntitlementBootstrapEnvelope {
  const activeProductIDs = resolveActiveProductIDs(request);
  const tier: EntitlementTier = hasPlusProduct(activeProductIDs) ? "plus" : "starter";
  const source: EntitlementSource = activeProductIDs.size > 0 ? "storekit_verified" : "none";
  return issueEntitlementEnvelope(baseSnapshotForTier(tier, source), context, env);
}

export function resolveEntitlementSnapshot(req: Request, context: RequestContext, env: Env): EntitlementSnapshot {
  const suppliedToken = req.header(ENTITLEMENT_HEADER)?.trim();
  if (!suppliedToken) {
    return issueBootstrapEntitlements(req, context, env).snapshot;
  }

  return verifyEntitlementToken(suppliedToken, context.installId, env).snapshot;
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

function baseSnapshotForTier(
  tier: EntitlementTier,
  source: EntitlementSource
): Omit<EntitlementSnapshot, "effective_at" | "expires_at"> {
  if (tier === "plus") {
    return {
      tier,
      source,
      max_child_profiles: 3,
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
    };
  }

  return {
    tier,
    source,
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
  };
}
