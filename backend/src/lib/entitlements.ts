import type { Request } from "express";
import type { Env } from "./env.js";
import type { RequestContext } from "./requestContext.js";
import { AppError } from "./errors.js";
import {
  createEntitlementToken,
  verifyEntitlementToken,
  type EntitlementOwner,
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
  owner: EntitlementOwner;
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
  entitlements?: EntitlementBootstrapEnvelope;
};

type UsageLedgerState = {
  new_story: number[];
  continue_story: number[];
};

type StoredEntitlementRecord = {
  owner: EntitlementOwner;
  snapshot: Omit<EntitlementSnapshot, "effective_at" | "expires_at">;
  updated_at: number;
};

const entitlementUsageLedger = new Map<string, UsageLedgerState>();
const entitlementRecordsByParentUserId = new Map<string, StoredEntitlementRecord>();

export function issueBootstrapEntitlements(req: Request, context: RequestContext, env: Env): EntitlementBootstrapEnvelope {
  const owner = resolveEntitlementOwner(context);
  const storedRecord = resolveStoredEntitlementRecord(owner);
  if (storedRecord) {
    return issueCurrentEntitlements(storedRecord.snapshot, owner, context, env);
  }

  const tier = resolveTierSeed(req, env);
  const source: EntitlementSource = tier === "plus" ? "debug_seed" : "none";
  return issueCurrentEntitlements(baseSnapshotForTier(env, tier, source), owner, context, env);
}

export function issueSyncedEntitlements(
  request: EntitlementsSyncRequest,
  context: RequestContext,
  env: Env
): EntitlementBootstrapEnvelope {
  const activeProductIDs = resolveActiveProductIDs(request);
  const owner = resolveEntitlementOwner(context);
  assertAccountOwnedCommerceSyncHasAuthenticatedParent(request, activeProductIDs, owner);
  const tier: EntitlementTier = hasPlusProduct(activeProductIDs) ? "plus" : "starter";
  const source: EntitlementSource = activeProductIDs.size > 0 ? "storekit_verified" : "none";
  const snapshot = baseSnapshotForTier(env, tier, source);

  if (owner.kind === "parent_user") {
    entitlementRecordsByParentUserId.set(owner.parent_user_id, {
      owner,
      snapshot,
      updated_at: Math.floor(Date.now() / 1_000)
    });
  }

  return issueCurrentEntitlements(snapshot, owner, context, env);
}

function assertAccountOwnedCommerceSyncHasAuthenticatedParent(
  request: EntitlementsSyncRequest,
  activeProductIDs: Set<string>,
  owner: EntitlementOwner
): void {
  if (activeProductIDs.size == 0) {
    return;
  }

  if (request.refresh_reason !== "purchase" && request.refresh_reason !== "restore") {
    return;
  }

  if (owner.kind === "parent_user") {
    return;
  }

  const publicMessage =
    request.refresh_reason === "restore"
      ? "Sign in to a parent account before restoring Plus."
      : "Sign in to a parent account before purchasing Plus.";

  throw new AppError(
    "Account-owned commerce sync requires an authenticated parent account",
    401,
    "parent_auth_required",
    {
      refresh_reason: request.refresh_reason,
      active_product_ids: Array.from(activeProductIDs)
    },
    {
      publicMessage
    }
  );
}

export function resolveEntitlementSnapshot(req: Request, context: RequestContext, env: Env): EntitlementSnapshot {
  const owner = resolveEntitlementOwner(context);
  const usageOwnerKey = resolveUsageOwnerKey(owner, context.installId);
  const storedRecord = resolveStoredEntitlementRecord(owner);
  if (storedRecord) {
    return issueCurrentEntitlements(applyUsageLedger(storedRecord.snapshot, usageOwnerKey), owner, context, env).snapshot;
  }

  const suppliedToken = req.header(ENTITLEMENT_HEADER)?.trim();
  if (!suppliedToken) {
    return issueBootstrapEntitlements(req, context, env).snapshot;
  }

  const verified = verifyEntitlementToken(suppliedToken, context.installId, env);
  if (entitlementOwnersMatch(verified.owner, owner)) {
    return issueCurrentEntitlements(
      applyUsageLedger(stripSnapshotLifetime(verified.snapshot), usageOwnerKey),
      owner,
      context,
      env
    ).snapshot;
  }

  return issueBootstrapEntitlements(req, context, env).snapshot;
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
    const entitlements = issueCurrentEntitlements(
      stripSnapshotLifetime(currentSnapshot),
      resolveEntitlementOwner(context),
      context,
      env
    );
    return {
      ...initialDecision,
      snapshot: entitlements.snapshot,
      entitlements
    };
  }

  recordUsage(resolveUsageOwnerKey(resolveEntitlementOwner(context), context.installId), request.action);
  const entitlements = issueCurrentEntitlements(
    stripSnapshotLifetime(currentSnapshot),
    resolveEntitlementOwner(context),
    context,
    env
  );

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
  entitlementRecordsByParentUserId.clear();
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
  owner: EntitlementOwner,
  context: RequestContext,
  env: Env
): EntitlementBootstrapEnvelope {
  return issueEntitlementEnvelope(
    applyUsageLedger(snapshot, resolveUsageOwnerKey(owner, context.installId)),
    owner,
    context,
    env
  );
}

function recommendedUpgradeSurface(action: EntitlementPreflightRequest["action"]): EntitlementUpgradeSurface {
  return action === "continue_story" ? "story_series_detail" : "new_story_journey";
}

function issueEntitlementEnvelope(
  snapshot: Omit<EntitlementSnapshot, "effective_at" | "expires_at">,
  owner: EntitlementOwner,
  context: RequestContext,
  env: Env
): EntitlementBootstrapEnvelope {
  const issued = createEntitlementToken(
    {
      install_id: context.installId,
      owner,
      snapshot
    },
    env
  );

  return {
    snapshot: issued.snapshot,
    token: issued.token,
    expires_at: issued.expires_at,
    owner
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
  usageOwnerKey: string
): Omit<EntitlementSnapshot, "effective_at" | "expires_at"> {
  const state = pruneUsageState(usageOwnerKey, snapshot.usage_window.duration_seconds);
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

function recordUsage(usageOwnerKey: string, action: EntitlementPreflightRequest["action"]): void {
  const state = pruneUsageState(usageOwnerKey, null);
  state[action].push(Math.floor(Date.now() / 1_000));
  entitlementUsageLedger.set(usageOwnerKey, state);
}

function pruneUsageState(usageOwnerKey: string, durationSeconds: number | null): UsageLedgerState {
  const existing = entitlementUsageLedger.get(usageOwnerKey) ?? {
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
    entitlementUsageLedger.delete(usageOwnerKey);
  } else {
    entitlementUsageLedger.set(usageOwnerKey, pruned);
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

function resolveEntitlementOwner(context: RequestContext): EntitlementOwner {
  if (context.parentIdentity) {
    return {
      kind: "parent_user",
      parent_user_id: context.parentIdentity.uid,
      auth_provider: context.parentIdentity.provider
    };
  }

  return {
    kind: "install"
  };
}

function resolveStoredEntitlementRecord(owner: EntitlementOwner): StoredEntitlementRecord | null {
  if (owner.kind !== "parent_user") {
    return null;
  }

  return entitlementRecordsByParentUserId.get(owner.parent_user_id) ?? null;
}

function resolveUsageOwnerKey(owner: EntitlementOwner, installId: string): string {
  if (owner.kind === "parent_user") {
    return `parent:${owner.parent_user_id}`;
  }

  return `install:${installId}`;
}

function entitlementOwnersMatch(left: EntitlementOwner, right: EntitlementOwner): boolean {
  if (left.kind !== right.kind) {
    return false;
  }

  if (left.kind === "install" && right.kind === "install") {
    return true;
  }

  if (left.kind === "parent_user" && right.kind === "parent_user") {
    return left.parent_user_id === right.parent_user_id && left.auth_provider === right.auth_provider;
  }

  return false;
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
