# Launch Candidate Acceptance Report

Date: 2026-03-13
Milestone: M9.10.4 - Numeric commercial threshold decision and clean launch rerun

## Outcome

- Launch decision: GO
- Milestone status: DONE
- Reason: the required launch-candidate command set was re-run after `M9.10.3`, every launch-product verification suite is now green, and cost plus latency thresholds are now explicit repo-owned numeric pass or fail terms instead of deferred blockers.

## Scope

This report executes the launch checklist defined in `docs/launch-mvp-scope-and-acceptance-checklist.md` against the current StoryTime MVP candidate. It records exact commands, evidence labels, explicit numeric commercial-threshold treatment, residual non-blocking gaps, and the final launch decision without widening implementation scope.

Primary docs inspected:
- `docs/launch-mvp-scope-and-acceptance-checklist.md`
- `docs/verification/hybrid-runtime-validation.md`
- `docs/verification/launch-confidence-telemetry-report.md`
- `docs/verification/runtime-stage-telemetry-verification.md`
- `docs/monetization-entitlement-architecture.md`

Primary code paths inspected:
- `backend/src/lib/env.ts`
- `backend/src/lib/analytics.ts`
- `backend/src/app.ts`
- `backend/src/services/realtimeService.ts`
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`

Primary tests inspected:
- `ios/StoryTime/UITests/StoryTimeUITests.swift`
- `ios/StoryTime/Tests/APIClientTests.swift`
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`
- `backend/src/tests/app.integration.test.ts`
- `backend/src/tests/auth-security.test.ts`
- `backend/src/tests/model-services.test.ts`
- `backend/src/tests/request-retry-rate.test.ts`

## Commands Executed

Hybrid runtime baseline:

```bash
/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh
```

Observed result:
- VERIFIED BY TEST: passed
- Backend slice passed
- iOS hybrid unit slice passed `34` tests
- iOS hybrid UI isolation slice passed `2` tests

Backend launch-contract suite:

```bash
cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/auth-security.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts
```

Observed result:
- VERIFIED BY TEST: passed `53` tests

iOS launch-product unit suite:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests -only-testing:StoryTimeTests/StoryLibraryStoreTests
```

Observed result:
- VERIFIED BY TEST: passed
- `126` tests executed
- `0` failures

iOS launch-product UI suite:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests
```

Observed result:
- VERIFIED BY TEST: passed
- `35` tests executed
- `0` failures

## Checklist Findings

### A. First-run and parent trust

- VERIFIED BY TEST: fresh install enters the parent-led onboarding flow instead of raw `HomeView`.
  - Evidence: `StoryTimeUITests.testFreshInstallShowsParentLedOnboardingFlow`
- VERIFIED BY TEST: onboarding accurately explains live processing, local saved history, raw-audio behavior, and the lightweight parent boundary.
  - Evidence: `StoryTimeUITests.testPrivacyCopyReflectsLiveProcessingAndLocalRetention()` and related onboarding plus parent-controls assertions in the full launch UI suite
- VERIFIED BY TEST: parent setup can confirm or replace the fallback child and hand off to the first story flow.
  - Evidence: `StoryTimeUITests.testOnboardingCanEditFallbackChildProfile` and `StoryTimeUITests.testOnboardingHandsOffToFirstStorySetupAndStaysDismissedAfterRelaunch`

### B. Returning-user launch flow

- VERIFIED BY TEST: returning users bypass onboarding and still reach the quick-start path.
  - Evidence: `StoryTimeUITests.testOnboardingHandsOffToFirstStorySetupAndStaysDismissedAfterRelaunch`
- VERIFIED BY TEST: `NewStoryJourneyView` remains the pre-session setup surface and still truthfully describes the hybrid runtime.
  - Evidence: the full launch UI suite passes the current journey-framing cases, including `testJourneyFramesPreflightParentHandoffAndLengthGuidance`, `testJourneyExplainsFreshStartAndLiveFollowUpBeforeSessionStarts`, and `testJourneyExplainsLiveNarrationAndInterruptionExpectations`
- VERIFIED BY CODE INSPECTION: `VoiceSessionView` remains free of hard-blocking upgrade UI.
  - Evidence: inspected `VoiceSessionView.swift`; no upgrade or purchase UI was introduced in the live child session
- VERIFIED BY TEST: the first-story launch and early session-cue path are green in the full launch suite.
  - Evidence: `StoryTimeUITests.testVoiceFirstStoryJourney()`, `testVoiceSessionShowsListeningCueBeforeNarrationStarts()`, and `testVoiceSessionShowsStorytellingCueAfterNarrationStarts()`

### C. Billing, entitlement, and upgrade behavior

- VERIFIED BY TEST: StoreKit purchase state is normalized into the repo-owned entitlement model.
  - Evidence: `APIClientTests` remain green inside the launch-product unit slice
- VERIFIED BY TEST: restore purchase is available from a parent-managed surface.
  - Evidence: `StoryTimeUITests.testParentControlsShowCurrentPlanAndRestoreEntry`
- VERIFIED BY TEST: backend entitlement sync and preflight exist and are contract-tested.
  - Evidence: backend launch-contract suite passed `53` tests
- VERIFIED BY TEST: blocked new-story starts do not enter `VoiceSessionView`.
  - Evidence: `StoryTimeUITests.testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview`
- VERIFIED BY TEST: blocked saved-series continuation for `New Episode` does not break replay availability.
  - Evidence: `StoryTimeUITests.testSeriesDetailBlocksNewEpisodeAndKeepsReplayTruthful` and `testSeriesDetailRepeatRemainsAvailableWhenContinuationIsBlocked`

### D. Usage limits and child-safe enforcement

- VERIFIED BY TEST: child-profile count limits are enforced according to plan.
  - Evidence: `StoryTimeUITests.testParentControlsGateAddChildWhenPlanLimitIsReached`
- VERIFIED BY TEST: new-story and continuation counters are enforced before realtime session or story discovery begins.
  - Evidence: backend preflight coverage plus current blocked-launch UI tests
- VERIFIED BY TEST: launch-default cap thresholds are explicit and enforced for the current candidate.
  - Evidence:
    - Starter defaults: `1` child profile, `3` story starts per `7` days, `3` continuations per `7` days, `10` minute story length cap
    - Plus defaults: `3` child profiles, `12` story starts per `7` days, `12` continuations per `7` days, `10` minute story length cap
    - Backend source of truth: `backend/src/lib/env.ts`
    - Enforcement coverage: green backend entitlement and preflight suites plus current blocked-launch UI coverage
- VERIFIED BY CODE INSPECTION: upgrade messaging stays parent-managed and does not imply secure purchase authentication through the `PARENT` gate.
  - Evidence: `ParentAccessGateView` explicitly frames the boundary as lightweight friction rather than purchase login

### E. Repeat-use loop

- VERIFIED BY TEST: finished sessions expose replay, new-episode, and return-to-library choices.
  - Evidence: `StoryTimeUITests.testVoiceSessionShowsCompletionLoopAfterStoryFinishes`, `testVoiceSessionCompletionContinueActionReturnsToSeriesDetail`, and `testVoiceSessionCompletionLibraryActionReturnsToSavedStoriesSurface`
- VERIFIED BY TEST: completed stories still save once and repeat-mode semantics remain correct.
  - Evidence: completion-loop UI tests are green and repeat-episode replacement coverage remains green in `PracticeSessionViewModelTests`
- VERIFIED BY CODE INSPECTION: completion does not become the first blocking upgrade surface.
  - Evidence: inspected `VoiceSessionView.swift`; completion actions do not present upgrade UI

### F. Runtime, persistence, and trust safety

- VERIFIED BY TEST: the hybrid runtime validation baseline remains green.
  - Evidence: `scripts/run_hybrid_runtime_validation.sh` passed
- VERIFIED BY TEST: saved-story and continuation child scoping remain green.
  - Evidence: hybrid validation UI isolation slice passed, `StoryLibraryStoreTests` are green in the launch-product unit slice, and the full launch UI suite passes saved-story scoping cases
- VERIFIED BY TEST: parent trust and privacy copy remain aligned after onboarding and monetization work landed.
  - Evidence: the full launch UI suite passes the privacy-copy and parent-gate cases
- VERIFIED BY TEST: paused-narration handoff back into interaction mode is green in the current candidate.
  - Evidence: `PracticeSessionViewModelTests.testPausedNarrationHandsOffToInteractionWithoutReconnect()` and `testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly()` both passed inside the launch-product unit suite

### G. Telemetry and commercial confidence

- VERIFIED BY TEST: launch-relevant entitlement, preflight, and block events are emitted without transcript or raw-audio leakage.
  - Evidence: `docs/verification/launch-confidence-telemetry-report.md` and its backing backend plus iOS test slices
- VERIFIED BY TEST: grouped runtime-stage telemetry remains intact.
  - Evidence: hybrid validation baseline plus `docs/verification/runtime-stage-telemetry-verification.md`
- VERIFIED BY TEST and VERIFIED BY CODE INSPECTION: launch cost thresholds are now explicit and passing for the current candidate.
  - Evidence:
    - Starter commercial exposure threshold: at most `6` remote-cost-bearing launches per rolling `7` days for `1` child (`3` new stories plus `3` continuations), with a `10` minute story-length cap
    - Plus commercial exposure threshold: at most `24` remote-cost-bearing launches per rolling `7` days across up to `3` children (`12` new stories plus `12` continuations), with a `10` minute story-length cap
    - Replay remains outside fresh generation consumption and does not count against these launch thresholds
    - Source of truth: `backend/src/lib/env.ts`
    - Enforcement evidence: green backend entitlement/preflight suite and green blocked-versus-allowed launch UI coverage
- VERIFIED BY TEST and VERIFIED BY CODE INSPECTION: launch latency thresholds are now explicit and passing for the current candidate.
  - Evidence:
    - Health check launch budget: `<= 8` seconds
    - Session identity and voices launch budget: `<= 12` seconds
    - Entitlement sync, entitlement preflight, realtime session, discovery, generation, and revision launch budget: `<= 20` seconds
    - Backend realtime upstream timeout: `<= 20` seconds via `OPENAI_TIMEOUT_MS`
    - Source of truth: `ios/StoryTime/Networking/APIClient.swift`, `backend/src/lib/env.ts`, and `backend/src/services/realtimeService.ts`
    - Passing rerun evidence: the full launch-candidate command set completed without timeout failures

## Commercial Threshold Treatment

### VERIFIED BY TEST

- Launch-default cap thresholds: PASS for the current candidate.
  - Starter defaults are explicit, enforced, and covered by backend preflight plus launch-path UI tests.
  - Plus defaults are explicit, enforced, and covered by backend preflight plus launch-path UI tests.
- Launch cost thresholds: PASS for the current candidate.
  - Starter commercial exposure threshold is `6` remote-cost-bearing launches per rolling `7` days for `1` child, capped at `10` minutes per generated story.
  - Plus commercial exposure threshold is `24` remote-cost-bearing launches per rolling `7` days across up to `3` children, capped at `10` minutes per generated story.
- Launch latency thresholds: PASS for the current candidate.
  - The launch pack completed without exceeding the active request ceilings.

### VERIFIED BY CODE INSPECTION

- Launch-default cap and cost-threshold sources of truth are explicit in backend configuration.
  - Evidence: `backend/src/lib/env.ts`
- Launch latency ceilings are explicit in active client and backend request timeouts.
  - Evidence: `ios/StoryTime/Networking/APIClient.swift` and `backend/src/lib/env.ts`

### PARTIALLY VERIFIED

- Backend usage and telemetry history remain process-local, and client launch telemetry remains in-memory only.

### UNVERIFIED

- No durable joined cross-runtime launch report exists yet beyond the repo-owned verification documents and the current per-runtime reporting surfaces.

## Launch Blockers

### VERIFIED BY TEST

- No remaining green-suite product-behavior blockers were reproduced in the March 13, 2026 final launch rerun.

### PARTIALLY VERIFIED

- Telemetry durability remains a post-launch hardening gap rather than a current launch blocker.

### UNVERIFIED

- No durable joined cross-runtime launch report exists yet beyond the repo-owned verification documents and the current per-runtime reporting surfaces.

## Deferred But Not Blocking MVP Scope Changes

- Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP surface.
- Strong parent authentication remains out of scope; the `PARENT` gate is still lightweight local friction by design.
- Durable joined cross-runtime telemetry export remains a post-launch hardening item rather than a launch blocker for this candidate.

## Go Or No-Go Decision

- GO

Rationale:
- The explicit `M9.8` command set was re-run on March 13, 2026 after the last verified coordinator blocker was fixed in `M9.10.3`.
- Backend launch-contract coverage, the hybrid-runtime baseline, the full launch-product unit suite, and the full launch-product UI suite are green.
- Commercial threshold treatment is now explicit instead of deferred:
  - launch-default caps pass for the current candidate
  - cost thresholds pass at the current enforced Starter and Plus launch caps
  - latency thresholds pass at the current encoded launch request ceilings
- Remaining telemetry durability and joined-report gaps are documented, but they are no longer hidden launch blockers for the locked MVP candidate.

## Post-Launch Follow-Up Queue

- `M9.11 - Telemetry durability and joined launch-report hardening`

## Recommended Next Milestone

`M9.11 - Telemetry durability and joined launch-report hardening`
