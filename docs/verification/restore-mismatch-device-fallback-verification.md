# Restore Mismatch And Device-Fallback Verification

Date: 2026-03-21
Milestone: `M13.2 - Restore mismatch and device-fallback product rule`

## Product Rule

- Restore-linked Plus now stays claimed to the parent account that restored it on the current device or install.
- If a different signed-in parent later tries to restore the same device-level Plus ownership, StoryTime rejects the restore with `restore_parent_mismatch` instead of silently transferring access.
- Signing out falls back to the local device state intentionally; restored Plus does not move between signed-in parent accounts on the same device.

## Commands

```bash
cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts
cd /Users/rory/Documents/StoryTime/backend && npm run build
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testRestoreSyncSurfacesParentMismatchFailure
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowRestoreMismatchForDifferentParentOnSameDevice -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsPlanRestoreAndPromoEntryPoints
```

## Files Inspected

- `backend/src/lib/entitlements.ts`
- `backend/src/app.ts`
- `backend/src/tests/entitlements.test.ts`
- `backend/src/tests/app.integration.test.ts`
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/App/UITestSeed.swift`
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Tests/APIClientTests.swift`
- `ios/StoryTime/UITests/StoryTimeUITests.swift`

## Outcome Matrix

### VERIFIED BY TEST

- Backend restore sync now rejects a second parent account on the same install with `restore_parent_mismatch`, and the restore-claim ledger survives both in-memory reset and backend recreation.
- iOS `APIClient` now surfaces the `409 restore_parent_mismatch` response with the parent-facing restore-conflict message intact.
- Parent Controls now shows explicit signed-out restore copy, successful restore-linked Plus ownership copy, and the mismatch error path for a different signed-in parent on the same device.
- Onboarding now exposes the same restore-ownership summary so first-run activation does not hide the restore rule.

### VERIFIED BY CODE INSPECTION

- `backend/src/lib/entitlements.ts` now persists install-level restore claims separately from entitlement ownership and checks those claims before issuing restored Plus ownership to a signed-in parent.
- `ios/StoryTime/Features/Story/HomeView.swift` now keeps the local fallback rule explicit in both the signed-out restore summary and the signed-in ownership summary instead of implying restored access can move between parents.
- `ios/StoryTime/App/UITestSeed.swift` provides a deterministic mismatch seam only for UI automation; the real product rule is enforced server-side through the restore-claim check.

### PARTIALLY VERIFIED

- Family-share or other StoreKit edge cases now fall under the same no-transfer rule if they surface as active Plus ownership on the current install, but repo automation did not exercise a live family-share environment.
- Device-local fallback is explicit in code and UI copy, but the exact post-sign-out fallback tier still depends on the local entitlement snapshot available on that install.

### UNVERIFIED

- Live App Store restore sheet behavior with production Apple IDs.
- Production `Sign in with Apple` plus real App Store restore conflict handling on physical devices.
- Cross-device restore transfer semantics beyond the current same-install no-transfer rule.

## Notes

- This milestone deliberately did not change the restore or entitlement envelope contract.
- Remaining live-environment verification work moves to `M13.3`.
