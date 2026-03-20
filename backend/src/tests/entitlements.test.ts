import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  evaluatePreflight,
  evaluatePreflightForRequest,
  issueSyncedEntitlements,
  resetEntitlementUsageLedger,
  resolveActiveProductIDs
} from "../lib/entitlements.js";
import { makeRequestContext, makeTestEnv } from "./testHelpers.js";
import { makeRequest } from "./testHelpers.js";

describe("entitlements sync", () => {
  beforeEach(() => {
    resetEntitlementUsageLedger();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    resetEntitlementUsageLedger();
  });

  it("normalizes active verified products from sync payload", () => {
    const activeProductIDs = resolveActiveProductIDs({
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
        },
        {
          product_id: "storytime.plus.monthly",
          original_transaction_id: "original-2",
          latest_transaction_id: "latest-2",
          purchased_at: Math.floor(Date.now() / 1000) - 120,
          expires_at: Math.floor(Date.now() / 1000) + 3_600,
          revoked_at: null,
          ownership_type: "purchased",
          environment: "sandbox",
          verification_state: "unverified",
          is_active: true
        }
      ]
    });

    expect(Array.from(activeProductIDs)).toEqual(["storytime.plus.monthly"]);
  });

  it("issues plus entitlements only from active verified plus products", () => {
    const env = makeTestEnv();
    const context = makeRequestContext();
    const plusEnvelope = issueSyncedEntitlements(
      {
        refresh_reason: "restore",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "original-1",
            latest_transaction_id: "latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 600,
            expires_at: Math.floor(Date.now() / 1000) + 3_600,
            revoked_at: null,
            ownership_type: "family_shared",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      },
      context,
      env
    );
    const starterEnvelope = issueSyncedEntitlements(
      {
        refresh_reason: "restore",
        active_product_ids: [],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "original-1",
            latest_transaction_id: "latest-1",
            purchased_at: Math.floor(Date.now() / 1000) - 600,
            expires_at: Math.floor(Date.now() / 1000) - 1,
            revoked_at: null,
            ownership_type: "family_shared",
            environment: "sandbox",
            verification_state: "verified",
            is_active: true
          }
        ]
      },
      context,
      env
    );

    expect(plusEnvelope.snapshot.tier).toBe("plus");
    expect(plusEnvelope.snapshot.source).toBe("storekit_verified");
    expect(plusEnvelope.snapshot.max_child_profiles).toBe(3);
    expect(plusEnvelope.snapshot.max_story_starts_per_period).toBe(12);
    expect(plusEnvelope.snapshot.max_continuations_per_period).toBe(12);
    expect(plusEnvelope.snapshot.max_story_length_minutes).toBe(10);
    expect(plusEnvelope.snapshot.usage_window.duration_seconds).toBe(604800);
    expect(plusEnvelope.snapshot.remaining_story_starts).toBe(12);
    expect(plusEnvelope.snapshot.remaining_continuations).toBe(12);
    expect(starterEnvelope.snapshot.tier).toBe("starter");
    expect(starterEnvelope.snapshot.source).toBe("none");
    expect(starterEnvelope.snapshot.max_child_profiles).toBe(1);
    expect(starterEnvelope.snapshot.max_story_starts_per_period).toBe(3);
    expect(starterEnvelope.snapshot.max_continuations_per_period).toBe(3);
    expect(starterEnvelope.snapshot.max_story_length_minutes).toBe(10);
    expect(starterEnvelope.snapshot.usage_window.duration_seconds).toBe(604800);
    expect(starterEnvelope.snapshot.remaining_story_starts).toBe(3);
    expect(starterEnvelope.snapshot.remaining_continuations).toBe(3);
  });

  it("uses configured launch defaults when issuing starter and plus snapshots", () => {
    const env = makeTestEnv({
      STARTER_MAX_CHILD_PROFILES: 1,
      STARTER_MAX_STORY_STARTS_PER_PERIOD: 2,
      STARTER_MAX_CONTINUATIONS_PER_PERIOD: 4,
      STARTER_MAX_STORY_LENGTH_MINUTES: 8,
      STARTER_USAGE_WINDOW_DURATION_SECONDS: 172800,
      PLUS_MAX_CHILD_PROFILES: 3,
      PLUS_MAX_STORY_STARTS_PER_PERIOD: 15,
      PLUS_MAX_CONTINUATIONS_PER_PERIOD: 18,
      PLUS_MAX_STORY_LENGTH_MINUTES: 10,
      PLUS_USAGE_WINDOW_DURATION_SECONDS: 1209600
    });
    const context = makeRequestContext();

    const starterEnvelope = issueSyncedEntitlements(
      {
        refresh_reason: "app_launch",
        active_product_ids: [],
        transactions: []
      },
      context,
      env
    );
    const plusEnvelope = issueSyncedEntitlements(
      {
        refresh_reason: "purchase",
        active_product_ids: ["storytime.plus.monthly"],
        transactions: []
      },
      context,
      env
    );

    expect(starterEnvelope.snapshot.max_story_starts_per_period).toBe(2);
    expect(starterEnvelope.snapshot.max_continuations_per_period).toBe(4);
    expect(starterEnvelope.snapshot.max_story_length_minutes).toBe(8);
    expect(starterEnvelope.snapshot.usage_window.duration_seconds).toBe(172800);
    expect(starterEnvelope.snapshot.remaining_story_starts).toBe(2);
    expect(starterEnvelope.snapshot.remaining_continuations).toBe(4);

    expect(plusEnvelope.snapshot.max_story_starts_per_period).toBe(15);
    expect(plusEnvelope.snapshot.max_continuations_per_period).toBe(18);
    expect(plusEnvelope.snapshot.max_story_length_minutes).toBe(10);
    expect(plusEnvelope.snapshot.usage_window.duration_seconds).toBe(1209600);
    expect(plusEnvelope.snapshot.remaining_story_starts).toBe(15);
    expect(plusEnvelope.snapshot.remaining_continuations).toBe(18);
  });

  it("allows starter preflight when launch intent is within current capability bounds", () => {
    const decision = evaluatePreflight(
      {
        action: "new_story",
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        child_profile_count: 1,
        requested_length_minutes: 4
      },
      issueSyncedEntitlements(
        {
          refresh_reason: "app_launch",
          active_product_ids: [],
          transactions: []
        },
        makeRequestContext(),
        makeTestEnv()
      ).snapshot
    );

    expect(decision.allowed).toBe(true);
    expect(decision.block_reason).toBeNull();
    expect(decision.recommended_upgrade_surface).toBeNull();
  });

  it("blocks preflight when child profile count exceeds the entitlement cap", () => {
    const decision = evaluatePreflight(
      {
        action: "new_story",
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        child_profile_count: 2,
        requested_length_minutes: 4
      },
      issueSyncedEntitlements(
        {
          refresh_reason: "app_launch",
          active_product_ids: [],
          transactions: []
        },
        makeRequestContext(),
        makeTestEnv()
      ).snapshot
    );

    expect(decision.allowed).toBe(false);
    expect(decision.block_reason).toBe("child_profile_limit");
    expect(decision.recommended_upgrade_surface).toBe("parent_trust_center");
  });

  it("blocks continuation preflight when remaining continuations are exhausted", () => {
    const decision = evaluatePreflight(
      {
        action: "continue_story",
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        child_profile_count: 1,
        requested_length_minutes: 4,
        selected_series_id: "22222222-2222-2222-2222-222222222222"
      },
      {
        tier: "starter",
        source: "none",
        max_child_profiles: 1,
        max_story_starts_per_period: null,
        max_continuations_per_period: 3,
        max_story_length_minutes: null,
        can_replay_saved_stories: true,
        can_start_new_stories: true,
        can_continue_saved_series: true,
        effective_at: Math.floor(Date.now() / 1000),
        expires_at: Math.floor(Date.now() / 1000) + 300,
        usage_window: {
          kind: "rolling_period",
          duration_seconds: null,
          resets_at: null
        },
        remaining_story_starts: 2,
        remaining_continuations: 0
      }
    );

    expect(decision.allowed).toBe(false);
    expect(decision.block_reason).toBe("continuations_exhausted");
    expect(decision.recommended_upgrade_surface).toBe("story_series_detail");
  });

  it("depletes remaining story starts across allowed preflight requests for the same install", () => {
    const env = makeTestEnv({
      STARTER_MAX_STORY_STARTS_PER_PERIOD: 2
    });
    const context = makeRequestContext();
    const bootstrap = issueSyncedEntitlements(
      {
        refresh_reason: "app_launch",
        active_product_ids: [],
        transactions: []
      },
      context,
      env
    );

    const first = evaluatePreflightForRequest(
      makeRequest({
        headers: {
          "x-storytime-entitlement": bootstrap.token
        }
      }),
      {
        action: "new_story",
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        child_profile_count: 1,
        requested_length_minutes: 4
      },
      context,
      env
    );

    const second = evaluatePreflightForRequest(
      makeRequest({
        headers: {
          "x-storytime-entitlement": first.entitlements.token
        }
      }),
      {
        action: "new_story",
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        child_profile_count: 1,
        requested_length_minutes: 4
      },
      context,
      env
    );

    const third = evaluatePreflightForRequest(
      makeRequest({
        headers: {
          "x-storytime-entitlement": second.entitlements.token
        }
      }),
      {
        action: "new_story",
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        child_profile_count: 1,
        requested_length_minutes: 4
      },
      context,
      env
    );

    expect(first.allowed).toBe(true);
    expect(first.snapshot.remaining_story_starts).toBe(1);
    expect(first.entitlements.snapshot.remaining_story_starts).toBe(1);

    expect(second.allowed).toBe(true);
    expect(second.snapshot.remaining_story_starts).toBe(0);

    expect(third.allowed).toBe(false);
    expect(third.block_reason).toBe("story_starts_exhausted");
    expect(third.snapshot.remaining_story_starts).toBe(0);
    expect(third.entitlements.snapshot.remaining_story_starts).toBe(0);
  });

  it("restores remaining counters after the rolling usage window expires", () => {
    const env = makeTestEnv({
      STARTER_MAX_CONTINUATIONS_PER_PERIOD: 1,
      STARTER_USAGE_WINDOW_DURATION_SECONDS: 60
    });
    const context = makeRequestContext();
    const baseTimeMs = 1_700_000_000_000;
    const nowSpy = vi.spyOn(Date, "now").mockReturnValue(baseTimeMs);
    const bootstrap = issueSyncedEntitlements(
      {
        refresh_reason: "app_launch",
        active_product_ids: [],
        transactions: []
      },
      context,
      env
    );

    const first = evaluatePreflightForRequest(
      makeRequest({
        headers: {
          "x-storytime-entitlement": bootstrap.token
        }
      }),
      {
        action: "continue_story",
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        child_profile_count: 1,
        requested_length_minutes: 4,
        selected_series_id: "22222222-2222-2222-2222-222222222222"
      },
      context,
      env
    );

    nowSpy.mockReturnValue(baseTimeMs + 61_000);
    const refreshed = issueSyncedEntitlements(
      {
        refresh_reason: "foreground",
        active_product_ids: [],
        transactions: []
      },
      context,
      env
    );

    expect(first.allowed).toBe(true);
    expect(first.snapshot.remaining_continuations).toBe(0);
    expect(refreshed.snapshot.remaining_continuations).toBe(1);
  });
});
