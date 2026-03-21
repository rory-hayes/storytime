# Live Authenticated Commerce Verification Prep

Date: 2026-03-21
Milestone: `M13.3a - Live authenticated-commerce verification prep and support rerun`

## Why This Milestone Was Split

- The original `M13.3` milestone asked for a real live-environment verification pass covering production `Sign in with Apple`, App Store purchase, and App Store restore.
- That work requires a human-operated physical iOS device, a live-capable build, and real Apple or App Store environment interaction that cannot be completed honestly from this repo automation environment alone.
- This prep milestone reruns the deterministic support pack, records the exact live prerequisites and manual steps, and leaves the actual live execution for `M13.3b`.

## Code And Docs Inspected

- `ios/StoryTime/App/ParentAuthManager.swift`
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Features/Story/HomeView.swift`
- `backend/src/app.ts`
- `backend/src/lib/entitlements.ts`
- `docs/authenticated-commerce-hardening-plan.md`
- `docs/verification/onboarding-activation-verification.md`
- `docs/verification/account-payment-promo-happy-path-verification.md`
- `docs/verification/authenticated-restore-entitlement-refresh-verification.md`
- `docs/verification/restore-mismatch-device-fallback-verification.md`
- `PLANS.md`
- `SPRINT.md`

## Deterministic Support Commands

Commands rerun successfully in this prep pass:

```bash
cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts
cd /Users/rory/Documents/StoryTime/backend && npm run build
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/ParentAuthManagerTests/testSignOutRestoresLastInstallOwnedEntitlementSnapshot -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityWithoutEntitlementsPreservesInstallFallback -only-testing:StoryTimeTests/APIClientTests/testRestoreSyncSurfacesParentMismatchFailure -only-testing:StoryTimeTests/APIClientTests/testRedeemPromoCodeStoresPromoGrantOwnerMetadata -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanSignInWithAppleAndPersistAcrossRelaunch -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanCompleteParentManagedPlusPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowRestoreMismatchForDifferentParentOnSameDevice
```

Attempted but unstable in this prep pass:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut
```

- That isolated rerun exited after simulator or runner instability around the system notification prompt seam.
- The same restore-plus-then-sign-out product path already has passing evidence in `docs/verification/restore-mismatch-device-fallback-verification.md`, so this prep pass treats the rerun instability as a support-pack limitation rather than a newly reproduced product failure.

## Current Environment Check

Commands checked during the blocked execution follow-up:

```bash
xcrun xctrace list devices
xcrun devicectl list devices
xcrun devicectl list devices --verbose
```

Current result:

- `xcrun devicectl list devices` now reports one connected physical iPhone.
- `xcrun devicectl list devices --verbose` shows that device as:
  - `bootState: booted`
  - `osVersionNumber: 26.3.1`
  - `pairingState: unpaired`
  - `tunnelState: disconnected`
- `xcrun xctrace list devices` shows the local Mac host, simulator runtimes, and the same physical iPhone.

Interpretation:

- The blocker is no longer "no device exists".
- The blocker is now that the available physical iPhone is not yet paired or ready for live developer execution, and the live Apple/App Store credentials plus human-operated pass are still missing.

## Outcome Matrix

### VERIFIED BY TEST

- Backend entitlement, restore-claim, and promo routes still pass the focused support suite after the durability and mismatch milestones.
- The focused iOS unit suite still passes the current install-fallback, restore-mismatch, promo-grant, purchase-refresh, and sign-out-fallback logic.
- Deterministic UI support still passes:
  - `Sign in with Apple` parent-account relaunch persistence
  - parent-managed Plus purchase completion
  - restore mismatch rejection for a different parent on the same device

### VERIFIED BY CODE INSPECTION

- The live production pass should still use parent-managed surfaces only: onboarding or Parent Controls for account, purchase, restore, and promo work.
- Child storytelling surfaces remain out of scope for live commerce verification.
- The current same-device restore rule is explicit: restored Plus stays linked to the parent account that restored it on that device or install, and a different signed-in parent should receive the restore-conflict message instead of a silent transfer.

### PARTIALLY VERIFIED

- The deterministic restore-plus-then-sign-out UI path is still supported by earlier passing `M13.2` evidence, but this prep pass did not reproduce that path cleanly because the simulator runner became unstable during rerun.
- First-run onboarding plus live Apple or App Store behavior is still only partially covered here because this prep milestone reran the simpler Parent Controls path as the support baseline.

### UNVERIFIED

- Production `Sign in with Apple` on a physical device.
- Live App Store purchase sheet completion against the real product configuration.
- Live App Store restore on a physical device, including real post-purchase reinstall or relogin behavior.
- Live family-share behavior and broader cross-device restore semantics.

## Live Execution Prerequisites For M13.3b

- One physical iPhone or iPad running a supported iOS version.
- That device must be paired and ready for developer execution.
- A build connected to the live backend and live Firebase configuration.
- A build channel that can perform the real purchase or restore flow intended for release verification.
- One primary parent account for purchase and restore verification.
- One secondary parent account for optional restore-mismatch validation on the same device after the primary restore path is proven.
- One live-purchase-capable Apple ID appropriate for the chosen release-verification environment.
- A way to capture screenshots, timestamps, and exact outcomes for the final verification artifact.

## Live Execution Checklist For M13.3b

1. Install a clean build on a physical device and confirm the app opens into onboarding or the expected parent-managed setup path.
2. Complete parent sign-in with production `Sign in with Apple`.
3. Record whether Apple auth returns to the app cleanly, whether the signed-in parent status is shown, and whether relaunch preserves that signed-in parent.
4. Enter Parent Controls or the approved onboarding plan step and complete a live Plus purchase.
5. Record the exact product shown, whether the purchase sheet completes successfully, and whether the app shows the expected Plus state afterward.
6. Force-close and relaunch the app, then confirm the purchased Plus state still resolves for the signed-in parent.
7. Reinstall the app or otherwise reach a clean restore scenario on the same physical device.
8. Sign back in as the same parent and execute Restore Purchases from the approved parent-managed surface.
9. Record whether restore completes, whether Plus state returns, and whether parent-facing copy stays truthful.
10. Optional mismatch check: sign out, sign in as a different parent, attempt restore again on the same device, and record whether the explicit restore-conflict rule appears instead of transferring access.
11. Record screenshots or notes for every major step, plus the exact date, device model, iOS version, build identifier, and any Apple or StoreKit environment assumptions.

## Required Evidence To Capture In M13.3b

- Absolute date and time of the live pass.
- Device model and iOS version.
- Build identifier or distribution channel.
- Whether the pass used onboarding or Parent Controls for each step.
- One outcome line each for:
  - Apple sign-in
  - purchase completion
  - relaunch persistence
  - restore completion
  - optional mismatch attempt
- Any discrepancy between live behavior and current deterministic repo behavior.

## Conclusion

`M13.3a` is complete in repo terms. The deterministic support pack is refreshed, the live-only execution gap is explicit, and `M13.3b` can now focus on the actual physical-device verification pass instead of spending another run rediscovering prerequisites or command coverage.
