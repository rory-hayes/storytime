# Account, Payment, And Promo Happy-Path Verification

Date: 2026-03-21

## Scope

- Code paths inspected:
  - `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
  - `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
  - `ios/StoryTime/Features/Story/HomeView.swift`
  - `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
  - `ios/StoryTime/App/UITestSeed.swift`
  - `ios/StoryTime/Networking/APIClient.swift`
  - `backend/src/tests/app.integration.test.ts`
  - `docs/verification/authenticated-restore-entitlement-refresh-verification.md`
- Tests executed:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRedeemedPromoEntitlementTokenAfterAuthenticatedUnlock`
  - `npm test -- --run src/tests/app.integration.test.ts`
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterAuthenticatedRestore -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterPromoRedemption -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterPromoRedemption`

## Route Assumptions

- Purchase and restore UI coverage use the deterministic parent-managed test providers already wired through `UITestSeed.swift`; they verify repo-owned flow behavior rather than live App Store sheet behavior.
- Promo coverage uses the real backend promo redemption contract plus deterministic promo catalog seeding for UI automation.
- Restore continuation evidence still lives in `docs/verification/authenticated-restore-entitlement-refresh-verification.md`; this pass re-ran the restore-backed new-story recovery path and reused the earlier continuation evidence rather than duplicating the full restore suite.

## Results

- VERIFIED BY TEST: blocked new-story start can recover after parent account creation plus authenticated purchase.
  - Evidence:
    - `StoryTimeUITests.testJourneyBlockedStartCanRecoverAfterParentManagedPurchase`
    - The flow blocks before `VoiceSessionView`, routes through the parent gate and parent review, creates a parent account, completes the parent-managed Plus purchase in `ParentTrustCenterView`, dismisses back to `NewStoryJourneyView`, and successfully retries into the story session.

- VERIFIED BY TEST: blocked saved-series continuation can recover after parent account creation plus authenticated purchase.
  - Evidence:
    - `StoryTimeUITests.testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase`
    - The flow blocks `New Episode`, keeps replay separate, routes through the parent gate and series review, completes the parent-managed Plus purchase, dismisses back to `StorySeriesDetailView`, and successfully retries into the story session.

- VERIFIED BY TEST: blocked new-story start can recover after parent account creation plus authenticated restore.
  - Evidence:
    - `StoryTimeUITests.testJourneyBlockedStartCanRecoverAfterAuthenticatedRestore`
    - `docs/verification/authenticated-restore-entitlement-refresh-verification.md`
    - Restore stays inside parent-managed controls, returns to the original journey surface after entitlement state changes, and allows the blocked start to retry successfully.

- VERIFIED BY TEST: blocked new-story start can recover after parent account creation plus promo redemption.
  - Evidence:
    - `StoryTimeUITests.testJourneyBlockedStartCanRecoverAfterPromoRedemption`
    - The flow blocks before `VoiceSessionView`, routes through the parent gate and parent review, creates a parent account, redeems a promo code in `ParentTrustCenterView`, dismisses back to `NewStoryJourneyView`, and successfully retries into the story session.

- VERIFIED BY TEST: blocked saved-series continuation can recover after parent account creation plus promo redemption.
  - Evidence:
    - `StoryTimeUITests.testSeriesDetailBlockedContinuationCanRecoverAfterPromoRedemption`
    - The flow blocks `New Episode`, keeps replay separate, routes through the parent gate and series review, redeems a promo code in `ParentTrustCenterView`, dismisses back to `StorySeriesDetailView`, and successfully retries into the story session.

- VERIFIED BY TEST: retry uses the authenticated entitlement path instead of bypassing gating after purchase or promo unlock.
  - Evidence:
    - `StoryTimeTests.APIClientTests.testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync`
    - `StoryTimeTests.APIClientTests.testPreflightUsesRedeemedPromoEntitlementTokenAfterAuthenticatedUnlock`
    - `backend/src/tests/app.integration.test.ts`
    - `allows blocked new-story preflight after purchase refresh updates the entitlement token`
    - `allows blocked new-story preflight after promo redemption updates the entitlement token`
    - The client stores the refreshed entitlement token after purchase sync or promo redemption, sends that token on the next `/v1/entitlements/preflight`, and receives an allowed decision instead of bypassing preflight locally.

- VERIFIED BY CODE INSPECTION: child-facing runtime surfaces still do not host auth, purchase, restore, or promo prompts.
  - Evidence:
    - `NewStoryJourneyView` and `StorySeriesDetailView` still route blocked flows into `ParentTrustCenterView` and only clear blocked state after entitlement state materially changes.
    - `VoiceSessionView` remains free of parent-account, purchase, restore, and promo UI while retry success happens before the child enters the live session.

- PARTIALLY VERIFIED: restore-backed continuation recovery remains covered in repo terms but was not re-run in this exact command set.
  - Evidence:
    - `StoryTimeUITests.testSeriesDetailBlockedContinuationCanRecoverAfterAuthenticatedPlanRefresh`
    - `docs/verification/authenticated-restore-entitlement-refresh-verification.md`
  - Gap:
    - This pass prioritized purchase and promo continuation recovery plus restore-backed new-story recovery, so the continuation refresh case still relies on the earlier focused restore verification run.

- UNVERIFIED: live App Store purchase and restore sheet behavior, family-share cases, and durable multi-process promo or entitlement storage.
  - Evidence:
    - Repo verification uses deterministic StoreKit and promo seeds plus process-local backend entitlement and promo ledgers.
  - Gap:
    - Live production commerce behavior still needs external verification, and backend promo or entitlement persistence is not durable across backend restarts yet.

## Conclusion

`M11.8` is complete in repo terms. The repo now has direct automated evidence that blocked new-story and blocked continuation flows can recover after parent account creation plus purchase or promo redemption, that restore stays parent-managed, and that retry uses refreshed authenticated entitlement state instead of bypassing gating. Child storytelling surfaces remain auth-free and purchase-free, and the remaining gaps are limited to live-environment commerce behavior and later durability hardening.
