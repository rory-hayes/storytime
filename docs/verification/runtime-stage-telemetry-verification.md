# Runtime Stage Telemetry Verification

Date: 2026-03-20
Milestone: M9.12 - Narration wall-clock telemetry hardening

## Scope

This report verifies the repo's current runtime cost and latency telemetry by stage. It stays scoped to verification-grade measurement and does not widen into dashboards, alerting, or commercialization tooling. This refresh extends the earlier stage audit with coordinator-owned narration playback wall-clock evidence so narration is no longer represented primarily by TTS preparation timing.

Primary code paths inspected:
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `backend/src/lib/analytics.ts`
- `backend/src/services/realtimeService.ts`
- `backend/src/services/storyDiscoveryService.ts`
- `backend/src/services/storyService.ts`
- `backend/src/services/embeddingsService.ts`
- `backend/src/services/storyContinuityService.ts`

Primary tests and verification artifacts inspected:
- `ios/StoryTime/Tests/APIClientTests.swift`
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- `backend/src/tests/request-retry-rate.test.ts`
- `backend/src/tests/model-services.test.ts`
- `docs/verification/hybrid-runtime-end-to-end-report.md`
- `docs/verification/realtime-voice-determinism-report.md`

## Commands Executed

Targeted iOS telemetry slice:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPlaybackTelemetryRecordsWallClockStartAndCompletion -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPlaybackTelemetryRecordsCancellationWallClockOnInterruption
```

Observed result:
- `3` tests passed

## Stage Model

The repo now uses two telemetry layers:

- detailed stage:
  - `discovery`
  - `story_generation`
  - `answer_only_interaction`
  - `revise_future_scenes`
  - `tts_generation`
  - `tts_playback_started`
  - `tts_playback_completed`
  - `tts_playback_cancelled`
  - `continuity_retrieval`
- primary stage group:
  - `interaction`
  - `generation`
  - `narration`
  - `revision`

Mapping rules in the current repo:
- `discovery` -> `interaction`
- `answer_only_interaction` -> `interaction`
- `story_generation` -> `generation`
- `tts_generation` -> `narration`
- `tts_playback_started` -> `narration`
- `tts_playback_completed` -> `narration`
- `tts_playback_cancelled` -> `narration`
- `revise_future_scenes` -> `revision`
- `continuity_retrieval` -> no primary stage group; it remains a supporting stage reported separately

Startup scaffolding remains intentionally outside the four primary runtime stages:
- `healthCheck`
- `sessionBootstrap`
- `voices`
- `realtimeSession`

## Verification Findings By Runtime Stage

### 1. Interaction

- VERIFIED BY TEST: `APIClientTests.testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages` now proves discovery API traces group into `interaction`.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testInterruptionQuestionDoesNotBlindlyStartRevision` proves answer-only coordinator telemetry groups into `interaction` while staying redacted.
- VERIFIED BY TEST: `request-retry-rate.test.ts` and `model-services.test.ts` now prove backend OpenAI usage increments both detailed and grouped `interaction` counters for realtime interaction usage.
- VERIFIED BY CODE INSPECTION: `PracticeSessionViewModel.startAnswerOnlyResponse(...)` records local interaction latency with detailed stage `answer_only_interaction`, while `RealtimeService.recordUsage(...)` now tags provider-side realtime usage as `interaction`.
- PARTIALLY VERIFIED: setup follow-up interaction is represented by detailed stage `discovery`, which groups correctly to `interaction`, but the repo still reports that detail separately rather than as a pure top-level interaction-only event stream.

### 2. Generation

- VERIFIED BY TEST: `APIClientTests.testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages` proves story generation API traces group into `generation`.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation` proves coordinator telemetry keeps generation stage attribution redacted and request-correlated.
- VERIFIED BY TEST: `request-retry-rate.test.ts` proves backend analytics meters `story_generation` into grouped `generation` counters.
- VERIFIED BY CODE INSPECTION: `APIClientTraceOperation.storyGeneration` maps to detailed stage `story_generation`, remote-model cost driver, and primary group `generation`.
- PARTIALLY VERIFIED: generation-adjacent continuity extraction and moderation work are not fully grouped under `generation`; some of that support work remains measured separately or not stage-grouped at all.

### 3. Narration

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance` proves local narration preparation records detailed stage `tts_generation` and groups to `narration`.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testNarrationPlaybackTelemetryRecordsWallClockStartAndCompletion` proves coordinator-owned narration now records `tts_playback_started` and `tts_playback_completed` with grouped `narration` attribution and measured wall-clock duration.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testNarrationPlaybackTelemetryRecordsCancellationWallClockOnInterruption` proves coordinator-owned narration now records `tts_playback_cancelled` with grouped `narration` attribution when a live interruption stops active playback.
- VERIFIED BY CODE INSPECTION: long-form narration telemetry is currently client-side only because the active narration path is coordinator-owned TTS transport rather than a backend OpenAI narration service.
- VERIFIED BY CODE INSPECTION: `PracticeSessionViewModel.startNarration(...)` now records playback start before `playScene(...)` begins, then records completion or cancellation using the same narration start source and wall-clock duration measured around the transport-owned playback await.
- VERIFIED BY CODE INSPECTION: narration keeps preparation and playback economically distinct by recording `tts_generation` separately from the new playback stages instead of collapsing them into one narration duration.
- PARTIALLY VERIFIED: playback wall-clock evidence is now first-class at the coordinator boundary, but it still reflects transport-observed playback rather than lower-level device audio route latency or speaker hardware variance.

### 4. Revision

- VERIFIED BY TEST: `APIClientTests.testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages` proves revision API traces group into `revision`.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation` proves revise-future-scenes telemetry stays request-correlated and redacted.
- VERIFIED BY CODE INSPECTION: `APIClientTraceOperation.storyRevision` maps to detailed stage `revise_future_scenes` and grouped stage `revision`.
- PARTIALLY VERIFIED: revision-adjacent overflow/drop behavior is measured only through coordinator logs and request traces, not through a richer exported revision-quality or user-feedback metric.

## Supporting Stages

### Discovery

- VERIFIED BY TEST: discovery is recorded explicitly as a detailed stage and grouped into `interaction`.
- VERIFIED BY CODE INSPECTION: this is deliberate because discovery is setup interaction, not generation.

### Continuity Retrieval

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testExtendModeUsesPreviousRecapAndContinuityEmbeddings` proves both local and remote continuity retrieval telemetry remain redacted and intentionally have no primary stage group.
- VERIFIED BY CODE INSPECTION: `continuity_retrieval` is treated as a supporting stage because it can feed generation or revision preparation without always belonging to one primary runtime stage.
- PARTIALLY VERIFIED: backend continuity enrichment inside `StoryContinuityService` still records provider usage without a detailed runtime stage, so supporting-stage coverage is not yet completely uniform.

## On-Device Versus Backend Measurement

- VERIFIED BY CODE INSPECTION: on-device telemetry now covers local answer-only interaction timing, TTS preparation timing, narration playback start/completion/cancellation timing, and local continuity fact aggregation timing through `PracticeSessionViewModel.recordRuntimeTelemetry(...)`.
- VERIFIED BY CODE INSPECTION: backend telemetry currently covers OpenAI usage for realtime interaction, discovery, story generation, revision, embeddings retrieval, moderation, and continuity extraction through `analytics.recordOpenAI(...)`.
- VERIFIED BY TEST: targeted iOS and backend tests prove the emitted telemetry stays redacted and does not include transcript text or raw audio content in the asserted fields and counters.
- PARTIALLY VERIFIED: the durable joined launch report from `M9.11` still does not export per-scene runtime telemetry as one backend-plus-client timeline; narration playback wall-clock evidence is currently verification-facing coordinator telemetry rather than a joined durable runtime report.

## Redaction And Privacy

- VERIFIED BY TEST: `PracticeSessionViewModelTests` assertions continue to prove telemetry `source` fields do not contain user transcript or story content in the exercised paths.
- VERIFIED BY TEST: backend service tests continue to prove lifecycle and usage logs avoid raw SDP, upstream bodies, transcript text, and raw audio.
- VERIFIED BY CODE INSPECTION: telemetry fields stay limited to stage labels, grouped stage labels, cost drivers, durations, request IDs, session IDs, routes, operations, status codes, and success state.

## Remaining Gaps

- PARTIALLY VERIFIED: the four primary runtime stage groups are now explicit, but supporting-stage coverage is still uneven, especially for continuity enrichment and moderation internals.
- PARTIALLY VERIFIED: narration now has coordinator-owned playback wall-clock evidence, but the repo still does not measure device-audio output latency below the transport boundary or export a durable per-scene runtime timeline.
- PARTIALLY VERIFIED: startup scaffolding remains intentionally outside the four primary runtime stages, which is correct for product-stage comparison but means startup cost is not part of the grouped stage model.
- VERIFIED BY TEST and VERIFIED BY CODE INSPECTION: repo-owned launch thresholds now exist for the locked MVP candidate, so commercial pass or fail treatment is no longer an unowned telemetry gap.
- PARTIALLY VERIFIED: the joined launch-report surface remains verification-oriented and does not yet expose full runtime-stage timelines outside targeted coordinator inspection.
