# Authenticated Restore And Entitlement Refresh Verification

Date: 2026-03-20

## Scope

- Code paths inspected:
  - `ios/StoryTime/Features/Story/HomeView.swift`
  - `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
  - `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
  - `ios/StoryTime/App/ParentAuthManager.swift`
  - `ios/StoryTime/App/UITestSeed.swift`
  - `ios/StoryTime/Networking/APIClient.swift`
  - `backend/src/lib/entitlements.ts`
  - `backend/src/tests/app.integration.test.ts`
  - `backend/src/tests/entitlements.test.ts`
- Tests executed:
  - `npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts`
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/ParentAuthManagerTests`
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterAuthenticatedRestore`
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterAuthenticatedPlanRefresh`
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut`

## Results

- VERIFIED BY TEST: backend restore sync now requires authenticated parent identity and returns parent-owned entitlement metadata.
  - Evidence:
    - `backend/src/tests/app.integration.test.ts`
    - `backend/src/tests/entitlements.test.ts`
    - Restore-linked entitlement sync now rejects unauthenticated restore with `parent_auth_required` and returns parent-owned `owner` metadata when restore is tied to a signed-in parent account.

- VERIFIED BY TEST: the iOS client preserves authenticated owner metadata for restore and maps restore account requirements safely.
  - Evidence:
    - `StoryTimeTests.APIClientTests.testRestoreSyncStoresAuthenticatedOwnerMetadata`
    - `StoryTimeTests.APIClientTests.testRestoreSyncWithoutParentAuthSurfacesAccountRequirement`
    - `StoryTimeTests.ParentAuthManagerTests.testSignOutRestoresLastInstallOwnedEntitlementSnapshot`
    - `StoryTimeTests.ParentAuthManagerTests.testSignOutClearsCachedParentOwnedEntitlements`
    - `StoryTimeTests.ParentAuthManagerTests.testSwitchingParentsClearsCachedEntitlementsOwnedByDifferentParent`

- VERIFIED BY TEST: blocked new-story start can recover after authenticated restore.
  - Evidence:
    - `StoryTimeUITests.testJourneyBlockedStartCanRecoverAfterAuthenticatedRestore`
    - The flow blocks before session start, routes through the parent gate and parent controls, creates a parent account, performs restore from the parent-managed surface, dismisses back to `NewStoryJourneyView`, and successfully retries into `VoiceSessionView`.

- VERIFIED BY TEST: blocked saved-series continuation can recover after authenticated plan refresh.
  - Evidence:
    - `StoryTimeUITests.testSeriesDetailBlockedContinuationCanRecoverAfterAuthenticatedPlanRefresh`
    - The flow blocks `New Episode`, routes through the parent gate and parent controls, creates a parent account, refreshes plan state in the parent-managed surface, dismisses back to `StorySeriesDetailView`, and successfully retries into `VoiceSessionView`.

- VERIFIED BY CODE INSPECTION: authenticated restore and refresh stay parent-managed and do not add purchase or auth clutter to child-session surfaces.
  - Evidence:
    - `HomeView` now requires signed-in parent state before restore, shows parent-account requirement copy in `ParentTrustCenterView`, and uses the existing parent-managed controls instead of adding restore or auth prompts to `NewStoryJourneyView`, `StorySeriesDetailView`, or `VoiceSessionView`.
    - `NewStoryJourneyView` and `StorySeriesDetailView` still reopen their original launch buttons only after entitlement state materially changes.

- PARTIALLY VERIFIED: signing out after a restored parent-owned entitlement should fall back to the last install-owned entitlement snapshot on the device.
  - Evidence:
    - `AppEntitlements` now persists the last install-owned entitlement envelope separately and restores that baseline when a parent-owned entitlement no longer matches the signed-in parent.
    - `StoryTimeTests.ParentAuthManagerTests.testSignOutRestoresLastInstallOwnedEntitlementSnapshot` passes.
  - Gap:
    - `StoryTimeUITests.testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut` is still failing because the parent-controls UI does not yet observe the expected `Starter` title after sign-out, even though the cache fallback path is now covered at unit level.

- UNVERIFIED: live App Store restore sheet behavior and production StoreKit/account mismatch semantics.
  - Evidence:
    - This verification pass used deterministic UI-test restore seeding for repeatable repo evidence.
  - Gap:
    - Real App Store restore completion, family-share edge cases, and mismatch handling between StoreKit ownership, authenticated parent account, and current device state still require live-environment verification and a final explicit product rule.

## Conclusion

`M11.6` is materially advanced but not fully closed. The backend, iOS contract handling, and both blocked-flow recovery paths now have direct automated evidence under authenticated restore or refresh conditions. The remaining repo blocker is one parent-controls UI assertion: after restore and sign-out, the surface still does not visibly settle on the expected `Starter` plan title in UI automation, so the milestone should remain in progress until that last stale-state presentation gap is resolved or intentionally re-scoped.
