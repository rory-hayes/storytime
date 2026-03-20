# Commercial Upgrade Happy-Path Verification

Date: 2026-03-20

## Scope

- Code paths inspected:
  - `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
  - `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
  - `ios/StoryTime/Features/Story/HomeView.swift`
  - `ios/StoryTime/App/UITestSeed.swift`
  - `ios/StoryTime/Networking/APIClient.swift`
  - `backend/src/tests/app.integration.test.ts`
- Tests executed:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationRoutesToParentManagedReview`
  - `npm test -- --run src/tests/app.integration.test.ts`

## Results

- VERIFIED BY TEST: blocked new-story start can recover after a parent-managed purchase.
  - Evidence:
    - `StoryTimeUITests.testJourneyBlockedStartCanRecoverAfterParentManagedPurchase`
    - The flow blocks before session start, routes through the parent gate and review sheet, completes the parent-managed Plus purchase in `ParentTrustCenterView`, dismisses back to `NewStoryJourneyView`, and successfully retries into `VoiceSessionView`.

- VERIFIED BY TEST: blocked saved-series continuation can recover after a parent-managed purchase.
  - Evidence:
    - `StoryTimeUITests.testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase`
    - The flow blocks `New Episode`, keeps replay separate, routes through the parent gate and review sheet, completes the parent-managed Plus purchase in `ParentTrustCenterView`, dismisses back to `StorySeriesDetailView`, and successfully retries into `VoiceSessionView`.

- VERIFIED BY TEST: retry uses refreshed entitlement state instead of bypassing gating.
  - Evidence:
    - `APIClientTests.testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync`
    - The client first stores the purchase-refreshed entitlement token from `/v1/entitlements/sync`, then sends that refreshed token on the next `/v1/entitlements/preflight` request and receives an allowed decision.

- VERIFIED BY TEST: the backend contract supports blocked-to-purchased-to-allowed recovery.
  - Evidence:
    - `backend/src/tests/app.integration.test.ts`
    - `allows blocked new-story preflight after purchase refresh updates the entitlement token`
    - A starter preflight blocked on child-profile limits becomes allowed after a purchase refresh returns a Plus entitlement token and that token is reused on the next preflight.

- VERIFIED BY CODE INSPECTION: retry remains parent-managed and purchase-free in child-session surfaces.
  - Evidence:
    - `JourneyUpgradeReviewView` and `SeriesDetailUpgradeReviewView` still route parents into `ParentTrustCenterView`.
    - `NewStoryJourneyView` and `StorySeriesDetailView` now clear stale blocked state only after the entitlement snapshot or token changes, so retry returns to the original start buttons instead of embedding purchase UI into `VoiceSessionView`.
    - `VoiceSessionView` was not modified to host purchase or recovery prompts.

- PARTIALLY VERIFIED: blocked flows can also recover after a non-purchase entitlement refresh when the refreshed snapshot materially changes.
  - Evidence:
    - Code inspection of `refreshBlockedStateAfterParentReview()` in `NewStoryJourneyView` and `StorySeriesDetailView`
    - The same stale-block clearing path watches for either snapshot or token changes, so restore or refresh can reopen retry when counters or permissions change.
  - Gap:
    - This exact restore-driven UI recovery path was not directly executed in this verification pass.

- UNVERIFIED: production App Store sheet behavior and live StoreKit product availability.
  - Evidence:
    - The repo now has a production StoreKit-backed purchase path, but this pass used the seeded UI purchase provider for deterministic verification.
  - Gap:
    - Live App Store purchase completion still needs final launch rerun coverage and production configuration readiness in `M10.3`.

## Conclusion

`M10.2` closes the remaining happy-path verification blocker in repo terms. StoryTime now has direct automated evidence that both blocked new-story and blocked continuation flows can recover after parent-managed purchase, that the retry path uses refreshed entitlements instead of bypassing preflight, and that purchase UI remains outside the child session. The remaining commercial launch work is the final rerun and closeout in `M10.3`.
