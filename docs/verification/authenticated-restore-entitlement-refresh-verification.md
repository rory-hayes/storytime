# Authenticated Restore And Entitlement Refresh Verification

Date: 2026-03-21

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
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityWithoutEntitlementsPreservesInstallFallback -only-testing:StoryTimeTests/ParentAuthManagerTests/testSignOutRestoresLastInstallOwnedEntitlementSnapshot`
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
    - `StoryTimeTests.APIClientTests.testBootstrapSessionIdentityWithoutEntitlementsPreservesInstallFallback`
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

- VERIFIED BY TEST: signing out after a restored parent-owned entitlement falls back to the last install-owned entitlement snapshot on the device.
  - Evidence:
    - `AppEntitlements` persists the last install-owned entitlement envelope separately and restores that baseline when a parent-owned entitlement no longer matches the signed-in parent.
    - `APIClient.ensureSessionIdentity(baseURL:)` now clears only the current entitlement when bootstrap returns no entitlement envelope, preserving the install-owned fallback instead of wiping it.
    - `StoryTimeTests.APIClientTests.testBootstrapSessionIdentityWithoutEntitlementsPreservesInstallFallback` passes.
    - `StoryTimeTests.ParentAuthManagerTests.testSignOutRestoresLastInstallOwnedEntitlementSnapshot` passes.
    - `StoryTimeUITests.testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut` passes.

- UNVERIFIED: live App Store restore sheet behavior and production StoreKit/account mismatch semantics.
  - Evidence:
    - This verification pass used deterministic UI-test restore seeding for repeatable repo evidence.
  - Gap:
    - Real App Store restore completion, family-share edge cases, and mismatch handling between StoreKit ownership, authenticated parent account, and current device state still require live-environment verification and a final explicit product rule.

## Conclusion

`M11.6` is complete in repo terms. The backend, iOS entitlement bootstrap and sign-out handling, and both blocked-flow recovery paths now have direct automated evidence under authenticated restore or refresh conditions, including the parent-controls restore-plus-then-sign-out path. The remaining gaps are environment-dependent only: live App Store restore behavior and final production mismatch semantics between StoreKit ownership, authenticated parent identity, and device-local fallback still require external verification.
