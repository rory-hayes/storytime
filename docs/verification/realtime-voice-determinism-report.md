# Realtime Interaction-Path Determinism Audit

Date: 2026-03-07
Milestone: M6.2 - Realtime interaction-path determinism audit

## Scope

This audit refreshes the realtime interaction-path evidence after `M6.1`. It stays scoped to live interaction determinism inside the active hybrid runtime, especially the coordinator-owned TTS-to-realtime boundary. It does not widen into telemetry redesign, bridge-harness implementation, or broader acceptance-pack work.

Primary code paths inspected:
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `ios/StoryTime/Core/RealtimeVoiceClient.swift`
- `ios/StoryTime/Core/RealtimeVoiceBridgeView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Models/StoryDomain.swift`
- `backend/src/app.ts`
- `backend/src/services/realtimeService.ts`

Primary test and verification artifacts inspected:
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`
- `ios/StoryTime/Tests/APIClientTests.swift`
- `backend/src/tests/app.integration.test.ts`
- `backend/src/tests/model-services.test.ts`
- `backend/src/tests/types.test.ts`
- `docs/verification/hybrid-runtime-end-to-end-report.md`
- `docs/verification/hybrid-runtime-validation.md`

## Commands Executed

Backend realtime slice:

```bash
cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/types.test.ts
```

Observed result:
- `34` tests passed

Scoped iOS interaction-path slice:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionWithRealAPIClientExecutesFullStartupContractSequence -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionUsesResolvedBackendRegionDuringRealtimeStartup -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionRefreshesStaleSessionTokenBeforeRealtimeStartupFails -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testAnswerOnlyResumeCompletesAndSavesOnce -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationHandsOffToInteractionWithoutReconnect -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringGenerationIsRejectedAfterNarrationBegins -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testLateTranscriptAfterFailureDoesNotOverwriteLatestTranscript -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionDuringGenerationIsRejectedDeterministically
```

Observed result:
- `43` tests passed

Additional repo note from this run:
- A broader `PracticeSessionViewModelTests` class run exposed unrelated repeat-history and revision-queue failures outside the scoped `M6.2` interaction slice. Those failures did not block this audit, but they should be revisited when `M6.4` consolidates the acceptance pack.

## Active Interaction-Path Summary

The repo-accurate interaction path is:
- `VoiceSessionView` starts the coordinator and mounts the hidden realtime bridge.
- `PracticeSessionViewModel` owns startup, narration pause/handoff, interruption intake, answer-only replay, revise-future-scenes, and terminal failure handling.
- `RealtimeVoiceClient` owns bridge readiness, WebRTC startup, and callback fan-out from the hidden `WKWebView`.
- `APIClient` owns backend selection, install/session bootstrap, region propagation, realtime session creation, and request correlation.
- The backend keeps the interaction startup boundary narrow: signed realtime ticket from `/v1/realtime/session`, validated SDP proxy through `/v1/realtime/call`.

## Determinism Findings

### 1. Startup and bridge handshake

- VERIFIED BY TEST: `APIClientTests` passed for identity bootstrap, session reuse/refresh, region propagation, realtime-session creation, and startup sequencing.
- VERIFIED BY TEST: `RealtimeVoiceClientTests` passed for bridge-ready gating, endpoint normalization, startup payload construction, disconnect-before-ready, and bridge-error startup failure.
- VERIFIED BY TEST: backend realtime route/service/type tests passed for `/v1/realtime/session`, `/v1/realtime/call`, signed ticket validation, retry handling, and strict SDP validation.
- VERIFIED BY CODE INSPECTION: `PracticeSessionViewModel.startSession()` still serializes backend health, session bootstrap, voice fetch, realtime session creation, and `voiceCore.connect()` under one coordinator-owned boot path.
- PARTIALLY VERIFIED: live browser/WebRTC event ordering inside the hidden bridge is still inferred from embedded bridge logic and native callback tests rather than a real peer-connection acceptance harness.

### 2. TTS-to-realtime handoff during interruption

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testPausedNarrationHandsOffToInteractionWithoutReconnect` and `PracticeSessionViewModelTests.testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly` passed, proving paused narration transitions into interaction handling without a reconnect path.
- VERIFIED BY CODE INSPECTION: `beginNarrationInterruption(...)` serializes narration stop, assistant cancel, interruption-state entry, and immediate-update handling through the coordinator instead of transport-side state.
- PARTIALLY VERIFIED: the live timing edge between real TTS stop completion, realtime audio readiness, and actual child speech onset is still inferred rather than exercised through device-level audio timing.

### 3. Answer-only interaction path

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testInterruptionQuestionDoesNotBlindlyStartRevision` and `PracticeSessionViewModelTests.testAnswerOnlyResumeCompletesAndSavesOnce` passed.
- VERIFIED BY CODE INSPECTION: `startAnswerOnlyResponse(...)` keeps the path non-mutating, sends the short response through the live interaction transport, and resumes narration using the typed replay decision rather than changing story state.
- PARTIALLY VERIFIED: answer quality is intentionally out of scope here; this audit verifies routing and handoff determinism, not conversational richness.

### 4. Repeat-or-clarify path

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision` passed.
- VERIFIED BY CODE INSPECTION: repeat-or-clarify remains a replay of the current scene boundary and does not enter revision or generation.
- PARTIALLY VERIFIED: the path is deterministic, but richer clarify behavior remains intentionally absent.

### 5. Deferred transcript and callback ordering guards

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testInterruptionDuringGenerationIsRejectedDeterministically`, `testTranscriptStartedDuringGenerationIsRejectedAfterNarrationBegins`, and `testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes` passed.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testLateTranscriptAfterFailureDoesNotOverwriteLatestTranscript` passed.
- VERIFIED BY CODE INSPECTION: `handleTranscriptFinal(...)` now accepts finals only from legal consumer states, while deferred generating/revising finals are rejected if the coordinator already moved on.
- PARTIALLY VERIFIED: callback ordering under real bridge jitter is still inferred from mocked callback fan-out rather than a live OpenAI data-channel session.

### 6. Terminal disconnect semantics

- VERIFIED BY TEST: `PracticeSessionViewModelTests.testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory` passed.
- VERIFIED BY TEST: `RealtimeVoiceClientTests` passed for disconnect-before-ready failure and post-connect disconnect callback fan-out.
- VERIFIED BY CODE INSPECTION: `handleDisconnected()` treats disconnect as terminal after boot, clears active coordination IDs, and does not attempt reconnect or silent recovery.
- VERIFIED BY CODE INSPECTION: the current product semantics are intentionally no-reconnect. Recovery requires a new session.
- UNVERIFIED: recoverable reconnect behavior after a transient network drop, because the repo does not implement or test it.

### 7. Backend contract and redaction

- VERIFIED BY TEST: backend realtime tests prove signed-ticket enforcement, retry behavior, safe upstream failure mapping, and answer-SDP validation without exposing raw SDP or upstream response bodies in lifecycle logs.
- VERIFIED BY CODE INSPECTION: `RealtimeService` and `APIClient` keep the interaction startup contract narrow and request-correlated while preserving redaction.
- PARTIALLY VERIFIED: the audit proves route determinism and redaction, but not end-to-end latency behavior under production-grade network variance.

## Remaining Gaps

- PARTIALLY VERIFIED: the realtime interaction path is deterministic at the coordinator and contract level, but live bridge/browser ordering remains inferred because there is no real `WKWebView`/WebRTC acceptance harness.
- PARTIALLY VERIFIED: terminal disconnect semantics are explicit and repo-consistent, but there is still no product decision to add reconnect or resumable transport behavior.
- PARTIALLY VERIFIED: some passing interaction tests still emit `Revision index mismatch` diagnostics during paused/revision handoffs. This audit did not reproduce state drift from those paths, so they remain evidence noise rather than a confirmed runtime defect.
- UNVERIFIED: actual peer-connection callback ordering under real microphone capture, data-channel latency skew, and browser scheduling variance.
- UNVERIFIED: whether the current no-reconnect behavior is commercially acceptable under realistic session-drop rates, because the repo does not yet define that threshold.

## Audit Outcome

- VERIFIED BY TEST: the active hybrid interaction path has current targeted evidence for startup, bridge connect gating, pause-to-interaction handoff, answer-only, repeat-or-clarify, deferred transcript rejection, and terminal disconnect behavior.
- VERIFIED BY CODE INSPECTION: the coordinator remains the single authority for interaction-path state transitions at the TTS-to-realtime boundary.
- PARTIALLY VERIFIED: the remaining determinism gap is not state-machine ambiguity inside the repo; it is the absence of a live bridge acceptance harness and explicit commercial thresholds for disconnect tolerance.
- UNVERIFIED: real browser/WebRTC callback ordering and any reconnect-capable runtime, because neither exists in the current repo.

## Recommended Next Milestone

`M6.3 - Stage-level cost and latency telemetry verification`

Reason:
- `M6.2` reduces the main open interaction-path question to measurable bridge/runtime limits rather than uncontrolled coordinator behavior.
- The next missing proof is whether the current hybrid runtime is measurable enough by stage to support later acceptance and productization decisions.
