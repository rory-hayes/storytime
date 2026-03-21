import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  configureEntitlementPersistence,
  evaluatePreflight,
  evaluatePreflightForRequest,
  issueBootstrapEntitlements,
  issueSyncedEntitlements,
  redeemPromoCodeEntitlements,
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
    const authenticatedContext = makeRequestContext({
      parentIdentity: {
        uid: "parent-restore-1",
        provider: "firebase"
      }
    });
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
      authenticatedContext,
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
    const authenticatedContext = makeRequestContext({
      parentIdentity: {
        uid: "parent-123",
        provider: "firebase"
      }
    });

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
      authenticatedContext,
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

  it("requires an authenticated parent account for purchase-linked plus sync", () => {
    expect(() =>
      issueSyncedEntitlements(
        {
          refresh_reason: "purchase",
          active_product_ids: ["storytime.plus.monthly"],
          transactions: []
        },
        makeRequestContext(),
        makeTestEnv()
      )
    ).toThrowError(/authenticated parent account/i);
  });

  it("requires an authenticated parent account for restore-linked plus sync", () => {
    expect(() =>
      issueSyncedEntitlements(
        {
          refresh_reason: "restore",
          active_product_ids: ["storytime.plus.monthly"],
          transactions: []
        },
        makeRequestContext(),
        makeTestEnv()
      )
    ).toThrowError(/authenticated parent account/i);
  });

  it("rejects restore-linked plus sync when this device was already restored for a different parent", () => {
    const env = makeTestEnv();

    issueSyncedEntitlements(
      {
        refresh_reason: "restore",
        active_product_ids: ["storytime.plus.yearly"],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "restore-original-1",
            latest_transaction_id: "restore-latest-1",
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
      makeRequestContext({
        installId: "install-restore-claim",
        parentIdentity: {
          uid: "parent-alpha",
          provider: "firebase"
        }
      }),
      env
    );

    expect(() =>
      issueSyncedEntitlements(
        {
          refresh_reason: "restore",
          active_product_ids: ["storytime.plus.yearly"],
          transactions: [
            {
              product_id: "storytime.plus.yearly",
              original_transaction_id: "restore-original-2",
              latest_transaction_id: "restore-latest-2",
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
        makeRequestContext({
          installId: "install-restore-claim",
          parentIdentity: {
            uid: "parent-beta",
            provider: "firebase"
          }
        }),
        env
      )
    ).toThrowError(/restore claim belongs to a different parent account on this device/i);
  });

  it("redeems a configured promo code into a parent-owned plus entitlement", () => {
    const env = makeTestEnv({
      PROMO_CODE_GRANTS: [
        {
          code: "FRIENDS-PLUS-2026",
          tier: "plus",
          expires_at: Math.floor(Date.now() / 1_000) + 3_600
        }
      ]
    });
    const context = makeRequestContext({
      parentIdentity: {
        uid: "parent-promo-1",
        provider: "firebase"
      }
    });

    const envelope = redeemPromoCodeEntitlements(
      {
        code: " friends-plus-2026 "
      },
      context,
      env
    );

    expect(envelope.snapshot.tier).toBe("plus");
    expect(envelope.snapshot.source).toBe("promo_grant");
    expect(envelope.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-promo-1",
      auth_provider: "firebase"
    });
  });

  it("rejects promo redemption for invalid codes", () => {
    expect(() =>
      redeemPromoCodeEntitlements(
        {
          code: "missing-code"
        },
        makeRequestContext({
          parentIdentity: {
            uid: "parent-promo-1",
            provider: "firebase"
          }
        }),
        makeTestEnv()
      )
    ).toThrowError(/promo code was not found/i);
  });

  it("rejects promo redemption for already-redeemed codes", () => {
    const env = makeTestEnv({
      PROMO_CODE_GRANTS: [
        {
          code: "ONE-TIME-PLUS",
          tier: "plus",
          expires_at: Math.floor(Date.now() / 1_000) + 3_600
        }
      ]
    });

    redeemPromoCodeEntitlements(
      {
        code: "ONE-TIME-PLUS"
      },
      makeRequestContext({
        parentIdentity: {
          uid: "parent-promo-1",
          provider: "firebase"
        }
      }),
      env
    );

    expect(() =>
      redeemPromoCodeEntitlements(
        {
          code: "ONE-TIME-PLUS"
        },
        makeRequestContext({
          parentIdentity: {
            uid: "parent-promo-2",
            provider: "firebase"
          }
        }),
        env
      )
    ).toThrowError(/already redeemed/i);
  });

  it("rejects promo redemption for expired codes", () => {
    const env = makeTestEnv({
      PROMO_CODE_GRANTS: [
        {
          code: "EXPIRED-PLUS",
          tier: "plus",
          expires_at: Math.floor(Date.now() / 1_000) - 1
        }
      ]
    });

    expect(() =>
      redeemPromoCodeEntitlements(
        {
          code: "EXPIRED-PLUS"
        },
        makeRequestContext({
          parentIdentity: {
            uid: "parent-promo-1",
            provider: "firebase"
          }
        }),
        env
      )
    ).toThrowError(/expired/i);
  });

  it("reloads persisted parent-owned entitlements after an in-memory reset", () => {
    const persistencePath = path.join(os.tmpdir(), `storytime-entitlements-${Date.now()}.json`);
    const env = makeTestEnv({
      ENTITLEMENTS_PERSIST_PATH: persistencePath
    });
    configureEntitlementPersistence(persistencePath);

    issueSyncedEntitlements(
      {
        refresh_reason: "purchase",
        active_product_ids: ["storytime.plus.monthly"],
        transactions: []
      },
      makeRequestContext({
        parentIdentity: {
          uid: "parent-persist-1",
          provider: "firebase"
        }
      }),
      env
    );

    resetEntitlementUsageLedger({ clearPersistence: false });
    configureEntitlementPersistence(persistencePath);

    const reloaded = issueBootstrapEntitlements(
      makeRequest(),
      makeRequestContext({
        parentIdentity: {
          uid: "parent-persist-1",
          provider: "firebase"
        }
      }),
      env
    );

    expect(reloaded.snapshot.tier).toBe("plus");
    expect(reloaded.snapshot.source).toBe("storekit_verified");
    expect(reloaded.owner).toEqual({
      kind: "parent_user",
      parent_user_id: "parent-persist-1",
      auth_provider: "firebase"
    });

    if (fs.existsSync(persistencePath)) {
      fs.unlinkSync(persistencePath);
    }
  });

  it("reloads persisted promo redemptions after an in-memory reset", () => {
    const persistencePath = path.join(os.tmpdir(), `storytime-promo-redemptions-${Date.now()}.json`);
    const env = makeTestEnv({
      ENTITLEMENTS_PERSIST_PATH: persistencePath,
      PROMO_CODE_GRANTS: [
        {
          code: "RELOAD-PLUS-2026",
          tier: "plus",
          expires_at: Math.floor(Date.now() / 1_000) + 3_600
        }
      ]
    });
    configureEntitlementPersistence(persistencePath);

    redeemPromoCodeEntitlements(
      {
        code: "RELOAD-PLUS-2026"
      },
      makeRequestContext({
        parentIdentity: {
          uid: "parent-persist-alpha",
          provider: "firebase"
        }
      }),
      env
    );

    resetEntitlementUsageLedger({ clearPersistence: false });
    configureEntitlementPersistence(persistencePath);

    expect(() =>
      redeemPromoCodeEntitlements(
        {
          code: "RELOAD-PLUS-2026"
        },
        makeRequestContext({
          parentIdentity: {
            uid: "parent-persist-beta",
            provider: "firebase"
          }
        }),
        env
      )
    ).toThrowError(/already redeemed/i);

    if (fs.existsSync(persistencePath)) {
      fs.unlinkSync(persistencePath);
    }
  });

  it("reloads persisted restore claims after an in-memory reset", () => {
    const persistencePath = path.join(os.tmpdir(), `storytime-restore-claims-${Date.now()}.json`);
    const env = makeTestEnv({
      ENTITLEMENTS_PERSIST_PATH: persistencePath
    });
    configureEntitlementPersistence(persistencePath);

    issueSyncedEntitlements(
      {
        refresh_reason: "restore",
        active_product_ids: ["storytime.plus.yearly"],
        transactions: [
          {
            product_id: "storytime.plus.yearly",
            original_transaction_id: "restore-original-1",
            latest_transaction_id: "restore-latest-1",
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
      makeRequestContext({
        installId: "install-reload-restore-claim",
        parentIdentity: {
          uid: "parent-persist-alpha",
          provider: "firebase"
        }
      }),
      env
    );

    resetEntitlementUsageLedger({ clearPersistence: false });
    configureEntitlementPersistence(persistencePath);

    expect(() =>
      issueSyncedEntitlements(
        {
          refresh_reason: "restore",
          active_product_ids: ["storytime.plus.yearly"],
          transactions: [
            {
              product_id: "storytime.plus.yearly",
              original_transaction_id: "restore-original-2",
              latest_transaction_id: "restore-latest-2",
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
        makeRequestContext({
          installId: "install-reload-restore-claim",
          parentIdentity: {
            uid: "parent-persist-beta",
            provider: "firebase"
          }
        }),
        env
      )
    ).toThrowError(/restore claim belongs to a different parent account on this device/i);

    if (fs.existsSync(persistencePath)) {
      fs.unlinkSync(persistencePath);
    }
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
          "x-storytime-entitlement": first.entitlements!.token
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
          "x-storytime-entitlement": second.entitlements!.token
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
    expect(first.entitlements?.snapshot.remaining_story_starts).toBe(1);

    expect(second.allowed).toBe(true);
    expect(second.snapshot.remaining_story_starts).toBe(0);

    expect(third.allowed).toBe(false);
    expect(third.block_reason).toBe("story_starts_exhausted");
    expect(third.snapshot.remaining_story_starts).toBe(0);
    expect(third.entitlements?.snapshot.remaining_story_starts).toBe(0);
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
