# SPRINT.md

## Sprint Goal

Use the repo-ready MVP baseline to ship the smallest parent-account, authenticated-entitlement, StoreKit, and promo-grant foundation without weakening the runtime gate or the child-safe product boundary.

## Execution Rules

- Work one milestone per Codex run unless the milestone is explicitly split first.
- Inspect the active code paths before editing.
- Use the active repo as the source of truth, not archived code or stale assumptions.
- If a milestone is too large for one run, split it into smaller milestones here before implementation.
- Do not mark a milestone `DONE` until its definition of done is met and its required tests pass.
- After every run, update both `PLANS.md` and this file.
- Keep `tiny-backend/` out of active implementation and planning except as labeled historical context.
- The hybrid runtime baseline and launch-ready MVP baseline are established; prioritize parent-managed account identity, authenticated entitlements, parent-only commerce flows, promo grants, and explicit blocked-to-unlocked verification unless a new runtime defect is explicitly recorded in `PLANS.md`.

## Queue State

- Sprint 10 is complete.
- The final launch recommendation is now recorded in `docs/verification/launch-candidate-acceptance-report.md` as `READY FOR MVP LAUNCH`.
- Sprint 11 is now approved as the parent-account and payment-foundation sprint.
- The next ordered milestone is still `M11.6 - Authenticated restore and entitlement refresh verification`.

## Status Legend

- `TODO`
- `IN PROGRESS`
- `DONE`
- `BLOCKED`

## Planning Placeholder

### M10.0 - Launch-gap assessment review and Sprint 10 approval

Status: `DONE`

Goal:
- Turn the current launch-gap assessment into an approved Sprint 10 execution queue without inventing scope during implementation runs.

Concrete tasks:
- Review `docs/verification/launch-readiness-gap-assessment.md`.
- Decide whether StoryTime is pursuing a commercial MVP launch or a narrower non-commercial launch scope.
- Approve an ordered Sprint 10 milestone group that closes any chosen launch blockers.

Required tests:
- None. This is a planning-only milestone.

Dependencies:
- `docs/verification/launch-readiness-gap-assessment.md`

Definition of done:
- `SPRINT.md` contains an approved ordered Sprint 10 milestone queue.
- The chosen launch scope is explicit enough that future runs can classify blockers consistently.

Completion notes:
- Gap assessment created on 2026-03-20.
- The final commercial-closure sprint is now approved and narrowed to `M10.1` through `M10.3`.
- Current recommendation remains `CONDITIONALLY READY IF BLOCKERS ARE CLOSED` until the commercial blockers are closed and launch readiness is rerun.

## Phase 10 - Final Commercial Closure

### M10.1 - Parent-managed purchase surface closure

Status: `DONE`

Goal:
- Add the smallest truthful in-app purchase completion path on parent-managed surfaces only so blocked commercial flows can close without moving purchase UI into the child runtime.

Concrete tasks:
- Inspect the current parent-managed upgrade destinations in `ParentTrustCenterView`, `JourneyUpgradeReviewView`, and `SeriesDetailUpgradeReviewView` and keep the approved parent-managed hierarchy intact.
- Add the minimum purchase completion path needed for the locked MVP using the existing StoreKit normalization seam and entitlement refresh flow.
- Keep purchase entry and recovery inside parent-managed surfaces only; do not add purchase UI to `VoiceSessionView`, live interruption flows, narration, or other child-facing runtime surfaces.
- Keep blocked-flow copy, plan framing, and upgrade affordances aligned with the active entitlement architecture and current Starter/Plus limits.
- Preserve existing restore behavior and truthful privacy or trust messaging while introducing purchase completion.

Required tests:
- `StoryTimeUITests` coverage for the parent-managed purchase entry path and for the absence of purchase UI in child-session surfaces
- `APIClientTests` coverage if purchase-state normalization, sync, or refresh handling changes
- backend entitlement route tests if sync or preflight contract behavior changes

Dependencies:
- `M10.0`
- `docs/verification/launch-readiness-gap-assessment.md`
- Existing entitlement bootstrap, sync, restore, and preflight foundations from `M9.3` through `M9.5`

Definition of done:
- A parent can complete the smallest truthful purchase path from approved parent-managed surfaces.
- Blocked launch-review surfaces can route into that purchase path without entering the child session.
- Purchase UI remains absent from `VoiceSessionView` and other child-facing runtime surfaces.
- Directly affected UI, unit, and backend tests pass.

Completion notes:
- `ParentTrustCenterView` now loads parent-managed Plus purchase options, presents a parent-only purchase CTA, and completes the smallest StoreKit-backed purchase path without moving purchase UI into the child runtime.
- `EntitlementManager` now supports purchase completion through the existing StoreKit normalization seam and refreshes the local entitlement snapshot after a verified purchase.
- Seeded UI coverage now proves the parent-managed upgrade path can complete and that `VoiceSessionView` still shows no purchase UI.

### M10.2 - Upgrade unblock happy-path verification

Status: `DONE`

Goal:
- Prove that the blocked-to-upgraded-to-unblocked happy path works end to end for the remaining commercial blockers.

Concrete tasks:
- Add or update automated coverage for blocked new-story start -> parent-managed purchase or entitlement refresh -> successful retry.
- Add or update automated coverage for blocked saved-series continuation -> parent-managed purchase or entitlement refresh -> successful retry, if the path remains applicable after `M10.1`.
- Verify that post-purchase or post-refresh retry uses refreshed entitlement state and preflight behavior instead of bypassing gating.
- Verify that replay remains available when only new remote-cost-bearing actions are blocked.
- Record the verification evidence in the appropriate repo verification artifact without widening into unrelated post-launch telemetry work.

Required tests or verification method:
- `StoryTimeUITests` for blocked new-story and blocked continuation recovery paths
- `APIClientTests` for refreshed entitlement-state handling and retry-safe preflight behavior
- backend integration tests for any changed `/v1/entitlements/sync` or `/v1/entitlements/preflight` contract behavior
- Updated verification doc with explicit evidence labels

Dependencies:
- `M10.1`

Definition of done:
- The repo has direct automated evidence that blocked commercial flows can recover after purchase or entitlement refresh.
- Both new-story and continuation recovery are covered if both remain launch-relevant.
- Retry succeeds without introducing purchase UI into the child session.
- Verification docs clearly distinguish what was verified by test versus inspection.

Completion notes:
- `NewStoryJourneyView` and `StorySeriesDetailView` now clear stale blocked state only after the entitlement snapshot or token changes, so retry stays on the normal preflight path instead of bypassing gating.
- Seeded UI tests now prove blocked new-story and blocked continuation flows can recover after parent-managed purchase and still enter `VoiceSessionView` without showing purchase UI in the child session.
- `APIClientTests` and backend integration coverage now prove purchase-refreshed entitlement tokens are reused on retry and that blocked preflight can become allowed after purchase refresh.
- `docs/verification/commercial-upgrade-happy-path-verification.md` now records the exact commands, evidence labels, and remaining live StoreKit gap for the final launch rerun.

### M10.3 - Commercial launch rerun and blocker closeout

Status: `DONE`

Goal:
- Rerun launch readiness after commercial blocker closure and record an explicit final launch recommendation for the active MVP scope.

Concrete tasks:
- Re-run the exact launch-readiness suites needed for the active MVP candidate, including the commercial closure coverage added in `M10.1` and `M10.2`.
- Update the launch-readiness report with the final blocker status, deferred non-blocking gaps, and the exact commands plus evidence labels.
- Explicitly choose one final recommendation in repo terms:
  - `READY FOR MVP LAUNCH`
  - `CONDITIONALLY READY`
  - `NOT YET READY FOR MVP LAUNCH`
- Update `PLANS.md` and `SPRINT.md` with the final sprint outcome and any remaining blocker or no-go state if the rerun does not pass cleanly.

Required tests or verification method:
- `scripts/run_hybrid_runtime_validation.sh`
- Backend launch-contract suite covering entitlement routes and existing launch-critical behavior
- iOS launch-product unit suite
- iOS launch-product UI suite including the new commercial blocker-closure coverage
- Updated launch report in `docs/verification/`

Dependencies:
- `M10.1`
- `M10.2`

Definition of done:
- The required launch-readiness command set has been rerun after commercial blocker closure.
- The repo contains an updated final launch report with exact commands, evidence labels, and one explicit recommendation.
- `PLANS.md` and `SPRINT.md` reflect whether StoryTime is ready, conditionally ready, or not yet ready after the final sprint.

Completion notes:
- The March 20, 2026 rerun passed the hybrid validation baseline, backend launch-contract suite, iOS launch-product unit suite, and full `38`-test iOS UI launch suite after `M10.1` and `M10.2`.
- The only rerun issue was a tightly related brittle UI assertion in `testJourneyReviewLinksToDurableParentPlanSurface`; updating that test to use the existing `scrollToElement(...)` pattern produced a clean targeted rerun and a clean full rerun without changing product behavior.
- `docs/verification/launch-candidate-acceptance-report.md` now records the final repo-grounded recommendation as `READY FOR MVP LAUNCH`, while keeping the external live App Store environment gap explicitly labeled as non-blocking and unverified in repo terms.

## Phase 11 - Parent Accounts, Authenticated Entitlements, And Commerce Foundation

### M11.1 - Account architecture and flow alignment

Status: `DONE`

Goal:
- Lock the minimal Sprint 11 architecture so parent identity, payments, entitlements, and promo grants fit the current repo without widening into cloud sync or child-facing auth friction.

Concrete tasks:
- Inspect the active parent-managed surfaces, install/session auth flow, entitlement token model, and Firebase bootstrap already present in the repo.
- Define the minimal parent account journey across onboarding, `HomeView`, `NewStoryJourneyView`, `StorySeriesDetailView`, and `ParentTrustCenterView`.
- Decide which parent auth methods are in scope first and which are explicitly deferred.
- Define how authenticated parent identity, StoreKit purchase ownership, backend entitlement records, and promo grants stay separate but connected.
- Define whether story history and continuity remain local-only in Sprint 11 and record any explicit deferrals such as cloud sync or cross-device continuity.
- Update the relevant planning docs and control files with the approved architecture, open decisions, and next implementation step.

Required tests or verification method:
- Planning-only milestone; no new automated tests required.
- Repo-grounded documentation update citing the inspected code paths, tests, and recent verification artifacts.

Dependencies:
- `docs/verification/launch-candidate-acceptance-report.md`
- Current auth, entitlement, and purchase seams in `ios/StoryTime/App/StoryTimeApp.swift`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `backend/src/app.ts`, `backend/src/lib/auth.ts`, `backend/src/lib/security.ts`, and `backend/src/lib/entitlements.ts`

Definition of done:
- The minimal Sprint 11 architecture is explicit in repo terms.
- Parent-managed auth and commerce boundaries are locked.
- The first implementation milestone after planning is specific enough for one Codex run.

Completion notes:
- `docs/parent-account-payment-foundation-architecture.md` now locks Sprint 11 around Firebase-backed parent identity layered on top of the existing install/session runtime model instead of replacing it outright.
- First-scope auth methods are now explicitly narrowed to `email/password` plus `Sign in with Apple`, while Google sign-in, phone auth, child identity, and broader family-role systems remain deferred.
- Parent identity, StoreKit purchase truth, and backend entitlement enforcement are now explicitly separated systems, with authenticated parent ownership kept separate from `EntitlementSnapshot.source`.
- Promo redemption is now locked as a parent-only, authenticated, bounded flow with `promo_grant` as the intended premium source, and story history plus continuity remain local-only for Sprint 11.

### M11.2 - Firebase Auth integration for parent identity

Status: `DONE`

Goal:
- Add the minimum Firebase Auth foundation needed to support parent identity without disturbing child-facing story flow or the verified runtime startup path.

Concrete tasks:
- Add the required Firebase Auth dependency and app bootstrap wiring on top of the existing `FirebaseCore` setup.
- Introduce a parent-auth manager or equivalent seam that can expose signed-in parent state to parent-managed UI surfaces.
- Keep install/session runtime bootstrap separate from parent identity until backend-authenticated ownership is ready.
- Ensure sign-in state is available to onboarding and `ParentTrustCenterView` without adding prompts to `VoiceSessionView`.
- Record any required config, environment, or local-development setup needed for repo use.

Required tests or verification method:
- New or updated iOS auth-manager tests
- `StoryTimeUITests` coverage proving child-facing story surfaces stay sign-in-free
- `APIClientTests` only if request headers or bootstrap behavior change

Dependencies:
- `M11.1`

Definition of done:
- The repo has a working Firebase Auth foundation for parent identity.
- Parent auth state is observable from parent-managed surfaces.
- Child storytelling surfaces remain auth-free.

Completion notes:
- `FirebaseAuth` is now linked in the iOS target on top of the existing `FirebaseCore` package setup, and `StoryTimeApp` now bootstraps Firebase before the parent-auth seam is created.
- The app now owns a dedicated `ParentAuthManager` observable object that listens to Firebase Auth state and exposes signed-in versus signed-out parent status without touching `APIClient` or the install/session runtime model.
- Onboarding handoff and `ParentTrustCenterView` now display parent-auth status, while `NewStoryJourneyView`, `StorySeriesDetailView`, and `VoiceSessionView` remain free of sign-in prompts.
- Targeted unit and UI coverage now prove the parent-auth seam works and that child-facing story surfaces stay sign-in-free.

### M11.3a - Email/password parent account surfaces and relaunch persistence

Status: `DONE`

Goal:
- Implement the smallest parent-managed account UI and persistence flow for `email/password` so a parent can create or sign into an account without turning story start into a sign-in-first experience.

Concrete tasks:
- Add a parent-managed account entry surface reachable from onboarding handoff or `ParentTrustCenterView`.
- Implement `email/password` create-account and sign-in flows through the Firebase-backed parent-auth seam.
- Persist and restore signed-in parent session state on app relaunch in a way that stays separate from child story history.
- Add parent-facing signed-in state, direct sign-out, and safe failure messaging where appropriate.
- Keep blocked launch review and purchase entry parent-managed, and do not inject sign-in prompts into `NewStoryJourneyView`, `StorySeriesDetailView`, or `VoiceSessionView` during child use.

Required tests or verification method:
- `StoryTimeUITests` for parent create account, sign in, relaunch persistence, and sign-out
- iOS auth-manager tests for parent session restoration and failure states

Dependencies:
- `M11.2`

Definition of done:
- A parent can create or sign into an account with `email/password` from a parent-managed surface.
- Signed-in state persists across relaunch.
- Child-facing story flows remain usable without direct auth clutter.

Completion notes:
- `ParentTrustCenterView` and onboarding handoff now route to a shared `ParentAccountSheetView` for parent-only `email/password` create-account and sign-in actions.
- `ParentAuthManager` now exposes async create-account and sign-in actions, safe failure messaging, and sign-out while keeping parent identity separate from install/session runtime plumbing.
- Direct signed-in sign-out now stays in `ParentTrustCenterView`, relaunch persistence is covered with the deterministic UI-test auth provider, and child-facing story surfaces remain auth-free in targeted UI coverage.

### M11.3b - Sign in with Apple on parent-managed account surfaces

Status: `DONE`

Goal:
- Add `Sign in with Apple` to the same parent-managed account surfaces so Sprint 11 completes the planned first-scope auth set without widening into child-facing auth friction.

Concrete tasks:
- Extend the parent account sheet and any related parent-led entry points with `Sign in with Apple`.
- Integrate the Apple sign-in credential flow into the existing `ParentAuthManager` seam without weakening explicit signed-in versus signed-out state handling.
- Ensure relaunch persistence, signed-in summary, sign-out, and safe cancellation or failure messaging remain explicit for Apple-authenticated sessions.
- Keep onboarding, `ParentTrustCenterView`, blocked review surfaces, and purchase entry parent-managed while leaving child story flow sign-in-free.
- Record any repo-level setup or simulator constraints needed to test the Apple flow honestly.

Required tests or verification method:
- `StoryTimeUITests` for parent-managed `Sign in with Apple` entry visibility and signed-in-state behavior
- iOS auth-manager tests for Apple sign-in success, cancellation, and failure handling

Dependencies:
- `M11.3a`

Definition of done:
- A parent can use `Sign in with Apple` from the approved parent-managed account surfaces.
- Apple-authenticated state is explicit, safe, and persistent across relaunch.
- Child-facing story flows remain free of direct auth prompts.

Completion notes:
- The shared `ParentAccountSheetView` now includes a parent-managed `Sign in with Apple` action alongside the existing `email/password` flow, and onboarding handoff plus `ParentTrustCenterView` continue to reuse that shared surface instead of adding auth prompts to child story flow.
- `ParentAuthManager` now supports Apple-authenticated sign-in, explicit Apple-versus-email signed-in summaries, safe cancellation messaging, and the Firebase Auth Apple credential flow behind the same observable parent-auth seam.
- The app target now includes the required Apple sign-in entitlement, and the repo records the environment constraint honestly: production code uses `AuthenticationServices`, while deterministic UI-test coverage uses the seeded test auth provider because the system Apple authorization sheet is environment-dependent in automation.
- Targeted unit and UI coverage now prove Apple-authenticated relaunch persistence on parent-managed surfaces and confirm child story surfaces remain free of direct auth prompts.

### M11.4 - Backend authenticated entitlement model alignment

Status: `DONE`

Goal:
- Align backend entitlement lookup, persistence, and preflight ownership to authenticated parent users while preserving the existing install/session runtime plumbing.

Concrete tasks:
- Add backend verification for Firebase-authenticated parent identity on the routes that need account ownership.
- Introduce the minimal backend user-ownership model needed for entitlement records and promo grants.
- Separate install-scoped runtime session behavior from authenticated parent ownership so the current realtime and story routes do not regress.
- Update entitlement bootstrap, sync, refresh, and preflight contracts to support authenticated ownership while keeping parent-managed surfaces truthful.
- Record the ownership model for purchase-derived versus promo-derived premium access.

Required tests or verification method:
- backend `auth-security.test.ts` updates for authenticated parent identity handling
- backend entitlement route or integration tests for authenticated ownership
- `APIClientTests` for any changed contract handling

Dependencies:
- `M11.1`
- `M11.2`

Definition of done:
- Backend entitlement ownership is explicit and authenticated.
- Install/session runtime plumbing still works for the active app architecture.
- Directly affected backend and client contract tests pass.

Completion notes:
- The backend now verifies Firebase-authenticated parent identity on `/v1/session/identity` and entitlement routes through an injected verifier seam and the `x-storytime-parent-auth` header.
- Entitlement owner is now explicit and separate from source; bootstrap, sync, and preflight return owner metadata, and signed entitlement tokens carry that owner forward for later checks.
- Authenticated parent entitlement records now resolve by parent user while story and realtime routes remain install/session scoped, and stale install-owned entitlement tokens are ignored once a parent account is authenticated.
- Targeted backend auth plus integration tests, a backend production build, and `APIClientTests` all pass for the updated ownership contract.

### M11.5 - StoreKit purchase integration in parent-managed surfaces

Status: `DONE`

Goal:
- Tie the existing parent-managed StoreKit purchase flow to authenticated parent accounts while keeping purchase UI out of child-session surfaces.

Concrete tasks:
- Reuse the existing StoreKit normalization seam and parent-managed purchase UI in `ParentTrustCenterView`.
- Connect purchase completion to the authenticated backend entitlement owner model instead of install-only entitlement ownership.
- Keep purchase initiation, completion, and failure handling in parent-managed surfaces only.
- Keep blocked review sheets routing into parent-managed surfaces rather than embedding purchase UI in story setup or voice runtime.
- Update parent-facing copy so purchase ownership and account expectations are truthful.

Required tests or verification method:
- `StoryTimeUITests` for authenticated parent-managed purchase completion
- `APIClientTests` for purchase-sync contract changes
- backend entitlement integration tests for authenticated purchase ownership

Dependencies:
- `M11.3a`
- `M11.3b`
- `M11.4`

Definition of done:
- An authenticated parent can complete a purchase from approved parent-managed surfaces.
- Purchase ownership is tied to the authenticated account.
- Child-session surfaces remain purchase-free.

Notes:
- Client and backend purchase ownership now require an authenticated parent account, and parent-facing copy in `ParentTrustCenterView` now explains that new purchases belong to the signed-in parent rather than only to the current device.
- Backend purchase-linked `/v1/entitlements/sync` now rejects unauthenticated purchase refresh with `parent_auth_required`, and targeted backend entitlement tests plus `APIClientTests`/`SmokeTests` are passing.
- Focused UI coverage now proves direct authenticated purchase completion in `ParentTrustCenterView`, plus blocked new-story and blocked continuation recovery after purchase while child-session surfaces remain purchase-free.
- UI-test account helpers now dismiss the system `Save Password?` sheet so parent-managed purchase verification remains deterministic without changing product behavior.

### M11.6 - Authenticated restore and entitlement refresh verification

Status: `IN PROGRESS`

Goal:
- Prove restore and entitlement refresh behave correctly once account ownership exists.

Concrete tasks:
- Verify restore works for the signed-in parent account and refreshes the correct entitlement owner.
- Verify account relaunch, sign-out, and re-sign-in do not leave stale entitlement state on device.
- Verify blocked new-story and continuation flows can recover after authenticated restore or entitlement refresh when the refreshed state materially changes.
- Record the verification evidence and any remaining environment-dependent gaps.

Required tests or verification method:
- `StoryTimeUITests` for authenticated restore and refresh recovery paths
- `APIClientTests` for refreshed authenticated entitlement-state handling
- backend integration tests for authenticated sync or refresh routes
- Updated verification doc with explicit evidence labels

Dependencies:
- `M11.5`

Definition of done:
- Restore and entitlement refresh are directly verified under authenticated user ownership.
- Retry uses refreshed authenticated entitlement state instead of bypassing gating.
- Remaining live-environment gaps are documented explicitly.

Notes:
- Backend restore-linked `/v1/entitlements/sync` now requires authenticated parent ownership with the same `parent_auth_required` boundary as purchase-linked sync, and targeted backend restore tests are passing.
- `APIClientTests` plus `ParentAuthManagerTests` now cover authenticated restore owner metadata, restore account requirements, and the new install-owned entitlement fallback path after parent sign-out.
- Isolated UI tests now prove blocked new-story recovery after authenticated restore and blocked continuation recovery after authenticated plan refresh.
- The milestone is not done yet because `StoryTimeUITests.testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut` still does not observe the expected `Starter` title after sign-out from restored Plus, even though the underlying fallback path now passes in unit coverage.

### M11.7 - Promo-code redemption flow for premium grants

Status: `TODO`

Goal:
- Add a bounded parent-only promo redemption flow that grants premium access through backend entitlement ownership without requiring a paid purchase.

Concrete tasks:
- Add a parent-managed promo redemption entry point in an approved parent surface.
- Define the minimal backend promo-grant record and redemption rules chosen in `M11.1`.
- Update the entitlement model so promo grants can produce premium access with truthful source or ownership metadata.
- Ensure promo redemption remains explicit, safe to test, and separate from paid purchase completion.
- Document any admin or seeding assumptions required for repo verification without relying on hidden debug-only behavior for real promo logic.

Required tests or verification method:
- `StoryTimeUITests` for promo redemption from a parent-managed surface
- `APIClientTests` for promo redemption contract handling
- backend integration tests for promo redemption success, invalid code, and already-used or expired code cases

Dependencies:
- `M11.3a`
- `M11.3b`
- `M11.4`

Definition of done:
- An authenticated parent can redeem a valid promo code and receive premium access.
- Promo-derived premium access is distinguishable from paid purchase ownership in the backend model.
- Promo failure modes are safe and test-covered.

### M11.8 - Account, payment, and promo happy-path verification

Status: `TODO`

Goal:
- Prove the new account-backed commercial flows work end to end without leaking auth or purchase friction into child storytelling surfaces.

Concrete tasks:
- Verify blocked new-story start -> parent sign in or account creation -> purchase -> unlock -> retry success.
- Verify blocked saved-series continuation -> parent sign in or account creation -> purchase -> unlock -> retry success.
- Verify blocked flows can also recover through promo redemption where applicable.
- Verify restore remains parent-managed and child-session surfaces stay auth-free and purchase-free.
- Record exact commands, evidence labels, remaining gaps, and any route-specific assumptions.

Required tests or verification method:
- `StoryTimeUITests` for purchase and promo recovery paths
- `APIClientTests` for authenticated entitlement-token or state reuse on retry
- backend integration tests for blocked-to-allowed authenticated transitions
- Updated verification artifact in `docs/verification/`

Dependencies:
- `M11.6`
- `M11.7`

Definition of done:
- The repo has direct automated evidence for purchase-backed and promo-backed blocked-to-unlocked recovery.
- Retry uses the authenticated entitlement path instead of bypassing gating.
- Child-facing runtime surfaces still do not host auth or purchase prompts.

### M11.9 - Post-sprint readiness summary and remaining gaps

Status: `TODO`

Goal:
- Summarize the resulting account and commerce foundation, remaining risks, and the next recommended workstream after Sprint 11.

Concrete tasks:
- Re-inspect the new parent-auth, entitlement, purchase, restore, and promo flows in repo terms.
- Record what is fully verified, partially verified, or still unverified after Sprint 11.
- Decide whether the next sprint should stay on authenticated commerce hardening or move into cross-device and account-linked continuity planning.
- Update `PLANS.md`, `SPRINT.md`, and the relevant verification or architecture docs with the explicit recommendation.

Required tests or verification method:
- The exact Sprint 11 verification command set recorded in the updated docs
- Updated summary or readiness report in `docs/`

Dependencies:
- `M11.8`

Definition of done:
- The repo contains one explicit post-sprint recommendation.
- Remaining gaps and intentional deferrals are documented clearly enough for the next queue decision.

## Phase 1 - Core Voice Reliability

### M1.1 - Realtime startup flow audit

Status: `DONE`

Goal:
- Map and reproduce the active startup path end to end so the failing branch is concrete before changing code.

Concrete tasks:
- Trace the active startup path from `VoiceSessionView.task` through `PracticeSessionViewModel.startSession()`.
- Trace `APIClient.prepareConnection()`, `/v1/session/identity`, `/v1/realtime/session`, `RealtimeVoiceClient.connect()`, the hidden `WKWebView` bridge, and `/v1/realtime/call`.
- Record the exact current assumptions around base URL, endpoint path, session header, install header, and SDP exchange.
- Identify the currently failing startup branch and capture the reproduction steps in `PLANS.md`.
- Note transport/config smells already present in code, including the hardcoded bridge base URL and hardcoded client realtime region.

Required tests:
- None required to start the audit.
- If a failing startup path is reproduced in a test during the audit, add the failing regression test and leave the milestone `IN PROGRESS` until the fix lands.

Dependencies:
- None

Definition of done:
- The startup sequence is documented in repo terms.
- The failing path is narrowed to a specific branch or assumption.
- The next startup milestone can be implemented without re-discovery.

Completion notes:
- Audit captured in `docs/realtime-startup-audit.md`.
- Concrete failing branch identified in `backend/src/services/realtimeService.ts`: upstream non-OK responses currently hit an undefined `loggerForContext(...)` call before the intended `AppError`.
- Additional startup assumptions recorded: hardcoded bridge base URL, hardcoded realtime region `"US"`, and raw error propagation through `localizedDescription`.

### M1.2 - `/v1/realtime/call` contract and SDP handling

Status: `DONE`

Goal:
- Make the iOS bridge, backend proxy, and OpenAI call contract consistent and deterministic.

Concrete tasks:
- Confirm the request and response contract between `RealtimeVoiceClient` bridge JavaScript and `backend/src/services/realtimeService.ts`.
- Harden SDP offer and answer handling so line endings and body shape are preserved exactly.
- Verify absolute and relative call endpoint handling from `RealtimeVoiceClient.connect()`.
- Remove or isolate any startup assumptions that are not actually owned by the backend session response.
- Keep the backend proxy contract explicit and minimal.

Required tests:
- `RealtimeVoiceClientTests` for call URL construction and connect payload handling
- `APIClientTests` for realtime session bootstrap behavior
- backend realtime service tests for multipart field handling and invalid SDP rejection
- backend integration tests for `/v1/realtime/call`

Dependencies:
- M1.1

Definition of done:
- The `/v1/realtime/call` contract is explicit and stable.
- Client and backend tests cover the active SDP path.
- Startup no longer depends on ambiguous contract behavior.

Completion notes:
- `RealtimeVoiceClient.connect()` now resolves absolute, root-relative, and path-relative call endpoints explicitly.
- The embedded realtime bridge now uses a local secure origin instead of a deployment-specific backend base URL.
- `APIClient` preserves absolute realtime call endpoints returned by `/v1/realtime/session`.
- `RealtimeService` now cleanly returns `AppError` on upstream rejection and rejects invalid upstream answer SDP.
- Verified by targeted iOS tests in `APIClientTests` and `RealtimeVoiceClientTests`, plus backend service and integration tests for `/v1/realtime/call`.
- 2026-03-07 follow-up: backend schema tests now pin the same WebRTC SDP requirement as the runtime contract. `types.test.ts` uses valid offer SDP with both `m=` and `a=fingerprint:` and explicitly rejects truncated payloads that omit either line.

### M1.3 - Safe startup failure states

Status: `DONE`

Goal:
- Ensure startup failures end in safe, deterministic states and never surface raw internal payloads.

Concrete tasks:
- Separate startup failures for health check, session bootstrap, realtime session creation, bridge readiness, call connect, and disconnect-before-ready.
- Replace raw `localizedDescription` user-facing startup failures with safe presentation.
- Ensure stale startup callbacks cannot revive a failed or cancelled session.
- Ensure disconnect and bridge error events during boot resolve once.
- Keep child-facing copy simple and safe.

Required tests:
- client tests for each startup failure branch
- regression test proving raw backend body text is not shown in UI
- backend tests if public error payload shape changes

Dependencies:
- M1.1
- M1.2

Definition of done:
- Startup failures are categorized.
- The session lands in one valid failure state.
- UI shows safe error copy only.

Completion notes:
- `PracticeSessionViewModel` now distinguishes startup failures for health check, session bootstrap, realtime session creation, bridge readiness, call connect, and disconnect-before-ready.
- Startup failures now use safe child-facing copy instead of raw `localizedDescription`.
- Boot-time disconnect and bridge error callbacks now resolve immediately, and stale startup callbacks no longer revive a failed boot.
- `RealtimeVoiceClient` now throws typed boot-time errors for bridge-ready timeout, bridge-ready failure, and disconnect-before-ready.
- Verified by targeted `PracticeSessionViewModelTests`, `APIClientTests`, and `RealtimeVoiceClientTests`.

### M1.4 - Startup-path tests

Status: `DONE`

Goal:
- Add a dedicated regression test layer for the startup path.

Concrete tasks:
- Add deterministic client tests spanning `PracticeSessionViewModel`, `APIClient`, and mock voice transport startup.
- Add tests for late ready/disconnect/error callbacks during boot.
- Add backend route tests for missing install ID, invalid session token, unsupported region, and invalid realtime call payloads that matter to startup.
- Add at least one startup test that exercises the full active contract sequence without the real network.

Required tests:
- new startup regression tests in `PracticeSessionViewModelTests`
- `APIClientTests`
- `RealtimeVoiceClientTests`
- backend integration or service tests for startup route behavior

Dependencies:
- M1.2
- M1.3

Definition of done:
- Startup has its own repeatable regression suite.
- The currently failing startup path is protected by tests.

Completion notes:
- `PracticeSessionViewModelTests` now exercises the full active startup contract with the real `APIClient` over a stubbed `URLSession`, covering health check, session bootstrap, voice catalog fetch, realtime session creation, and voice connect without the real network.
- `APIClientTests` now pin the startup request order and session-header reuse across prepare connection, session bootstrap, voice catalog, and realtime session creation.
- `RealtimeVoiceClientTests` now verify bridge readiness gating before the startup connect command is sent.
- Backend integration tests now cover missing install ID on `/v1/session/identity` and invalid session token rejection on `/v1/realtime/session`, alongside the existing unsupported-region and invalid-call-payload coverage.

### M1.5 - Canonical voice session state model cleanup

Status: `DONE`

Goal:
- Finish consolidating client session behavior around the explicit `VoiceSessionState` model.

Concrete tasks:
- Remove remaining duplicate or ambiguous session flags where possible.
- Keep `VoiceSessionState` and `ConversationPhase` aligned and minimal.
- Keep the coordinator as the only place that advances session state.
- Make invalid transitions log consistently with enough context.

Required tests:
- valid transition coverage
- invalid transition rejection coverage
- terminal-state restart coverage

Dependencies:
- M1.3

Definition of done:
- Session state is controlled by the canonical model only.
- No critical transition depends on out-of-band flags.

Completion notes:
- `PracticeSessionViewModel.phase` is now derived from `sessionState` instead of stored as a parallel mutable flag.
- Discovery, generation, revision, startup-attempt, and terminal-state guards now validate exact `VoiceSessionState` cases instead of broader phase checks.
- Transition and invalid-transition logs now include full canonical state context, including scene indices, ready-step numbers, and queued revision counts.
- Verified by `PracticeSessionViewModelTests` coverage for canonical state progression, invalid transition rejection with state context, and clean restart from the completed terminal state.

### M1.6 - Deterministic discovery, generation, and narration transitions

Status: `DONE`

Goal:
- Make discovery, generation, and narration progression explicit and race-resistant.

Concrete tasks:
- Ensure discovery results cannot trigger generation twice.
- Ensure generation cannot start before discovery completion.
- Ensure narration start only occurs from valid generating or revising states.
- Harden stale result rejection for discovery and generation callbacks.

Required tests:
- normal discovery-to-generation path
- discovery blocked path
- stale discovery result rejection
- stale generation result rejection
- narration start only from valid states

Dependencies:
- M1.5

Definition of done:
- Discovery, generation, and narration have explicit allowed transitions.
- Overlapping async completions cannot advance the session incorrectly.

Completion notes:
- Live generation now starts only from the matching discovery result, and mock generation only from the final ready discovery step instead of any generic `.ready` state.
- Generation request inputs are now snapped at kickoff before async continuity work starts, so late generation work cannot inherit later session mutations.
- Narration start now validates explicit source states for replay boot, generation resolution, revision resolution, and prior scene completion instead of coarse phase buckets.
- Verified by new `PracticeSessionViewModelTests` coverage for no generation before discovery resolution, stale discovery result rejection after failure, and stale generation result rejection without late narration.

### M1.7 - Interruption and revision serialization

Status: `DONE`

Goal:
- Keep interruption, revision, and continue behavior deterministic under overlap.

Concrete tasks:
- Ensure interruptions during narration, generation, and in-flight revision are serialized or rejected deliberately.
- Keep queued revision updates explicit and bounded.
- Ensure revise-and-continue resumes from the correct scene index every time.
- Ensure interruption cancellation of assistant speech is deterministic.

Required tests:
- interruption during narration
- interruption during generation
- interruption during in-flight revision
- queued revision ordering
- resume narration from correct scene after revision

Dependencies:
- M1.6

Definition of done:
- Only one revision request owns the future scene set at a time.
- Resume position is correct after every accepted revision.

Completion notes:
- Speech that starts during `.generating` or `.revising` now carries a deferred origin policy, so a late transcript final is rejected if the session has already advanced to narration instead of being reinterpreted under the new state.
- Revision queueing is now explicitly bounded to one pending update, and overflow is rejected with logging instead of silently growing the queue of future-scene work.
- Narration interruption tests now assert assistant speech cancellation exactly once, so cancellation behavior is pinned to a deterministic single cancel call.
- Verified by new `PracticeSessionViewModelTests` coverage for late generation-origin transcript rejection, late revision-origin transcript rejection, and queue overflow rejection.

### M1.8 - Duplicate completion and save prevention

Status: `DONE`

Goal:
- Ensure completion, save, and replay terminal behavior happen once.

Concrete tasks:
- Keep completion side effects centralized.
- Prevent duplicate save from narration completion races, disconnects, or replay flows.
- Make repeat-episode behavior explicit so it does not create or overwrite incorrect history.
- Keep transcript clearing behavior aligned with terminal transitions.

Required tests:
- duplicate completion rejection
- duplicate save rejection
- replay flow save behavior
- transcript clearing on completion when enabled

Dependencies:
- M1.6
- M1.7

Definition of done:
- Completion and save happen once.
- Terminal transitions cannot replay side effects.

Completion notes:
- `completeSession()` now only accepts explicit non-terminal source states, so late terminal paths cannot flip `.failed` into `.completed` or replay completion side effects.
- Transcript clearing now follows terminal session end instead of only successful completion, keeping the privacy setting aligned across completion and failure.
- Replay completion now leaves history unchanged, while repeat-episode revisions replace the existing episode instead of adding duplicate history.
- Verified by updated `PracticeSessionViewModelTests` coverage for duplicate completion/save prevention, replay-without-save, replay-with-replace, and terminal transcript clearing.

## Phase 2 - Data Integrity And Isolation

### M2.1 - Persistence audit

Status: `DONE`

Goal:
- Document the exact current local storage surface and invariants before migration.

Concrete tasks:
- Inventory every active `UserDefaults` key used for story data, profiles, privacy, install identity, session token, and continuity.
- Identify which data is primary product data versus bootstrap or config data.
- Record current save, replace, delete, clear-history, and retention paths.
- Record where continuity cleanup depends on story library state.

Required tests:
- none required for the audit itself
- if audit reveals untested critical behavior, add the missing baseline tests and leave the milestone `IN PROGRESS`

Dependencies:
- None

Definition of done:
- The active local storage surface is documented.
- Migration work can proceed without rediscovery.

Completion notes:
- `docs/persistence-audit.md` now inventories the active iOS persistence surface, including all active `UserDefaults` keys, primary product data versus bootstrap/config data, and the active save, replace, delete, clear-history, and retention cleanup paths.
- `StoryLibraryStoreTests` now pin shared continuity cleanup for clear-history, delete-series, retention prune, and child-delete cascade.
- `StoryLibraryStore.addStory(...)` now keeps pre-save series pruning semantics while deferring continuity sync until after the library mutation, and async continuity prune tasks now re-read the latest persisted library snapshot when they execute.
- `StoryLibraryStoreTests.testAddStoryPreservesImmediateContinuityIndexingAfterSave` now protects the former stale-prune race as a passing regression.

### M2.2 - Local schema design for story data

Status: `DONE`

Goal:
- Choose the durable/queryable local schema for primary story storage.

Concrete tasks:
- Define the target storage model for child profiles, story series, episodes, privacy settings, and continuity facts.
- Keep child scoping and retention cleanup explicit in the schema.
- Keep install identity and session token storage decisions separate from primary story data.
- Record the migration plan and rollback assumptions in `PLANS.md`.

Required tests:
- schema or repository tests for basic create/read/update/delete operations if code lands
- migration-plan test design notes recorded in `PLANS.md`

Dependencies:
- M2.1

Definition of done:
- The target local schema is chosen and documented.
- Migration implementation can begin without re-arguing the storage model.

Completion notes:
- Chosen target store: `Core Data` with `storytime-v2.sqlite`.
- New schema entities are defined in `docs/story-data-schema.md`: `Profile`, `LibrarySettings`, `StorySeries`, `StoryEpisode`, `ContinuityFact`, `SchemaMigrationLog`.
- The schema records explicit series ordering with `libraryPosition` and keeps `storyIndex` for episode ordering.
- Child scoping is intentionally staged: the schema keeps `childProfileId` nullable for migration compatibility now, and `M2.6` removes fallback visibility.
- Continuity linkage remains explicit by `(seriesId, storyId)` for replace/delete/prune correctness.
- Migration plan and rollback assumptions are captured in `docs/story-data-schema.md` and `PLANS.md`.

### M2.3.1 - Core Data bootstrap for library, profile, and privacy data

Status: `DONE`

Goal:
- Replace the interim file-backed v2 snapshot with the chosen Core Data-backed library store for story series, child profiles, active child selection, and privacy settings.

Concrete tasks:
- Replace the current v2 snapshot backend with a Core Data-backed store file.
- Keep `StoryLibraryStore` behavior stable while migrating legacy `storytime.*.v1` library/profile/privacy keys into the new store.
- Preserve corruption fallback and idempotent relaunch behavior for legacy imports.
- Keep the legacy keys as read source only; do not make them the primary write path again.

Required tests:
- migration from populated `UserDefaults`
- corrupted source data fallback
- idempotent re-launch after migration
- direct v2 store reload regression

Dependencies:
- M2.2

Definition of done:
- Existing users keep their story library, child profiles, active child selection, and privacy settings across relaunch.
- Those library/profile/privacy reads and writes no longer depend on large serialized `UserDefaults` blobs.

Completion notes:
- `StoryLibraryV2Storage` now persists the v2 snapshot through a Core Data-backed `storytime-v2.sqlite` store instead of a flat JSON blob file.
- The Core Data schema currently stores library settings, child profiles, story series, story episodes, and migration metadata, with `libraryPosition` preserving current series ordering.
- `StoryLibraryStore` still bootstraps from legacy `UserDefaults` only when the v2 store is absent or older than the current migration version.
- Store tests now cover migration from populated legacy defaults, corrupted legacy fallback, idempotent relaunch, and direct v2 snapshot reload against the Core Data backend.

### M2.3.2 - Continuity migration and legacy blob retirement

Status: `DONE`

Goal:
- Finish the migration away from `UserDefaults` for the remaining primary story data and remove residual legacy bootstrap dependence.

Concrete tasks:
- Migrate `ContinuityMemoryStore` off `storytime.continuity.memory.v1` and into the v2 local store.
- Keep continuity cleanup, retention prune, and child-delete behavior aligned with the migrated library store.
- Retire remaining legacy read paths once the v2 store is confirmed current.
- Preserve corruption fallback and idempotent relaunch behavior for the full migrated store.

Required tests:
- continuity migration from populated `UserDefaults`
- corrupted continuity source fallback
- idempotent re-launch after full migration

Dependencies:
- M2.3.1

Definition of done:
- Continuity facts and library/profile/privacy data no longer depend on `UserDefaults`.
- Legacy `storytime.*.v1` blobs are migration source only, not active primary storage.

Completion notes:
- `ContinuityMemoryStore` now persists semantic continuity facts through the Core Data-backed `storytime-v2.sqlite` store instead of `storytime.continuity.memory.v1`.
- Continuity migration now records its own completion note in the v2 migration log, removes the legacy continuity blob after successful import, and falls back safely on corrupt legacy continuity data.
- Existing v1 Core Data snapshot installs now upgrade in place to the current migration version instead of re-bootstraping library/profile/privacy data from legacy defaults during the continuity cutover.
- Verified by new `StoryLibraryStoreTests` coverage for continuity migration from legacy defaults, corrupt continuity fallback, idempotent relaunch, and in-place v1 snapshot upgrade, plus the targeted `PracticeSessionViewModelTests` suite.

### M2.4 - Save, load, and delete flow migration

Status: `DONE`

Goal:
- Move the active story lifecycle onto the new local store.

Concrete tasks:
- Replace whole-snapshot rewrites with entity-level add, extend, replace, repeat, delete-series, clear-history, and read flows on the new store.
- Keep continuation metadata and story-series ordering consistent.
- Keep save behavior atomic enough to avoid partial story writes.

Required tests:
- save new series
- append episode
- replace episode
- delete series
- clear history
- repeat episode no-save behavior

Dependencies:
- M2.3.2

Definition of done:
- Active story lifecycle reads and writes use entity-level operations on the new store.
- Whole-snapshot rewrites are no longer the active library persistence path.

Completion notes:
- `StoryLibraryStore` now persists story lifecycle mutations through direct v2 series and episode operations for new series, append, replace, delete-series, clear-history, and repeat-no-save flows instead of rewriting the full library snapshot.
- Reload regressions now prove those flows survive a fresh store load directly from the Core Data-backed `StoredStorySeries` and `StoredStoryEpisode` rows.
- Retention pruning still uses collection-level series replacement for now, which is deferred to `M2.5`.

### M2.5 - Retention pruning hardening

Status: `DONE`

Goal:
- Keep retention pruning correct after storage migration.

Concrete tasks:
- Re-implement retention pruning against the new local store.
- Ensure pruning updates continuity cleanup consistently.
- Ensure "save story history off" truly removes retained story history from the active primary store.

Required tests:
- retention by cutoff date
- save-history-off cleanup
- continuity prune after retention

Dependencies:
- M2.4

Definition of done:
- Retention settings enforce actual data removal in the active store.

Completion notes:
- Retention pruning now updates the v2 story store through selective series and episode deletion plus episode-order compaction instead of collection-level replacement writes.
- Save-history-off cleanup now clears persisted story rows and shared continuity before the disabled setting is reloaded.
- Reload regressions now cover cutoff-based pruning, continuity cleanup after pruning, and save-history-off cleanup across a fresh store load.

### M2.6 - Active-child library scoping fix

Status: `DONE`

Goal:
- Enforce strict active-child library visibility.

Concrete tasks:
- Remove the current `visibleSeries` fallback that shows all series when a child has no matches.
- Update empty-state behavior for children with no saved stories.
- Audit story selection in `NewStoryJourneyView` so it respects strict child scoping.
- Update any tests that currently encode the fallback behavior.

Required tests:
- active child with no stories shows empty state, not all series
- past-story picker only shows series for the active child
- cross-child visibility regression tests

Dependencies:
- M2.1

Definition of done:
- No saved story list or picker crosses child boundaries by fallback.

Completion notes:
- `StoryLibraryStore.visibleSeries` no longer falls back to all series when the active child has no matches, and `visibleSeries(for:)` now scopes continuation choices to an explicitly selected child.
- `NewStoryJourneyView` now derives its continuation selection from the selected child's scoped series and sanitizes stale `selectedSeriesId` values before building the launch plan.
- `HomeView` and `NewStoryJourneyView` now expose regression-covered empty states for the no-stories child path instead of leaking another child's seeded series.
- Verified by updated `StoryLibraryStoreTests` plus a focused `StoryTimeUITests` regression that switches from Milo to Nora and asserts both saved-story list and past-story picker stay empty.

### M2.7 - Child-delete cascade behavior

Status: `DONE`

Goal:
- Keep child deletion scoped, complete, and non-destructive to other children.

Concrete tasks:
- Audit child-profile deletion across stories, continuity, active profile selection, and fallback profile creation.
- Ensure deleting one child does not affect another child's stories or continuity.
- Make the final-profile fallback behavior explicit and tested.

Required tests:
- delete one child keeps other child's stories
- delete child clears only matching continuity
- delete final child recreates expected fallback profile state

Dependencies:
- M2.6

Definition of done:
- Child deletion is fully scoped and predictable.

Completion notes:
- `StoryLibraryStore.deleteChildProfile(_:)` now resolves the remaining profile set, active-profile fallback, and removed series IDs before mutating state, so delete semantics are explicit instead of relying on incidental array mutation order.
- Reload regressions now prove that deleting the active child preserves another child's stories, deleting a child clears only matching continuity, and deleting the final child recreates the default fallback profile with no retained stories.
- The milestone intentionally keeps continuity cleanup scoped to the deleted child's series IDs; broader continuity provenance remains in `M2.8`.

### M2.8 - Continuity provenance and cleanup

Status: `DONE`

Goal:
- Keep continuity facts attributable, clean, and aligned with migrated story state.

Concrete tasks:
- Preserve story and series provenance for continuity facts.
- Ensure replace, delete, prune, and child-delete flows remove or update continuity correctly.
- Ensure revised stories do not leave stale future-scene continuity behind.

Required tests:
- replace story continuity update
- delete series continuity cleanup
- retention prune continuity cleanup
- revised-story continuity integrity

Dependencies:
- M2.4
- M2.5
- M2.7

Definition of done:
- Continuity data stays attributable and cleanup-safe across the full lifecycle.

Completion notes:
- `ContinuityMemoryStore` now prunes semantic continuity by explicit `(seriesId, storyId)` provenance instead of separate global series and story sets, so cleanup remains correct even if story IDs collide across series.
- `StoryLibraryStore` now rebuilds series structural continuity from retained episode engine memory after append, replace, and retention prune, while preserving migrated legacy continuity metadata when there is no engine-derived memory to recompute from.
- Repeat-episode revisions now replace the original story's semantic continuity facts and clear closed open loops from the saved series metadata instead of leaving stale future-scene continuity behind.
- Verified by new `StoryLibraryStoreTests` coverage for replace-story continuity rebuild, pair-scoped provenance pruning, and retention-prune structural cleanup, plus `PracticeSessionViewModelTests` coverage for revised-story continuity replacement.

## Phase 3 - Safety, Privacy, And Production Hardening

### M3.1 - Safe application error model

Status: `DONE`

Goal:
- Define the safe client-visible error model for the app.

Concrete tasks:
- Define app-level error categories for startup, moderation block, network failure, backend failure, decode failure, persistence failure, and cancellation.
- Ensure child-facing copy stays safe and simple.
- Ensure errors do not leave the session in ambiguous states.

Required tests:
- error-category mapping tests
- blocked story path tests
- cancellation is not failure tests

Dependencies:
- M1.3

Definition of done:
- The app has a safe, explicit error model instead of raw transport strings.

Completion notes:
- `StoryTimeAppErrorCategory` and `StoryTimeAppError` now define the active client-safe error model for startup, moderation block, network failure, backend failure, decode failure, persistence failure, and cancellation.
- `PracticeSessionViewModel` now maps non-startup discovery, generation, revision, runtime voice error, and disconnect paths onto safe typed copy instead of surfacing raw transport strings.
- Blocked discovery, generation, and revision flows now record typed moderation notices without failing the session, and discovery/revision cancellation now restores explicit recoverable states instead of failing the session.
- Verified by expanded `PracticeSessionViewModelTests` coverage for category mapping, blocked-story paths, safe runtime voice errors, and cancellation-not-failure recovery.

### M3.2 - Client/backend error mapping

Status: `DONE`

Goal:
- Align backend `AppError` responses and client error presentation.

Concrete tasks:
- Map backend error codes and public messages into client-safe errors.
- Stop using raw backend response bodies as user-facing text.
- Verify blocked `422` story flows still decode correctly while non-blocking failures stay safe.

Required tests:
- `APIClientTests`
- `PracticeSessionViewModelTests`
- backend route tests if response payloads change

Dependencies:
- M3.1

Definition of done:
- Client and backend error handling are aligned and safe.

Completion notes:
- `APIClient` now parses backend `{ error, message, request_id }` envelopes into structured `APIError.invalidResponse` values, preserves backend code/message/request ID for higher-level mapping, and keeps `localizedDescription` free of raw response bodies.
- `PracticeSessionViewModel` now maps backend codes like `rate_limited`, session-token failures, `unsupported_region`, `revision_conflict`, and realtime transport failures into safe client-visible errors instead of relying only on generic status-code heuristics.
- `422` blocked discovery/generation/revision flows still stay on the typed-success decode path, while non-blocking failures now use the structured backend error envelope.
- Verified by targeted `APIClientTests`, `PracticeSessionViewModelTests`, and backend `app.integration.test.ts` coverage for explicit app-error `message/request_id` and safe internal-error envelopes.

### M3.3 - Session correlation IDs and tracing

Status: `DONE`

Goal:
- Make live session activity traceable across client and backend without leaking content.

Concrete tasks:
- Carry request IDs and session IDs into client diagnostics where useful.
- Keep correlation fields structured and redacted.
- Add coordinator event tracing for startup, discovery, generation, revision, completion, and failure.

Required tests:
- client tracing tests
- backend request context and analytics tests

Dependencies:
- M1.4
- M3.2

Definition of done:
- Critical-path events can be correlated end to end without logging sensitive content.

Completion notes:
- `APIClient` now generates per-request `x-request-id` headers, stores backend `session_id` in `AppSession`, and emits structured transport trace events across startup, voices, realtime session creation, discovery, generation, revision, and embeddings requests.
- `PracticeSessionViewModel` now records redacted coordinator trace events for startup, discovery, generation, revision, completion, and failure, keyed by backend request ID and session ID instead of transcript or story text.
- Backend request-context tests now pin caller-supplied request ID echo behavior on story routes, and analytics tests now cover session-aware request metrics alongside request IDs.
- Verified by targeted `APIClientTests`, `PracticeSessionViewModelTests`, backend `app.integration.test.ts`, and backend `request-retry-rate.test.ts` coverage.

### M3.4 - Backend lifecycle logging

Status: `DONE`

Goal:
- Strengthen backend lifecycle logging for the active realtime and story pipeline.

Concrete tasks:
- Add structured lifecycle logs around realtime ticket issuance, realtime call proxying, discovery, generate, revise, retry, and failure paths.
- Keep logs request-scoped and redacted.
- Avoid logging transcripts or story text by default.

Required tests:
- analytics/logging unit tests where practical
- route or service tests covering success and failure logging hooks

Dependencies:
- M3.3

Definition of done:
- Backend lifecycle events are logged consistently and safely.

Completion notes:
- Added `lifecycle_event` backend logging helpers that use request-scoped child loggers and emit structured start, completed, blocked, retrying, and failed events.
- `RealtimeService`, `StoryDiscoveryService`, and `StoryService` now log realtime ticket issuance, realtime call proxying, discovery, generate, and revise lifecycle hooks with correlation metadata already present in request context.
- Lifecycle logs stay redacted by design: they use counts, retry timing, safe error codes/status, and other metadata instead of transcript text, story text, SDP bodies, or raw upstream response bodies.
- Verified by targeted backend service tests for realtime lifecycle logging, discovery retry logging, generate completion logging, revise failure logging, and the existing request-context/integration coverage.

### M3.5 - Real data-flow and privacy audit

Status: `DONE`

Goal:
- Verify that the product's actual storage, transport, and logging match its privacy claims.

Concrete tasks:
- Audit raw audio handling, transcript handling, story retention, continuity retention, telemetry, and install/session identifiers.
- Verify which data remains on device and which crosses the network.
- Record any mismatch between UI copy and code behavior.

Required tests:
- none for the audit itself
- add regression tests for any mismatches that are fixed during the audit

Dependencies:
- M2.8
- M3.3

Definition of done:
- Real data flow is documented and mismatches are identified explicitly.

Completion notes:
- Audit captured in `docs/privacy-data-flow-audit.md`.
- Confirmed that raw audio is not persisted in active code, but live microphone audio leaves the device during realtime sessions after backend-mediated SDP setup.
- Confirmed that saved story history and continuity remain local after completion, while discovery transcripts, generation inputs, revision inputs, generated story content, and embeddings requests cross the network during processing.
- Recorded the active privacy-copy mismatches for `M3.6`: "Stories stay on device" is too broad, "Raw audio is not saved by default" is misleading because there is no active raw-audio save path, and transcript clearing is local-only.

### M3.6 - Privacy copy alignment

Status: `DONE`

Goal:
- Align parent-facing and child-facing privacy language with actual behavior.

Concrete tasks:
- Update privacy copy in `HomeView`, `NewStoryJourneyView`, `VoiceSessionView`, and `ParentTrustCenterView` as needed.
- Remove ambiguous claims or settings.
- Keep docs aligned with the final implementation.

Required tests:
- UI or unit tests covering privacy setting behavior where available
- regression tests for transcript clearing if behavior changes

Dependencies:
- M3.5

Definition of done:
- Privacy copy matches actual behavior exactly.

Completion notes:
- Updated `HomeView`, `NewStoryJourneyView`, `VoiceSessionView`, `PracticeSessionViewModel.privacySummary`, and `ParentTrustCenterView` so the active copy no longer implies the full story loop stays on device.
- Parent-facing and child-facing copy now states the current behavior directly: raw audio is not saved, story prompts and generated stories are sent for live processing, saved history stays on device after completion, and transcript clearing is local on-screen cleanup when enabled.
- Added accessibility identifiers for the updated privacy surfaces and verified them with a focused UI regression plus `PracticeSessionViewModelTests` coverage for both privacy-summary branches.

### M3.7 - Transport and config hardening

Status: `DONE`

Goal:
- Tighten fragile transport and deployment assumptions.

Concrete tasks:
- Remove or isolate hardcoded realtime startup assumptions that do not belong in client code.
- Review `RealtimeVoiceClient` bridge loading assumptions.
- Tighten backend env validation and unsafe defaults where needed.
- Review session TTL and refresh behavior against the live startup path.

Required tests:
- backend env and auth tests
- client startup regression tests affected by transport changes

Dependencies:
- M1.2
- M3.4

Definition of done:
- Startup and backend config rely on explicit, tested assumptions.

Completion notes:
- `AppConfig` now reads the deployed backend URL from the app bundle `StoryTimeAPIBaseURL` key with explicit environment override precedence instead of depending only on an inline deployment URL in code.
- The iOS app now uses `NSAllowsLocalNetworking` instead of global `NSAllowsArbitraryLoads`, so loopback development stays available without broad insecure transport allowance.
- `APIClient` now recovers once from stale or missing session-token failures on authenticated realtime/story/embeddings requests by clearing the old token, re-bootstrapping `/v1/session/identity`, and retrying the request.
- `RealtimeVoiceClient` now fails bridge readiness immediately on navigation failure and web-content termination instead of waiting only for the ready-timeout path.
- Backend env loading now rejects unsafe session refresh windows and production defaults that leave CORS wildcarded or session auth disabled.

### M3.8 - Region handling alignment

Status: `DONE`

Goal:
- Align client and backend region behavior.

Concrete tasks:
- Replace the current client hardcoded realtime region with an explicit aligned approach.
- Ensure client request headers and body region values match backend policy.
- Keep unsupported-region failures safe and testable.

Required tests:
- client tests for region propagation
- backend auth/request-context tests for region enforcement

Dependencies:
- M3.7

Definition of done:
- Region behavior is explicit and consistent across client and backend.

Completion notes:
- `APIClient` now resolves processing region from backend `/health` metadata or `/v1/session/identity`, stores it alongside session state, and sends `x-storytime-region` on follow-on requests.
- `PracticeSessionViewModel` no longer hardcodes `"US"` for realtime startup; the realtime session body now aligns to the same resolved region value as the request header.
- Startup unsupported-region failures now preserve the safe region-specific message instead of collapsing into generic startup copy.
- Verified by new iOS regressions for region propagation and unsupported-region startup handling, plus backend request-context default-region and `/v1/session/identity` region-echo coverage.

### M3.9 - Lightweight parent access gate

Status: `DONE`

Goal:
- Add a minimal parent access gate around the parent trust surface.

Concrete tasks:
- Define the lightest acceptable access gate for the current product scope.
- Apply it to the `ParentTrustCenterView` entry path without redesigning the product.
- Keep the gate testable and easy to reason about.

Required tests:
- unit or UI tests for parent gate entry behavior
- regression tests ensuring children cannot open parent controls directly without the gate once implemented

Dependencies:
- None

Definition of done:
- Parent controls have a deliberate access gate and tests cover the entry behavior.

Completion notes:
- `HomeView` now presents a local gate sheet before switching to `ParentTrustCenterView`.
- The shipped gate is intentionally lightweight: the parent must type `PARENT` before the trust surface opens.
- UI regressions now prove the parent trust surface does not open directly from a single tap and that the existing parent-control flows still work after gated entry.

### M3.10.1 - Acceptance harness foundation and happy path

Status: `DONE`

Goal:
- Create the reusable acceptance harness foundation and cover the full happy-path critical loop once.

Concrete tasks:
- Add a dedicated acceptance-harness layer on top of the existing mock API and mock voice transport.
- Cover startup, discovery, generation, narration, interruption, revision, completion, and save in one repeatable happy-path scenario.
- Keep the harness isolated from network and persisted state left by other tests.

Required tests:
- critical-path happy-path acceptance suite

Dependencies:
- M1.8
- M2.8
- M3.8

Definition of done:
- A reusable acceptance harness exists and the full happy-path critical loop is covered end to end.

Completion notes:
- `PracticeSessionViewModelTests` now includes a reusable happy-path acceptance runner built on top of the existing mock API and mock realtime voice core.
- The new acceptance slice covers startup, discovery, generation, narration, interruption, revision, completion, and save in one no-network scenario.
- The acceptance suite now reloads `StoryLibraryStore` after completion to prove the revised story persists correctly for the active child.

### M3.10.1a - Critical-path verification pass

Status: `DONE`

Goal:
- Verify the current highest-value StoryTime flows explicitly and record what is fully covered, indirectly covered, or still unverified.

Concrete tasks:
- Review the active critical-path tests, mocks, and stubs across iOS and backend.
- Run targeted verification for startup, happy path, repeat mode, parent controls, delete flows, and child-scoped visibility.
- Add one small high-signal regression if an obvious coverage gap appears during the pass.
- Record the results in `docs/verification/critical-path-verification.md`.

Required tests:
- targeted iOS unit tests for startup, coordinator happy path, repeat mode, store cleanup, and privacy summary behavior
- targeted iOS UI tests for home/journey/parent/series-detail/delete flows
- targeted backend route/service tests for startup, realtime contract, discovery, and story service contracts

Dependencies:
- M3.10.1

Definition of done:
- The repo contains a concrete critical-path verification report.
- Flow-by-flow confidence and remaining gaps are explicit.
- Any obvious high-signal gap addressed in-scope is covered by test.

Completion notes:
- Added `docs/verification/critical-path-verification.md` with per-flow methods, results, confidence, defects, and remaining gaps.
- Added `StoryTimeUITests.testDeleteAllSavedStoryHistoryClearsSeededSeriesFromHome` so the parent-surface delete-all-history flow now has end-to-end UI coverage in addition to store cleanup tests.
- Verification found no new reproduced product defects; the main remaining gaps are the planned failure-injection acceptance slice, a dedicated single-series delete UI regression, and a dedicated end-to-end assertion for launching from a selected prior story during setup.

### M3.10.1b - Realtime voice determinism verification pass

Status: `DONE`

Goal:
- Audit the end-to-end realtime voice lifecycle for contract correctness, deterministic transitions, transcript safety, and transport assumptions.

Concrete tasks:
- Inspect the active iOS realtime transport, hidden bridge, coordinator state machine, and backend realtime routes/services.
- Run targeted backend realtime route/service/type tests plus targeted iOS realtime client/API/coordinator tests.
- Add one small regression if the audit finds a concrete determinism gap on the active voice path.
- Record the results in `docs/verification/realtime-voice-determinism-report.md`.

Required tests:
- targeted backend realtime route/service/type tests
- targeted iOS realtime client/API/coordinator tests
- focused coordinator regression for any in-scope determinism bug found during the pass

Dependencies:
- M3.10.1

Definition of done:
- The repo contains a concrete realtime determinism report.
- Startup contract, runtime flow, transcript flow, and remaining realtime risks are explicit.
- Any small in-scope determinism fix found during verification is covered by regression.

Completion notes:
- Added `docs/verification/realtime-voice-determinism-report.md` with startup-contract, event-flow, transcript-flow, determinism, weak-spot, and confidence findings.
- Added `PracticeSessionViewModelTests.testLateTranscriptAfterFailureDoesNotOverwriteLatestTranscript` and tightened `handleTranscriptFinal` so terminal or deferred-rejected final transcripts no longer mutate coordinator transcript state.
- Verification confirmed strong startup-contract coverage across `APIClientTests`, `RealtimeVoiceClientTests`, and backend realtime route/service/type tests, but also documented that the hidden `WKWebView` bridge still lacks a live WebRTC acceptance harness and that runtime disconnect remains intentionally terminal.

## Phase 4 - Hybrid Runtime Migration

### M4.1 - Hybrid runtime contract

Status: `DONE`

Goal:
- Define the hybrid runtime contract in repo terms before transport changes begin.

Concrete tasks:
- Document the runtime split between interaction mode, narration mode, and authoritative story/scene state.
- Define which coordinator responsibilities stay in `PracticeSessionViewModel` and which transport responsibilities belong to realtime interaction versus TTS narration.
- Define the initial backend/client contract boundaries for answer-only interactions, future-scene revision, and narration resume.
- Record the contract in repo docs and align `PLANS.md` and `SPRINT.md` language if the implementation-facing terms change during the write-up.

Required tests:
- none required unless a tiny supporting type/doc test lands with the contract

Dependencies:
- M3.10.1b

Definition of done:
- The hybrid runtime contract is explicit enough to implement against without re-arguing core boundaries.
- Interaction mode, narration mode, and authoritative story state each have clear ownership.

Completion notes:
- Added `docs/hybrid-runtime-contract.md` to pin the hybrid runtime boundary in repo terms: realtime interaction, TTS long-form narration, scene-based story authority, interruption classification outputs, and narration resume rules.
- Added typed contract markers in `StoryDomain.swift`: `HybridRuntimeMode`, `HybridInteractionPhase`, `InterruptionIntent`, and `NarrationResumeDecision`.
- Added `HybridRuntimeContractTests` inside `PracticeSessionViewModelTests.swift` to pin the contract semantics for transport expectations, future-scene mutation boundaries, and narration resume boundaries.

### M4.2 - Mode transition state model

Status: `DONE`

Goal:
- Define and pin the allowed transitions between hybrid interaction and narration modes.

Concrete tasks:
- Extend the current coordinator state model into explicit hybrid mode transitions without introducing parallel mutable flags.
- Define entry and exit rules for setup interaction, narration playback, interruption intake, answer-only handling, revise-future-scenes handling, and narration resume.
- Record invalid transition rules and terminal behavior expectations for hybrid mode handoffs.

Required tests:
- state-model tests or coordinator tests for allowed and rejected mode transitions if code lands

Dependencies:
- M4.1

Definition of done:
- The hybrid mode graph is finite, explicit, and implementation-ready.
- Invalid handoffs are defined before code lands.

Completion notes:
- Added `HybridRuntimeStateNode`, `HybridRuntimeTransitionTrigger`, and `VoiceSessionState.hybridRuntimeStateNode` to `StoryDomain.swift` so the hybrid mode graph is explicit without introducing a second live coordinator state machine.
- Added `docs/hybrid-mode-transition-model.md` to record the allowed mode graph, current coordinator-state mapping, invalid handoffs, and terminal expectations for hybrid runtime work.
- Expanded `HybridRuntimeContractTests` in `PracticeSessionViewModelTests.swift` to pin current-state mapping, the main hybrid flow, and rejected handoffs.

### M4.3 - Scene-state authority and revision boundary contract

Status: `DONE`

Goal:
- Define exactly how scene state owns narration progress, answer context, and future-scene revision boundaries.

Concrete tasks:
- Pin the authoritative scene-state structure the coordinator must use during hybrid narration.
- Define how the current scene, completed scenes, remaining scenes, and resume boundary are represented.
- Define the rule that revision changes future scenes only unless a later milestone explicitly widens scope.
- Define how answer-only interactions may reference story state without mutating future scenes.

Required tests:
- coordinator or type tests for scene-boundary ownership if code lands
- backend contract tests if revise request or response shapes change

Dependencies:
- M4.1
- M4.2

Definition of done:
- Scene-state authority and revision boundaries are explicit and testable.
- Resume-from-boundary behavior can be implemented without ambiguity.

Completion notes:
- Added `AuthoritativeStorySceneState`, `StorySceneBoundary`, `StoryAnswerContext`, `StoryRevisionBoundary`, and `StorySceneMutationScope` to `StoryDomain.swift` so completed scenes, the current boundary scene, remaining scenes, future-only mutation scope, and resume semantics are explicit in code.
- Added `docs/hybrid-scene-state-authority.md` and aligned the earlier hybrid contract docs so answer-only remains read-only while revise-future-scenes preserves the current boundary scene and mutates only later scenes.
- Expanded `HybridRuntimeContractTests` in `PracticeSessionViewModelTests.swift` to pin the new authoritative scene-state slices, answer-context immutability, future-only revision request mapping, and final-scene no-revision behavior.

### M4.4 - TTS narration pipeline

Status: `DONE`

Goal:
- Replace long-form scene narration with a dedicated TTS pipeline while preserving coordinator authority.

Concrete tasks:
- Add a narration transport abstraction for scene playback that is separate from realtime interaction transport.
- Implement initial TTS generation/playback for one scene at a time under coordinator control.
- Keep narration progress keyed to scene state rather than transport callbacks inventing progression.
- Preserve existing completion/save protections while switching narration transport.

Required tests:
- narration transport tests for single-scene playback start/finish
- coordinator tests proving scene progression still follows authoritative state

Dependencies:
- M4.2
- M4.3

Definition of done:
- Long-form narration plays through the TTS path for the active scene under coordinator control.
- Realtime interaction transport is no longer the default long-form narration path.

Completion notes:
- `PracticeSessionViewModel` now owns a dedicated `StoryNarrationTransporting` abstraction for scene playback instead of treating realtime voice output as the default narration path.
- Production narration now defaults to a `SystemSpeechNarrationTransport` backed by `AVSpeechSynthesizer`, while realtime remains available for live interaction and interruption handling.
- Narration progression remains coordinator-owned: the transport only reports active-scene completion, and the coordinator still decides scene advancement, interruption, revision, and completion/save behavior.
- Targeted hybrid contract and coordinator regressions passed after the transport split, including narration-transport and interruption/revision coverage.

### M4.5 - Pause and resume behavior

Status: `DONE`

Goal:
- Make narration pause and resume deterministic at explicit scene boundaries.

Concrete tasks:
- Define pause semantics for active scene playback versus boundary-safe resume.
- Implement coordinator-owned pause and resume controls for narration transport.
- Ensure pause/resume preserves current scene index and does not duplicate completion side effects.

Required tests:
- coordinator tests for pause, resume, and duplicate-finish rejection
- narration transport tests for pause/resume signaling

Dependencies:
- M4.4

Definition of done:
- Narration can pause and resume without losing scene ownership or replaying terminal side effects.

Completion notes:
- `VoiceSessionState` now includes an explicit `paused(sceneIndex:)` narration state so pause/resume remains finite and coordinator-owned instead of hiding behind transport booleans.
- `PracticeSessionViewModel` now exposes deterministic `pauseNarration()` and `resumeNarration()` controls that preserve the active scene boundary and keep completion/save behavior single-run.
- The narration transport contract now supports `pause()` and `resume()` so TTS playback can halt and continue without handing scene ownership to the transport layer.
- Targeted coordinator and hybrid contract regressions passed, including pause/resume ownership and single-completion coverage.

### M4.6 - Interruption handoff from TTS to realtime

Status: `DONE`

Goal:
- Make interruption during TTS narration hand off cleanly into realtime interaction mode.

Concrete tasks:
- Stop or pause TTS playback deterministically when the child interrupts.
- Transition from narration mode into interaction mode without losing current scene boundary.
- Keep the realtime transport ready for interruption intake according to the hybrid contract.

Required tests:
- coordinator tests for narration-to-interaction handoff
- transport tests for TTS stop/pause plus realtime interaction activation

Dependencies:
- M4.4
- M4.5

Definition of done:
- TTS narration interruption produces one valid interaction handoff path with correct scene ownership preserved.

Completion notes:
- `PracticeSessionViewModel` now accepts narration interruption handoff from both `narrating(sceneIndex:)` and `paused(sceneIndex:)`, preserving the current scene boundary while moving into `interrupting(sceneIndex:)`.
- The coordinator tears down the active TTS playback task deterministically during handoff and reuses the already-connected realtime interaction transport instead of reconnecting.
- Final transcripts received while paused now trigger the same valid interruption-intake path as speech-start events, so paused narration can move directly into live interaction handling.
- Targeted coordinator regressions passed for paused-to-interaction handoff, transcript-driven handoff, and no-reconnect behavior.

### M4.7a - Deterministic interruption intent classifier

Status: `DONE`

Goal:
- Add a deterministic, implementation-facing interruption intent classifier before path execution work begins.

Concrete tasks:
- Add an interruption intent router contract that produces explicit outputs for answer-only, revise-future-scenes, and repeat/clarify.
- Define the minimum story-state context each route needs from transcript input plus current scene authority.
- Keep classification local, deterministic, and cheap enough for live interaction.

Required tests:
- router contract tests across answer-only, revise-future-scenes, and repeat/clarify cases
- tests for revision-unavailable output when no future scenes remain

Dependencies:
- M4.1
- M4.2
- M4.3
- M4.6

Definition of done:
- Every interruption transcript can be mapped to an explicit intent plus required story-state context.
- The router outputs are explicit, deterministic, and transport-independent.

Completion notes:
- `StoryDomain.swift` now exposes `InterruptionIntentRouteDecision` and `InterruptionIntentRouter`, keeping interruption classification local, deterministic, and transport-independent.
- The router always returns explicit answer context, returns revision boundary data only for future-scene mutation requests, and marks revision unavailable when no future scenes remain.
- Hybrid contract tests now cover answer-only, repeat-or-clarify, revise-future-scenes, and revision-unavailable outputs.

### M4.7b - Coordinator route-selection activation

Status: `DONE`

Goal:
- Make the coordinator consult the interruption classifier before choosing any post-handoff path.

Concrete tasks:
- Invoke the classifier at the coordinator interruption boundary using authoritative story state.
- Surface explicit route outputs for downstream answer-only, revise-future-scenes, or repeat/clarify handling.
- Keep unsupported routes in a safe waiting state until their execution milestones land.

Required tests:
- coordinator tests proving interruption transcripts are classified before path selection
- regression tests that revision is no longer chosen blindly for every interruption

Dependencies:
- M4.7a

Definition of done:
- The coordinator no longer treats every interruption as an implicit revision request.
- Classified route outputs are available for downstream interruption-path milestones.

Completion notes:
- `PracticeSessionViewModel` now consults `InterruptionIntentRouter` at the interruption boundary instead of routing every transcript directly into revision.
- The coordinator now surfaces `interruptionRouteDecision` as an explicit typed output for downstream answer-only, repeat-or-clarify, and revise-future-scenes handling.
- Only immediately applicable revise-future-scenes requests continue into the existing revision path; answer-only, repeat-or-clarify, and revision-unavailable cases remain safely in `interrupting(sceneIndex:)` until their execution milestones land.
- Targeted coordinator regressions now cover routed revision, no-blind-revision for answer-only interruptions, and safe waiting when no future scenes remain.

### M4.8 - Answer-only interruption path

Status: `DONE`

Goal:
- Handle current-story questions without unnecessary story regeneration.

Concrete tasks:
- Implement an answer-only path that uses current story/scene context without mutating future scenes.
- Keep answer-only responses short, live, and clearly separate from narration progress.
- Return to narration mode cleanly when the answer path completes.

Required tests:
- coordinator tests proving answer-only handling does not trigger revision or story replacement
- tests for resume to the same scene boundary after answer-only interaction

Dependencies:
- M4.7b

Definition of done:
- Question-answer interruptions are handled without regeneration and without corrupting narration state.

Completion notes:
- `PracticeSessionViewModel` now answers `answer_only` interruption routes from local `StoryAnswerContext` instead of falling through to revision.
- Answer-only responses are delivered over the live interaction transport, remain non-mutating, and resume narration from the same scene boundary after the short response completes.
- Targeted coordinator regressions now verify no revision request is sent for current-story questions, the generated story stays unchanged, and narration replays the current scene boundary after the answer.

### M4.9 - Revise-future-scenes path

Status: `DONE`

Goal:
- Preserve the current future-scene revision behavior under the hybrid runtime.

Concrete tasks:
- Route revise-future-scenes interruptions through the existing revision boundary contract.
- Keep completed scenes fixed and revise only the remaining scenes.
- Preserve continuity and repeat-mode invariants while the narration transport is no longer realtime-led.

Required tests:
- coordinator tests for revise-future-scenes ownership and resume index
- backend tests if revision request or response contracts change

Dependencies:
- M4.7b

Definition of done:
- Hybrid revision still changes only future scenes and leaves completed scenes untouched.

Completion notes:
- `PracticeSessionViewModel` now submits live revise requests through `StoryRevisionBoundary.makeRequest(userUpdate:)` instead of the pre-hybrid current-scene request shape.
- Live revision now preserves the current narration boundary scene on merge, replaces only future scenes, and expects `revised_from_scene_index` to point at the first mutable future scene.
- Targeted coordinator regressions now verify preserved-scene request ownership, future-scene-only mutation, and resume from the unchanged current boundary scene.

### M4.10 - Narration resume from correct scene boundary

Status: `DONE`

Goal:
- Resume narration from the correct post-interaction boundary after answer-only or revision flows.

Concrete tasks:
- Implement distinct resume rules for answer-only, repeat/clarify, and revise-future-scenes outcomes.
- Keep resume behavior keyed to authoritative scene state rather than transport assumptions.
- Ensure completion and save still run exactly once after resumed narration.

Required tests:
- coordinator tests for resume after each interruption outcome
- regression tests for duplicate completion/save protection after resume

Dependencies:
- M4.8
- M4.9

Definition of done:
- Every interruption outcome resumes narration from the correct scene boundary without duplicate side effects.

Completion notes:
- `PracticeSessionViewModel` now routes post-interruption narration through a typed `NarrationResumeDecision` instead of separate answer-only and revision-specific resume branches.
- Answer-only and repeat-or-clarify now both replay the current scene boundary explicitly, while revise-future-scenes resumes through `replayCurrentSceneWithRevisedFuture(sceneIndex:, revisedFutureStartIndex:)`.
- Repeat-or-clarify now has a concrete runtime path that replays the active scene boundary without sending a revise request, and resumed narration keeps the existing one-time completion/save protection intact.

### M4.11 - Scene audio preload and caching strategy

Status: `DONE`

Goal:
- Reduce narration stalls without weakening authoritative scene ownership.

Concrete tasks:
- Implement scene-ahead TTS preload and caching for upcoming scenes under coordinator control.
- Bound cache lifetime and invalidation rules so revised future scenes cannot reuse stale audio.
- Define fallback behavior when preload misses or TTS generation lags.

Required tests:
- narration transport tests for cache hit, cache miss, and invalidation on revision
- coordinator tests ensuring revised scenes invalidate stale preloaded audio

Dependencies:
- M4.4
- M4.9

Definition of done:
- Upcoming scene audio can be preloaded and invalidated safely when story state changes.

Completion notes:
- `PracticeSessionViewModel` now manages one-scene-ahead narration preparation under coordinator control and starts each scene through a typed `PreparedNarrationScene`.
- The narration transport now supports prepare, play, and invalidate operations so preloaded scene payloads stay bounded and transport-local instead of leaking into story-state authority.
- Revision now invalidates stale future-scene prepared payloads while keeping the current boundary scene warm, and the targeted regression slice covers cache hit, cache miss, and revision invalidation behavior.

### M4.12 - Cost telemetry by runtime stage

Status: `DONE`

Goal:
- Make runtime cost visible by interaction, narration, and revision stage.

Concrete tasks:
- Add telemetry boundaries for discovery, answer-only interaction, revise-future-scenes, TTS generation, and continuity retrieval.
- Keep telemetry redacted and aligned with privacy rules.
- Expose enough structured data to compare routing cost and latency by runtime stage.

Required tests:
- client or backend telemetry tests for runtime-stage attribution
- regression tests proving no transcript or raw audio content is logged

Dependencies:
- M4.4
- M4.7

Definition of done:
- Runtime-stage cost and latency can be measured without leaking sensitive content.

Completion notes:
- `APIClientTraceEvent` now carries runtime-stage attribution, redacted cost-driver classification, and per-request duration for discovery, story generation, revise-future-scenes, and continuity-retrieval API work.
- `PracticeSessionViewModel` now records redacted runtime telemetry for local hybrid stages as well, including answer-only interaction playback, one-scene-ahead TTS preparation, and combined continuity retrieval timing.
- Backend analytics now meter OpenAI usage by runtime stage in addition to operation, so stage-level usage snapshots can be compared without logging transcript or raw audio content.

### M4.13 - Hybrid runtime tests and validation command

Status: `DONE`

Goal:
- Establish the repeatable validation layer for the hybrid runtime.

Concrete tasks:
- Add targeted hybrid coordinator coverage for narration transport, interruption routing, answer-only handling, revision, and resume.
- Add backend tests for any new interaction or routing contracts.
- Document the stable targeted validation command future hybrid milestones should run.

Required tests:
- hybrid coordinator test slice
- hybrid transport test slice
- backend contract tests for any hybrid APIs added

Dependencies:
- M4.8
- M4.9
- M4.10
- M4.11
- M4.12

Definition of done:
- The hybrid runtime has a stable, repeatable validation surface for future milestones.

Completion notes:
- Added `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` as the stable targeted hybrid validation command for future milestones.
- Added `/Users/rory/Documents/StoryTime/docs/verification/hybrid-runtime-validation.md` to document the command, its coverage, and when to use it instead of the full suite.
- Refreshed the lifecycle trace regression in `PracticeSessionViewModelTests` so the stable validation slice matches current future-scene revision semantics and hybrid narration timing.
- Verified the command end to end with:
  - `npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts src/tests/types.test.ts`, which passed `39` backend tests.
  - the targeted iOS `xcodebuild test` slice in the new script, which passed `27` tests.

### M3.10.2 - Failure injection acceptance coverage

Status: `DONE`

Goal:
- Extend the acceptance harness to cover the highest-risk failure paths.

Concrete tasks:
- Add failure injections for startup failure, disconnect during session, revision overlap, and duplicate completion/save attempts.
- Verify the acceptance harness asserts safe recoverable or terminal states instead of only targeted unit regressions.
- Keep failure scenarios fast enough for regular milestone validation.

Required tests:
- startup failure acceptance suite
- revision overlap acceptance suite
- duplicate completion acceptance suite

Dependencies:
- M3.10.1

Definition of done:
- The acceptance harness covers the main failure modes that have historically caused drift or duplicate side effects.

Completion notes:
- Extended the targeted hybrid validation slice to cover startup failure, disconnect during live narration, revision-overlap queuing, and duplicate completion/save protection.
- Added `testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory` to pin terminal behavior and no-save guarantees after a mid-narration disconnect.
- Refreshed the overlapping-revision acceptance test to use the active interruption router and future-scene revision boundary instead of the legacy implicit-revision path.
- Updated `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` and `/Users/rory/Documents/StoryTime/docs/verification/hybrid-runtime-validation.md` so the stable validation layer now includes the failure-injection acceptance slice.
- Verified:
  - backend hybrid contract slice: `39` tests passed
  - targeted iOS hybrid + failure-injection slice: `31` tests passed
  - note: an earlier end-to-end script rerun was externally terminated during `xcodebuild`; the identical iOS command rerun passed cleanly.

### M3.10.3 - Child isolation acceptance coverage and validation command

Status: `DONE`

Goal:
- Finish the acceptance layer with multi-child isolation coverage and a stable validation entry point.

Concrete tasks:
- Add a multi-child acceptance scenario that proves saved-story visibility and persistence remain scoped during the critical loop.
- Document and pin the targeted acceptance test command future milestones should run.
- Keep the acceptance layer small enough to stay in regular milestone validation.

Required tests:
- child-isolation acceptance suite
- targeted acceptance harness command regression

Dependencies:
- M3.10.1
- M3.10.2

Definition of done:
- The critical-path acceptance harness covers happy path, failure injection, child isolation, and has a stable validation command for future runs.

Notes:
- This milestone should build on the same hybrid runtime validation layer established in `M4.13` and expanded in `M3.10.2`.
- Completed 2026-03-07 with a seeded multi-child UI acceptance slice added to the stable validation command.
- Validation command result:
  - backend hybrid contract slice: `39` tests passed
  - targeted iOS hybrid + failure-injection slice: `31` tests passed
  - seeded child-isolation UI slice: `2` tests passed
- The first UI-targeted command wiring used incomplete `-only-testing` identifiers and executed `0` UI tests; the script now targets the `StoryTimeUITests/StoryTimeUITests/...` bundle path explicitly.

### M5.1 - Coordinator revision-index logging hardening

Status: `DONE`

Goal:
- Remove the remaining revision-index logging drift from the stable hybrid validation slice.

Concrete tasks:
- Reproduce the passing `Revision index mismatch. expected=2 actual=1` coordinator log inside the current hybrid acceptance slice.
- Align revision resume logging with the active future-scene revision boundary so passing runs do not emit misleading mismatch diagnostics.
- Keep the change scoped to logging and coordinator diagnostics unless a real state bug is uncovered.

Required tests:
- targeted hybrid validation command regression
- coordinator lifecycle trace regression

Dependencies:
- M3.10.3

Definition of done:
- The stable hybrid validation command stays green and no longer emits the known revision-index mismatch log during passing runs.

Notes:
- This is intentionally a narrow post-acceptance hardening milestone, not a broader runtime redesign.
- Completed 2026-03-07 by correcting the stale lifecycle regression fixture to use the active future-scene revision boundary.
- Added an explicit lifecycle assertion that no `Revision index mismatch` message is recorded in `invalidTransitionMessages`.
- Validation results:
  - targeted lifecycle trace regression: `1` test passed
  - stable hybrid validation command: backend `39` tests passed, targeted iOS hybrid slice `31` tests passed, child-isolation UI slice `2` tests passed
- The first attempt to run the isolated lifecycle regression in parallel with the full validation command failed with an Xcode `build.db` lock; the required runs were rerun sequentially and passed cleanly.

## Phase 5 - Hybrid Runtime Verification And Measurement

### M6.1 - Hybrid runtime end-to-end verification report

Status: `DONE`

Goal:
- Produce a repo-grounded verification report for the active hybrid runtime before more implementation or UX work continues.

Concrete tasks:
- Inspect the active hybrid runtime surfaces in `PracticeSessionViewModel.swift`, `StoryDomain.swift`, the narration transport layer, and the current docs under `docs/verification/`.
- Run the stable hybrid validation command and any narrow supporting test reruns needed to support the report.
- Write or update a report in `docs/verification/` that labels each major hybrid-runtime behavior as `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, or `UNVERIFIED`.
- Cover at minimum startup, discovery-to-generation handoff, long-form narration, interruption routing, answer-only handling, revise-future-scenes, narration resume, completion/save, child isolation, and privacy/telemetry touchpoints.
- Record the specific partially verified and unverified areas that should feed `M6.2`, `M6.3`, and `M6.4`.

Required tests:
- `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`
- targeted iOS or backend reruns only if the report relies on narrower evidence than the stable slice

Dependencies:
- M5.1

Definition of done:
- The repo contains a current end-to-end hybrid-runtime verification report.
- Every material runtime behavior is tagged with one of the required evidence labels.
- The next verification, telemetry, and acceptance gaps are explicit enough to execute without rediscovery.

Notes:
- This is a verification/reporting milestone, not a runtime redesign milestone.

Completion notes:
- Added `docs/verification/hybrid-runtime-end-to-end-report.md` as the first explicit post-migration verification report for the active hybrid runtime.
- The report labels each covered hybrid behavior as `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, or `UNVERIFIED`, and it records the follow-on gaps that feed `M6.2`, `M6.3`, and `M6.4`.
- Verified with `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed:
  - backend slice: `39` tests
  - iOS unit slice: `31` tests
  - iOS UI child-isolation slice: `2` tests

### M6.2 - Realtime interaction-path determinism audit

Status: `DONE`

Goal:
- Verify that the live interaction path remains deterministic inside the hybrid runtime, especially at TTS-to-realtime boundaries.

Concrete tasks:
- Audit the interaction startup, interruption handoff, answer-only response path, revise-future-scenes path, and disconnect behavior across `PracticeSessionViewModel`, `RealtimeVoiceClient`, `RealtimeVoiceBridgeView`, `APIClient`, and backend realtime routes/services.
- Use the `M6.1` report to focus on the interaction-path areas still marked `PARTIALLY VERIFIED` or `UNVERIFIED`.
- Run targeted coordinator, realtime client, API client, and backend realtime tests; add one narrow regression if the audit finds a concrete determinism defect in scope.
- Write or update a deterministic interaction-path report in `docs/verification/` with the same evidence-label taxonomy and explicit remaining harness gaps.
- Make the intentional no-reconnect or terminal-disconnect semantics explicit if they remain the chosen product behavior.

Required tests:
- targeted `PracticeSessionViewModelTests`
- `RealtimeVoiceClientTests`
- `APIClientTests`
- backend realtime route, service, and type tests
- `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` if interaction-path behavior changes in scope

Dependencies:
- M6.1

Definition of done:
- The repo contains a current realtime interaction-path determinism audit for the hybrid runtime.
- Handoff, ordering, and terminal interaction semantics are evidenced explicitly.
- Any small determinism bug found in scope is pinned by regression.

Completion notes:
- Refreshed `docs/verification/realtime-voice-determinism-report.md` so it matches the active hybrid runtime and explicitly covers startup, TTS-to-realtime handoff, answer-only, repeat-or-clarify, deferred transcript rejection, backend realtime contract handling, and intentional no-reconnect semantics.
- Verified the backend realtime route/service/type slice with `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/types.test.ts`, which passed `34` tests.
- Verified the scoped iOS interaction-path slice with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionWithRealAPIClientExecutesFullStartupContractSequence -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionUsesResolvedBackendRegionDuringRealtimeStartup -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionRefreshesStaleSessionTokenBeforeRealtimeStartupFails -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testAnswerOnlyResumeCompletesAndSavesOnce -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationHandsOffToInteractionWithoutReconnect -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringGenerationIsRejectedAfterNarrationBegins -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testLateTranscriptAfterFailureDoesNotOverwriteLatestTranscript -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionDuringGenerationIsRejectedDeterministically`, which passed `43` tests.
- No new in-scope determinism defect was reproduced, so this milestone stayed verification-only and did not widen into reconnect or bridge-harness implementation work.

### M6.3 - Stage-level cost and latency telemetry verification

Status: `DONE`

Goal:
- Make the active hybrid runtime measurable by stage without widening into dashboards or product-surface work.

Concrete tasks:
- Audit current client and backend telemetry coverage for `interaction`, `generation`, `narration`, and `revision`, and document how supporting stages such as discovery or continuity retrieval map alongside them.
- Tighten stage naming or fill the smallest remaining instrumentation gaps so cost and latency can be compared across the required runtime stages with redacted data only.
- Add or update docs that explain where the stage metrics come from, what is measured on-device versus on-backend, and which stage readings are still indirect or estimated.
- Add or update tests for stage attribution, redaction, and analytics meter output.
- Record any remaining commercialization, threshold, or export questions in `PLANS.md` instead of building dashboards or alerting in this milestone.

Required tests:
- `APIClientTests`
- `PracticeSessionViewModelTests`
- backend analytics/request tests, including `backend/src/tests/request-retry-rate.test.ts`
- any touched backend service tests for runtime-stage attribution
- `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` if telemetry changes touch the active hybrid validation slice

Dependencies:
- M6.1
- M6.2

Definition of done:
- Stage-based telemetry is explicit and consistent for `interaction`, `generation`, `narration`, and `revision`.
- The repo documents what can be measured today and what remains indirect.
- Telemetry tests prove attribution stays redacted and stage-correct.

Notes:
- Do not add dashboards, alerts, or product analytics expansion here. Keep the milestone scoped to verification-grade telemetry.

Completion notes:
- Added `docs/verification/runtime-stage-telemetry-verification.md` as the current telemetry audit for the active hybrid runtime, using the required evidence labels and distinguishing the four primary stage groups from supporting stages.
- `APIClientTraceEvent` and coordinator runtime telemetry now expose grouped stage attribution for `interaction`, `generation`, `narration`, and `revision`, while `continuity_retrieval` remains a deliberate supporting stage with no forced primary grouping.
- Backend analytics now emits grouped stage counters and log fields in addition to detailed runtime stages, and realtime provider usage is now explicitly attributed to `interaction`.
- Verified the targeted backend telemetry slice with `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/request-retry-rate.test.ts src/tests/model-services.test.ts`, which passed `13` tests.
- Verified the targeted iOS telemetry slice with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation -only-testing:StoryTimeTests/APIClientTests/testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testExtendModeUsesPreviousRecapAndContinuityEmbeddings`, which passed `6` tests.
- Re-ran `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed backend `39`, iOS unit `31`, and iOS UI `2` tests.

### M6.4 - Hybrid runtime acceptance regression pack

Status: `DONE`

Goal:
- Consolidate the active hybrid runtime into an explicit acceptance regression pack that future runtime work must keep green.

Concrete tasks:
- Review the gaps and follow-ups from `M6.1`, `M6.2`, and `M6.3`, then add the smallest missing high-signal regression scenarios to the stable validation command or its adjacent targeted commands.
- Ensure the acceptance pack covers, at minimum, happy path, startup failure, disconnect during narration, interruption answer-only handling, revise-future-scenes, pause/resume, child isolation, and any stable telemetry assertions added in `M6.3`.
- Update `docs/verification/hybrid-runtime-validation.md` so it describes the acceptance pack scope, the exact commands to run, and what remains intentionally outside the pack.
- Keep the acceptance pack small enough for routine milestone validation; do not widen it into a full-suite UX or productization test run.

Required tests:
- `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`
- any new targeted acceptance, transport, or UI slices added in scope

Dependencies:
- M6.1
- M6.2
- M6.3

Definition of done:
- The repo has an explicit hybrid-runtime acceptance regression pack and a documented command path for running it.
- The pack covers the required hybrid-runtime scenarios and names the excluded cases explicitly.
- Future hybrid milestones can point to this pack as the default validation gate instead of rebuilding their own ad hoc slice.

Completion notes:
- Updated `docs/verification/hybrid-runtime-validation.md` so it now defines the explicit default acceptance pack for the active hybrid runtime, including covered scenarios, excluded cases, and why the command is the default gate.
- The stable validation command now includes an explicit happy-path completion regression and the grouped runtime-stage telemetry assertion added during `M6.3`.
- To stabilize the gate itself, `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` now runs backend, iOS unit, and iOS UI isolation slices as separate steps instead of mixing unit and UI execution in one `xcodebuild` run.
- Verified `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed backend `39`, iOS unit `33`, and iOS UI `2` tests.

## Phase 6 - UX And Productization Readiness

### M7.1 - UX audit for parent/child storytelling flow

Status: `DONE`

Goal:
- Audit the current parent and child storytelling flow only after the verification and measurement milestone group is materially complete.

Concrete tasks:
- Review the active `HomeView` -> `NewStoryJourneyView` -> `VoiceSessionView` -> parent controls flow using the now-verified hybrid runtime assumptions.
- Audit parent trust/privacy surfaces, child setup flow, launch clarity, interruption feel, and saved-story continuation cues without widening into redesign or feature implementation.
- Produce a prioritized UX audit document that distinguishes parent trust-boundary issues from child storytelling-loop issues.
- Record recommended follow-up milestones in repo terms, but do not start redesign or implementation work in this milestone.

Required tests:
- none required for the audit itself
- if a tiny supporting doc or copy correction lands during the audit, run only the directly affected UI or unit tests before marking the milestone done

Dependencies:
- M6.1
- M6.2
- M6.3
- M6.4

Definition of done:
- The repo contains a current UX audit grounded in the verified hybrid runtime.
- Parent-flow and child-flow issues are prioritized separately.
- The next UX/productization milestone set can start without reopening hybrid-runtime reliability questions.

Notes:
- Do not start this milestone until the `M6` verification and measurement group is materially complete unless `PLANS.md` records an explicit reprioritization.

Completion notes:
- Added `docs/verification/parent-child-storytelling-ux-audit.md` as the repo-grounded audit for the active `HomeView` -> `NewStoryJourneyView` -> `VoiceSessionView` -> saved-story/parent-controls flow.
- The audit separates parent trust-boundary issues from child storytelling-loop issues and uses the required evidence labels `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, and `UNVERIFIED`.
- The highest-priority findings are trust-boundary mismatches: saved-story deletion remains reachable outside the parent gate, and parent history copy is scoped to the active child even though the underlying clear-history action is global.
- Verified the audit against targeted store and UI evidence: `StoryLibraryStoreTests` passed `3` tests and `StoryTimeUITests` passed `5` tests.

### M7.2 - Parent trust-boundary hardening for saved-story management

Status: `DONE`

Goal:
- Align saved-story management with the repo’s parent trust boundary before broader UX polish starts.

Concrete tasks:
- Audit every saved-story delete or destructive-history affordance reachable from child-facing surfaces.
- Decide whether destructive history actions belong behind the existing parent gate, inside the parent hub only, or behind a narrower local confirmation pattern.
- Align the “Delete All Saved Story History” copy and behavior scope so active-child wording does not mask a global delete action.
- Keep child-facing replay and continue entry paths intact while removing or gating trust-sensitive mutations.

Required tests:
- `StoryTimeUITests` coverage for any gated or relocated saved-story delete flows
- `StoryLibraryStoreTests` if delete-history behavior scope changes
- targeted UI tests for the parent gate if routing changes

Dependencies:
- M7.1

Definition of done:
- Child-facing surfaces no longer expose trust-sensitive saved-story mutations ambiguously.
- Delete-history scope is explicit and aligned between UI copy and underlying behavior.
- Parent trust-boundary behavior is regression-covered.

Completion notes:
- `StorySeriesDetailView` now keeps replay and continue actions on the child-facing saved-story surface while removing the delete affordance from that surface entirely.
- `ParentTrustCenterView` now owns single-series deletion plus the existing device-wide clear-history action, and the parent copy now explicitly states that delete-all applies across all children on this device.
- Verified by targeted persistence regressions in `StoryLibraryStoreTests` (`3` passed) and the focused parent-controls single-series delete UI regression in `StoryTimeUITests` (`1` passed). Broader multi-test UI reruns still showed intermittent simulator-runner bootstrap failures unrelated to the feature behavior.

### M7.3 - Launch-plan clarity for continuity choices

Status: `DONE`

Goal:
- Make the pre-session setup explain the live storytelling loop and continuity choices more clearly without changing the hybrid runtime behavior.

Concrete tasks:
- Clarify how `Use past story`, `Use old characters`, and extend-mode selection interact in `NewStoryJourneyView`.
- Strengthen the launch summary so it explains what the child should expect from the live follow-up phase before narration begins.
- Keep privacy and child-scoping copy accurate while improving continuity-choice legibility.

Required tests:
- directly affected `StoryTimeUITests`
- targeted unit tests only if launch-plan summary or selection state logic changes

Dependencies:
- M7.1

Definition of done:
- The launch screen explains the continuity choices in repo-accurate terms.
- The live interaction loop is clearer before the child starts the session.
- Continuation-choice behavior remains scoped and regression-covered.

Completion notes:
- `NewStoryJourneyView` now explains the live follow-up loop before narration, clarifies fresh-story versus continue-story behavior, and keeps character reuse scoped to a selected saved series with reusable hints.
- The launch preview now separates live follow-up, story path, and character plan into explicit lines instead of relying only on one compressed preview sentence.
- Verified by targeted `StoryTimeUITests` coverage for fresh-start explanation, continue-story explanation, and the existing happy-path launch flow (`3` passed).

### M7.4 - Live session interaction-state clarity

Status: `DONE`

Goal:
- Make the hybrid live session easier for a child to understand without changing its deterministic runtime behavior.

Concrete tasks:
- Audit and tighten the visible cues for listening, narrating, answering, revising, paused, and failed states in `VoiceSessionView`.
- Make interruption and resume cues easier to follow without reworking coordinator logic or transport behavior.
- Keep privacy and live-processing copy truthful while improving the child-facing session affordances.

Required tests:
- directly affected `StoryTimeUITests`
- targeted `PracticeSessionViewModelTests` only if status/cue behavior changes at the coordinator boundary

Dependencies:
- M7.1

Definition of done:
- The child-facing session UI distinguishes the main hybrid states clearly.
- Interruption and recovery cues are more legible without weakening runtime determinism.
- The updated cues are regression-covered where practical.

Completion notes:
- `VoiceSessionView` now shows a dedicated session cue card plus a matching action hint that interpret the existing coordinator state without changing runtime behavior.
- `PracticeSessionViewModel` now exposes a derived `sessionCue` for listening, question time, narration, answering, revising, paused, completed, and failed states, keeping the UI tied to deterministic coordinator state instead of new flags.
- Verified by targeted `PracticeSessionViewModelTests` (`5` passed across the session-cue and startup-failure slices) and targeted `StoryTimeUITests` for listening and storytelling cue visibility (`2` passed).

### M7.5 - Saved-story detail information hierarchy pass

Status: `DONE`

Goal:
- Separate continuation cues from history-management concerns on the saved-story detail surface.

Concrete tasks:
- Rework `StorySeriesDetailView` so replay and new-episode actions are clear before continuity metadata or destructive controls.
- Make continuity information feel intentional and understandable instead of internal or mixed with trust-sensitive actions.
- Keep saved-story continuation behavior intact and scoped to the correct child.

Required tests:
- directly affected `StoryTimeUITests`
- `StoryLibraryStoreTests` only if story-history behavior changes

Dependencies:
- M7.1
- M7.2

Definition of done:
- Saved-story detail has a clearer action hierarchy.
- Continuation actions and history-management concerns are no longer conflated.
- The resulting surface is regression-covered where practical.

Completion notes:
- `StorySeriesDetailView` now leads with a dedicated continuation card for replay and new-episode intent, reframes continuity as story memory for the next episode, and keeps parent-only history management in a separate lower-priority section.
- Verified by targeted `StoryTimeUITests` coverage for the saved-story detail hierarchy (`1` passed).
- The current `SPRINT.md` queue has no remaining incomplete milestone after `M7.5`; the next run should be a planning pass to define the next milestone group before more implementation work starts.

## Phase 7 - Productization, Monetization, And Polished UX

### M8.1 - Productization planning and user-journey alignment

Status: `DONE`

Goal:
- Define the repo-grounded StoryTime product journey so later monetization and polish work stays coherent across parent and child flows.

Concrete tasks:
- Inspect the active parent and child journey across `HomeView`, `ParentAccessGateView`, `ParentTrustCenterView`, `NewStoryJourneyView`, `VoiceSessionView`, and `StorySeriesDetailView`.
- Map the key user journeys: first-time parent setup, returning child story start, saved-series continuation, session completion, and parent-management return path.
- Record the current value moments, trust moments, friction points, and candidate upgrade moments without starting implementation work.
- Capture technical constraints that later productization work must respect, especially the verified hybrid runtime split and local-only saved history.

Required tests or verification method:
- repo inspection across the active surfaces, relevant verification docs, and existing UI/unit evidence
- planning artifact in `docs/` or equivalent repo documentation with explicit source references

Dependencies:
- M7.5

Definition of done:
- The active StoryTime user journeys are documented in repo terms.
- The next productization and monetization milestones have a shared product-flow baseline.
- Future runs can implement later M8 milestones without re-discovering the current product shape.

Completion notes:
- Added `docs/productization-user-journey-alignment.md` to map the current parent and child journeys, value moments, trust moments, friction points, and candidate upgrade moments in repo terms.
- The artifact stays grounded in the verified hybrid runtime, current privacy/trust surfaces, and existing automated evidence instead of speculative redesign.
- No new tests were run because `M8.1` is a planning milestone; verification came from existing UI/unit/verification artifacts plus direct code inspection.

### M8.2 - Monetization model and entitlement architecture

Status: `DONE`

Goal:
- Define the first monetization model and entitlement architecture that fit StoryTime's current runtime economics and technical boundaries.

Concrete tasks:
- Inspect runtime-stage telemetry and cost-driver evidence in the client, backend, and `docs/verification/runtime-stage-telemetry-verification.md`.
- Propose repo-grounded free versus paid boundaries, including candidate limits around story starts, session minutes, saved-series continuation, child profiles, or retention features.
- Define the entitlement source of truth and the client/backend touchpoints needed for later implementation.
- Record what is still unknown for pricing confidence and which telemetry gaps matter before final package decisions.

Required tests or verification method:
- code and doc inspection of telemetry, request tracing, and active app surfaces
- architecture/planning document that references the inspected telemetry and runtime-cost evidence

Dependencies:
- M8.1
- M6.3

Definition of done:
- The repo has an explicit monetization and entitlement architecture direction.
- Package-boundary candidates are grounded in current runtime-stage telemetry rather than guesswork.
- Follow-on paywall and product polish milestones have a clear entitlement baseline.

Completion notes:
- Added `docs/monetization-entitlement-architecture.md` to define the first repo-fit monetization direction, including `Starter` versus `Plus` package-boundary candidates, launch-count and continuation-count as the first cap levers, and the main pricing-confidence gaps that still remain.
- Chose a split entitlement model: StoreKit 2 on device as purchase truth, plus a backend-issued entitlement snapshot and preflight checks as the enforcement layer for cost-bearing runtime work.
- No new tests were run because `M8.2` is an architecture and planning milestone; verification came from direct inspection of the active telemetry code, product surfaces, `AuditUpdated.md`, and existing verification artifacts.

### M8.3 - Onboarding and first-run flow audit and direction

Status: `DONE`

Goal:
- Define how first-time parents and first-time children should enter StoryTime before any onboarding implementation begins.

Concrete tasks:
- Audit the current first-run experience when the app opens into `HomeView` without saved stories or prior setup context.
- Review parent gate, parent controls, trust copy, child profile setup, and new-story launch to identify missing onboarding structure.
- Define the intended first-run sequence, including value framing, trust framing, child setup, and the first story start.
- Keep the direction grounded in current runtime behavior and privacy truthfulness.

Required tests or verification method:
- repo inspection of current first-run surfaces plus existing UI and privacy-verification evidence
- audit/design-direction document with explicit notes about what is current behavior versus proposed product flow

Dependencies:
- M8.1

Definition of done:
- The repo has a first-run and onboarding direction that future implementation work can follow.
- Trust, safety, and value framing are defined for the start of the product journey.
- The audit distinguishes current behavior from later design intent clearly.

Completion notes:
- Added `docs/onboarding-first-run-audit.md` to audit the current implicit first-run path, including the immediate boot into `HomeView`, the fallback `Story Explorer` profile, the parent gate, and the current trust-copy distribution across the app.
- The artifact defines a parent-led onboarding direction with explicit stages for welcome/value framing, trust and privacy setup, child setup, first-session expectation-setting, and the handoff into the first story start.
- No new tests were run because `M8.3` is an audit and direction milestone; verification came from direct inspection of the active surfaces, `AuditUpdated.md`, and the existing UI/store/privacy evidence already present in the repo.

### M8.4 - Paywall and upgrade entry-point strategy

Status: `DONE`

Goal:
- Decide where and how upgrades should appear in StoryTime without breaking child flow or parent trust.

Concrete tasks:
- Use the M8.1 journey map, M8.2 entitlement model, and M8.3 onboarding direction to inventory candidate upgrade moments.
- Decide which upgrade prompts must remain parent-managed versus child-visible.
- Define upgrade-entry rules for home, new-story setup, completion/replay loops, and parent controls.
- Record blocking rules, copy principles, and UX constraints for future paywall implementation.

Required tests or verification method:
- code and flow inspection only in this milestone
- strategy document covering entry points, ownership, gating rules, and excluded surfaces

Dependencies:
- M8.1
- M8.2
- M8.3

Definition of done:
- Upgrade entry points are explicit and prioritized.
- Parent-managed versus child-visible upgrade behavior is defined.
- Later implementation work can add paywall surfaces without reopening the product-flow strategy.

Completion notes:
- Added `docs/paywall-upgrade-entry-strategy.md` to define the approved upgrade surfaces, including `NewStoryJourneyView` as the primary preflight hard gate, `StorySeriesDetailView` as the contextual continuation gate, `ParentTrustCenterView` as the durable parent-managed upgrade surface, and `HomeView` as a soft-awareness surface.
- The strategy explicitly keeps `VoiceSessionView`, live interruption paths, and already-saved story replay free of blocking upgrade UI so the child runtime remains clean.
- No new tests were run because `M8.4` is a strategy milestone; verification came from direct inspection of the active surfaces plus the existing journey, monetization, onboarding, and UI evidence already present in the repo.

### M8.5 - Home and Library product polish pass

Status: `DONE`

Goal:
- Refine the home and saved-library surfaces so StoryTime feels more productized without weakening child scoping, trust, or parent controls.

Concrete tasks:
- Apply the approved productization direction to `HomeView` and the saved-story library surface.
- Improve value framing, active-child clarity, saved-story affordances, and any approved upgrade entry points on the home screen.
- Preserve parent gate behavior and child-profile scoping while improving hierarchy and polish.

Required tests or verification method:
- directly affected `StoryTimeUITests`
- `StoryLibraryStoreTests` only if scoping, retention, or saved-story behavior changes

Dependencies:
- M8.1
- M8.4

Definition of done:
- `HomeView` and the saved-library surface reflect the approved product direction.
- Any new home-surface upgrade or trust affordance is regression-covered.
- Child scoping and parent-boundary behavior remain intact.

Completion notes:
- `HomeView` now frames the quick-start loop more clearly with explicit live-question and scene-by-scene narration copy, while keeping the primary `Start New Story` path intact.
- The trust card now includes a direct parent-controls entry that still routes through the existing lightweight parent gate instead of inventing a new trust or upgrade flow.
- The saved-library section now explains replay and continuation value on home, and each saved-story card explicitly signals that the child can repeat or continue from the library surface.
- Verified by targeted `StoryTimeUITests` coverage for the new home framing and saved-story affordances, plus regressions for the existing quick-start path, parent gate, and child-scoped saved-story behavior.

### M8.6 - New Story setup polish pass

Status: `DONE`

Goal:
- Refine the pre-session setup experience so it aligns with onboarding, monetization boundaries, and the verified hybrid loop.

Concrete tasks:
- Apply the approved product direction to `NewStoryJourneyView`.
- Improve hierarchy around child choice, continuity setup, package limits or entitlement messaging, and session expectations.
- Preserve privacy truthfulness and child scoping while adding any approved upgrade or cap messaging.

Required tests or verification method:
- directly affected `StoryTimeUITests`
- targeted unit tests only if launch-plan or selection-state logic changes

Dependencies:
- M8.1
- M8.3
- M8.4

Definition of done:
- The setup flow is more productized and coherent.
- Any package-boundary messaging or upgrade hook is regression-covered.
- The launch flow still reflects the current hybrid runtime accurately.

Completion notes:
- `NewStoryJourneyView` now presents setup as a clearer preflight step before the live questions begin, with explicit parent handoff guidance instead of reading like a loose configuration form.
- The setup surface now separates story-path choice, length-and-pacing guidance, and what-happens-next expectations so the hybrid runtime is easier to understand before session start.
- The milestone stayed architecture-truthful: no fake entitlement state, no StoreKit UI, and no blocking upgrade logic was added before real preflight enforcement exists.
- Verified by targeted `StoryTimeUITests` coverage for the new preflight framing and expectation copy, plus existing regressions for fresh-start launch, continue-mode guidance, child-scoped saved-series selection, and the quick-start voice journey.

### M8.7 - End-of-story and repeat-use loop design pass

Status: `DONE`

Goal:
- Define the post-story loop that should drive replay, continuation, return-to-library behavior, and future repeat use.

Concrete tasks:
- Inspect the current completion, save, replay, continue, and series-detail return paths in the coordinator and UI.
- Define the intended end-of-story product flow for child and parent perspectives, including repeat, continue, saved-story return, and any approved upgrade moments.
- Record how completion should connect back to the home/library surface and saved-series continuation.
- Keep the work design-direction only unless a tiny documentation correction is required.

Required tests or verification method:
- repo inspection of completion/save paths, saved-story surfaces, and current verification evidence
- design-direction document with explicit current-state references

Dependencies:
- M8.1
- M8.2

Definition of done:
- The post-story loop is defined in repo terms and ready for later implementation.
- Replay, continuation, and return-surface roles are explicit.
- Later polish work can follow one documented loop instead of ad hoc screen decisions.

Completion notes:
- Captured in `docs/end-of-story-repeat-use-loop.md`.
- The doc pins the current authoritative completion/save behavior in `PracticeSessionViewModel`, the absence of an explicit post-story action surface in `VoiceSessionView`, and the existing replay/continue surfaces in `HomeView` and `StorySeriesDetailView`.
- The approved post-story action order is now explicit: replay the finished story, start a new episode from the saved series, or return to saved stories and home.

### M8.8 - Parent trust and privacy communication refinement

Status: `DONE`

Goal:
- Refine trust, privacy, and parent-facing communication so it supports productization and monetization without overstating the app's protections or data behavior.

Concrete tasks:
- Apply the approved trust and product-flow direction to parent-facing copy and hierarchy across `HomeView`, `ParentAccessGateView`, `ParentTrustCenterView`, `NewStoryJourneyView`, and `VoiceSessionView`.
- Keep privacy statements exact, especially around raw audio, live processing, retention, deletion, and local history.
- Integrate any approved parent-managed upgrade communication without weakening the trust boundary.

Required tests or verification method:
- directly affected `StoryTimeUITests`
- targeted unit tests if privacy-summary strings or trust-state helpers change
- update related docs if privacy or trust framing changes materially

Dependencies:
- M8.3
- M8.4
- M8.5
- M8.6

Definition of done:
- Parent trust and privacy communication is cohesive across the product.
- Upgrade language, if added, stays parent-managed and repo-accurate.
- The refined communication is regression-covered where practical.

Completion notes:
- `HomeView`, the lightweight parent gate, `ParentTrustCenterView`, `NewStoryJourneyView`, and `VoiceSessionView` now use tighter trust and privacy copy that stays accurate about raw audio, live processing, on-device history, and the limited role of the `PARENT` check.
- Parent-facing communication now separates what stays on device from what goes live during a session, and the setup plus live-session surfaces now say more clearly that parent controls stay outside the live child story.
- Verified by targeted `StoryTimeUITests` coverage for the gate, home, setup footer, and privacy-copy path (`5` passed) plus targeted `PracticeSessionViewModelTests` coverage for both privacy-summary branches (`2` passed across two focused runs).
- The current sprint queue is complete after `M8.8`; the next run should start with a planning pass instead of more unqueued implementation work.

## Phase 8 - Launch Readiness

### M9.1 - Launch scope lock and MVP acceptance checklist

Status: `DONE`

Goal:
- Lock the StoryTime MVP launch scope, explicit exclusions, and the evidence-based acceptance checklist before implementation spreads across onboarding, billing, paywall, enforcement, and QA work.

Concrete tasks:
- Audit the current repo state against the completed M8 groundwork, current verification docs, and the known launch gaps.
- Define what is in scope for the MVP launch candidate versus explicitly deferred until after launch.
- Resolve or narrow the open launch decisions enough to implement safely:
  - free versus paid boundaries
  - story-start and continuation caps
  - billing and restore scope
  - entitlement storage and enforcement ownership
  - required upgrade entry points
- Define the launch acceptance checklist in repo terms, including the exact flows, commands, verification docs, and pass or fail evidence required for the launch-candidate milestone.

Required tests or verification method:
- planning artifact grounded in repo inspection and current verification evidence
- no new code tests required unless the planning pass discovers repo/doc mismatch that must be corrected immediately

Dependencies:
- M8.8

Definition of done:
- MVP launch scope and explicit exclusions are written down.
- The acceptance checklist is concrete enough to drive the later launch-candidate pass.
- The next implementation milestone can start without reopening the basic launch-plan questions.

Completion notes:
- Added `docs/launch-mvp-scope-and-acceptance-checklist.md` to lock the MVP launch surface, explicit exclusions, narrowed monetization and launch decisions, and the exact command groups plus evidence labels required for `M9.8`.
- Locked the launch product shape to a two-tier `Starter` / `Plus` model with StoreKit 2 purchase truth, backend entitlement or preflight enforcement, parent-managed upgrade surfaces, pre-session gating, replay availability after cap exhaustion, and a required completion-loop implementation before launch.
- No new tests were run because `M9.1` is a planning-only milestone; verification came from repo inspection of the active app entry, product surfaces, backend route surface, test inventory, and the current verification docs.

### M9.2 - Onboarding and first-run flow implementation

Status: `DONE`

Goal:
- Implement the parent-led first-run flow that the repo now defines, without weakening trust language, active-child isolation, or the verified launch path into `NewStoryJourneyView`.

Concrete tasks:
- Add first-run presentation and completion state so fresh installs do not drop straight into the normal returning-user home experience without guidance.
- Implement the approved onboarding sequence:
  - parent welcome and core product promise
  - trust and privacy framing
  - child setup or fallback-child confirmation
  - first-session expectation setting
  - parent handoff into the first story setup flow
- Reuse the current child-profile and parent-trust structures where practical instead of inventing duplicate models or screens.
- Persist the first-run completion state safely so returning users bypass onboarding while fresh installs still receive the guided setup path.

Required tests or verification method:
- directly affected `StoryTimeUITests` covering fresh install onboarding, parent setup, and first-story handoff
- targeted store or model tests if onboarding state persistence or child-profile bootstrap rules change
- update any impacted onboarding or trust docs if the implementation materially narrows the planning direction

Dependencies:
- M9.1

Definition of done:
- Fresh installs receive the guided first-run flow.
- Returning users bypass onboarding correctly.
- The onboarding path stays truthful about live processing, local retention, and the lightweight parent boundary.
- The first-run flow hands off cleanly into the existing pre-session launch surface.

Completion notes:
- `ContentView` now routes fresh installs into a dedicated `FirstRunOnboardingView` and only shows the normal `HomeView` once onboarding is complete.
- The onboarding flow now covers parent welcome, trust and privacy framing, fallback-child review or edit, session expectation setting, and final handoff into `NewStoryJourneyView`.
- `FirstRunExperienceStore` persists first-run completion locally, `UITestSeed` now resets or bypasses onboarding deterministically for UI coverage, and targeted `StoryTimeUITests` plus a small persistence unit test cover fresh install behavior, child editing, and first-story handoff.

### M9.3.1 - Entitlement snapshot model and bootstrap foundation

Status: `DONE`

Goal:
- Establish the shared entitlement model plus backend-issued snapshot bootstrap and client cache foundation that later StoreKit sync, paywall routing, and enforcement work can rely on.

Concrete tasks:
- Add the repo-owned entitlement model on client and backend:
  - tier
  - source
  - capability flags
  - child-profile cap
  - remaining counters
  - effective and expiry metadata
- Add backend-issued entitlement snapshot support and bootstrap exposure through the existing session/bootstrap path or an explicitly adjacent bootstrap route.
- Add a client entitlement store or manager that can cache, refresh, and expose the latest snapshot without widening into paywall UI.
- Keep the first implementation architecture-first:
  - allow debug or bootstrap-backed snapshot sources
  - do not implement usage enforcement yet
  - do not add child-session paywall behavior

Required tests or verification method:
- targeted iOS unit tests for entitlement decoding, cache rules, and bootstrap exposure
- backend route and service tests for snapshot issuance and bootstrap contract handling
- client/backend contract coverage proving one normalized snapshot shape

Dependencies:
- M9.1

Definition of done:
- The client and backend share one entitlement snapshot shape.
- The app can bootstrap and cache entitlement state without placeholder UI-only flags.
- Later StoreKit sync, paywall, and enforcement work can consume a real entitlement foundation.

Completion notes:
- `/v1/session/identity` now returns a normalized entitlement bootstrap envelope with a signed install-scoped token instead of leaving entitlement state as a planning-only concept.
- The backend now owns the shared entitlement snapshot types plus bootstrap issuance in `backend/src/lib/entitlements.ts`, and `security.ts` now signs and verifies entitlement tokens against the install ID.
- `APIClient` now decodes bootstrap entitlements, `AppEntitlements` caches the current envelope safely in `UserDefaults`, and `EntitlementManager` exposes the snapshot for later paywall and enforcement work without adding UI-only flags.
- Targeted backend tests cover bootstrap issuance, debug-seeded `plus` snapshots, and entitlement token verification; targeted iOS tests cover bootstrap decoding, cache expiry clearing, and manager reload from cache.

### M9.3.2 - StoreKit sync seam and entitlement refresh flow

Status: `DONE`

Goal:
- Add the StoreKit-facing client seam and backend sync route needed to normalize purchase state and refresh the backend entitlement snapshot.

Concrete tasks:
- Add the client purchase-state normalization seam needed for purchases and restore without forcing full paywall UI into this milestone.
- Implement the backend sync route that accepts normalized purchase state and returns a refreshed entitlement snapshot.
- Define how entitlement refresh is triggered, retried, and invalidated without introducing account assumptions or hidden purchase state.
- Keep this slice foundation-focused:
  - no paywall UI
  - no usage enforcement copy
  - no speculative post-launch catalog expansion

Required tests or verification method:
- targeted iOS unit tests for purchase normalization and entitlement refresh handling
- backend route and service tests for sync request validation and refreshed snapshot issuance
- client/backend contract coverage for sync error handling and refresh success paths

Dependencies:
- M9.3.1

Definition of done:
- StoreKit-facing state can be normalized into the repo-owned entitlement model.
- The backend can refresh the entitlement snapshot from normalized purchase input.
- Later upgrade UI can rely on a real refresh path instead of a static bootstrap snapshot.

Completion notes:
- `APIClient` now exposes a StoreKit-facing purchase normalization seam, an authenticated `/v1/entitlements/sync` client, and an `EntitlementManager` refresh path so purchase and restore flows can refresh the same entitlement envelope used at bootstrap.
- The backend now validates normalized purchase-state payloads, maps verified active Plus products to refreshed entitlement snapshots, and returns the same signed envelope shape from `/v1/entitlements/sync`.
- Targeted backend tests cover sync validation plus refreshed snapshot issuance, and targeted iOS tests cover sync request encoding, cache refresh handling, and manager-driven refresh from normalized purchase state.

### M9.3.3 - Preflight contract foundation for launch gating

Status: `DONE`

Goal:
- Define and implement the entitlement preflight contract that later usage enforcement and paywall routing will consume before runtime cost begins.

Concrete tasks:
- Add the shared preflight request and response contract for:
  - new story
  - saved-series continuation
  - child-profile cap context
  - requested length context
- Implement backend preflight evaluation foundations against the current entitlement snapshot without final usage accounting yet.
- Add client API plumbing so approved pre-session surfaces can request preflight results later without reworking the contract.
- Keep this slice non-final for launch caps:
  - no final usage accounting yet
  - no upgrade UI yet
  - no live-session gating

Required tests or verification method:
- targeted iOS unit tests for preflight decoding and client contract handling
- backend route and service tests for preflight validation and response shape
- client/backend contract coverage for allowed and blocked preflight scenarios using seeded entitlement snapshots

Dependencies:
- M9.3.1
- M9.3.2

Definition of done:
- The client and backend share one preflight contract.
- Later paywall and enforcement milestones can consume preflight results without reworking the entitlement foundation.
- Cost-bearing launch flows now have a real contract boundary ready for M9.4 and M9.5.

Completion notes:
- The backend now exposes `/v1/entitlements/preflight`, validates the signed install-scoped entitlement snapshot when present, and evaluates new-story versus continuation launch context against child-profile, length, and remaining-capability rules.
- `APIClient` now exposes a repo-owned preflight request and response model plus the authenticated preflight call, and the iOS target has request builders that keep repeat-only replay outside the contract.
- Targeted backend tests cover allowed, blocked, and invalid-token preflight scenarios, and targeted iOS tests cover request encoding, response decoding, and preflight request derivation from launch context.

### M9.4.1 - New story journey block surface and parent-managed route

Status: `DONE`

Goal:
- Add the first real blocked-launch upgrade surface to `NewStoryJourneyView` so pre-session launch attempts stop before `VoiceSessionView` and route into a parent-managed review path.

Concrete tasks:
- Run entitlement preflight from `NewStoryJourneyView` before session start.
- Show a truthful blocked-launch explanation on the journey surface for new-story and journey-based continuation attempts.
- Route blocked launches into a parent-managed review flow that preserves child and story context without adding purchase UI to the live child path.
- Keep `VoiceSessionView`, interruption handling, and active narration free of blocking upgrade UI.

Required tests or verification method:
- directly affected `StoryTimeUITests` for blocked new-story launch, blocked journey continuation, and parent-managed review routing
- targeted iOS unit tests if blocked-launch messaging or routing state is extracted into helpers

Dependencies:
- M9.1
- M9.3.2
- M9.3.3

Definition of done:
- `NewStoryJourneyView` preflights before session start.
- Blocked launches do not enter `VoiceSessionView`.
- A parent-managed review path exists from the journey surface without widening into durable purchase-management UI yet.

Completion notes:
- `NewStoryJourneyView` now runs entitlement preflight before starting a session and keeps blocked new-story plus journey-continuation attempts out of `VoiceSessionView`.
- Blocked launches now surface truthful parent-facing review copy on the journey screen and route through the lightweight `PARENT` gate into a journey-owned review sheet instead of live-session upgrade UI.
- Targeted UI coverage now pins blocked new-story review routing, blocked journey continuation behavior, and the unchanged continuation setup copy on the journey surface.

### M9.4.2 - Saved-series continuation gate and replay-safe routing

Status: `DONE`

Goal:
- Add the continuation-focused upgrade surface to `StorySeriesDetailView` while keeping replay available according to the locked MVP rules.

Concrete tasks:
- Run entitlement preflight before `New Episode` launches from `StorySeriesDetailView`.
- Show a continuation-specific blocked surface that explains replay versus new-episode behavior truthfully.
- Keep `Repeat` available when allowed by the plan rules and keep blocked continuation outside `VoiceSessionView`.

Required tests or verification method:
- directly affected `StoryTimeUITests` for blocked continuation, allowed replay, and parent-managed review routing from saved-series detail
- targeted iOS unit tests if continuation gating helpers are extracted

Dependencies:
- M9.4.1

Definition of done:
- `StorySeriesDetailView` blocks new-episode launches before runtime cost begins when preflight disallows them.
- Replay remains available according to the approved rules.

Completion notes:
- `StorySeriesDetailView` now runs entitlement preflight before `New Episode`, keeps blocked continuation out of `VoiceSessionView`, and routes the parent through the lightweight gate into a saved-series review sheet.
- `Repeat` remains a direct replay path and is not preflighted, keeping the surface aligned to the locked MVP replay rule.
- Targeted UI coverage now pins blocked saved-series continuation, parent-managed review routing, replay remaining available under a continuation block, and the unchanged saved-series action hierarchy.

### M9.4.3 - Durable parent plan management and optional home awareness

Status: `DONE`

Goal:
- Add the durable parent-managed plan surface, restore affordance, and any low-risk soft plan awareness needed to complete the approved upgrade hierarchy.

Concrete tasks:
- Add current plan state, upgrade framing, and restore-purchase entry points to the parent-managed controls path.
- Reuse the blocked-launch review flow to reach the durable parent-managed plan surface.
- Add only soft `HomeView` plan awareness if it still fits the locked MVP scope without adding execution risk.

Required tests or verification method:
- directly affected `StoryTimeUITests` for parent-managed plan and restore entry
- targeted iOS unit tests if plan presentation helpers are extracted
- update paywall or upgrade-strategy docs only if implementation intentionally narrows the approved rules

Dependencies:
- M9.4.1
- M9.4.2

Definition of done:
- The approved parent-managed upgrade hierarchy is fully present.
- Durable plan-state and restore entry are available outside the live child session.

Completion notes:
- `ParentTrustCenterView` now exposes a durable plan section with current Starter status, remaining-use summaries, explicit Starter versus Plus framing, refresh, and restore entry without introducing child-facing purchase UI.
- The blocked new-story review flow now points parents at `ParentTrustCenterView`, and the review copy explicitly says that current plan review, upgrades, and restore live in Parent Controls.
- Optional `HomeView` plan awareness was intentionally deferred because it was not required to complete the approved hierarchy and would have widened launch-scope risk.
- Targeted UI coverage now pins the durable parent plan surface, the journey-review handoff into Parent Controls, and the existing add-child parent-controls flow with scrolling for the new higher plan section.

### M9.5 - Usage limits and plan enforcement

Status: `DONE`

Goal:
- Enforce the final Starter versus Plus boundaries before realtime boot, discovery, generation, or continuation cost is incurred.

Concrete tasks:
- Implement the final usage counters, windows, and capability checks chosen in `M9.1`.
- Wire preflight enforcement into new-story launch, saved-series continuation, child-profile caps, and any approved length or pacing limits.
- Keep replay of already-saved stories, trust controls, and deletion flows available regardless of paid status unless `M9.1` explicitly says otherwise.
- Ensure backend enforcement and client messaging stay aligned so blocked flows fail safely and truthfully.

Required tests or verification method:
- directly affected `StoryTimeUITests` for blocked and allowed launch paths
- targeted iOS unit tests for preflight decision handling and plan-state presentation
- backend route and service tests for usage accounting and preflight enforcement

Dependencies:
- M9.1
- M9.3.2
- M9.3.3
- M9.4

Definition of done:
- Usage limits are enforced before cost-bearing runtime work starts.
- Client and backend agree on blocked versus allowed behavior.
- Allowed replay and trust flows remain intact.

Split note:
- `M9.5` is too large for one safe run because the repo still lacks both config-backed launch defaults and a backend-owned usage ledger. It is split into `M9.5.1` through `M9.5.3` so launch-readiness enforcement can land in deterministic slices without inventing a fake client-side counter system.

Completion notes:
- `M9.5.1` moved Starter and Plus defaults into backend config-backed entitlement snapshots so live bootstrap, sync, and preflight all expose explicit caps and remaining allowance.
- `M9.5.2` added backend-owned rolling usage depletion at entitlement preflight and refreshed entitlement envelopes back to the client cache.
- `M9.5.3` aligned parent-facing copy, child-profile gating, and blocked-launch review summaries to the enforced counters and finished the blocked-versus-allowed UI verification for the final launch-path rules.

### M9.5.1 - Config-backed entitlement defaults in live snapshots

Status: `DONE`

Goal:
- Replace the current nil-heavy starter and plus capability defaults with config-backed launch defaults in backend-issued entitlement snapshots.

Concrete tasks:
- Add backend configuration for starter and plus launch defaults covering child-profile cap, new-story cap, continuation cap, and rolling usage window.
- Issue bootstrap and sync entitlement snapshots from those configured defaults instead of hardcoded nil counters.
- Keep replay and parent-trust capabilities allowed, and do not introduce fake counter depletion before a backend-owned usage ledger exists.

Required tests or verification method:
- backend `entitlements.test.ts` for configured starter and plus snapshot issuance
- backend `app.integration.test.ts` for bootstrap or preflight snapshots carrying the configured defaults
- iOS `APIClientTests` for decoding and caching the updated entitlement snapshot contract

Dependencies:
- M9.1
- M9.3.2
- M9.3.3

Definition of done:
- Live bootstrap and sync snapshots expose explicit config-backed plan defaults instead of nil counters.
- Preflight decisions consume those configured defaults through the existing contract.
- Client and backend tests pin the updated snapshot shape.

Completion notes:
- Backend env now defines config-backed Starter and Plus launch defaults for child-profile cap, new-story allowance, continuation allowance, story-length cap, and rolling usage-window duration.
- `issueBootstrapEntitlements(...)` and `issueSyncedEntitlements(...)` now issue live snapshots with explicit remaining counts and window duration instead of nil-heavy placeholder values.
- Targeted backend entitlement and integration tests plus iOS `APIClientTests` now pin the updated snapshot contract.

### M9.5.2 - Backend usage accounting and preflight depletion

Status: `DONE`

Goal:
- Add backend-owned usage accounting so starter and plus snapshots can deplete remaining new-story and continuation allowance across launches.

Concrete tasks:
- Introduce a backend-owned usage ledger keyed to the active install/session identity model.
- Decrement remaining new-story and continuation allowance at the correct pre-cost boundary.
- Refresh issued entitlement snapshots so remaining counters stay aligned with backend truth.

Required tests or verification method:
- backend route and service tests for counter initialization, depletion, and reset-window behavior
- iOS `APIClientTests` for refreshed remaining-counter handling if response shapes change
- targeted `StoryTimeUITests` for blocked versus allowed new-story and saved-series continuation flows once live depletion is wired

Dependencies:
- M9.5.1

Definition of done:
- Remaining story-start and continuation counts are backend-owned and survive beyond a single bootstrap.
- Preflight blocks depleted launches before runtime cost starts.
- Replay and parent-trust flows remain available.

Completion notes:
- Backend entitlement handling now maintains an install-scoped rolling usage ledger for `new_story` and `continue_story` actions, recalculates remaining counters against the current plan snapshot, and reflects depleted counters in bootstrap and sync responses.
- `/v1/entitlements/preflight` now consumes allowed cost-bearing launches at the preflight boundary, returns refreshed remaining counters, and includes a refreshed entitlement envelope for client cache alignment.
- `APIClient.preflightEntitlements(...)` now stores refreshed entitlement envelopes from preflight responses, and targeted backend, client, and focused UI verification now pin depletion, reset-window behavior, blocked launch behavior, and replay-safe routing.

### M9.5.3 - Client plan-limit alignment and launch-path verification

Status: `DONE`

Goal:
- Align parent-managed client surfaces with the enforced plan limits and finish the launch-facing verification for `M9.5`.

Concrete tasks:
- Update parent-controls child-profile management and plan messaging so they reflect the enforced entitlement limits truthfully.
- Ensure blocked new-story and continuation paths present plan state and review guidance consistent with the backend-owned counters.
- Finish the directly affected UI coverage for allowed and blocked launch paths under the final `M9.5` rules.

Required tests or verification method:
- directly affected `StoryTimeUITests` for blocked and allowed launch paths plus parent-controls child-profile gating
- targeted iOS unit tests for plan-state presentation if helper extraction is needed

Dependencies:
- M9.5.1
- M9.5.2

Definition of done:
- Parent-managed client surfaces reflect the enforced plan limits truthfully.
- Launch-facing UI coverage pins the final blocked versus allowed behavior.
- `M9.5` can be marked done without known launch-readiness gaps in usage-limit enforcement.

Completion notes:
- `ParentTrustCenterView` now uses entitlement-backed child-profile caps for add-child gating, shows truthful plan allowance summaries, and surfaces the blocked child-profile state without fallback hardcoded marketing copy.
- Blocked new-story and saved-series continuation review copy now mirrors the live entitlement snapshot counters so parent-managed guidance stays aligned with backend-owned limits.
- `UITestSeed` now exposes deterministic allowed and blocked entitlement variants, `StoryLibraryStore` now accepts a plan-backed child-profile cap for gating, and targeted `StoryLibraryStoreTests` plus `StoryTimeUITests` now pin blocked and allowed launch behavior for the final `M9.5` rules.

### M9.6 - End-of-story and repeat-use loop implementation

Status: `DONE`

Goal:
- Turn the documented completion-loop direction into a real product flow that bridges a finished session into replay, continuation, and return-to-library behavior.

Concrete tasks:
- Add the explicit completion acknowledgement and next-step actions to `VoiceSessionView` or its approved successor surface.
- Wire the approved next-step order:
  - replay the finished story
  - start a new episode
  - return to saved stories or home
- Keep the completion experience child-safe and non-transactional even if continuation later routes to a parent-managed upgrade surface.
- Preserve the existing coordinator completion and persistence semantics while productizing the post-story UI.

Required tests or verification method:
- directly affected `StoryTimeUITests` for completion actions and navigation
- targeted `PracticeSessionViewModelTests` only if completion-state logic or save behavior changes
- update the repeat-use loop doc if implementation narrows the planned behavior

Dependencies:
- M9.1
- M9.4
- M9.5

Definition of done:
- Completion is no longer a dead-end prompt.
- Replay, continuation, and return-to-library actions map cleanly to real product behavior.
- Finished stories are not interrupted by blocking upgrade UI.

Completion notes:
- `VoiceSessionView` now shows an explicit completion card plus child-safe replay, new-episode, and return actions once a story finishes.
- `PracticeSessionViewModel.replayCompletedStory()` now restarts narration from the beginning of the completed story without widening save behavior, and targeted tests pin the replay path plus repeat-history invariants.
- Saved-series sessions now return to the existing `StorySeriesDetailView` context for continuation and "Back to Saved Stories," while new-story launches still keep a clean path back toward home through the journey flow.
- `docs/end-of-story-repeat-use-loop.md` now includes an implementation addendum documenting the shipped behavior and the narrowed saved-series return-path decision.

### M9.7 - Cost, usage, and latency telemetry for launch confidence

Status: `DONE`

Goal:
- Finalize the telemetry needed to make launch economics, limit decisions, and launch-candidate confidence evidence-based.

Concrete tasks:
- Fill the known telemetry gaps from `M8.2` and `M6.3`, especially joined per-session cost and latency visibility across client and backend.
- Add launch-relevant telemetry for entitlement sync, preflight allow or block decisions, upgrade-surface presentation, restore flows, and capped-session outcomes as approved by `M9.1`.
- Define the minimum reporting or verification output required to judge commercial confidence for launch.
- Keep runtime stages explicit and preserve the existing grouped-stage model instead of collapsing launch telemetry into generic counters.

Required tests or verification method:
- targeted iOS and backend telemetry tests for any new emitted events or counters
- updated verification artifact documenting commands, evidence labels, and remaining telemetry gaps
- no milestone completion without a concrete launch-confidence reporting path

Dependencies:
- M9.1
- M9.3.2
- M9.3.3
- M9.4
- M9.5
- M9.6

Definition of done:
- Launch-relevant telemetry answers the MVP commercial-confidence questions.
- New entitlement and upgrade events are measurable and redacted appropriately.
- The later launch-candidate milestone can rely on explicit telemetry evidence instead of inference.

Completion notes:
- `M9.7` is split into `M9.7.1` through `M9.7.3` because the original milestone combines backend analytics shape, client launch-event capture, and the final verification/report artifact. Landing those in one run would make it too easy to blur instrumentation, reporting, and acceptance evidence changes.
- `backend/src/app.ts` and `backend/src/lib/analytics.ts` now expose a concrete backend `/health` telemetry report with launch-event counters plus per-session usage summaries, and `APIClient.swift` now exposes the parallel client `ClientLaunchTelemetry.report()` surface for restore, blocked-review, and parent-plan events.
- `docs/verification/launch-confidence-telemetry-report.md` now records the exact verification commands, evidence labels, minimum commercial-confidence report shape, and the remaining threshold and durability gaps that still feed `M9.8`.

### M9.7.1 - Backend launch telemetry and session-reporting foundation

Status: `DONE`

Goal:
- Extend the backend analytics layer so launch-relevant entitlement activity and provider usage can be inspected by session instead of only through flat counters.

Concrete tasks:
- Add backend launch telemetry for entitlement bootstrap, entitlement sync, and entitlement preflight allow or block outcomes.
- Extend backend analytics to keep per-session request, provider-usage, and launch-event summaries without logging transcript text, story text, or raw audio.
- Expose a concrete backend reporting surface that later launch-confidence verification can inspect directly.

Required tests or verification method:
- targeted backend analytics and integration tests for new counters and session summaries
- no completion without a backend-visible reporting path for launch-relevant telemetry

Dependencies:
- M9.3.2
- M9.3.3
- M9.5

Definition of done:
- Backend telemetry now exposes redacted launch-event counters plus per-session summaries for request, provider-usage, and entitlement activity.
- The reporting surface is concrete enough for later launch-confidence verification to consume directly.

Completion notes:
- Backend analytics now records launch events for entitlement bootstrap, entitlement sync, and entitlement preflight allow or block outcomes.
- Provider-usage telemetry is now session-joinable through `sessionId`, and the analytics report now exposes both flat counters and per-session summaries for request, OpenAI usage, runtime-stage groups, and launch-event activity.
- `/health` now returns the concrete backend telemetry report shape needed for later launch-confidence verification, and targeted analytics plus integration tests pin that reporting surface.

### M9.7.2 - Client launch telemetry for entitlement and upgrade surfaces

Status: `DONE`

Goal:
- Add the client-side launch telemetry needed to observe restore, upgrade-surface presentation, and launch-path outcomes on the active iOS product surfaces.

Concrete tasks:
- Record launch-relevant client events for restore attempts, blocked-launch review presentation, parent-controls plan management, and related entitlement outcomes.
- Keep the existing grouped runtime-stage telemetry intact while making launch moments observable without transcript leakage.
- Add targeted iOS tests for the new launch-event capture path.

Required tests or verification method:
- targeted iOS unit or UI telemetry tests for the emitted launch events

Dependencies:
- M9.7.1

Definition of done:
- The active iOS launch surfaces emit redacted launch telemetry for restore, upgrade review, and blocked-versus-allowed launch moments.

Completion notes:
- `APIClient` now records entitlement sync and preflight launch outcomes into a redacted client launch-telemetry store, and the entitlement trace operation labels for sync versus preflight are corrected so API traces and launch telemetry stay aligned.
- `ParentTrustCenterView` now emits parent-managed plan presentation plus refresh and restore events, and both blocked-review surfaces now emit presentation events without logging transcript text, story text, or raw audio.
- Targeted `APIClientTests` now pin the emitted counters and per-session summary shape, and focused existing UI tests re-verify the touched parent-managed review and plan surfaces.

### M9.7.3 - Launch-confidence verification artifact and reporting path

Status: `DONE`

Goal:
- Turn the backend and client telemetry foundations into the explicit verification artifact required for launch-go or no-go review.

Concrete tasks:
- Update the verification artifact for launch telemetry with exact commands, evidence labels, and remaining gaps.
- Define the minimum commercial-confidence report shape for launch review using the concrete reporting paths added in `M9.7.1` and `M9.7.2`.
- Record any still-unverified telemetry limits or threshold gaps explicitly.

Required tests or verification method:
- updated verification artifact with evidence labels and exact commands
- targeted reruns needed to support the recorded evidence

Dependencies:
- M9.7.1
- M9.7.2

Definition of done:
- The repo contains an explicit launch-confidence telemetry report with evidence labels, exact commands, and remaining gaps.
- `M9.8` can consume that report instead of inferring telemetry readiness.

Completion notes:
- `docs/verification/launch-confidence-telemetry-report.md` now turns the backend `/health` telemetry report and the client `ClientLaunchTelemetry.report()` surface into one explicit repo-owned verification artifact for launch review.
- The report records the exact backend, unit-test, and focused UI commands used for evidence, and it labels material telemetry claims as `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, or `UNVERIFIED`.
- The minimum commercial-confidence report shape is now explicit in repo terms, and the remaining gaps are narrowed to undefined numeric thresholds plus the current in-memory or process-local durability limits.

### M9.8 - Launch candidate QA and acceptance pass

Status: `DONE`

Goal:
- Run the explicit launch-candidate QA and acceptance pass for the MVP defined in `M9.1`.

Concrete tasks:
- Execute the launch acceptance checklist across the full MVP flow:
  - fresh install and onboarding
  - parent controls and privacy trust flow
  - purchase, restore, and entitlement sync
  - new story start and continuation gating
  - repeat and completion-loop behavior
  - save, deletion, and child-isolation behavior
  - startup, failure, and recovery behavior
  - launch telemetry sanity
- Record each checked behavior with the required evidence labels, exact commands, and remaining gaps.
- Document any launch blockers, defer-only items, or go/no-go decisions without widening the milestone into unrelated new feature work.

Required tests or verification method:
- the exact launch checklist and commands defined in `M9.1`
- updated launch-candidate verification report in `docs/verification/`
- required iOS unit, iOS UI, and backend test commands for the final MVP surface

Dependencies:
- M9.1
- M9.2
- M9.3.1
- M9.3.2
- M9.3.3
- M9.4
- M9.5
- M9.6
- M9.7.1
- M9.7.2
- M9.7.3
- M9.7

Definition of done:
- The repo has an explicit launch-candidate acceptance report with pass, fail, or blocked outcomes.
- Remaining blockers are recorded clearly in `PLANS.md` and `SPRINT.md`.
- StoryTime is either evidence-backed launch-ready or the blocking gaps are explicit and queued.

Completion notes:
- `docs/verification/launch-candidate-acceptance-report.md` now records the exact launch-candidate command set, evidence labels, checklist findings, blocker inventory, and final go or no-go decision.
- The launch-candidate QA pass completed with a `NO-GO` outcome because the backend launch-contract suite and hybrid-runtime baseline are green, but the final iOS launch-product unit and UI suites still fail on coordinator repeat-revision behavior, first-story entry, session cueing, privacy-copy, and parent-gate regressions.
- Pricing-confidence thresholds and durable joined telemetry remain only partially verified, so they are recorded explicitly instead of being treated as hidden assumptions.

### M9.9 - Launch blocker remediation

Status: `DONE`

Goal:
- Clear the concrete blockers found in `M9.8` and rerun launch acceptance against a green candidate.

Concrete tasks:
- Fix the failing coordinator repeat or revision acceptance regressions.
- Fix the failing first-story, session-cue, privacy-copy, and parent-gate UI regressions.
- Re-run the blocked launch-product suites and carry any remaining go or no-go gaps into a final launch rerun.

Required tests or verification method:
- the failing iOS unit and UI cases recorded in `docs/verification/launch-candidate-acceptance-report.md`
- targeted regression reruns per blocker slice
- a final `M9.9.3` launch-rerun verification update

Dependencies:
- M9.8

Definition of done:
- The blockers recorded in `M9.8` are either fixed and green or explicitly reclassified with evidence.
- The next launch-candidate rerun has a concrete blocker-free target.

### M9.9.1 - Coordinator repeat/revision acceptance regression fixes

Status: `DONE`

Goal:
- Restore green coordinator acceptance coverage for revised-story persistence, repeat-episode replacement, resume position, and bounded revision-queue behavior.

Concrete tasks:
- Reproduce and fix the failing `PracticeSessionViewModelTests` acceptance and repeat-revision cases recorded by `M9.8`.
- Keep revision ownership, repeat replacement semantics, and continuity replacement deterministic.
- Add or update coordinator regression tests only as needed for the repaired behavior.

Required tests or verification method:
- targeted `PracticeSessionViewModelTests`
- targeted related `StoryLibraryStoreTests` only if persistence semantics change

Dependencies:
- M9.8

Definition of done:
- The current `M9.8` coordinator blocker cases pass and the repaired behavior stays regression-covered.

Completion notes:
- `PracticeSessionViewModel` now issues deterministic repeat-episode full-story rewrite requests when no future-scene boundary exists, merges revisions from the backend-reported `revisedFromSceneIndex`, and completes repeat-mode replace-in-place saves without getting stuck in a resume path.
- The blocked coordinator acceptance tests from `M9.8` are green again, and the interruption router now explicitly treats plain "add a ..." cues as revision language.

### M9.9.2 - Launch UI and parent-trust regression fixes

Status: `DONE`

Goal:
- Restore green launch-product UI coverage for parent gate behavior, truthful privacy copy, first-story entry, and session cue presentation.

Concrete tasks:
- Reproduce and fix the failing `StoryTimeUITests` cases recorded by `M9.8`.
- Keep onboarding, parent controls, privacy messaging, and voice-session cueing aligned with the current hybrid runtime and trust model.
- Add or update only the directly affected UI coverage.

Required tests or verification method:
- targeted `StoryTimeUITests`

Dependencies:
- M9.8

Definition of done:
- The current `M9.8` UI blocker cases pass and the repaired launch surfaces remain truthfully aligned.

Completion notes:
- The blocked `StoryTimeUITests` launch-product cases from `M9.8` are green again, including parent gate entry, privacy-copy verification, first-story entry, and the listening plus storytelling cue surfaces.
- Seeded UI-test preflight now derives a local fallback decision from the current entitlement snapshot when no explicit override is present, so launch-facing UI coverage no longer depends on live backend availability.
- `VoiceSessionView` now swaps in a deterministic UI-test session client under `STORYTIME_UI_TEST_MODE`, keeping story generation and revision stable for the launch-product UI suite without changing production behavior.
- Parent/privacy UI assertions now scroll within the current plan-first parent-controls form, and the listening-cue assertion now checks the stable child-facing contract instead of a timing-sensitive discovery question number.

### M9.9.3 - Launch candidate re-run and commercial-threshold decision

Status: `DONE`

Goal:
- Re-run the blocked launch-candidate pack after `M9.9.1` and `M9.9.2`, then record the final threshold decision and launch state.

Concrete tasks:
- Re-run the `M9.8` command set after blocker remediation.
- Update the launch-candidate report with the new outcomes.
- Record the commercial threshold decision explicitly as pass, fail, or deferred blocker.

Required tests or verification method:
- the exact `M9.8` command set
- updated launch verification report in `docs/verification/`

Dependencies:
- M9.9.1
- M9.9.2

Definition of done:
- The repo has an updated post-remediation launch decision with explicit threshold treatment and no hidden blocker state.

Completion notes:
- The launch-candidate pack was rerun cleanly on dedicated simulators after `M9.9.1` and `M9.9.2`.
- The hybrid-runtime baseline and backend launch-contract suite are green, and the full `StoryTimeUITests` launch-product UI suite is now green.
- The final launch-product unit suite still fails on `PracticeSessionViewModelTests.testBlockedRevisionUsesModerationCategoryAndSafeMessage()` and `PracticeSessionViewModelTests.testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes()`, so the launch decision remains `NO-GO`.
- Commercial thresholds remain explicitly deferred instead of being treated as a hidden launch-ready assumption.

### M9.10 - Remaining launch blockers and threshold closure

Status: `DONE`

Goal:
- Clear the last verified launch blocker cases and finish the explicit commercial threshold decision before one final launch rerun.

Concrete tasks:
- Fix the remaining coordinator revision-resume failures that still block the final launch-product unit suite.
- Define explicit repo-owned cost, latency, and launch-cap threshold treatment for launch review.
- Re-run the final launch-candidate pack once those items are complete and record the updated go or no-go state.

Required tests or verification method:
- targeted `PracticeSessionViewModelTests` for the remaining blocker cases
- updated launch verification report in `docs/verification/launch-candidate-acceptance-report.md`

Dependencies:
- M9.9.3

Definition of done:
- The remaining verified launch blocker cases are green.
- Commercial thresholds are explicit in repo-owned pass, fail, or deferred terms.
- The repo has one updated final launch decision based on a clean rerun.

Notes:
- `M9.10.1` through `M9.10.4` are complete.
- Launch-default cap treatment is explicit and passing, cost plus latency thresholds now have repo-owned numeric terms, and the final launch rerun is green.
- The current locked MVP candidate is now recorded as `GO`; the next workstream is post-launch telemetry durability and joined-report hardening rather than launch-blocker remediation.

### M9.10.1 - Revision-resume moderation and deferred-transcript blocker fix

Status: `DONE`

Goal:
- Repair the remaining revision-resume mismatch so blocked revision moderation and deferred transcript rejection after narration resumes both return to deterministic green behavior.

Concrete tasks:
- Reproduce and fix the two remaining `PracticeSessionViewModelTests` failures from `M9.9.3`.
- Keep moderation-safe blocked revision handling and deferred transcript rejection aligned with the active revision boundary rules.
- Add or update only the directly affected coordinator regressions.

Required tests or verification method:
- `PracticeSessionViewModelTests/testBlockedRevisionUsesModerationCategoryAndSafeMessage`
- `PracticeSessionViewModelTests/testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes`
- related targeted coordinator tests only if the repaired behavior actually changes

Dependencies:
- M9.9.3

Definition of done:
- The remaining `M9.9.3` coordinator blocker cases are green and regression-covered.

Notes:
- `PracticeSessionViewModel` now accepts backend-authored current-scene replay as a valid revision resume target when narration needs to restart from the interrupted scene.
- The remaining blocker tests `testBlockedRevisionUsesModerationCategoryAndSafeMessage` and `testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes` are green again.
- Related revision resume, repeat replacement, and revision queue coordinator reruns also passed after the fix.

### M9.10.2 - Commercial threshold definition and final launch rerun

Status: `DONE`

Goal:
- Define explicit launch-threshold treatment in repo terms and rerun the launch pack after `M9.10.1`.

Concrete tasks:
- Record explicit pass, fail, or deferred treatment for acceptable cost, latency, and launch-default cap thresholds.
- Re-run the `M9.8` launch-candidate command set after `M9.10.1`.
- Update the launch-candidate report with the resulting final go or no-go decision.

Required tests or verification method:
- the exact `M9.8` command set
- updated launch verification report in `docs/verification/`

Dependencies:
- M9.10.1

Definition of done:
- The repo has an updated final launch decision with explicit threshold treatment and no hidden blocker state.

Notes:
- The full launch-candidate command set was rerun on March 13, 2026.
- The hybrid-runtime baseline passed, the backend launch-contract suite passed `53` tests, and the full `StoryTimeUITests` launch-product UI suite passed all `35` tests.
- The launch-product unit suite still fails on `PracticeSessionViewModelTests.testPausedNarrationHandsOffToInteractionWithoutReconnect()` and `PracticeSessionViewModelTests.testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly()`, so the launch decision remains `NO-GO`.
- Launch-default caps now have explicit PASS treatment in repo terms, while cost and latency thresholds are explicit deferred blockers.

### M9.10.3 - Paused-narration interaction handoff blocker fix

Status: `DONE`

Goal:
- Repair the remaining paused-narration interaction-handoff mismatch so the launch-product unit suite returns to green behavior for no-reconnect handoff and transcript-final direct handoff.

Concrete tasks:
- Reproduce and fix `PracticeSessionViewModelTests.testPausedNarrationHandsOffToInteractionWithoutReconnect()`.
- Reproduce and fix `PracticeSessionViewModelTests.testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly()`.
- Keep paused narration, direct interaction handoff, and no-reconnect semantics aligned with the active hybrid runtime.

Required tests or verification method:
- `PracticeSessionViewModelTests/testPausedNarrationHandsOffToInteractionWithoutReconnect`
- `PracticeSessionViewModelTests/testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly`
- related targeted coordinator tests only if the repaired behavior actually changes

Dependencies:
- M9.10.2

Definition of done:
- The remaining paused-narration interaction-handoff blocker cases are green and regression-covered.

Notes:
- `PracticeSessionViewModel` now accepts later future-scene revision start indices during resume validation, which matches the existing `NarrationResumeDecision` and hybrid-state-model contract instead of assuming every revision must restart at `sceneIndex + 1`.
- `testPausedNarrationHandsOffToInteractionWithoutReconnect()` and `testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly()` are green again.
- The broader launch-product unit slice covering `APIClientTests`, `PracticeSessionViewModelTests`, and `StoryLibraryStoreTests` now passes `126` tests with `0` failures.

### M9.10.4 - Numeric commercial threshold decision and clean launch rerun

Status: `DONE`

Goal:
- Convert cost and latency threshold treatment from deferred blockers into repo-owned numeric pass or fail terms, then rerun the launch pack after `M9.10.3`.

Concrete tasks:
- Record explicit numeric pass or fail thresholds for launch cost review.
- Record explicit numeric pass or fail thresholds for launch latency review.
- Re-run the `M9.8` launch-candidate command set after `M9.10.3`.
- Update the launch-candidate report with the resulting final go or no-go decision.

Required tests or verification method:
- the exact `M9.8` command set
- updated launch verification report in `docs/verification/launch-candidate-acceptance-report.md`

Dependencies:
- M9.10.3

Definition of done:
- The repo has one updated launch decision with green verified product suites and commercial thresholds that are no longer deferred.

Notes:
- The final March 13, 2026 rerun is green: the hybrid-runtime baseline passed, the backend launch-contract suite passed `53` tests, the launch-product unit suite passed `126` tests with `0` failures, and the full `StoryTimeUITests` suite passed `35` tests with `0` failures.
- Launch cost thresholds are now explicit numeric pass criteria tied to enforced backend plan caps: Starter allows `6` remote-cost-bearing launches per rolling `7` days for `1` child, and Plus allows `24` remote-cost-bearing launches per rolling `7` days across up to `3` children, both with a `10` minute story-length cap.
- Launch latency thresholds are now explicit numeric pass criteria tied to the active timeout ceilings: `<= 8` seconds for health checks, `<= 12` seconds for session identity and voices, and `<= 20` seconds for entitlement sync, entitlement preflight, realtime session, discovery, generation, revision, and the backend realtime upstream proxy.
- `docs/verification/launch-candidate-acceptance-report.md` now records the current locked MVP candidate as `GO`.

### M9.11 - Telemetry durability and joined launch-report hardening

Status: `DONE`

Goal:
- Persist launch telemetry beyond process lifetime and define a joined backend-plus-client launch report so post-launch confidence no longer depends on separate transient reporting surfaces.

Concrete tasks:
- Persist backend launch telemetry and usage history beyond backend process lifetime.
- Persist client launch telemetry beyond app process lifetime or export it into a durable launch-review surface.
- Define one joined backend-plus-client launch report shape that can be inspected directly during post-launch verification.

Required tests or verification method:
- targeted backend analytics tests
- targeted iOS telemetry tests
- updated verification artifact in `docs/verification/`

Dependencies:
- M9.10.4

Definition of done:
- Launch telemetry survives process restarts or is exported durably enough for verification.
- The repo has one joined launch-report surface instead of separate transient backend and client reports.

Notes:
- Backend analytics now persist counters and per-session summaries to `ANALYTICS_PERSIST_PATH`, and `/health` reloads and serves that durable report through `analytics.report()`.
- Client launch telemetry now persists its report in `UserDefaults`, and `APIClient.fetchLaunchTelemetryReport()` now joins that durable client report with backend `/health` telemetry in one `LaunchTelemetryJoinedReport`.
- Targeted backend telemetry tests passed `38` tests, targeted iOS telemetry tests passed `3` tests, and `docs/verification/launch-confidence-telemetry-report.md` now records the durable and joined-report evidence.

### M9.12 - Narration wall-clock telemetry hardening

Status: `DONE`

Goal:
- Extend narration telemetry from preparation-heavy timing into playback wall-clock evidence so post-launch review can reason about actual narration latency and completion behavior.

Concrete tasks:
- Record narration playback start, completion, and cancellation wall-clock timing at the coordinator or narration-transport boundary.
- Preserve explicit stage attribution between narration preparation and playback so the telemetry stays economically meaningful.
- Update the verification artifact to show the new playback-wall-clock evidence and any remaining measurement gaps.

Required tests or verification method:
- targeted iOS telemetry or coordinator tests for narration playback timing
- updated verification artifact in `docs/verification/`

Dependencies:
- M9.11

Definition of done:
- Narration telemetry includes playback wall-clock evidence instead of relying primarily on TTS preparation timing.
- The verification docs record the updated evidence and the remaining telemetry limits clearly.

Notes:
- `RuntimeTelemetryStage` now separates narration preparation from playback with `tts_generation`, `tts_playback_started`, `tts_playback_completed`, and `tts_playback_cancelled`, all still grouped under `narration`.
- `PracticeSessionViewModel` now records playback start before `playScene(...)` begins and records completion or cancellation wall-clock duration after playback returns, preserving the original narration start source for attribution.
- Targeted `PracticeSessionViewModelTests` passed `3` tests, covering preload telemetry plus playback completion and interruption-driven cancellation telemetry.
- `docs/verification/runtime-stage-telemetry-verification.md` now records the new playback-wall-clock evidence, and the remaining telemetry gap narrows to durable runtime-stage timeline export rather than missing playback timing itself.
