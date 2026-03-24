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

## 2026-03-22 Device Debugging Unblocker

Code paths inspected during the live-device follow-up:

- `ios/StoryTime/App/AppConfig.swift`
- `ios/StoryTime/App/Info.plist`
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
- `ios/StoryTime/App/UITestSeed.swift`
- `ios/StoryTime/Tests/SmokeTests.swift`
- `ios/StoryTime/UITests/StoryTimeUITests.swift`

Device and local-debug outcome:

- The physical iPhone was later paired successfully and became developer-ready.
- A debug build was installed locally on device through a Personal Team after temporarily removing the `Sign in with Apple` capability for local signing.
- That local device run exposed one repo-fit blocker in the app itself: Parent Controls only reloaded cached entitlement state on first open, and launch surfaces still swallowed the underlying preflight error behind the generic "plan check unavailable" copy.

Repo changes made as the minimum unblocker:

- `ParentTrustCenterView` now auto-bootstraps plan status when no cached entitlement snapshot exists, instead of showing `Plan status unavailable` until a parent manually taps refresh.
- `NewStoryJourneyView` and `StorySeriesDetailView` now surface a safe, sanitized plan-check failure message rather than discarding the underlying contract error entirely.
- `UITestSeed` now supports starting with no seeded entitlement cache so the new parent-controls bootstrap path can be verified deterministically.

Commands run:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsBootstrapPlanStatusWhenCacheStartsEmpty -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests/testPlanStatusPresentationSurfacesSafePlanMessages
```

Observed result:

- Both targeted reruns passed after the helper was folded into an existing compiled file.
- An initial parallel xcodebuild attempt hit a transient `build.db` lock and was rerun sequentially; no product code change was required for that retry.

## 2026-03-22 Live-Capable Build Blocker Confirmation

Current environment checks:

```bash
xcrun devicectl list devices --verbose
xcodebuild -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -showBuildSettings | rg "DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN_ENTITLEMENTS|CODE_SIGN_STYLE"
git diff -- ios/StoryTime/App/StoryTime.entitlements ios/StoryTime/StoryTime.xcodeproj/project.pbxproj
```

Current result:

- The physical iPhone is now fully developer-ready again:
  - `pairingState: paired`
  - `ddiServicesAvailable: true`
  - `tunnelState: connected`
- The current repo working tree still reflects the local Personal Team signing path used for debug installation:
  - `ios/StoryTime/App/StoryTime.entitlements` is currently an empty `<dict/>`
  - `ios/StoryTime/StoryTime.xcodeproj/project.pbxproj` currently sets `DEVELOPMENT_TEAM = 5H788MVV6G`
  - current build settings still resolve `CODE_SIGN_ENTITLEMENTS = App/StoryTime.entitlements`

Interpretation:

- The blocker is no longer physical-device readiness.
- The blocker is now the currently signed build configuration itself: the local Personal Team debug path removed the real `Sign in with Apple` entitlement, so the current on-device build cannot satisfy the production Apple-auth portion of `M13.3b2`.
- The final live pass still requires a live-capable signed build that restores the real Apple capability, plus real Apple/App Store credentials and the human-operated purchase or restore execution.

## 2026-03-22 Explicit Backend-Target Debug Fix

Code paths inspected during the follow-up:

- `ios/StoryTime/App/AppConfig.swift`
- `ios/StoryTime/Tests/SmokeTests.swift`

Repo-fit issue:

- Debug builds still appended the localhost fallback candidate even when `API_BASE_URL` was explicitly set to the hosted backend for a physical-device run.
- That meant a live-device debug session could silently fall through to `http://127.0.0.1:8787` after a hosted timeout or transport failure, which made a stuck `Checking Plan...` repro much less truthful.
- Localhost was also still available by default on physical devices, even though that fallback is only meaningful on the simulator unless a developer explicitly opts into a device-side localhost experiment.

Repo change made:

- `AppConfig.candidateAPIBaseURLs(...)` now suppresses the localhost debug fallback when an explicit `API_BASE_URL` override is present.
- Physical-device debug runs no longer append localhost by default; a developer must explicitly opt in with `STORYTIME_ALLOW_DEVICE_LOCALHOST_FALLBACK=1`.
- The localhost fallback still remains available by default for simulator debug runs that do not explicitly choose a backend target.

Command run:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests
```

Observed result:

- The `SmokeTests` slice passed `24` tests, including the updated AppConfig candidate-order coverage and the new simulator-versus-device localhost-fallback coverage.

## 2026-03-22 Parent Auth Token Timeout Guard

Code paths inspected during the follow-up:

- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Tests/APIClientTests.swift`
- `ios/StoryTime/Tests/SmokeTests.swift`

Repo-fit issue:

- A follow-up physical-device repro still hung at `Checking Plan...` even after the explicit backend-target fix.
- Repo inspection showed `APIClient` awaited Firebase parent-token lookup before session bootstrap and entitlement preflight with no timeout at all.
- If that token provider stalled instead of returning a token or `nil`, the app could wait indefinitely before any request reached the backend, leaving the parent with no truthful plan-check error.

Repo change made:

- `APIClient` now bounds parent-auth token lookup with a timeout before applying the `x-storytime-parent-auth` header.
- If token lookup stalls, the request continues without that header so the existing backend contract can return a truthful `parent_auth_required` or other safe plan-check response.
- Focused API client coverage now verifies that a stalled parent-auth token provider no longer traps entitlement preflight forever.

Command run:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testPreflightDoesNotHangWhenParentAuthTokenProviderStalls -only-testing:StoryTimeTests/SmokeTests
```

Observed result:

- The focused simulator slice passed `25` tests.
- `APIClientTests.testPreflightDoesNotHangWhenParentAuthTokenProviderStalls` now proves that a hung parent-auth provider falls through to a normal `401 parent_auth_required` response instead of hanging indefinitely.

## 2026-03-22 Request Transport Timeout Guard

Code paths inspected during the follow-up:

- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Tests/APIClientTests.swift`

Repo-fit issue:

- After the explicit backend-target and parent-auth token timeout fixes, the remaining silent-spinner path was the transport itself.
- If `URLSession.data(for:)` never yielded a response cleanly, the entitlement preflight task could still stay in flight indefinitely and leave the UI stuck on `Checking Plan...`.

Repo change made:

- `APIClient.perform(...)` now bounds the request transport by the request timeout interval instead of trusting the lower-level request wait to fail deterministically on every device path.
- A stalled transport now falls through to the existing connection-failure path, which means the parent sees the safe plan-service failure message instead of an indefinite spinner.
- Focused API client coverage now verifies both silent-stall protections: parent-auth token timeout and request-transport timeout.

Command run:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testPreflightDoesNotHangWhenParentAuthTokenProviderStalls -only-testing:StoryTimeTests/APIClientTests/testPreflightTimesOutWhenTransportStalls -only-testing:StoryTimeTests/SmokeTests
```

Observed result:

- The focused simulator slice passed `26` tests.
- `APIClientTests.testPreflightTimesOutWhenTransportStalls` now proves that a stalled entitlement preflight transport becomes a normal connection failure instead of hanging indefinitely.

## Outcome Matrix

## 2026-03-22 Physical-Device Plan-Check Debug Overlay

- Trigger: After the backend-target, parent-auth timeout, and transport-timeout guards landed, the local phone repro could still sit on `Checking Plan...` without producing usable console output for the current Xcode session.
- Commands:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests`
- Files inspected:
  - `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
  - `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
  - `ios/StoryTime/Networking/APIClient.swift`
  - `ios/StoryTime/Tests/SmokeTests.swift`
- Files changed:
  - `ios/StoryTime/Features/Story/HomeView.swift`
  - `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
  - `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
  - `ios/StoryTime/Tests/SmokeTests.swift`
- Result:
  - The story-start surfaces now expose an opt-in `STORYTIME_DEBUG_PLAN_CHECK_OVERLAY=1` overlay for local physical-device debugging only.
- The overlay shows safe, short phase messages sourced from `APIClientTraceEvent` for session bootstrap and entitlement preflight, plus the sanitized user-facing failure category when the request falls through to an error.
- The focused simulator slice passed `26` tests.

## 2026-03-22 Realtime Connect Timeout Guard

- Trigger: A follow-up physical-device repro clarified that the remaining indefinite spinner was no longer only the plan-check path. `Start Voice Session` itself could still hang after the bridge was ready because `RealtimeVoiceClient.connect(...)` had no timeout once it sent the bridge `connect` command.
- Commands:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartupCallConnectFailureUsesSafeMessageAndCategory -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartupCallConnectTimeoutUsesSafeMessageAndCategory`
- Files inspected:
  - `ios/StoryTime/Core/RealtimeVoiceClient.swift`
  - `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
  - `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`
  - `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- Files changed:
  - `ios/StoryTime/Core/RealtimeVoiceClient.swift`
  - `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
  - `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`
  - `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- Result:
  - `RealtimeVoiceClient.connect(...)` now bounds the post-command bridge connect handshake with an explicit timeout and resolves the pending connection safely if the bridge never responds.
  - `PracticeSessionViewModel` now maps that timeout into the existing `callConnect` startup failure category, so the app can fail with safe connection copy instead of leaving the startup flow stuck forever.
  - The focused simulator slice passed `17` tests.

## 2026-03-22 Voice Startup Debug Overlay

- Trigger: Even after the plan-check guards and realtime-connect timeout landed, a fresh local phone repro still reported the same stuck `Start Voice Session` behavior, and the available console output was not enough to distinguish the remaining boot phase on-device.
- Commands:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests`
- Files inspected:
  - `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
  - `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
  - `ios/StoryTime/Tests/SmokeTests.swift`
- Files changed:
  - `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
  - `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
  - `ios/StoryTime/Tests/SmokeTests.swift`
- Result:
  - `VoiceSessionView` now exposes an opt-in `STORYTIME_DEBUG_VOICE_STARTUP_OVERLAY=1` overlay for local physical-device debugging only.
  - The overlay shows safe boot-phase breadcrumbs from `PracticeSessionViewModel`: current conversation phase, active startup step, status message, last startup failure, and the latest safe session traces.
  - The focused simulator slice passed `28` tests.

## 2026-03-22 Hosted Backend Route Mismatch Confirmation

- Trigger: A fresh physical-device repro finally surfaced a concrete plan-check failure instead of another silent spinner. The on-device `Plan Check Debug` overlay showed `Plan service responded (404)` followed by `Displayed error: server returned 404.`
- Commands:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests`
  - `curl -i -s https://backend-brown-ten-94.vercel.app/health`
  - `curl -i -s -X POST https://backend-brown-ten-94.vercel.app/v1/session/identity -H 'Content-Type: application/json' -H 'X-StoryTime-Install-ID: debug-install' -d '{}'`
  - `curl -i -s -X POST https://backend-brown-ten-94.vercel.app/v1/entitlements/preflight -H 'Content-Type: application/json' -H 'X-StoryTime-Install-ID: debug-install' -d '{"action":"new_story_start","context":{"child_profile_id":"debug-child","length_minutes":4,"child_profile_count":1}}'`
  - `vercel deploy /Users/rory/Documents/StoryTime/backend -y`
  - `vercel curl /health --deployment https://backend-hmrffqq7a-rorys-projects-accf0d71.vercel.app`
  - `vercel curl /v1/entitlements/preflight --deployment https://backend-hmrffqq7a-rorys-projects-accf0d71.vercel.app -- --request POST --header 'Content-Type: application/json' --header 'X-StoryTime-Install-ID: debug-install' --data '{"action":"new_story_start","context":{"child_profile_id":"debug-child","length_minutes":4,"child_profile_count":1}}'`
- Files inspected:
  - `ios/StoryTime/App/AppConfig.swift`
  - `ios/StoryTime/Features/Story/HomeView.swift`
  - `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
  - `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
  - `backend/src/app.ts`
  - `backend/api/index.ts`
  - `backend/vercel.json`
  - `backend/src/tests/vercel-api.test.ts`
- Files changed:
  - `ios/StoryTime/App/AppConfig.swift`
  - `ios/StoryTime/Features/Story/HomeView.swift`
  - `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
  - `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
  - `ios/StoryTime/Tests/SmokeTests.swift`
- Result:
  - The on-device debug overlay now includes backend target candidates plus full route-aware trace messages so local repros can show the exact plan-check target and route.
  - The focused simulator slice passed `29` tests.
  - The current production alias `https://backend-brown-ten-94.vercel.app` still returns `200` for `/health` and `200` for `POST /v1/session/identity`, but it returns `404 Cannot POST /v1/entitlements/preflight`.
  - The active repo backend source still defines `app.post("/v1/entitlements/preflight", ...)`, so the local failure is now confirmed as a hosted deployment mismatch, not another silent client-side spinner.
  - A fresh Vercel preview deployment was created at `https://backend-hmrffqq7a-rorys-projects-accf0d71.vercel.app`, but authenticated preview checks currently fail with `FUNCTION_INVOCATION_FAILED`, so the preview is not yet a usable replacement backend for phone testing.

## 2026-03-23 Production Backend Redeploy And Route Restoration

- Trigger: The user asked to deploy the backend through Vercel after simulator and physical-device repros both confirmed the same `404` on `POST /v1/entitlements/preflight`.
- Commands:
  - `vercel deploy /Users/rory/Documents/StoryTime/backend --prod -y`
  - `vercel logs https://backend-brown-ten-94.vercel.app --since 15m --no-follow --level error --expand`
  - `vercel env ls production`
  - `printf 'true\n' | vercel env add API_AUTH_REQUIRED production`
  - `vercel deploy /Users/rory/Documents/StoryTime/backend --prod -y`
  - `curl -i -s https://backend-brown-ten-94.vercel.app/health`
  - `curl -i -s -X POST https://backend-brown-ten-94.vercel.app/v1/session/identity -H 'Content-Type: application/json' -H 'X-StoryTime-Install-ID: debug-install' -d '{}'`
  - `curl -i -s -X POST https://backend-brown-ten-94.vercel.app/v1/entitlements/preflight -H 'Content-Type: application/json' -H 'X-StoryTime-Install-ID: debug-install' -d '{"action":"new_story_start","context":{"child_profile_id":"debug-child","length_minutes":4,"child_profile_count":1}}'`
- Files inspected:
  - `backend/src/lib/env.ts`
  - `backend/vercel.json`
  - `backend/api/index.ts`
- Files changed:
  - no repo source files changed in the backend for this deploy; the fix was the production Vercel environment plus the redeploy itself
- Result:
  - The first production redeploy failed at runtime with `FUNCTION_INVOCATION_FAILED` on every route.
  - Vercel runtime logs showed the exact startup error: `API_AUTH_REQUIRED must be enabled in production.`
  - `vercel env ls production` confirmed that `API_AUTH_REQUIRED` was missing from the production environment.
  - After adding `API_AUTH_REQUIRED=true` to production and redeploying, the production alias `https://backend-brown-ten-94.vercel.app` was restored.
  - The restored production alias now returns:
    - `200` for `/health`
    - `200` for `POST /v1/session/identity`
    - `401 missing_session_token` for a bare `POST /v1/entitlements/preflight`
  - The original `404 Cannot POST /v1/entitlements/preflight` mismatch is now resolved on production.

### VERIFIED BY TEST

- Backend entitlement, restore-claim, and promo routes still pass the focused support suite after the durability and mismatch milestones.
- The focused iOS unit suite still passes the current install-fallback, restore-mismatch, promo-grant, purchase-refresh, and sign-out-fallback logic.
- The focused realtime startup slice now also proves that a bridge-ready but never-connected realtime session fails safely through the existing `callConnect` startup path instead of hanging forever.
- The focused smoke suite now also proves that the opt-in voice-startup overlay enable flag and safe summary formatting compile and behave deterministically.
- Deterministic UI support still passes:
  - `Sign in with Apple` parent-account relaunch persistence
  - parent-managed Plus purchase completion
  - restore mismatch rejection for a different parent on the same device

### VERIFIED BY CODE INSPECTION

- The live production pass should still use parent-managed surfaces only: onboarding or Parent Controls for account, purchase, restore, and promo work.
- Child storytelling surfaces remain out of scope for live commerce verification.
- The current same-device restore rule is explicit: restored Plus stays linked to the parent account that restored it on that device or install, and a different signed-in parent should receive the restore-conflict message instead of a silent transfer.
- Parent Controls now truthfully bootstraps plan state on first open when the device has no cached entitlement envelope, instead of requiring a hidden manual refresh to leave `Plan status unavailable`.
- The API client now treats a stalled parent-auth token lookup as a timeout-bound missing token, so entitlement preflight can fail truthfully instead of hanging forever before any request is sent.
- The API client now also bounds the request transport itself, so a stalled entitlement-preflight request becomes a normal connection failure instead of leaving the UI spinner stuck indefinitely.
- Local physical-device debugging can now show safe in-app phase breadcrumbs for parent session bootstrap and entitlement preflight even when Xcode console capture is unreliable.
- Local physical-device debugging can now also show the backend target candidate list plus full route-aware phase messages, which is what made the hosted `404` mismatch explicit.

### PARTIALLY VERIFIED

- The deterministic restore-plus-then-sign-out UI path is still supported by earlier passing `M13.2` evidence, but this prep pass did not reproduce that path cleanly because the simulator runner became unstable during rerun.
- First-run onboarding plus live Apple or App Store behavior is still only partially covered here because this prep milestone reran the simpler Parent Controls path as the support baseline.
- The current production backend alias now has direct evidence for a route mismatch: `/v1/session/identity` is live, while `/v1/entitlements/preflight` still returns `404` on the deployed alias used by the app.
- The production backend alias has now been restored and the old `404` route mismatch is closed. The alias now exposes `/v1/entitlements/preflight` and correctly enforces session-token requirements with `401 missing_session_token` when the caller omits the session token.
- The local physical-device run is now good enough to expose repo-fit entitlement and preflight issues, but it still does not count as the live Apple-auth or App Store verification pass because the Personal Team build removed `Sign in with Apple` capability for local signing.
- The physical device itself is no longer the blocker; the remaining repo-visible blocker is that the current working tree and signed build are still configured for the Personal Team debug path with the Apple sign-in entitlement removed.
- The new in-app plan-check overlay only applies when `STORYTIME_DEBUG_PLAN_CHECK_OVERLAY=1` is set for a local debug run. It is a local troubleshooting aid, not live-verification evidence.

### UNVERIFIED

- Production `Sign in with Apple` on a physical device.
- Live App Store purchase sheet completion against the real product configuration.
- Live App Store restore on a physical device, including real post-purchase reinstall or relogin behavior.
- Live family-share behavior and broader cross-device restore semantics.

## Live Execution Prerequisites For M13.3b

- One physical iPhone or iPad running a supported iOS version.
- That device must be paired and ready for developer execution.
- A live-capable signed build that restores the real `Sign in with Apple` entitlement instead of the current Personal Team debug signing path.
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
