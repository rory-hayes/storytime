# Hybrid Runtime Acceptance Regression Pack

Date: 2026-03-07
Milestone: M6.4 - Hybrid runtime acceptance regression pack

## Stable Command

Run:

```bash
/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh
```

## Pack Scope

This command is the default acceptance gate for the active hybrid runtime. It stays intentionally narrow:
- backend contract and telemetry assertions that the hybrid client depends on
- iOS coordinator/runtime assertions for the main hybrid story loop
- seeded UI child-isolation checks for saved-story and prior-story reuse scoping

It is not a full repo test suite and it is not a UX/productization sweep.

The command runs in three steps so the unit and UI slices can fail independently without destabilizing each other:
- backend hybrid contract slice
- iOS hybrid unit slice
- iOS hybrid UI isolation slice

## Required Scenarios Covered

### 1. Happy path

- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testNormalSessionProgressionCompletesAndSavesOnce`
- `VERIFIED BY TEST`: `HybridRuntimeContractTests`

This pins the coordinator-owned startup -> discovery -> generation -> narration -> completion loop, while revise-future-scenes stays pinned by its own dedicated acceptance assertions below.

### 2. Startup failure

- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testStartupHealthCheckFailureUsesSafeMessageAndCategory`
- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testStartupDisconnectBeforeReadyFailsOnceAndLateConnectedDoesNotReviveSession`
- `VERIFIED BY TEST`: backend realtime/auth coverage inside `app.integration.test.ts`, `model-services.test.ts`, and `types.test.ts`

### 3. Disconnect during narration

- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory`

### 4. Interruption answer-only handling

- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testInterruptionQuestionDoesNotBlindlyStartRevision`
- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testAnswerOnlyResumeCompletesAndSavesOnce`

### 5. Revise-future-scenes

- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes`
- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testOverlappingInterruptionsQueueInsteadOfStartingConcurrentRevisions`
- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testRevisionInvalidatesStalePreloadedFutureSceneAudio`

### 6. Pause/resume

- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testPauseAndResumeNarrationPreservesSceneOwnership`
- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision`

### 7. Child isolation

- `VERIFIED BY TEST`: `StoryTimeUITests.testSavedStoriesAndPastStoryPickerStayScopedToActiveChild`
- `VERIFIED BY TEST`: `StoryTimeUITests.testSavedStoriesAndPastStoryPickerReturnWhenSwitchingBackToSeededChild`

### 8. Stable telemetry assertions

- `VERIFIED BY TEST`: `APIClientTests.testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation`
- `VERIFIED BY TEST`: `APIClientTests.testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages`
- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation`
- `VERIFIED BY TEST`: `PracticeSessionViewModelTests.testExtendModeUsesPreviousRecapAndContinuityEmbeddings`
- `VERIFIED BY TEST`: backend runtime-stage analytics coverage in `request-retry-rate.test.ts`

These pin request/session correlation plus grouped runtime-stage telemetry for `interaction`, `generation`, `narration`, and `revision`, while keeping `continuity_retrieval` as a supporting stage.

## What The Command Runs

### Backend slice

- `app.integration.test.ts`
- `model-services.test.ts`
- `request-retry-rate.test.ts`
- `types.test.ts`

Coverage intent:
- realtime route and auth contract
- story route contract handling
- strict schema validation
- redacted runtime-stage analytics counters and grouped telemetry

### iOS unit slice

- selected `APIClientTests`
- full `HybridRuntimeContractTests`
- selected `PracticeSessionViewModelTests`

Coverage intent:
- coordinator-owned hybrid flow
- startup failure and terminal-failure handling
- answer-only vs revise-future-scenes routing
- pause/resume and replay determinism
- completion/save protection
- preload/cache behavior
- telemetry assertions

### iOS UI slice

- selected `StoryTimeUITests`

Coverage intent:
- active-child isolation for saved stories
- prior-story picker isolation and restoration when switching back to the seeded child

## Intentionally Excluded From The Default Pack

- `PARTIALLY VERIFIED`: live `WKWebView` or real WebRTC peer-connection callback ordering. The repo still has no browser-level acceptance harness.
- `PARTIALLY VERIFIED`: full playback wall-clock narration telemetry. The pack pins TTS preparation telemetry, not full device-audio completion variance.
- `PARTIALLY VERIFIED`: the broader revised-story happy path and reload-persistence acceptance cases remain outside the default pack because the current revision-index logging noise is not yet stable enough for this gate.
- `PARTIALLY VERIFIED`: broader repeat-history and revision-queue cases outside the selected high-signal hybrid tests. These remain outside the default gate until they are either stabilized or explicitly re-scoped.
- `PARTIALLY VERIFIED`: broader UX, parent-flow, and product-surface regression coverage. Those belong to later milestones, not the runtime acceptance gate.
- `UNVERIFIED`: threshold-based judgments about commercial latency/cost acceptability. The repo still does not define those pass/fail thresholds.

## When To Run It

- Before marking any hybrid-runtime milestone done.
- After changes to:
  - `PracticeSessionViewModel`
  - `StoryDomain`
  - `APIClient`
  - narration transport behavior
  - interruption routing
  - backend realtime, discovery, generation, revision, or telemetry contracts

## Why This Is The Default Gate

- `VERIFIED BY TEST`: it now covers the required acceptance scenarios for the active hybrid runtime in one repeatable command.
- `VERIFIED BY CODE INSPECTION`: the included slices line up with the coordinator-owned architecture and the active backend contracts.
- `PARTIALLY VERIFIED`: it still relies on narrower targeted slices and repo reports for live bridge ordering and commercial threshold interpretation, but those exclusions are now explicit instead of implicit.
