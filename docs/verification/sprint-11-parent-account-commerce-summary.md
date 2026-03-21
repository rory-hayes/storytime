# Sprint 11 Parent Account And Commerce Summary

Date: 2026-03-21
Milestone: M11.9 - Post-sprint readiness summary and remaining gaps

## Scope

- Code paths inspected:
  - `ios/StoryTime/App/ParentAuthManager.swift`
  - `ios/StoryTime/Features/Story/HomeView.swift`
  - `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
  - `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
  - `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
  - `ios/StoryTime/Networking/APIClient.swift`
  - `backend/src/app.ts`
  - `backend/src/lib/entitlements.ts`
  - `docs/parent-account-payment-foundation-architecture.md`
  - `docs/promo-code-redemption-setup.md`
  - `docs/verification/authenticated-restore-entitlement-refresh-verification.md`
  - `docs/verification/account-payment-promo-happy-path-verification.md`
  - `PLANS.md`
  - `SPRINT.md`

## Sprint 11 Verification Command Set

These are the exact verification commands recorded across `M11.2` through `M11.8`.

- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/ParentAuthManagerTests`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsParentAccountStatusOnHandoffStep -only-testing:StoryTimeUITests/StoryTimeUITests/testChildStorySurfacesRemainFreeOfAccountPrompts`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanCreateParentAccountAndPersistAcrossRelaunch -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanSignOutAndSignBackIn -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsParentAccountStatusOnHandoffStep -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingParentAccountEntryRemainsOptional -only-testing:StoryTimeUITests/StoryTimeUITests/testChildStorySurfacesRemainFreeOfAccountPrompts`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanSignInWithAppleAndPersistAcrossRelaunch -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingParentAccountEntryRemainsOptional -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsParentAccountStatusOnHandoffStep -only-testing:StoryTimeUITests/StoryTimeUITests/testChildStorySurfacesRemainFreeOfAccountPrompts`
- `npm test -- --run src/tests/auth-security.test.ts src/tests/app.integration.test.ts src/tests/entitlements.test.ts`
- `npm run build`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests`
- `npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests -only-testing:StoryTimeTests/APIClientTests`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanCompleteParentManagedPlusPurchase`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterParentManagedPlusPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/ParentAuthManagerTests`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterAuthenticatedRestore`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterAuthenticatedPlanRefresh`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityWithoutEntitlementsPreservesInstallFallback -only-testing:StoryTimeTests/ParentAuthManagerTests/testSignOutRestoresLastInstallOwnedEntitlementSnapshot`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testRedeemPromoCodeStoresPromoGrantOwnerMetadata -only-testing:StoryTimeTests/APIClientTests/testRedeemPromoCodeSurfacesInvalidPromoFailure -only-testing:StoryTimeTests/SmokeTests`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRedeemPromoCodeForSignedInParent`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRedeemedPromoEntitlementTokenAfterAuthenticatedUnlock`
- `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterAuthenticatedRestore -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterPromoRedemption -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterPromoRedemption`

## Outcome Summary

- VERIFIED BY TEST: parent-managed account creation, sign-in, sign-out, and relaunch persistence now work on approved parent surfaces, and child storytelling surfaces remain free of account prompts.
  - Evidence:
    - `M11.2`, `M11.3a`, and `M11.3b` targeted `ParentAuthManagerTests` and `StoryTimeUITests`
    - `ParentAuthManager` now owns explicit parent auth state and `ParentAccountSheetView` keeps the auth flow parent-managed.

- VERIFIED BY TEST: authenticated entitlement ownership is now explicit and separate from entitlement source.
  - Evidence:
    - `M11.4` backend auth, entitlement, and API coverage
    - `/v1/session/identity`, `/v1/entitlements/sync`, `/v1/entitlements/preflight`, and `/v1/entitlements/promo/redeem` now rely on authenticated parent identity for account-owned behavior.

- VERIFIED BY TEST: purchase, restore, and promo redemption all stay parent-managed and can unlock blocked product flows.
  - Evidence:
    - `docs/verification/authenticated-restore-entitlement-refresh-verification.md`
    - `docs/verification/account-payment-promo-happy-path-verification.md`
    - `StoryTimeUITests` now cover purchase-backed, restore-backed, and promo-backed blocked-to-unlocked recovery.

- VERIFIED BY TEST: retry after purchase or promo unlock uses refreshed authenticated entitlement state instead of bypassing gating.
  - Evidence:
    - `StoryTimeTests.APIClientTests.testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync`
    - `StoryTimeTests.APIClientTests.testPreflightUsesRedeemedPromoEntitlementTokenAfterAuthenticatedUnlock`
    - backend integration tests for blocked-to-allowed transitions

- VERIFIED BY CODE INSPECTION: child-facing runtime surfaces remain auth-free and purchase-free.
  - Evidence:
    - `VoiceSessionView` remains free of sign-in, purchase, restore, and promo UI.
    - Blocked flows still route into `ParentTrustCenterView` from `NewStoryJourneyView` and `StorySeriesDetailView`.

- VERIFIED BY CODE INSPECTION: story history and continuity remain local-only despite the new parent account layer.
  - Evidence:
    - Sprint 11 architecture and `PLANS.md` still explicitly defer cloud sync, cross-device portability, and account-linked story-history portability.

- PARTIALLY VERIFIED: production Sign in with Apple and live StoreKit surfaces are integrated, but repo automation still relies on deterministic providers for some environment-dependent system UI.
  - Evidence:
    - `M11.3b` records deterministic Apple-authenticated relaunch coverage while calling out the system Apple sheet as environment-dependent.
    - Purchase and restore verification rely on deterministic parent-managed StoreKit seeds for repo proof.

- PARTIALLY VERIFIED: restore-backed continuation recovery is covered in Sprint 11 evidence, but not re-run in the final aggregate `M11.8` command slice.
  - Evidence:
    - `StoryTimeUITests.testSeriesDetailBlockedContinuationCanRecoverAfterAuthenticatedPlanRefresh`
    - `docs/verification/authenticated-restore-entitlement-refresh-verification.md`

- UNVERIFIED: live App Store purchase and restore behavior, family-share edge cases, and the final mismatch rule between StoreKit ownership, authenticated parent identity, and current-device fallback.
  - Evidence:
    - `docs/verification/authenticated-restore-entitlement-refresh-verification.md`
    - `docs/verification/account-payment-promo-happy-path-verification.md`

- UNVERIFIED: durable backend persistence for authenticated entitlement ownership and promo redemption ledgers across backend restarts.
  - Evidence:
    - `backend/src/lib/entitlements.ts` still uses process-local repo storage for parent-owned entitlements and promo redemption tracking.
    - `PLANS.md` continues to record this as an intentional sprint tradeoff rather than a solved production-hardening concern.

## Recommendation

- VERIFIED BY CODE INSPECTION: the next workstream should stay on authenticated commerce hardening before any cross-device continuity or account-linked story-history planning.

Reason:
- Sprint 11 successfully established the smallest parent-account and commerce foundation, but the remaining unresolved items are still inside the identity, payment, and entitlement trust boundary.
- Live-environment commerce proof is still missing for App Store purchase and restore behavior.
- Restore mismatch semantics are still open and should be made explicit before the product broadens into account-linked continuity expectations.
- Backend entitlement and promo persistence are still process-local, which is acceptable for repo verification but not the right base for broader account-linked product promises.
- The repo still explicitly defers cloud sync and cross-device story portability, so moving into continuity planning now would outrun the locked Sprint 11 product truth.

Recommended next workstream:
- Define and implement durable authenticated entitlement and promo persistence.
- Lock the explicit product rule for StoreKit-account mismatch, restore conflict handling, and device-local fallback behavior.
- Run live-environment verification for production Apple sign-in, purchase, and restore flows after the persistence and mismatch rules are locked.
- Revisit cross-device continuity planning only after the commerce foundation is durable and truthfully verified.

## Conclusion

Sprint 11 is complete in repo terms. StoryTime now has a parent-managed account layer, authenticated entitlement ownership, parent-managed purchase and restore, explicit promo redemption, and direct automated evidence for blocked-to-unlocked recovery without adding auth or commerce clutter to child storytelling surfaces. The next repo recommendation is not cross-device continuity yet; it is a narrow authenticated-commerce hardening pass that closes the remaining live-environment and durability gaps first.
