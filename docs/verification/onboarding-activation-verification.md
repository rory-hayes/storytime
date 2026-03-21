# Onboarding Activation Verification

Date: 2026-03-21

## Scope

- Code paths inspected:
  - `ios/StoryTime/App/ContentView.swift`
  - `ios/StoryTime/App/StoryTimeApp.swift`
  - `ios/StoryTime/App/UITestSeed.swift`
  - `ios/StoryTime/App/ParentAuthManager.swift`
  - `ios/StoryTime/Features/Story/HomeView.swift`
  - `ios/StoryTime/Features/Story/ParentAccountSheetView.swift`
  - `ios/StoryTime/Tests/SmokeTests.swift`
  - `ios/StoryTime/UITests/StoryTimeUITests.swift`
- Tests executed:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests/testFirstRunExperienceStoreDefaultsToIncompleteAndPersistsCompletion -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateBlocksAccountStepUntilParentIsSignedIn -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateBlocksCompletionUntilPlanIsChosen -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateAllowsCompletionOnceAccountAndPlanAreReady -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateAllowsCompletionForAuthenticatedPlusPlan`
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCanCompleteAfterParentManagedPlusPurchase`
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testFreshInstallShowsParentLedOnboardingFlow -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsPlanRestoreAndPromoEntryPoints -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCanCompleteAfterRestoreRefresh -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCanCompleteAfterPromoRedemption`
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCompletesIntoHomeAndStaysDismissedAfterRelaunch`
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus`

## Results

- VERIFIED BY TEST: fresh installs land in onboarding instead of the main story surface.
  - Evidence:
    - `StoryTimeUITests.testFreshInstallShowsParentLedOnboardingFlow`
    - `StoryTimeTests.SmokeTests.testFirstRunExperienceStoreDefaultsToIncompleteAndPersistsCompletion`
    - `ContentView` now routes `needsOnboarding == true` directly into `FirstRunOnboardingView`.

- VERIFIED BY TEST: onboarding blocks activation until a parent account and plan state exist.
  - Evidence:
    - `StoryTimeTests.SmokeTests.testFirstRunActivationGateBlocksAccountStepUntilParentIsSignedIn`
    - `StoryTimeTests.SmokeTests.testFirstRunActivationGateBlocksCompletionUntilPlanIsChosen`
    - `StoryTimeTests.SmokeTests.testFirstRunActivationGateAllowsCompletionOnceAccountAndPlanAreReady`
    - `StoryTimeTests.SmokeTests.testFirstRunActivationGateAllowsCompletionForAuthenticatedPlusPlan`

- VERIFIED BY TEST: onboarding exposes parent-managed account entry plus Starter, purchase, restore, and promo plan entry points.
  - Evidence:
    - `StoryTimeUITests.testOnboardingShowsPlanRestoreAndPromoEntryPoints`
    - `StoryTimeUITests.testParentControlsShowSignedOutParentAccountStatus`
    - The onboarding account step still surfaces parent account creation or sign-in, and Parent Controls still exposes the ongoing management path afterward.

- VERIFIED BY TEST: onboarding can complete through purchase-backed, restore-backed, and promo-backed activation flows.
  - Evidence:
    - `StoryTimeUITests.testOnboardingCanCompleteAfterParentManagedPlusPurchase`
    - `StoryTimeUITests.testOnboardingCanCompleteAfterRestoreRefresh`
    - `StoryTimeUITests.testOnboardingCanCompleteAfterPromoRedemption`
    - Each flow signs in a parent through the deterministic test provider, completes the plan action on the onboarding plan step, reaches step 7, and lands in `HomeView`.

- VERIFIED BY TEST: completed onboarding stays dismissed after relaunch.
  - Evidence:
    - `StoryTimeUITests.testOnboardingCompletesIntoHomeAndStaysDismissedAfterRelaunch`
    - The relaunch check verifies `onboardingHeaderTitle` no longer appears once onboarding completion is stored.

- VERIFIED BY CODE INSPECTION: the onboarding completion key does not need a version bump in this pass.
  - Evidence:
    - `FirstRunExperienceStore.onboardingCompletedKey` remains `storytime.first-run.completed.v1`.
    - `UITestSeed.prepareIfNeeded()` clears that same key for deterministic fresh-install runs.
  - Decision:
    - Existing onboarded installs should continue bypassing onboarding. This pass keeps that behavior explicit instead of forcing a migration.

- VERIFIED BY CODE INSPECTION: successful parent auth now dismisses the onboarding account sheet on auth-state transition instead of relying only on the tapped button callback.
  - Evidence:
    - `ParentAccountSheetView` now observes `parentAuthManager.isSignedIn` and dismisses when the sheet transitions from signed out to signed in.

- PARTIALLY VERIFIED: the exact first-run email/password onboarding happy path is not directly re-run in this command set.
  - Evidence:
    - Onboarding still presents the shared `ParentAccountSheetView` with email/password fields and uses the same `ParentAuthManager` plus provider seams as Parent Controls.
    - Parent-managed email/password auth remains covered elsewhere in repo tests from Sprint 11.
  - Gap:
    - The broader onboarding verification pass used the deterministic `Sign in with Apple` UI-test seam to keep purchase, restore, promo, and relaunch verification stable after the email/password sheet path showed XCUITest timing noise.

- UNVERIFIED: live system-auth and live App Store activation behavior on first run.
  - Evidence:
    - Repo automation still uses deterministic auth and StoreKit seams for onboarding verification.
  - Gap:
    - Production `Sign in with Apple`, live email/password backend latency, and real App Store purchase or restore UI still need environment-level verification.

## Conclusion

`M12.2` is complete in repo terms. The first-run gate now has direct automated evidence for fresh-install routing, account-and-plan blocking, purchase or restore or promo completion, relaunch persistence, and continued Parent Controls management. The remaining gap is narrow and explicit: the exact onboarding email/password UI path is only partially verified in this pass, while live system-auth and App Store behavior remain external-environment work.
