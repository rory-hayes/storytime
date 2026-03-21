# Authenticated Commerce Hardening Plan

Date: 2026-03-21
Milestone: M13.0 - Authenticated commerce hardening plan and queue approval

## Scope

This planning milestone turns the remaining authenticated-commerce gaps after Sprint 11 and Phase 12 into an approved execution queue. It stays inside the parent identity, entitlement, payment, restore, and promo trust boundary. It does not widen into cloud sync, cross-device continuity, child-facing commerce, or unrelated runtime changes.

Primary code and docs inspected:
- `backend/src/app.ts`
- `backend/src/lib/entitlements.ts`
- `backend/src/lib/env.ts`
- `backend/src/lib/security.ts`
- `backend/src/tests/entitlements.test.ts`
- `ios/StoryTime/Networking/APIClient.swift`
- `docs/parent-account-payment-foundation-architecture.md`
- `docs/verification/sprint-11-parent-account-commerce-summary.md`
- `docs/verification/account-payment-promo-happy-path-verification.md`
- `docs/verification/authenticated-restore-entitlement-refresh-verification.md`
- `docs/verification/onboarding-activation-verification.md`
- `PLANS.md`
- `SPRINT.md`

## Commands Executed

No new automated tests were run in this milestone.

This was a repo-grounded planning pass based on the existing implementation, current verification artifacts, and the recorded open risks after `M11.9` and `M12.2`.

## Current Repo Truth

- VERIFIED BY CODE INSPECTION: authenticated entitlement ownership already exists as an explicit backend concept, and bootstrap, sync, preflight, and promo redemption all operate with owner metadata and signed entitlement envelopes.
- VERIFIED BY CODE INSPECTION: parent-managed purchase, restore, and promo flows already stay out of child storytelling surfaces and are reachable from onboarding plus Parent Controls.
- VERIFIED BY TEST: the repo already has direct automated evidence for account-backed purchase, restore, and promo recovery, plus first-run onboarding gating and post-onboarding management flows.
- VERIFIED BY CODE INSPECTION: backend entitlement records and promo redemptions are still process-local in `backend/src/lib/entitlements.ts` through in-memory `Map` storage.
- VERIFIED BY CODE INSPECTION: the backend currently has no durable storage or reload path for authenticated entitlement records or promo redemption ledgers comparable to the existing persisted analytics report.
- PARTIALLY VERIFIED: restore behavior is implemented and tested for authenticated parent ownership, but the final product rule for StoreKit-account mismatch, signed-in parent mismatch, family-share edge cases, and device-local fallback is still only partially locked.
- UNVERIFIED: live production `Sign in with Apple`, live App Store purchase behavior, and live App Store restore behavior remain outside deterministic repo automation.

## Why A New Phase Is Needed

Phase 12 closed the onboarding activation work, but it did not change the core authenticated-commerce hardening recommendation already recorded in Sprint 11:

- the commerce foundation works in repo terms
- the remaining risk is still inside the identity/payment/entitlement trust boundary
- moving into cross-device continuity planning now would outrun the repo's current truth because account-backed commerce durability and mismatch rules are not final yet

The next phase should therefore stay narrow:

1. make authenticated entitlement and promo state durable
2. lock the explicit restore and mismatch product rule
3. rerun the live-environment verification that deterministic repo tests cannot finish alone

## Approved Phase 13 Queue

### M13.1 - Durable authenticated entitlement and promo persistence

Goal:
- Replace process-local authenticated entitlement and promo redemption storage with a durable repo-fit persistence layer without widening into story-history cloud sync.

Scope:
- persist parent-owned entitlement records and promo redemption ledgers across backend restarts
- keep ownership, source, and signed snapshot behavior explicit
- add migration or bootstrap behavior only for entitlement or promo data, not for story continuity

Required tests:
- backend entitlement and promo persistence tests
- backend integration coverage for restart-safe entitlement lookup and promo reuse blocking
- `APIClientTests` only if the entitlement contract changes

### M13.2 - Restore mismatch and device-fallback product rule

Goal:
- Make restore, mismatch, sign-out fallback, and family-share edge handling explicit and truthful across onboarding and Parent Controls.

Scope:
- define and implement the user-visible rule when StoreKit ownership and the signed-in parent disagree
- preserve parent-managed surfaces and child-safe boundaries
- keep device-local fallback explicit instead of silent

Required tests:
- `StoryTimeUITests`
- `APIClientTests`
- backend route or integration tests if sync or restore contract behavior changes
- updated verification doc with explicit evidence labels

### M13.3 - Live authenticated-commerce verification pass

Goal:
- Record the first explicit live-environment verification pass for production `Sign in with Apple`, purchase, and restore after the durable and mismatch foundations are locked.

Scope:
- verify live Apple-auth sign-in behavior
- verify live App Store purchase and restore behavior
- record exact manual or semi-automated steps, outcomes, and remaining environment-dependent gaps

Required verification:
- updated verification artifact in `docs/verification/`
- exact commands and manual steps
- explicit `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, and `UNVERIFIED` labeling

## Explicit Deferrals

- VERIFIED BY CODE INSPECTION: cross-device story sync and account-linked story-history portability remain deferred.
- VERIFIED BY CODE INSPECTION: broader family-management roles or admin consoles remain deferred.
- VERIFIED BY CODE INSPECTION: child-facing auth or purchase surfaces remain out of scope.

## Alignment Outcome

- VERIFIED BY CODE INSPECTION: the repo now has an approved post-Phase-12 workstream instead of an empty queue.
- VERIFIED BY CODE INSPECTION: the next implementation target stays inside authenticated-commerce hardening rather than widening into unrelated product work.
- VERIFIED BY CODE INSPECTION: the first concrete next milestone is `M13.1 - Durable authenticated entitlement and promo persistence`.

## Recommended Next Milestone

`M13.1 - Durable authenticated entitlement and promo persistence`

Reason:
- it closes the most concrete production-hardening gap still visible in code
- it is a prerequisite for truthful mismatch handling and later live-environment verification
- it stays inside the current product truth: account-backed commerce hardening without cloud-sync expansion
