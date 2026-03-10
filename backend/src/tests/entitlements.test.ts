import { describe, expect, it } from "vitest";
import { evaluatePreflight, issueSyncedEntitlements, resolveActiveProductIDs } from "../lib/entitlements.js";
import { makeRequestContext, makeTestEnv } from "./testHelpers.js";

describe("entitlements sync", () => {
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
    expect(starterEnvelope.snapshot.tier).toBe("starter");
    expect(starterEnvelope.snapshot.source).toBe("none");
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
});
