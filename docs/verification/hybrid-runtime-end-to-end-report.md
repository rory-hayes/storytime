# Hybrid Runtime End-to-End Verification Report

Date: 2026-03-07
Milestone: M6.1 - Hybrid runtime end-to-end verification report

## Scope

This report verifies the active hybrid runtime end to end in repo terms. It is not a redesign milestone and it does not widen into the deeper interaction-path audit, telemetry follow-up, or acceptance-pack expansion planned for later milestones.

Primary code paths inspected:
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `ios/StoryTime/Models/StoryDomain.swift`
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Core/RealtimeVoiceClient.swift`
- `backend/src/app.ts`
- `backend/src/lib/analytics.ts`
- `backend/src/services/realtimeService.ts`
- `backend/src/services/storyDiscoveryService.ts`
- `backend/src/services/storyService.ts`
- `backend/src/services/storyContinuityService.ts`

Primary test and verification artifacts inspected:
- `scripts/run_hybrid_runtime_validation.sh`
- `docs/verification/hybrid-runtime-validation.md`
- `docs/verification/realtime-voice-determinism-report.md`
- `docs/verification/critical-path-verification.md`
- `docs/privacy-data-flow-audit.md`
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- `ios/StoryTime/Tests/APIClientTests.swift`
- `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`
- `ios/StoryTime/UITests/StoryTimeUITests.swift`
- `backend/src/tests/app.integration.test.ts`
- `backend/src/tests/model-services.test.ts`
- `backend/src/tests/request-retry-rate.test.ts`
- `backend/src/tests/types.test.ts`

## Commands Executed

Stable validation command:

```bash
/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh
```

Observed results from this run:
- backend slice: `39` tests passed
- iOS unit slice: `31` tests passed
- iOS UI child-isolation slice: `2` tests passed

## Runtime Summary

The active StoryTime runtime is now hybrid in the repo:
- realtime transport is used for startup, live interaction intake, and short spoken interaction responses
- long-form scene narration runs through the coordinator-owned TTS transport
- `PracticeSessionViewModel` remains the authority boundary for startup, discovery, generation, narration, interruption, revision, resume, completion, and persistence
- `StoryDomain.swift` exposes the typed hybrid runtime contract, interruption routing contract, scene authority model, and narration resume decisions

## Verification Findings

### 1. Startup and session bootstrap

- VERIFIED BY TEST: `scripts/run_hybrid_runtime_validation.sh` passed the backend contract slice plus the iOS startup regressions included in `PracticeSessionViewModelTests`, `APIClientTests`, and `RealtimeVoiceClientTests`.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testStartupHealthCheckFailureUsesSafeMessageAndCategory` and `PracticeSessionViewModelTests.testStartupDisconnectBeforeReadyFailsOnceAndLateConnectedDoesNotReviveSession` prove the active startup path fails safely and deterministically.
- VERIFIED BY CODE INSPECTION: `PracticeSessionViewModel.startSession()` still serializes health check, session bootstrap, voice fetch, realtime session creation, bridge connect, and launch-flow entry under one coordinator-owned boot path.
- PARTIALLY VERIFIED: real browser/WebRTC event ordering inside the hidden `WKWebView` bridge remains inferred from transport tests and prior realtime determinism audit rather than exercised by a live peer-connection harness.

### 2. Discovery to generation handoff

- VERIFIED BY TEST: the stable iOS hybrid slice still includes the coordinator lifecycle regression `PracticeSessionViewModelTests.testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation`, which exercises startup through discovery, generation, revision, resume, and completion.
- VERIFIED BY CODE INSPECTION: `handleDiscoveryResolved` only starts generation from the explicit ready-to-generate discovery result, and `handleGenerationResolved` only advances narration from the generating state.
- PARTIALLY VERIFIED: the stable `M6.1` slice does not isolate discovery follow-up branching as its own acceptance scenario, so confidence here still relies partly on broader lifecycle and prior targeted coordinator regressions.

### 3. Long-form narration transport

- VERIFIED BY TEST: `HybridRuntimeContractTests.testNarrationUsesDedicatedTransportInsteadOfRealtimeVoiceOutput` and `HybridRuntimeContractTests.testNarrationTransportAdvancesScenesUnderCoordinatorControl` passed in this run.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance` and `PracticeSessionViewModelTests.testRevisionInvalidatesStalePreloadedFutureSceneAudio` passed in this run.
- VERIFIED BY CODE INSPECTION: `PracticeSessionViewModel` builds `PreparedNarrationScene` values, uses `StoryNarrationTransporting`, and records preload timing without letting the transport invent scene progression.
- PARTIALLY VERIFIED: narration currently uses the system speech transport and a bounded prepared-scene cache; there is still no broader synthesized-audio asset pipeline or persisted scene-audio cache to verify.

### 4. Interruption routing

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testInterruptionQuestionDoesNotBlindlyStartRevision` and `PracticeSessionViewModelTests.testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes` passed in this run.
- VERIFIED BY TEST: `HybridRuntimeContractTests` passed for answer-only, repeat-or-clarify, revise-future-scenes, and revision-unavailable routing outputs.
- VERIFIED BY CODE INSPECTION: `handleInterruptingTranscript` routes through `InterruptionIntentRouter.classify(...)` before choosing any answer-only, replay, or revision path.
- PARTIALLY VERIFIED: the router remains deterministic and local, but its heuristic intent classification quality under real child phrasing variance is not what this milestone verifies.

### 5. Answer-only interaction path

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testAnswerOnlyResumeCompletesAndSavesOnce` passed in this run.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testInterruptionQuestionDoesNotBlindlyStartRevision` proves answer-only questions stay off the revision path.
- VERIFIED BY CODE INSPECTION: `startAnswerOnlyResponse` speaks a short response over the live interaction transport, records stage telemetry, and resumes narration through `.replayCurrentScene(...)` without mutating story state.
- PARTIALLY VERIFIED: answer quality itself is intentionally simple and derived from local scene summary text; this milestone verifies routing and determinism, not conversational richness.

### 6. Revise-future-scenes path

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes` passed in this run.
- VERIFIED BY TEST: `HybridRuntimeContractTests.testRevisionBoundaryPreservesCurrentSceneAndMutatesFutureScenesOnly` and `HybridRuntimeContractTests.testRevisionBoundaryIsUnavailableAtFinalSceneBecauseNoFutureScenesRemain` passed in this run.
- VERIFIED BY CODE INSPECTION: `StoryRevisionBoundary.makeRequest(userUpdate:)` preserves the current boundary scene, sends only future scenes as mutable input, and `handleRevisionResolved` merges preserved scenes with revised future scenes before boundary-safe replay.
- PARTIALLY VERIFIED: overflow beyond one queued revision update is bounded and logged, but the user-facing behavior for dropped overflow updates remains intentionally minimal.

### 7. Narration resume rules

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision` and `PracticeSessionViewModelTests.testAnswerOnlyResumeCompletesAndSavesOnce` passed in this run.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testPauseAndResumeNarrationPreservesSceneOwnership` passed in this run.
- VERIFIED BY CODE INSPECTION: `NarrationResumeDecision` is the typed coordinator contract for replaying the current scene, replaying current plus revised future scenes, or continuing to the next scene.
- VERIFIED BY CODE INSPECTION: `resumeNarration(using:intent:)` routes every post-interruption resume through the same coordinator-owned narration entry point.

### 8. Completion and persistence

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testDuplicateCompletionAndSavePrevention` passed in this run.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory` passed in this run.
- VERIFIED BY CODE INSPECTION: `completeSession(...)` rejects invalid terminal transitions, applies terminal transcript policy once, records completion trace, and delegates persistence through `persistCompletedStoryIfNeeded()`.
- PARTIALLY VERIFIED: this run did not add a new isolated regression for late transcript arrival after `.completed`; prior failure-path coverage is stronger than completed-path coverage here.

### 9. Child isolation and continuation scoping

- VERIFIED BY TEST: the stable validation command passed `StoryTimeUITests.testSavedStoriesAndPastStoryPickerStayScopedToActiveChild` and `StoryTimeUITests.testSavedStoriesAndPastStoryPickerReturnWhenSwitchingBackToSeededChild`.
- VERIFIED BY CODE INSPECTION: `StoryLibraryStore.visibleSeries(for:)` and the journey continuation picker still scope saved-story visibility to the selected or active child.
- PARTIALLY VERIFIED: this milestone verifies the seeded home and journey surfaces, but it does not broaden into a larger multi-surface child-isolation acceptance pack beyond the stable slice.

### 10. Privacy and telemetry touchpoints

- VERIFIED BY TEST: the stable backend slice passed `request-retry-rate.test.ts`, which still covers analytics counters including runtime-stage usage meter behavior.
- VERIFIED BY CODE INSPECTION: `recordRuntimeTelemetry(...)` records redacted timing, source, cost-driver, request ID, session ID, and status code only; it does not log transcript or raw audio content.
- VERIFIED BY CODE INSPECTION: `docs/privacy-data-flow-audit.md` remains aligned with the active hybrid runtime shape, including live microphone transport off device and local-only saved history after completion.
- PARTIALLY VERIFIED: stage telemetry is active for discovery, answer-only interaction, TTS preload, story generation, revision, and continuity retrieval, but the top-level stage model still needs the focused verification and reporting pass planned for `M6.3`.

## End-to-End Assessment

- VERIFIED BY TEST: the current stable hybrid validation command is green and covers the highest-value hybrid seams in one repeatable run.
- VERIFIED BY CODE INSPECTION: the repo’s active architecture matches the intended hybrid runtime contract, with realtime reserved for live interaction and TTS used for long-form narration.
- PARTIALLY VERIFIED: the end-to-end product loop is strong at the coordinator, backend contract, and scoped UI level, but bridge-level realtime ordering, telemetry interpretation, and acceptance-pack boundaries still need narrower follow-up work.
- UNVERIFIED: a live WebRTC/browser acceptance harness that exercises the hidden bridge with real peer-connection event ordering still does not exist in the repo.

## Gaps That Feed The Next Milestones

### Feed for M6.2 - Realtime interaction-path determinism audit

- PARTIALLY VERIFIED: the realtime bridge path is covered by tests and code inspection, but not by a live peer-connection harness.
- PARTIALLY VERIFIED: terminal disconnect behavior is explicit and tested, but its intentional no-reconnect semantics still need a tighter determinism-focused audit in hybrid context.
- UNVERIFIED: real-world callback ordering across microphone capture, data-channel delivery, and native callback fan-out under bridge timing skew.

### Feed for M6.3 - Stage-level cost and latency telemetry verification

- PARTIALLY VERIFIED: runtime-stage telemetry exists, but the repo still needs a clearer mapping between supporting stages such as discovery or continuity retrieval and the top-level execution stages `interaction`, `generation`, `narration`, and `revision`.
- PARTIALLY VERIFIED: the current usage meter and client telemetry prove stage attribution exists, but acceptable thresholds, exported reporting shape, and which stage values are still indirect remain undecided.
- UNVERIFIED: any threshold-based judgment about whether the hybrid runtime is already commercially sane by latency or cost, because the repo does not yet define those pass/fail thresholds.

### Feed for M6.4 - Hybrid runtime acceptance regression pack

- PARTIALLY VERIFIED: the stable slice is strong, but the repo still needs one explicit acceptance-pack document that names what is in scope and what is intentionally excluded.
- PARTIALLY VERIFIED: extend-mode and prior-story reuse remain covered more indirectly than the core happy-path, answer-only, and revise-future-scenes flows.
- PARTIALLY VERIFIED: telemetry assertions are present indirectly via analytics tests and runtime event capture, but they are not yet described as part of an explicit acceptance pack.

## Recommended Next Milestone

`M6.2 - Realtime interaction-path determinism audit`

Reason:
- `M6.1` confirms the hybrid runtime is broadly stable, but the highest remaining evidence gap is still the live interaction path at the TTS-to-realtime boundary.
- The strongest remaining `PARTIALLY VERIFIED` and `UNVERIFIED` items are bridge/runtime ordering, terminal disconnect semantics, and interaction-path determinism under the active hybrid split.
