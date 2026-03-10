# Launch MVP Scope Lock And Acceptance Checklist

Date: 2026-03-10
Milestone: M9.1 - Launch scope lock and MVP acceptance checklist

## Scope

This document locks the StoryTime MVP launch scope after the completed M8 groundwork. It defines:
- what the launch candidate must include
- what is explicitly out of scope for MVP
- the narrowed launch decisions that later implementation milestones should treat as fixed
- the acceptance checklist and command set that the launch-candidate pass must satisfy

This milestone is planning-only. It does not implement onboarding, StoreKit, entitlements, paywalls, usage enforcement, or completion-loop UI.

## Primary Repo Evidence Inspected

Primary code paths:
- `ios/StoryTime/App/StoryTimeApp.swift`
- `ios/StoryTime/App/ContentView.swift`
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
- `ios/StoryTime/Storage/StoryLibraryStore.swift`
- `backend/src/app.ts`
- `scripts/run_hybrid_runtime_validation.sh`

Primary tests and verification artifacts:
- `ios/StoryTime/UITests/StoryTimeUITests.swift`
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`
- `ios/StoryTime/Tests/APIClientTests.swift`
- `docs/onboarding-first-run-audit.md`
- `docs/monetization-entitlement-architecture.md`
- `docs/paywall-upgrade-entry-strategy.md`
- `docs/end-of-story-repeat-use-loop.md`
- `docs/verification/hybrid-runtime-validation.md`
- `docs/verification/runtime-stage-telemetry-verification.md`
- `docs/verification/parent-child-storytelling-ux-audit.md`
- `PLANS.md`
- `SPRINT.md`
- `AuditUpdated.md`

## Commands Executed

No new test commands were run in this milestone.

This was a planning pass grounded in repo inspection of the active launch surfaces, current test inventory, current verification artifacts, and the completed M8 direction docs.

## Current Launch Baseline

- VERIFIED BY CODE INSPECTION: `StoryTimeApp` still boots directly into `ContentView`, which renders `HomeView` immediately.
- VERIFIED BY CODE INSPECTION: the active child flow remains `HomeView` -> `NewStoryJourneyView` -> `VoiceSessionView` -> `PracticeSessionViewModel`.
- VERIFIED BY CODE INSPECTION: the active saved-story continuation flow remains `HomeView` -> `StorySeriesDetailView` -> `Repeat` or `New Episode`.
- VERIFIED BY CODE INSPECTION: the active runtime architecture remains hybrid:
  - realtime for live interaction
  - TTS for long-form narration
  - story and scene state as the authority layer
- VERIFIED BY CODE INSPECTION: there is still no onboarding container, StoreKit layer, entitlement sync, usage-limit enforcement, paywall UI, or completion-loop implementation in the active repo.
- VERIFIED BY CODE INSPECTION: the backend currently exposes session bootstrap, realtime, discovery, generation, revision, moderation, and embeddings routes, but no entitlement routes yet.
- VERIFIED BY TEST: the current repo already has strong evidence for hybrid runtime determinism, parent gate behavior, saved-story child scoping, launch-plan copy, live-session cueing, privacy copy alignment, and saved-story management.
- PARTIALLY VERIFIED: runtime-stage telemetry exists and is grouped by `interaction`, `generation`, `narration`, and `revision`, but the repo still lacks a joined per-session cost export and launch-threshold interpretation.
- PARTIALLY VERIFIED: the current acceptance pack is runtime-focused and explicitly excludes broader onboarding, purchase, entitlement, paywall, and launch-product QA coverage.

## MVP Scope Lock

### In Scope For MVP Launch

#### 1. Core product architecture stays fixed

- VERIFIED BY CODE INSPECTION: launch work must keep:
  - realtime for live interaction
  - TTS for long-form narration
  - `PracticeSessionViewModel` as the client session coordinator
  - story and scene state as the authority boundary
- VERIFIED BY CODE INSPECTION: launch readiness does not reopen the hybrid runtime architecture unless a new defect is reproduced.

#### 2. Parent-led first-run onboarding

- VERIFIED BY CODE INSPECTION: MVP launch must include an explicit first-run flow layered above the current app entry.
- REQUIRED product outcome:
  - parent welcome and product promise
  - trust and privacy framing
  - child setup or fallback-child confirmation
  - first-session expectation setting
  - clear handoff into the first story setup flow

#### 3. Single-device product scope

- VERIFIED BY CODE INSPECTION: MVP launch remains a single-device, local-history product.
- REQUIRED product outcome:
  - saved stories remain local on device
  - continuity remains local on device after save
  - no account system or multi-device sync is introduced

#### 4. Monetization model

- VERIFIED BY CODE INSPECTION: MVP launch is locked to two tiers:
  - `Starter`
  - `Plus`
- VERIFIED BY CODE INSPECTION: the product boundary stays capability-based, not screen-based.
- REQUIRED product outcome:
  - `Starter` includes replay of already-saved stories, parent controls, privacy controls, and one-child-family scope
  - `Starter` uses capped remote-cost actions for new-story starts and saved-series continuation starts
  - `Plus` expands child-profile count and remote-cost usage allowance

#### 5. Billing and entitlement ownership

- VERIFIED BY CODE INSPECTION: purchase truth is locked to StoreKit 2 on device.
- VERIFIED BY CODE INSPECTION: runtime enforcement truth is locked to a backend-issued entitlement snapshot or equivalent backend-owned preflight decision.
- REQUIRED implementation shape:
  - client normalizes StoreKit purchase state into a repo-owned entitlement model
  - backend verifies or accepts that state and returns a short-lived enforcement snapshot
  - cost-bearing launch paths consume backend preflight before session boot

#### 6. Approved upgrade surfaces

- VERIFIED BY CODE INSPECTION: the approved parent-managed upgrade hierarchy is locked for MVP:
  1. `NewStoryJourneyView` as the primary hard gate for new-story starts
  2. `StorySeriesDetailView` as the continuation gate for `New Episode`
  3. `ParentTrustCenterView` as the durable subscription and restore surface
  4. `HomeView` as optional soft plan awareness only
- VERIFIED BY CODE INSPECTION: `VoiceSessionView`, interruption flows, and active narration remain upgrade-free for hard blocking behavior.

#### 7. Usage-limit enforcement model

- VERIFIED BY CODE INSPECTION: MVP enforcement must happen before realtime startup, discovery, or continuation cost is incurred.
- LOCKED product rules:
  - new-story starts and saved-series continuations are separate counters
  - replay of already-saved stories remains available even when paid counters are exhausted
  - privacy controls, deletion controls, and trust surfaces are never monetized
  - child-profile count is part of plan enforcement

#### 8. End-of-story repeat-use loop

- VERIFIED BY CODE INSPECTION: MVP launch must include the completion-loop bridge that the repo currently lacks.
- REQUIRED product outcome:
  - completion acknowledgement in the finished-session surface
  - replay action
  - new-episode continuation action
  - return-to-library or home action
- VERIFIED BY CODE INSPECTION: completion must remain non-transactional; any later upgrade handling targets the continuation path, not a finished story acknowledgement.

#### 9. Launch telemetry and acceptance evidence

- VERIFIED BY CODE INSPECTION: MVP launch must ship with telemetry and acceptance evidence that cover:
  - entitlement sync and preflight outcomes
  - usage-blocked launch attempts
  - upgrade-surface presentation
  - continuation versus replay routing
  - grouped runtime stage cost and latency behavior
- VERIFIED BY CODE INSPECTION: launch readiness is not complete without an explicit launch-candidate report and command set.

## Explicit MVP Exclusions

- VERIFIED BY CODE INSPECTION: no account system or cloud sync
- VERIFIED BY CODE INSPECTION: no multi-device entitlement portability beyond what StoreKit and the backend snapshot naturally support
- VERIFIED BY CODE INSPECTION: no child-facing purchase CTA or mid-session paywall
- VERIFIED BY CODE INSPECTION: no blocking upgrade UI inside `VoiceSessionView`, interruption handling, or live narration
- VERIFIED BY CODE INSPECTION: no narration-minute pricing or user-facing “minutes remaining” promise in MVP
- VERIFIED BY CODE INSPECTION: no “unlimited” plan promise in copy or logic unless later telemetry proves it and the sprint is updated explicitly
- VERIFIED BY CODE INSPECTION: no raw audio persistence, raw audio telemetry, or trust-copy regression around raw audio
- VERIFIED BY CODE INSPECTION: no stronger parent authentication system in MVP; the existing `PARENT` gate remains lightweight friction and must not be described as secure purchase authentication
- VERIFIED BY CODE INSPECTION: no speculative post-launch growth features, marketing funnel work, social sharing, or acquisition surfaces

## Narrowed Launch Decisions

### Locked decisions

- VERIFIED BY CODE INSPECTION: launch is a two-tier product, not a wider package matrix.
- VERIFIED BY CODE INSPECTION: StoreKit 2 plus backend preflight is the locked ownership model for billing and entitlement.
- VERIFIED BY CODE INSPECTION: hard gates belong before runtime cost is incurred, primarily in `NewStoryJourneyView` and `StorySeriesDetailView`.
- VERIFIED BY CODE INSPECTION: replay remains outside paid exhaustion gates.
- VERIFIED BY CODE INSPECTION: `HomeView` soft plan state is optional for MVP; it is not required if it creates execution risk, as long as the primary parent-managed upgrade surfaces exist.
- VERIFIED BY CODE INSPECTION: onboarding may include soft plan framing or restore access, but not a first-screen hard paywall.

### Narrowed but not yet numerically fixed

- PARTIALLY VERIFIED: exact numeric launch defaults for `Starter` and `Plus` counters are still not evidenced well enough to hardcode into this milestone because the repo still lacks joined commercial-confidence telemetry.
- LOCKED implementation rule:
  - `M9.3` and `M9.5` must implement usage counters as configuration-backed values, not scattered UI literals
  - `M9.4` copy must avoid claiming exact quota numbers until those values are finalized in the implementation path
  - `M9.5` cannot be marked done until the launch defaults are chosen and wired into enforcement

### Remaining implementation-choice details that do not reopen scope

- PARTIALLY VERIFIED: whether the entitlement summary is returned from `/v1/session/identity` or an adjacent bootstrap route remains an implementation detail for `M9.3`.
- PARTIALLY VERIFIED: whether the onboarding container is a full-screen cover or embedded layered flow above `HomeView` remains an implementation detail for `M9.2`.
- PARTIALLY VERIFIED: whether `HomeView` ships a soft plan summary in MVP remains optional if `M9.4` determines it is non-essential for safe launch scope.

## MVP Launch-Ready Definition

StoryTime is MVP-launch-ready only when all of the following are true:

- onboarding exists and first-run users no longer infer setup from the returning-user home surface
- returning users can still reach the existing quick-start path without onboarding regression
- StoreKit purchase state, restore flow, and backend entitlement sync are implemented and test-covered
- new-story and continuation preflight enforcement happens before `VoiceSessionView` starts
- replay remains available when continuation or new-start limits are exhausted
- approved parent-managed upgrade surfaces are implemented and child-safe
- the completion loop exposes replay, continuation, and return-to-library behavior
- existing hybrid-runtime acceptance still passes
- launch-specific UI, unit, and backend suites pass
- launch telemetry and commercial-confidence evidence are recorded
- the launch-candidate report contains no unresolved blocker that contradicts the locked MVP scope

## Launch Acceptance Checklist

Each item below is the required evidence target for `M9.8`.

### A. First-run and parent trust

- Fresh install enters the parent-led onboarding flow instead of raw `HomeView`.
  - Current status: UNVERIFIED
- Onboarding accurately explains live processing, local saved history, raw-audio behavior, and the lightweight parent boundary.
  - Current status: PARTIALLY VERIFIED
  - Repo basis: truthfulness already exists across current surfaces, but onboarding is not implemented.
- Parent setup can confirm or replace the fallback child and hand off to the first story flow.
  - Current status: UNVERIFIED

### B. Returning-user launch flow

- Returning users bypass onboarding and still reach the quick-start path from `HomeView`.
  - Current status: UNVERIFIED
- `NewStoryJourneyView` remains the pre-session setup surface and still truthfully describes the hybrid runtime.
  - Current status: VERIFIED BY TEST
- `VoiceSessionView` remains free of hard-blocking upgrade UI.
  - Current status: VERIFIED BY CODE INSPECTION

### C. Billing, entitlement, and upgrade behavior

- StoreKit purchase state is normalized into the repo-owned entitlement model.
  - Current status: UNVERIFIED
- Restore purchase is available from a parent-managed surface.
  - Current status: UNVERIFIED
- Backend entitlement sync and preflight exist and are contract-tested.
  - Current status: UNVERIFIED
- Blocked new-story starts do not enter `VoiceSessionView`.
  - Current status: UNVERIFIED
- Blocked saved-series continuation for `New Episode` does not break replay availability.
  - Current status: UNVERIFIED

### D. Usage limits and child-safe enforcement

- Child-profile count limits are enforced according to plan.
  - Current status: UNVERIFIED
- New-story and continuation counters are enforced before realtime session or story discovery begins.
  - Current status: UNVERIFIED
- Upgrade messaging stays parent-managed and does not imply secure purchase authentication through the `PARENT` gate.
  - Current status: PARTIALLY VERIFIED
  - Repo basis: current trust copy is accurate, but upgrade flows are not implemented.

### E. Repeat-use loop

- Finished sessions expose replay, new-episode, and return-to-library choices.
  - Current status: UNVERIFIED
- Completed stories still save once and repeat-mode semantics remain correct.
  - Current status: VERIFIED BY TEST
- Completion does not become the first blocking upgrade surface.
  - Current status: PARTIALLY VERIFIED
  - Repo basis: locked by planning docs, not yet implemented.

### F. Runtime, persistence, and trust safety

- Hybrid runtime validation remains green.
  - Current status: VERIFIED BY TEST
- Saved-story and continuation child scoping remain green.
  - Current status: VERIFIED BY TEST
- Parent trust and privacy copy remain aligned after onboarding and monetization work land.
  - Current status: PARTIALLY VERIFIED
- Saved-story deletion, clear-history, and local continuity cleanup remain correct after launch work.
  - Current status: VERIFIED BY TEST

### G. Telemetry and commercial confidence

- Launch-relevant entitlement, preflight, and block events are emitted without transcript or raw-audio leakage.
  - Current status: UNVERIFIED
- Grouped runtime-stage telemetry remains intact for `interaction`, `generation`, `narration`, and `revision`.
  - Current status: VERIFIED BY TEST
- Launch review can inspect a joined enough view of cost, usage shape, and capped-session outcomes to judge commercial confidence.
  - Current status: UNVERIFIED

## Required Launch-Candidate Command Set

These commands are the minimum command set that `M9.8` must run and report.

### 1. Hybrid runtime baseline

```bash
/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh
```

Purpose:
- preserve the existing runtime gate while launch work lands

### 2. iOS launch-product UI suite

```bash
xcodebuild test \
  -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj \
  -scheme StoryTime \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:StoryTimeUITests
```

Purpose:
- cover onboarding, trust, launch gating, completion-loop, saved-story surfaces, and parent-managed upgrade flows once implemented

### 3. iOS launch-product unit suite

```bash
xcodebuild test \
  -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj \
  -scheme StoryTime \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:StoryTimeTests/APIClientTests \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests \
  -only-testing:StoryTimeTests/StoryLibraryStoreTests
```

Purpose:
- cover entitlement bootstrap or preflight handling, coordinator safety, completion semantics, and persistence or scoping regressions

### 4. Backend launch-contract suite

```bash
cd /Users/rory/Documents/StoryTime/backend && npm test -- --run \
  src/tests/app.integration.test.ts \
  src/tests/auth-security.test.ts \
  src/tests/model-services.test.ts \
  src/tests/request-retry-rate.test.ts
```

Purpose:
- cover auth, request context, entitlement-route integration once added, realtime and story-route behavior, and backend telemetry behavior

## Required Launch-Candidate Report Outputs

`M9.8` must produce a launch-candidate report that includes:
- exact commands run
- pass or fail outcome for each command
- checklist item status using:
  - `VERIFIED BY TEST`
  - `VERIFIED BY CODE INSPECTION`
  - `PARTIALLY VERIFIED`
  - `UNVERIFIED`
- blockers that prevent MVP launch
- any deferred item that remains outside locked MVP scope

## Outcome Of This Milestone

- VERIFIED BY CODE INSPECTION: MVP scope is now locked tightly enough for onboarding, entitlement, paywall, limit-enforcement, completion-loop, telemetry, and QA milestones to proceed without reopening the core launch plan.
- VERIFIED BY CODE INSPECTION: the parent-managed monetization and launch-readiness rules are now explicit enough to constrain later implementation work.
- PARTIALLY VERIFIED: exact numeric launch cap defaults remain intentionally configuration-backed rather than hardcoded by this milestone because the repo still lacks the final commercial-confidence telemetry needed to justify them.
- UNVERIFIED: the actual onboarding, entitlement, paywall, limit-enforcement, completion-loop, and launch-candidate behaviors because those belong to later M9 implementation milestones.

## Recommended Next Milestone

`M9.2 - Onboarding and first-run flow implementation`

Reason:
- The first-run direction is already documented, and `M9.1` now locks it into the MVP scope.
- Onboarding is the first missing launch-facing product system in the actual app entry path.
