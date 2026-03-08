# Runtime Stage Telemetry Verification

Date: 2026-03-07
Milestone: M6.3 - Stage-level cost and latency telemetry verification

## Scope

This report verifies the repo's current runtime cost and latency telemetry by stage. It stays scoped to verification-grade measurement and does not widen into dashboards, alerting, or commercialization tooling.

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
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation -only-testing:StoryTimeTests/APIClientTests/testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testExtendModeUsesPreviousRecapAndContinuityEmbeddings
```

Observed result:
- `6` tests passed

Targeted backend telemetry slice:

```bash
cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/request-retry-rate.test.ts src/tests/model-services.test.ts
```

Observed result:
- `13` tests passed

Stable hybrid validation command:

```bash
/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh
```

Observed result:
- backend slice: `39` tests passed
- iOS unit slice: `31` tests passed
- iOS UI child-isolation slice: `2` tests passed

## Stage Model

The repo now uses two telemetry layers:

- detailed stage:
  - `discovery`
  - `story_generation`
  - `answer_only_interaction`
  - `revise_future_scenes`
  - `tts_generation`
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
- VERIFIED BY CODE INSPECTION: long-form narration telemetry is currently client-side only because the active narration path is coordinator-owned TTS transport rather than a backend OpenAI narration service.
- VERIFIED BY CODE INSPECTION: the top-level narration group is intentionally fed from local TTS preparation timing, not from the realtime transport.
- PARTIALLY VERIFIED: the repo measures narration preparation latency but not broader scene-playback wall-clock or device-audio completion variance as a first-class exported stage metric.

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

- VERIFIED BY CODE INSPECTION: on-device telemetry currently covers local answer-only interaction timing, TTS preparation timing, and local continuity fact aggregation timing through `PracticeSessionViewModel.recordRuntimeTelemetry(...)`.
- VERIFIED BY CODE INSPECTION: backend telemetry currently covers OpenAI usage for realtime interaction, discovery, story generation, revision, embeddings retrieval, moderation, and continuity extraction through `analytics.recordOpenAI(...)`.
- VERIFIED BY TEST: targeted iOS and backend tests prove the emitted telemetry stays redacted and does not include transcript text or raw audio content in the asserted fields and counters.
- PARTIALLY VERIFIED: there is still no single exported joined report that merges on-device and backend timings into one end-to-end timeline per session.

## Redaction And Privacy

- VERIFIED BY TEST: `PracticeSessionViewModelTests` assertions continue to prove telemetry `source` fields do not contain user transcript or story content in the exercised paths.
- VERIFIED BY TEST: backend service tests continue to prove lifecycle and usage logs avoid raw SDP, upstream bodies, transcript text, and raw audio.
- VERIFIED BY CODE INSPECTION: telemetry fields stay limited to stage labels, grouped stage labels, cost drivers, durations, request IDs, session IDs, routes, operations, status codes, and success state.

## Remaining Gaps

- PARTIALLY VERIFIED: the four primary runtime stage groups are now explicit, but supporting-stage coverage is still uneven, especially for continuity enrichment and moderation internals.
- PARTIALLY VERIFIED: narration is measurable through local TTS preparation timing, but not yet through a broader scene-playback end-to-end latency model.
- PARTIALLY VERIFIED: startup scaffolding remains intentionally outside the four primary runtime stages, which is correct for product-stage comparison but means startup cost is not part of the grouped stage model.
- UNVERIFIED: any threshold-based judgment about commercial viability by stage, because the repo still does not define latency or cost pass/fail thresholds.
- UNVERIFIED: any durable export or reporting format beyond logs, in-memory counters, and verification documents.

## Recommended Next Milestone

`M6.4 - Hybrid runtime acceptance regression pack`

Reason:
- The repo now has current end-to-end, interaction-path, and telemetry-stage verification artifacts.
- The next step is to turn those verified slices into one explicit acceptance pack and decide which remaining noisy or indirect areas belong inside or outside the default validation gate.
