# Parent Account, Payment, And Promo Foundation Architecture

Date: 2026-03-20
Milestone: M11.1 - Account architecture and flow alignment

## Scope

This document locks the minimal Sprint 11 architecture for parent identity, authenticated entitlements, parent-managed payments, and promo-code grants. It stays architecture-first. It does not implement Firebase Auth, new backend ownership routes, cloud sync, or new commerce UI beyond the currently approved parent-managed surfaces.

Primary code and docs inspected:
- `ios/StoryTime/App/StoryTimeApp.swift`
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Networking/APIClient.swift`
- `backend/src/app.ts`
- `backend/src/lib/auth.ts`
- `backend/src/lib/security.ts`
- `backend/src/lib/entitlements.ts`
- `docs/verification/launch-candidate-acceptance-report.md`
- `docs/monetization-entitlement-architecture.md`
- `docs/paywall-upgrade-entry-strategy.md`
- `docs/onboarding-first-run-audit.md`
- `docs/privacy-data-flow-audit.md`
- `AuditUpdated.md`

## Commands Executed

No new automated tests were run in this milestone.

This was a repo-grounded planning pass based on the current launch-ready MVP baseline, active code seams, and existing verification artifacts.

## Current Repo Baseline

- VERIFIED BY CODE INSPECTION: `StoryTimeApp` configures `FirebaseCore`, and the iOS project already includes Firebase bootstrap configuration.
- VERIFIED BY CODE INSPECTION: the active app does not yet use Firebase Auth, a parent account session model, or a signed-in parent state in any active flow.
- VERIFIED BY CODE INSPECTION: parent-managed product controls already live in `ParentTrustCenterView`, reached through the lightweight local `PARENT` access gate in `HomeView`.
- VERIFIED BY CODE INSPECTION: blocked launch recovery already routes through parent-managed review surfaces in `NewStoryJourneyView` and `StorySeriesDetailView`.
- VERIFIED BY CODE INSPECTION: `VoiceSessionView` remains free of sign-in and purchase UI and should stay that way in Sprint 11.
- VERIFIED BY CODE INSPECTION: `APIClient` still bootstraps install/session identity through `/v1/session/identity` and still sends install-scoped headers such as `x-storytime-install-id`, `x-storytime-session`, and `x-storytime-entitlement`.
- VERIFIED BY CODE INSPECTION: backend request context, auth, and entitlement verification are still install-bound today; the active backend has no authenticated parent-user ownership model.
- VERIFIED BY CODE INSPECTION: purchase completion, restore, entitlement sync, and preflight already exist in parent-managed MVP form, but ownership is still tied to install-scoped entitlement state rather than an authenticated parent account.
- VERIFIED BY CODE INSPECTION: saved stories, story history, and continuity remain local to the device. There is no current cloud sync or cross-device story portability model.
- VERIFIED BY TEST: `docs/verification/launch-candidate-acceptance-report.md` records StoryTime as `READY FOR MVP LAUNCH` after the March 20, 2026 rerun, including parent-managed purchase closure and blocked-to-unblocked recovery under the install-bound entitlement model.

## Architecture Goals For Sprint 11

- VERIFIED BY CODE INSPECTION: add real parent identity without turning the child storytelling flow into a sign-in-first experience.
- VERIFIED BY CODE INSPECTION: move entitlement ownership from install-bound assumptions toward authenticated parent ownership while preserving the current runtime bootstrap and preflight safety model.
- VERIFIED BY CODE INSPECTION: keep purchase initiation, completion, restore, and promo redemption inside parent-managed surfaces only.
- VERIFIED BY CODE INSPECTION: keep identity, payment truth, and entitlement enforcement as separate but connected systems.
- VERIFIED BY CODE INSPECTION: keep story history and continuity local-only for this sprint unless a later milestone explicitly broadens scope and updates persistence plus privacy docs.

## Locked Sprint 11 Decisions

### 1. Parent identity is a new layer, not a silent replacement for runtime session bootstrap

- VERIFIED BY CODE INSPECTION: install/session bootstrap is already wired through `APIClient`, backend request context, and realtime startup, so replacing it wholesale would widen risk beyond this sprint.
- Decision:
  - parent identity is introduced as a separate authenticated layer on top of the existing install/session runtime plumbing
  - install/session tokens remain the runtime transport and request-correlation mechanism for the active app architecture
  - authenticated parent identity is added alongside that layer for account-owned routes and entitlement ownership

Practical implication:
- Sprint 11 should add parent-authenticated state without forcing `VoiceSessionView`, realtime startup, or existing child session routes to become account-bootstrap flows.

### 2. First auth methods in scope are narrow and parent-appropriate

- VERIFIED BY CODE INSPECTION: there is no current account UI, so the first scope must stay intentionally small.
- Decision:
  - first auth methods in scope are `email/password` and `Sign in with Apple`
  - Google sign-in, phone auth, child identity, and broader family account roles are deferred

Reason:
- `email/password` provides a simple cross-device baseline.
- `Sign in with Apple` is parent-appropriate for iOS and keeps Sprint 11 aligned with the platform.
- Deferring other methods keeps the implementation small enough for milestone-sized execution.

### 3. Parent-managed surfaces own account, payment, restore, and promo actions

- VERIFIED BY CODE INSPECTION: `ParentTrustCenterView` is already the durable parent-managed management surface.
- VERIFIED BY CODE INSPECTION: blocked review flows in `NewStoryJourneyView` and `StorySeriesDetailView` already route to parent-managed surfaces before entering the child runtime.
- Decision:
  - account creation, sign-in, sign-out, purchase management, restore, and promo redemption live in onboarding-adjacent parent flow and `ParentTrustCenterView`
  - blocked launch review may ask the parent to continue to account or plan management, but it does not host the full auth or purchase flow itself
  - `VoiceSessionView`, live interruption handling, and other child-session surfaces remain auth-free and purchase-free

### 4. Identity, payment truth, and entitlement enforcement stay separate

- VERIFIED BY CODE INSPECTION: the existing monetization architecture already separates StoreKit purchase truth from backend entitlement enforcement truth.
- Decision:
  - parent identity truth: Firebase Auth user
  - payment truth: StoreKit transaction state on device
  - entitlement enforcement truth: backend-owned entitlement record and signed snapshot tied to the authenticated parent user

Required system relationship:
- Firebase Auth identifies which parent account owns a purchase or promo grant.
- StoreKit proves that a paid plan exists on the current device account.
- The backend decides what premium entitlement record is active for the authenticated parent and what signed snapshot the app should use for preflight and management surfaces.

### 5. Authenticated entitlement ownership becomes explicit

- VERIFIED BY CODE INSPECTION: install-bound entitlement tokens were sufficient for the launch-ready MVP, but they are not enough for an account-backed product foundation.
- Decision:
  - Sprint 11 moves entitlement ownership to an authenticated parent user record on the backend
  - the backend should keep ownership separate from source
  - `EntitlementSnapshot.source` should describe grant origin, not account ownership

Recommended source values after Sprint 11:
- `storekit_verified`
- `promo_grant`
- `none`
- `debug_seed` only where the existing debug/test path still explicitly needs it

Recommended ownership model:
- authenticated parent user ID owns the entitlement record
- source explains why premium is active
- signed entitlement snapshot remains the client-facing enforcement payload

### 6. Promo grants are explicit, bounded, and distinguishable from paid premium

- VERIFIED BY CODE INSPECTION: the repo has no current promo-code grant path, so the first shape should stay narrow and testable.
- Decision:
  - promo redemption requires an authenticated parent account
  - promo redemption happens in a parent-managed surface only
  - promo grants create or update a backend entitlement record with source `promo_grant`
  - the default Sprint 11 rule is one-time bounded code redemption, not renewable subscriptions or open-ended admin toggles

Deferred unless later evidence requires it:
- reusable family codes
- renewable promo plans
- broad admin consoles

### 7. Story history and continuity remain local-only in Sprint 11

- VERIFIED BY CODE INSPECTION: the active product and privacy model still describe saved history and continuity as local-on-device behavior.
- Decision:
  - signed-in parent identity does not automatically imply cloud sync
  - story history, continuity, and child profile history remain local-only this sprint
  - authenticated entitlement ownership and purchase portability may expand across devices later, but local saved-story portability is explicitly deferred

Reason:
- this keeps the sprint focused on account-backed access and entitlement correctness instead of widening into persistence, sync, and privacy migration work.

## Minimal User Journey Direction

### First-run and onboarding

- VERIFIED BY CODE INSPECTION: onboarding is already parent-led and is the right place to explain that a parent can create an account before managing premium access.
- Direction:
  - onboarding may include a parent account entry point or soft sign-in invitation
  - onboarding should not hard-block the first child story behind sign-in
  - onboarding may route parents to account setup before they buy, restore, or redeem a code

### Home and blocked review surfaces

- VERIFIED BY CODE INSPECTION: `HomeView`, `NewStoryJourneyView`, and `StorySeriesDetailView` already preserve the parent trust boundary by routing plan work into parent-managed surfaces.
- Direction:
  - blocked review continues to explain the specific premium action that is unavailable
  - if account state is required for purchase, restore, or promo redemption, the parent-managed review path should route into account-capable parent controls
  - child launch surfaces should not become general sign-in forms

### Parent trust surface

- VERIFIED BY CODE INSPECTION: `ParentTrustCenterView` is the right durable home for:
  - account status
  - sign-in and sign-out
  - current plan state
  - purchase and restore
  - promo redemption
  - trust and privacy settings

## Backend Alignment Direction

- VERIFIED BY CODE INSPECTION: backend request context and auth already have clear seams for adding authenticated parent identity.
- Direction:
  - add verified Firebase-authenticated parent identity on account-owned routes
  - keep install/session runtime identity available for existing startup and route correlation
  - move entitlement ownership lookup, purchase sync ownership, restore ownership, and promo-grant ownership to the authenticated parent user

Recommended backend split:
- install/session context:
  - request correlation
  - current-device bootstrap
  - active runtime request safety
- authenticated parent context:
  - entitlement ownership
  - promo redemption authority
  - account-linked purchase or restore state

## Explicit Deferrals

- VERIFIED BY CODE INSPECTION: the following are intentionally out of Sprint 11 scope unless a later milestone explicitly adds them:
  - cloud sync for saved stories or continuity
  - cross-device story-history portability
  - broader auth-provider matrix beyond `email/password` and `Sign in with Apple`
  - child accounts or child sign-in
  - family-role systems beyond one authenticated parent account owner
  - web admin or back-office promo tooling beyond the smallest repo-backed promo flow needed for this sprint

## Open Decisions That Stay For Later Milestones

- PARTIALLY VERIFIED: restore conflict handling still needs one implementation rule when StoreKit ownership, the currently signed-in parent account, and the local device state disagree.
- PARTIALLY VERIFIED: the exact backend persistence shape for parent entitlement records still belongs to implementation, but ownership must be parent-account-based and source-aware.
- PARTIALLY VERIFIED: the final parent-facing copy for account-required purchase versus promo-required sign-in still belongs to UI implementation milestones.

## Alignment Outcome

- VERIFIED BY CODE INSPECTION: Sprint 11 now has a repo-grounded architecture that preserves the launch-ready child flow while adding a clear parent-account foundation.
- VERIFIED BY CODE INSPECTION: parent identity, payment truth, and backend entitlement ownership are now explicitly separated instead of being implied or collapsed into one system.
- VERIFIED BY CODE INSPECTION: promo grants are locked as parent-only, authenticated, bounded, and distinguishable from paid premium.
- VERIFIED BY CODE INSPECTION: story history and continuity remain local-only in this sprint.
- UNVERIFIED: the concrete Firebase Auth implementation, backend ownership routes, and authenticated restore behavior because those belong to later Sprint 11 implementation milestones.

## Recommended Next Milestone

`M11.2 - Firebase Auth integration for parent identity`

Reason:
- `M11.1` now locks the minimum architecture and the parent-managed boundary rules.
- The next step is to add the Firebase Auth foundation seam without yet widening into full account UI or backend ownership migration.
