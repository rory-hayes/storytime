# PLANS.md

## Product Summary

StoryTime is a voice-first iOS app for generating child-safe personalized audio stories.

Current active product shape in code:
- SwiftUI iOS app in `ios/StoryTime`
- TypeScript/Express backend in `backend`
- Hidden `WKWebView` realtime bridge for live voice transport
- Live discovery, generation, narration, interruption, revision, and continuation flow
- Local story continuity and story history stored on device

Archived code in `tiny-backend/` is not part of the active product.

## Current Program Goal

Harden the active product. Do not expand it.

The current goal is to make the core story loop reliable, deterministic, safe, and production-ready:
- fix fragile realtime startup
- eliminate raw internal errors from child-facing UI
- harden voice session state handling
- improve local persistence integrity
- enforce strict child-profile isolation
- align privacy copy with actual data flow
- harden config, transport, and observability

## Current Phase

Phase 3 - Safety, Privacy, And Production Hardening

## Overall Status Snapshot

- The active iOS flow is `HomeView` -> `NewStoryJourneyView` -> `VoiceSessionView` -> `PracticeSessionViewModel`.
- The active client session coordinator already uses an explicit `VoiceSessionState` model in `StoryDomain.swift`.
- The active realtime client uses a hidden `WKWebView` bridge in `RealtimeVoiceClient.swift` and `RealtimeVoiceBridgeView.swift`.
- The active backend already exposes `/v1/session/identity`, `/v1/realtime/session`, `/v1/realtime/call`, `/v1/story/discovery`, `/v1/story/generate`, `/v1/story/revise`, and `/v1/embeddings/create`.
- The backend already has signed session identity, signed realtime tickets, request context, and analytics hooks.
- Primary story storage now lives in the Core Data-backed `storytime-v2.sqlite` store; `UserDefaults` remains for install/session bootstrap keys and legacy migration source blobs only.
- The current test baseline already covers key iOS session logic, API handling, bridge behavior, story storage, backend auth/security, discovery, planner logic, story services, and integration routes.

## Current Architectural Notes

- `VoiceSessionView` starts the session in `.task` and hosts the hidden realtime bridge view.
- `PracticeSessionViewModel` coordinates boot, discovery, generation, narration, interruption, revision, completion, and local save behavior.
- `PracticeSessionViewModel.phase` is now derived from `sessionState` instead of stored separately, so the canonical `VoiceSessionState` is the single source of truth for the active session phase.
- `PracticeSessionViewModel` now categorizes startup failures explicitly as health check, session bootstrap, realtime session creation, bridge readiness, call connect, and disconnect-before-ready.
- `PracticeSessionViewModel` now maps startup failures to safe child-facing copy and resolves boot-time disconnect and bridge error callbacks immediately instead of letting them race the boot completion path.
- `StoryTimeAppErrorCategory` and `StoryTimeAppError` now define the active client-safe error model for startup, moderation block, network failure, backend failure, decode failure, persistence failure, and cancellation.
- `PracticeSessionViewModel` now routes non-startup discovery, generation, revision, runtime voice error, and disconnect paths through typed safe error mapping instead of surfacing raw transport strings in the UI.
- Discovery, generation, and revision cancellations now recover to explicit non-terminal states instead of failing the session, and moderation-blocked discovery/generation/revision paths now record typed safe notices.
- `APIClient` now parses backend `{ error, message, request_id }` envelopes into structured `APIError.invalidResponse` values, preserves backend codes/messages/request IDs for higher-level mapping, and keeps `localizedDescription` free of raw response bodies.
- `PracticeSessionViewModel` now maps backend codes like `rate_limited`, session-token failures, `unsupported_region`, `revision_conflict`, and realtime transport failures into explicit safe client-visible errors instead of relying only on local heuristics.
- `APIClient` now generates a per-request `x-request-id`, stores backend `session_id` in `AppSession`, and emits structured transport trace events for startup, voice discovery, story discovery, generation, revision, and embeddings requests.
- `PracticeSessionViewModel` now records redacted coordinator trace events for startup, discovery, generation, revision, completion, and failure, keyed by backend request ID and session ID instead of raw transcript or story text.
- Backend request-context tests now pin caller-supplied `x-request-id` echo behavior on story routes, and analytics tests now cover session-aware request metrics alongside request IDs.
- Backend services now emit request-scoped `lifecycle_event` logs for realtime ticket issuance, realtime call proxying, discovery, story generation, and revision, including retry and failure paths without transcript text, story text, SDP bodies, or raw upstream response bodies.
- `docs/privacy-data-flow-audit.md` now records the actual privacy-relevant data flow across on-device persistence, backend routes, realtime WebRTC transport, identifiers, analytics, and lifecycle logging.
- `PracticeSessionViewModelTests` now includes a reusable acceptance-harness runner for the no-network happy path, covering startup, discovery, generation, narration, interruption, revision, completion, and save against isolated local persistence.
- The active product keeps saved story history and continuity local after completion, but discovery transcripts, generation inputs, revision inputs, generated story content, and embeddings requests cross the network during processing.
- Raw audio is not persisted in active code, but the realtime bridge sends live microphone audio off device over WebRTC after backend-mediated SDP setup.
- `clearTranscriptsAfterSession` currently clears only the local in-memory session transcript, not already transmitted discovery or revision text.
- `PracticeSessionViewModel` hardcodes realtime region `"US"` when creating realtime sessions.
- State guards for discovery resolution, generation resolution, revision resolution, startup-attempt tracking, and terminal-state handling now validate against exact `VoiceSessionState` cases instead of a parallel mutable phase flag.
- Discovery-to-generation now has explicit ownership: live generation starts only from the matching discovery result, and mock generation starts only from the final ready discovery step instead of any generic `.ready` state.
- Generation requests now snapshot discovery slots, tone, voice, lesson, and continuity query inputs before async continuity work starts, so late generation work cannot inherit later session mutations.
- Narration start now validates explicit sources instead of coarse phase buckets: replay boot, generation resolution, revision resolution, and prior scene completion each require the exact owning state.
- Speech that starts while the session is `.generating` or `.revising` now carries deferred origin policy, so a late transcript final is rejected instead of being reinterpreted after the session has already advanced to narration.
- Queued revision updates are now explicitly bounded to one pending request, so only one revision request owns future scenes at a time and overflow is rejected with logging.
- Narration interruption tests now assert assistant speech cancellation exactly once, so interruption cancel behavior is pinned to a deterministic single cancel call.
- `completeSession()` now only accepts explicit non-terminal source states, so late terminal paths cannot flip `.failed` into `.completed` or replay completion side effects.
- Transcript clearing now follows terminal session end instead of only successful completion, so the privacy setting applies consistently when a session ends.
- Repeat-episode replay now leaves history unchanged unless a revision is accepted, and repeat-episode revisions replace the existing episode instead of adding duplicate history.
- Voice session transition and invalid-transition logs now include full state context such as discovery turn IDs, ready-step numbers, scene indices, and queued revision counts.
- The startup path now has a dedicated no-network regression layer: `PracticeSessionViewModelTests` exercises the full health -> session identity -> voices -> realtime session -> voice connect startup sequence with the real `APIClient`, `APIClientTests` verifies the same contract at the client boundary, and `RealtimeVoiceClientTests` verifies bridge readiness gating before the connect command is sent.
- `RealtimeVoiceClient` loads an inline HTML bridge in a `WKWebView`, then posts microphone and WebRTC events back into Swift.
- `RealtimeVoiceClient.connect()` now resolves absolute, root-relative, and path-relative realtime call endpoints explicitly instead of assuming one URL shape.
- `RealtimeVoiceClient` now loads the embedded bridge with a local secure origin and relies on the backend session response for the realtime call target instead of a deployment-specific base URL.
- `RealtimeVoiceClient` now fails boot-time connect deterministically when the bridge never becomes ready, disconnects before ready, or reports an error before the session is connected.
- `RealtimeService.fetchOpenAIAnswerSdp()` now preserves the minimal proxy contract: validated offer SDP in, validated answer SDP out, and safe `AppError` failure on upstream rejection.
- `APIClient` bootstraps `/v1/session/identity`, caches session headers, and decodes `422` blocked story responses into typed success envelopes.
- `APIClient.bootstrapSessionIdentity(baseURL:)` is now an explicit client boot step so startup can distinguish identity bootstrap failures from later realtime session failures.
- `APIClient.createRealtimeSession()` preserves absolute realtime call endpoints returned by the backend instead of rewriting them through the client base URL.
- `docs/persistence-audit.md` now inventories the active iOS persistence surface, including every active `UserDefaults` key, the split between primary product data and bootstrap/config data, and the current save, replace, delete, clear-history, and retention cleanup paths.
- `StoryLibraryStoreTests` now pin shared continuity cleanup for clear-history, delete-series, retention prune, and child-delete cascade against `ContinuityMemoryStore.shared`.
- `StoryLibraryStore.addStory(...)` now keeps series pruning semantics while deferring continuity sync until after the library mutation, and async continuity prune tasks now re-read the latest persisted library snapshot instead of pruning against stale captured state.
- `StoryLibraryV2Storage` now persists the active library/profile/privacy snapshot and continuity facts through a Core Data-backed `storytime-v2.sqlite` store instead of flat JSON blobs, and `StoryLibraryStore` only falls back to legacy `storytime.*.v1` library/profile/privacy keys when the v2 store is absent or older than the current migration version.
- The v2 store now preserves exact library ordering with `libraryPosition`, so series ordering no longer depends only on timestamp inference when the snapshot is reloaded.
- `ContinuityMemoryStore` now migrates semantic continuity facts out of `storytime.continuity.memory.v1`, records continuity migration completion in the v2 migration log, and removes the legacy continuity blob after successful import.
- `StoryLibraryStore` now upgrades existing v1 Core Data snapshot installs in place to the current migration version instead of re-bootstraping library/profile/privacy data from legacy defaults.
- `StoryLibraryStore` story lifecycle writes now use entity-level v2 operations for new-series insert, episode append, episode replace, delete-series, clear-history, and repeat-no-save behavior instead of rewriting the full library snapshot.
- The v2 story store now reloads those lifecycle changes directly from `StoredStorySeries` and `StoredStoryEpisode` rows, while profile/privacy mutations still use the snapshot writer until later hardening.
- Retention pruning now updates the v2 story store through selective series and episode deletion plus story-index compaction instead of collection-level replacement, and save-history-off now clears story rows before persisting the disabled setting.
- `ParentPrivacySettings.saveRawAudio` is present in persisted settings and UI test seed data, but there is no active control or behavior path that uses it.
- `StoryLibraryStore.visibleSeries` no longer falls back across children when the active child has no saved stories, and `StoryLibraryStore.visibleSeries(for:)` now lets `NewStoryJourneyView` scope continuation choices to its selected child instead of the global active child.
- Saved-story home empty state and the new-story continuation picker are now both regression-covered for the no-stories child path, including a focused UI test that switches from seeded Milo data to Nora and verifies both surfaces stay empty.
- `StoryLibraryStore.deleteChildProfile(_:)` now computes the post-delete profile set, fallback active profile, and removed series IDs before mutating state, so child removal, fallback creation, and continuity cleanup order are explicit and deterministic.
- `ContinuityMemoryStore` now prunes semantic continuity by explicit `(seriesId, storyId)` provenance instead of separate global series and story sets, so cleanup stays correct even if story IDs collide across series.
- `StoryLibraryStore` now rebuilds series structural continuity from retained episode engine memory after append, replace, and retention prune, while preserving migrated legacy continuity fields when no engine-derived series memory exists to rebuild from.
- Repeat-episode revisions now replace semantic continuity facts for the original persisted `(seriesId, storyId)` pair and clear closed open loops from the saved series metadata instead of leaving stale future-scene continuity behind.
- `HomeView`, `NewStoryJourneyView`, `VoiceSessionView`, and `ParentTrustCenterView` now distinguish local saved history from live session processing instead of implying the full story loop stays on device.
- Parent-facing and child-facing copy now says raw audio is not saved, and session copy now describes transcript clearing as local on-screen cleanup when that setting is enabled.
- `AppConfig` now reads the deployed backend URL from the app bundle `StoryTimeAPIBaseURL` key with explicit URL normalization and environment override precedence instead of relying only on an inline deployment URL in code.
- The iOS app transport policy now allows local networking for the debug loopback backend without enabling global `NSAllowsArbitraryLoads`.
- `APIClient` now retries authenticated realtime/story/embeddings requests once after `missing_session_token`, `invalid_session_token`, or `invalid_session_token_expired` by clearing the stale session and re-bootstrapping `/v1/session/identity`.
- `RealtimeVoiceClient` now fails bridge readiness immediately on navigation failure or web content process termination instead of waiting only for the bridge-ready timeout path.
- Backend env loading now rejects refresh windows that are as long as or longer than the session TTL, and production envs must set an explicit `ALLOWED_ORIGIN` plus `API_AUTH_REQUIRED=true`.
- `APIClient` now resolves processing region from backend `/health` metadata or `/v1/session/identity`, stores it with the active session, propagates `x-storytime-region`, and aligns realtime session request bodies to the same resolved value.
- Startup unsupported-region failures now preserve the safe region-specific user message instead of collapsing into generic startup copy.
- `HomeView` now routes parent controls through a lightweight local confirmation gate before switching the sheet into `ParentTrustCenterView`, so the parent trust surface no longer opens directly from a single tap.

## Key Risks

- Startup and non-startup coordinator failures are now categorized, backend/client error mapping is aligned around backend `error/message/request_id` envelopes, and request/session correlation now reaches the coordinator trace layer without logging transcript or story content.
- Realtime startup still spans `VoiceSessionView`, `PracticeSessionViewModel`, `APIClient`, `RealtimeVoiceClient`, the hidden bridge, and `/v1/realtime/call`, but the main startup contract now has repeatable client and backend regression coverage.
- Phase 1 voice-session reliability hardening, Phase 2 data integrity/isolation hardening, and Phase 3 transport/privacy hardening are largely complete for the current plan; the next major risk is end-to-end reliability coverage.
- Story lifecycle writes and retention pruning no longer rewrite the full library snapshot, but some profile/privacy mutations still use snapshot writes.
- Legacy library/profile/privacy blobs are now migration-source only and the legacy continuity blob is retired after import, but install/session bootstrap keys still remain in `UserDefaults` by design.
- Child-profile story visibility, child-delete cascade behavior, and continuity cleanup are now scoped and reload-safe for owned rows, but some profile/privacy mutations still use snapshot writes.
- Legacy `StorySeries.childProfileId == nil` rows are still compatibility-visible until a later cleanup or reassignment pass, so child scoping is strict for owned rows but not yet full legacy remediation.
- Continuity cleanup now follows persisted `(seriesId, storyId)` provenance across replace, revise, prune, delete-series, and child-delete flows, and the audited privacy copy is now aligned to the active behavior.
- `saveRawAudio` exists in the persisted privacy schema but has no active UI or storage behavior, so the privacy-copy pass must resolve whether it stays as compatibility-only state or is removed later.
- `saveRawAudio` still exists as compatibility-only persisted state even though the UI now states the active product behavior directly.
- Parent controls now require a local confirmation gate, but this remains lightweight friction rather than full parent authentication.
- The acceptance harness now has a reusable happy-path slice, but failure-injection and child-isolation acceptance coverage are still missing.

## Milestone Status

| Milestone | Status | Notes |
| --- | --- | --- |
| M1.1 Realtime startup flow audit | DONE | Startup chain documented in `docs/realtime-startup-audit.md`; failing backend realtime error branch identified. |
| M1.2 `/v1/realtime/call` contract and SDP handling | DONE | Client and backend now agree on endpoint resolution and SDP validation; targeted tests cover absolute, root-relative, and path-relative call targets plus invalid offer/answer handling. |
| M1.3 Safe startup failure states | DONE | Startup failures are now explicitly categorized, mapped to safe UI copy, and guarded against stale boot callbacks and pre-ready disconnect races. |
| M1.4 Startup-path tests | DONE | Dedicated client and backend startup regressions now cover the full startup contract, bridge readiness gating, and startup-route auth/payload failures. |
| M1.5 Canonical voice session state model cleanup | DONE | `phase` is now derived from `sessionState`, exact-state guards replaced parallel phase checks, and restart/invalid-transition regressions cover the canonical model. |
| M1.6 Deterministic discovery, generation, and narration transitions | DONE | Generation now starts only from explicit discovery owners, narration starts from explicit source states, and stale discovery/generation completions are pinned by regression tests. |
| M1.7 Interruption and revision serialization | DONE | Deferred generation/revision transcripts are now rejected if the session advances, revision queueing is bounded to one pending update, and interruption cancellation is regression-tested as a single cancel. |
| M1.8 Duplicate completion and save prevention | DONE | Completion now rejects invalid terminal re-entry, transcript clearing follows terminal session end, replay completion leaves history unchanged, and replay revisions replace existing history without adding episodes. |
| M2.1 Persistence audit | DONE | `docs/persistence-audit.md` now inventories the active iOS storage surface and cleanup paths, shared continuity cleanup is pinned by store tests, and the stale post-save continuity prune race has been fixed. |
| M2.2 Local schema design for story data | DONE | Core Data-based local schema chosen for child profiles, story series/episodes, privacy settings, continuity facts, and migration metadata. |
| M2.3.1 Core Data bootstrap for library, profile, and privacy data | DONE | The v2 store now uses Core Data-backed persistence plus legacy import fallback for library/profile/privacy data. |
| M2.3.2 Continuity migration and legacy blob retirement | DONE | Continuity facts now persist in the v2 Core Data store, legacy continuity blobs are retired after import, and existing v1 snapshot installs upgrade in place. |
| M2.4 Save, load, and delete flow migration | DONE | New series, append, replace, delete, clear-history, and repeat-no-save now persist through entity-level series and episode operations on the v2 store. |
| M2.5 Retention pruning hardening | DONE | Retention now prunes the v2 story store through selective series and episode updates, and save-history-off clears persisted story rows plus continuity across reloads. |
| M2.6 Active-child library scoping fix | DONE | Saved-story lists and past-story picker no longer fall back across children; store and UI regressions cover the empty-state path. |
| M2.7 Child-delete cascade behavior | DONE | Child deletion now keeps other-child stories and continuity intact, persists active-profile fallback, and recreates the default fallback profile when the last child is removed. |
| M2.8 Continuity provenance and cleanup | DONE | Continuity cleanup now keys off `(seriesId, storyId)` provenance, structural continuity rebuilds from retained episode memory, and revised stories replace stale continuity instead of leaking old loops. |
| M3.1 Safe application error model | DONE | Typed client-safe error categories now cover startup, moderation, network, backend, decode, and cancellation paths in `PracticeSessionViewModel`. |
| M3.2 Client/backend error mapping | DONE | `APIClient` now parses backend error envelopes, raw bodies stay out of `localizedDescription`, and the coordinator maps backend codes/public messages into safe client errors. |
| M3.3 Session correlation IDs and tracing | DONE | `APIClient` now generates request IDs and stores `session_id`, the coordinator records redacted trace events across the critical path, and backend tests pin caller-supplied request ID echo plus session-aware analytics coverage. |
| M3.4 Backend lifecycle logging | DONE | Backend services now emit request-scoped redacted lifecycle logs for realtime, discovery, generate, and revise success, retry, blocked, and failure paths. |
| M3.5 Real data-flow and privacy audit | DONE | `docs/privacy-data-flow-audit.md` now documents actual on-device storage, network transport, identifiers, and logging behavior, plus the current privacy-copy mismatches. |
| M3.6 Privacy copy alignment | DONE | Home, journey, voice, and parent-control copy now match the audited storage and live-processing behavior, with UI and unit regressions pinning the wording. |
| M3.7 Transport and config hardening | DONE | Backend URL config is bundle-backed, ATS no longer allows arbitrary loads, stale session tokens now re-bootstrap once, bridge-load failures fail fast, and backend env validation rejects unsafe production defaults. |
| M3.8 Region handling alignment | DONE | Client now resolves region from backend health/bootstrap, sends `x-storytime-region`, and aligns realtime session body region to the same value. |
| M3.9 Lightweight parent access gate | DONE | `HomeView` now presents a local typed confirmation gate before opening parent controls, and UI regressions cover blocked direct entry plus successful gated entry. |
| M3.10.1 Acceptance harness foundation and happy path | DONE | Reusable coordinator acceptance runner now covers startup through save, including interruption and revision, with reload-safe persistence assertions. |
| M3.10.2 Failure injection acceptance coverage | TODO | Extend the harness with startup, disconnect, revision-overlap, and duplicate-completion scenarios. |
| M3.10.3 Child isolation acceptance coverage and validation command | TODO | Add multi-child acceptance coverage and pin the stable harness command future runs should use. |

## Completed Work Log

### 2026-03-06 - M1.1 Realtime startup flow audit
- Status: DONE
- Summary: Mapped the active startup path from `VoiceSessionView.task` through `PracticeSessionViewModel`, `APIClient`, `RealtimeVoiceClient`, the hidden `WKWebView` bridge, and backend `/v1/realtime/call`. Identified the first concrete failing startup branch and recorded the active startup assumptions and handoff for the next milestone.
- Files: `docs/realtime-startup-audit.md`, `PLANS.md`, `SPRINT.md`
- Tests: No new tests added. `SPRINT.md` defines M1.1 as an audit milestone with no mandatory test changes unless a failing path is reproduced in a new regression test.
- Risks/Notes: The active failing branch is `backend/src/services/realtimeService.ts` calling undefined `loggerForContext(...)` on upstream non-OK responses. Raw startup errors can still reach the UI via `localizedDescription`. The bridge still relies on a hardcoded base URL and the client still hardcodes realtime region `"US"`.
- Next: M1.2 - `/v1/realtime/call` contract and SDP handling

### 2026-03-06 - M1.2 `/v1/realtime/call` contract and SDP handling
- Status: DONE
- Summary: Hardened the active realtime call contract between `APIClient`, `RealtimeVoiceClient`, the embedded bridge, and `RealtimeService`. The client now resolves absolute, root-relative, and path-relative call endpoints explicitly, preserves absolute backend endpoints, and no longer depends on a deployment-specific bridge base URL. The backend now cleanly rejects invalid offers and invalid upstream answers while preserving the minimal offer-in, answer-out proxy shape.
- Files: `ios/StoryTime/Core/RealtimeVoiceClient.swift`, `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `backend/src/services/realtimeService.ts`, `backend/src/tests/model-services.test.ts`, `backend/src/tests/app.integration.test.ts`, `PLANS.md`, `SPRINT.md`
- Tests: Updated `RealtimeVoiceClientTests` for absolute, root-relative, and path-relative call URL resolution and connect payload assertions. Added `APIClientTests` coverage for preserving absolute backend call endpoints. Added backend service and integration tests for exact SDP preservation, invalid offer rejection, invalid upstream answer rejection, and safe upstream failure handling. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests` and `npm test -- --run src/tests/model-services.test.ts src/tests/app.integration.test.ts`.
- Decisions: Keep `/v1/realtime/call` as a minimal backend proxy boundary. The backend owns the realtime call endpoint contract, the iOS client preserves absolute endpoints from the backend, and the bridge origin is treated as a local secure container instead of a source of backend routing.
- Risks/Notes: Safe startup failure presentation is still incomplete because `PracticeSessionViewModel` uses `localizedDescription` in some boot paths. Client region handling is still hardcoded to `"US"` and remains a later hardening milestone.
- Next: M1.3 - Safe startup failure states

### 2026-03-06 - M1.3 Safe startup failure states
- Status: DONE
- Summary: Hardened the startup path so boot failures land in explicit categories instead of surfacing raw transport text. `PracticeSessionViewModel` now distinguishes health check, session bootstrap, realtime session creation, bridge readiness, call connect, and disconnect-before-ready failures. Boot-time disconnect and bridge error callbacks now resolve immediately, and stale boot callbacks no longer revive a failed startup.
- Files: `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Core/RealtimeVoiceClient.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added targeted startup failure coverage in `PracticeSessionViewModelTests` for health check, session bootstrap, realtime session creation, bridge readiness timeout, connect failure, disconnect-before-ready, and late boot callback rejection. Added `APIClientTests` coverage for explicit session bootstrap. Added `RealtimeVoiceClientTests` coverage for bridge-ready timeout and pre-ready disconnect handling. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`.
- Decisions: Keep safe startup copy in the session coordinator instead of broadening the app-wide error model yet. Make session bootstrap explicit in the API client so startup can attribute failures correctly. Treat bridge-ready timeout and pre-ready disconnect as typed transport failures instead of generic invalid responses.
- Risks/Notes: Non-startup failures in discovery, generation, and revision still use raw `localizedDescription` in the coordinator. Client region handling is still hardcoded to `"US"`.
- Next: M1.4 - Startup-path tests

### 2026-03-07 - M1.4 Startup-path tests
- Status: DONE
- Summary: Added a dedicated startup regression layer across the iOS coordinator, API client, realtime bridge transport, and backend startup routes. The iOS suite now exercises the full active startup contract without real network calls, and the backend integration suite now covers missing install ID and invalid session token handling on startup routes in addition to the existing unsupported region and invalid realtime call coverage.
- Files: `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`, `backend/src/tests/app.integration.test.ts`, `PLANS.md`, `SPRINT.md`
- Tests: Added `APIClientTests.testStartupSequenceReusesBootstrappedSessionAcrossVoicesAndRealtimeSession`, `PracticeSessionViewModelTests.testStartSessionWithRealAPIClientExecutesFullStartupContractSequence`, and `RealtimeVoiceClientTests.testConnectWaitsForBridgeReadyBeforeSendingStartupCommand`. Added backend integration tests for missing install ID on `/v1/session/identity` and invalid session token on `/v1/realtime/session`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests` and `npm test -- --run src/tests/app.integration.test.ts`.
- Decisions: Keep the startup regression layer test-only for this milestone. Use the real `APIClient` with stubbed `URLSession` transport in coordinator tests so the active contract is exercised without introducing a broader test harness yet.
- Risks/Notes: The startup path is now covered, but non-startup discovery/generation/revision failures still surface raw `localizedDescription` and remain a later hardening target. Realtime region is still hardcoded to `"US"`.
- Next: M1.5 - Canonical voice session state model cleanup

### 2026-03-07 - M1.5 Canonical voice session state model cleanup
- Status: DONE
- Summary: Removed the mutable `phase` flag as a parallel state source and made `PracticeSessionViewModel` derive phase from `sessionState`. Tightened coordinator guards to exact `VoiceSessionState` cases for discovery, generation, revision, startup-attempt ownership, and terminal-state handling. Expanded state logging so transitions and invalid rejections now include the full canonical state payload.
- Files: `ios/StoryTime/Models/StoryDomain.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `PracticeSessionViewModelTests.testCanonicalSessionStateProgressionStaysAlignedWithDerivedPhase`, `PracticeSessionViewModelTests.testStartSessionWhileNarratingIsRejectedWithStateContext`, and `PracticeSessionViewModelTests.testStartSessionRestartsCleanlyFromCompletedTerminalState`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`.
- Decisions: Keep `ConversationPhase` as a derived convenience for UI/tests, but stop storing it separately from `VoiceSessionState`. Keep `currentSceneIndex` as published UI data even though scene-bearing states also encode it.
- Risks/Notes: Non-startup failure messaging still needs safe error mapping beyond boot. The stronger canonical state source does not yet finish the discovery/generation/narration race hardening planned in `M1.6`.
- Next: M1.6 - Deterministic discovery, generation, and narration transitions

### 2026-03-07 - M1.6 Deterministic discovery, generation, and narration transitions
- Status: DONE
- Summary: Replaced phase-based discovery, generation, and narration entry guards with explicit transition sources. Live generation now starts only from the matching discovery result, mock generation only from the final ready discovery step, and narration only from replay boot, generation resolution, revision resolution, or the immediately prior scene completion. Generation request inputs are now frozen before async continuity work starts so stale work cannot inherit later session mutations.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `PracticeSessionViewModelTests.testGenerationDoesNotStartUntilDiscoveryResolves`, `PracticeSessionViewModelTests.testStaleDiscoveryResultAfterFailureIsIgnored`, and `PracticeSessionViewModelTests.testLateGenerationResultAfterFailureIsIgnoredAndDoesNotStartNarration`. Re-ran the existing blocked-discovery regression alongside the targeted iOS suite with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`.
- Decisions: Keep repeat-episode boot-to-narration as an explicit allowed narration source instead of forcing it through generation. Freeze generation request inputs at kickoff instead of relying only on stale-result rejection after async continuity work completes.
- Risks/Notes: Non-startup failure messaging still uses raw `localizedDescription` outside the boot path. Interruption and revision overlap still need explicit serialization completion under `M1.7`.
- Next: M1.7 - Interruption and revision serialization

### 2026-03-07 - M1.7 Interruption and revision serialization
- Status: DONE
- Summary: Finished hardening overlap behavior for interruption and revision. Speech that begins during generation or in-flight revision now carries its source phase forward and is rejected if the session has already advanced by the time the final transcript arrives. Revision queueing is explicitly bounded to one pending update, and overflow is rejected instead of silently growing the future-scene work queue.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Tightened `PracticeSessionViewModelTests.testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes` to assert exactly one cancel call. Added `PracticeSessionViewModelTests.testTranscriptStartedDuringGenerationIsRejectedAfterNarrationBegins`, `PracticeSessionViewModelTests.testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes`, and `PracticeSessionViewModelTests.testRevisionQueueRejectsAdditionalUpdateBeyondOneQueuedRequest`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `61` targeted tests.
- Decisions: Reject deferred transcript finals that started in `.generating` or `.revising` if the session has already moved to a new phase instead of reinterpreting them against the later state. Keep at most one queued revision update so the future-scene owner stays explicit and bounded.
- Risks/Notes: Non-startup failure messaging still uses raw `localizedDescription` outside the boot path. Duplicate completion and save behavior is now the next remaining voice-session hardening target.
- Next: M1.8 - Duplicate completion and save prevention

### 2026-03-07 - M1.8 Duplicate completion and save prevention
- Status: DONE
- Summary: Hardened terminal behavior so completion only runs from explicit non-terminal source states and cannot overwrite a failed session. Completion-side persistence remains single-run, transcript clearing now follows terminal session end, replay completion no longer mutates history, and repeat-episode revisions replace the existing episode instead of adding duplicate history.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Updated `PracticeSessionViewModelTests.testDuplicateCompletionAndSavePrevention` to assert transcript clearing on completion. Added `PracticeSessionViewModelTests.testRepeatEpisodeCompletionDoesNotCreateNewHistory` and `PracticeSessionViewModelTests.testRepeatEpisodeRevisionReplacesExistingHistoryWithoutAddingEpisodes`. Updated `PracticeSessionViewModelTests.testDiscoveryAndGenerationFailuresEndSession` to assert terminal transcript clearing on failure. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `38` tests.
- Decisions: Keep completion gating inside the coordinator instead of adding a separate terminal-state object. Apply transcript clearing on terminal session end so the privacy setting stays aligned across completion and failure. Keep replay save semantics explicit: replay alone saves nothing, replay plus accepted revision replaces the existing episode.
- Risks/Notes: Broader safe error mapping outside startup is still pending. The next priority is persistence integrity and storage invariants, not more voice-session branching.
- Next: M2.1 - Persistence audit

### 2026-03-07 - M2.1 Persistence audit
- Status: DONE
- Summary: Closed the persistence audit with repo-grounded storage documentation and baseline cleanup coverage. `docs/persistence-audit.md` now records every active persisted key, the split between product data and bootstrap/config data, and the current save, replace, delete, clear-history, retention, and continuity cleanup flows. The small unblocker uncovered during the audit is now fixed: `StoryLibraryStore.addStory(...)` still prunes expired series before save, but continuity sync now runs after the library mutation and re-reads the latest persisted library snapshot when the async prune task executes, so immediate post-save continuity indexing is preserved.
- Files: `docs/persistence-audit.md`, `ios/StoryTime/Storage/StoryLibraryStore.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `StoryLibraryStoreTests.testAddStoryPreservesImmediateContinuityIndexingAfterSave` and verified the full targeted store suite with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which passed `12` tests.
- Decisions: Keep install identity and session token storage out of the primary story-store migration decision. Preserve existing pre-save retention semantics for expired series, but make continuity pruning depend on the latest persisted library state rather than stale captured state.
- Risks/Notes: Primary story data is still stored as large serialized blobs. `visibleSeries` still falls back across children. `saveRawAudio` still exists in persisted settings without an active behavior path.
- Next: M2.2 - Local schema design for story data

### 2026-03-07 - M2.2 Local schema design for story data

- Status: DONE
- Summary: Chose the new local persistence model to enable durable and queryable story storage without large serialized `UserDefaults` blobs. The design is `Core Data` with `storytime-v2.sqlite` and explicit schema entities for child profiles, app state/settings, story series, story episodes, continuity facts, and migration log. Query shapes now enforce strict per-child scoping and explicit continuity linkage by `(seriesId, storyId)`.
- Files: `docs/story-data-schema.md`, `PLANS.md`, `SPRINT.md`
- Decisions:
  - Use `Core Data` as the on-device durable primary store for M2.3 migration.
  - Keep install/session identity keys (`com.storytime.install-id`, `com.storytime.session-token`, `com.storytime.session-expiry`) outside primary story migration.
  - Keep continuity query logic in app layer for now; store vectors as persisted JSON in `ContinuityFact` rows and compute ranking in-memory as currently done.
- Migration plan assumptions:
  - M2.3 migration reads all existing `storytime.*.v1` keys from `UserDefaults` as source data.
  - Migration is one-time, idempotent, and records completion with `SchemaMigrationLog`.
  - Corrupt source blobs fallback per-source; successful migrations are durable and rollback-safe by keeping source keys until a `MIGRATION_COMPLETE` marker is persisted.
- Risks/Notes: The schema design introduces a new local file (`storytime-v2.sqlite`) and migration complexity; rollback and corruption recovery are explicit blockers to implement next in M2.3 and must be regression-tested there.
- Next: M2.3 - Migration away from `UserDefaults` for primary story storage

### 2026-03-07 - M2.3.1 Core Data bootstrap for library, profile, and privacy data

- Status: DONE
- Summary: Split the original `M2.3` because the repo already contained an in-progress v2 snapshot cutover and the remaining full migration scope was too large for one safe run. Replaced the file-backed v2 snapshot implementation with a Core Data-backed `storytime-v2.sqlite` store while preserving the existing `StoryLibraryStore` snapshot API and current product behavior. Legacy `storytime.*.v1` library/profile/privacy keys now act as one-time bootstrap source only when the v2 store is absent or older than the current migration version.
- Files: `ios/StoryTime/Storage/StoryLibraryStore.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `docs/story-data-schema.md`, `PLANS.md`, `SPRINT.md`
- Tests: Added `StoryLibraryStoreTests.testV2StoragePersistsSnapshotAcrossReload`. Verified `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/StoryLibraryStoreTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `54` tests. The targeted `StoryLibraryStoreTests` suite also passed `16` tests in isolation.
- Decisions:
  - Keep the current `StoryLibraryStore` snapshot boundary for now so the migration bootstrap can land without combining it with the later entity-level CRUD refactor.
  - Preserve `saveRawAudio` in the v2 settings row for compatibility, but treat it as a compatibility field only; it still does not activate raw-audio retention.
  - Preserve nullable `childProfileId` in the migrated store for now so the current fallback visibility behavior stays unchanged until `M2.6`.
- Risks/Notes: Continuity facts still persist through `ContinuityMemoryStore` in `storytime.continuity.memory.v1`, so the migration away from `UserDefaults` is only partial. `StoryLibraryStore` also still rewrites a full v2 snapshot on each mutation; entity-level store operations remain a follow-up.
- Next: M2.3.2 - Continuity migration and legacy blob retirement

### 2026-03-07 - M2.3.2 Continuity migration and legacy blob retirement

- Status: DONE
- Summary: Moved semantic continuity facts off the legacy `storytime.continuity.memory.v1` blob and into the Core Data-backed v2 store. `ContinuityMemoryStore` now migrates legacy continuity facts into `storytime-v2.sqlite`, records continuity migration completion in the v2 migration log, and removes the legacy continuity blob after successful import. Existing v1 Core Data snapshot installs also now upgrade in place to the current migration version so library/profile/privacy data is not re-bootstraped from legacy defaults during the continuity cutover.
- Files: `ios/StoryTime/Storage/StoryLibraryStore.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `ios/StoryTime/App/UITestSeed.swift`, `docs/story-data-schema.md`, `PLANS.md`, `SPRINT.md`
- Tests: Added `StoryLibraryStoreTests.testContinuityMigrationLoadsFromLegacyUserDefaults`, `StoryLibraryStoreTests.testContinuityMigrationFallsBackWhenLegacyBlobIsCorrupt`, `StoryLibraryStoreTests.testContinuityMigrationIsIdempotentAfterRelaunch`, and `StoryLibraryStoreTests.testExistingV1StoreUpgradesToCurrentVersionWithoutReimportingLegacyLibraryDefaults`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/StoryLibraryStoreTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `58` tests.
- Decisions:
  - Keep continuity ranking and query assembly in app code for now while only moving the persisted facts into the v2 Core Data store.
  - Preserve the current `StoryLibraryStore` snapshot API and upgrade existing v1 snapshot installs in place instead of folding entity-level CRUD into the continuity migration.
  - Clear the v2 store during UI-test seeding so legacy seeding through defaults still produces deterministic launches while entity-level seed writers do not exist yet.
- Risks/Notes: Primary story data is now off the legacy `UserDefaults` blobs, but `StoryLibraryStore` still rewrites the full snapshot into the v2 store on each mutation. Child fallback visibility and `saveRawAudio` compatibility still need separate follow-up milestones.
- Next: M2.4 - Save, load, and delete flow migration

### 2026-03-07 - M2.4 Save, load, and delete flow migration

- Status: DONE
- Summary: Moved the active story lifecycle off full-snapshot rewrites and onto direct v2 series and episode operations. `StoryLibraryStore` now inserts new series rows, appends new episode rows, replaces existing episodes in place, deletes a single series, clears history, and preserves repeat-no-save behavior without rewriting the entire library snapshot. Reload regressions now prove those flows survive a fresh store load directly from the Core Data-backed entity rows.
- Files: `ios/StoryTime/Storage/StoryLibraryStore.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `StoryLibraryStoreTests.testAddStoryPersistsNewSeriesAcrossReload`, `StoryLibraryStoreTests.testAppendEpisodePersistsAcrossReloadAndMovesSeriesToFront`, `StoryLibraryStoreTests.testReplaceStoryPersistsAcrossReload`, `StoryLibraryStoreTests.testDeleteSeriesPersistsAcrossReload`, `StoryLibraryStoreTests.testClearStoryHistoryPersistsAcrossReload`, and `StoryLibraryStoreTests.testRepeatEpisodeDoesNotPersistNewHistoryAcrossReload`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/StoryLibraryStoreTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `64` tests.
- Decisions:
  - Keep profile and privacy mutations on the existing snapshot writer for now and scope `M2.4` to story-series and episode lifecycle persistence only.
  - Keep a narrow full-series replacement helper only for the current retention-prune path until `M2.5` hardens pruning against the entity-level store.
  - Preserve current repeat-episode behavior exactly: replay alone does not create new history rows.
- Risks/Notes: Story lifecycle persistence is now entity-level, but retention pruning still does collection-level replacement work and child fallback visibility remains unchanged. `saveRawAudio` still exists as a compatibility field without active behavior.
- Next: M2.5 - Retention pruning hardening

### 2026-03-07 - M2.5 Retention pruning hardening

- Status: DONE
- Summary: Reworked the migrated retention path so it no longer falls back to whole-collection story rewrites. The v2 store now applies retention through selective series and episode updates, deletes expired series rows directly, compacts surviving episode order, and keeps continuity cleanup aligned with the pruned persisted library. Save-history-off now clears persisted story rows and shared continuity before the disabled setting is reloaded.
- Files: `ios/StoryTime/Storage/StoryLibraryStore.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `StoryLibraryStoreTests.testRetentionPolicyPrunesPersistedStoreAcrossReload` and `StoryLibraryStoreTests.testSaveHistoryOffClearsPersistedStoreAndSharedContinuityAcrossReload`, and tightened `StoryLibraryStoreTests.testRetentionPolicyPrunesSharedContinuityFactsToLibraryStories` with a reload assertion. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/StoryLibraryStoreTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `66` tests.
- Decisions:
  - Keep retention-specific settings persistence on a narrow settings-only write path instead of rewriting story rows alongside privacy toggles.
  - Keep profile and active-child mutations on the existing snapshot writer for now; they are outside `M2.5`.
  - Preserve current continuity cleanup ownership in `StoryLibraryStore` and harden it by pruning against the post-retention persisted library state.
- Risks/Notes: Child fallback visibility remains unchanged and is now the next data-isolation priority. Some non-retention profile/privacy mutations still use snapshot writes. `saveRawAudio` still exists as a compatibility field without active behavior.
- Next: M2.6 - Active-child library scoping fix

### 2026-03-07 - M2.6 Active-child library scoping fix

- Status: DONE
- Summary: Removed the saved-story fallback that exposed other children's series when the active child had none, and parameterized child scoping so `NewStoryJourneyView` now resolves continuation choices against its selected child instead of the global active child. Home empty state and past-story picker behavior now stay empty for Nora in the seeded two-child path rather than leaking Milo's saved series.
- Files: `ios/StoryTime/Storage/StoryLibraryStore.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Updated `StoryLibraryStoreTests.testStoryLifecycleVisibilityAndReplacement`, added `StoryLibraryStoreTests.testVisibleSeriesForRequestedChildDoesNotDependOnActiveProfileOrFallback`, and added `StoryTimeUITests.testSavedStoriesAndPastStoryPickerStayScopedToActiveChild`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which passed `29` tests, and `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeUITests/StoryTimeUITests/testSavedStoriesAndPastStoryPickerStayScopedToActiveChild`, which passed `1` UI test.
- Decisions:
  - Keep `visibleSeries(for:)` as the narrow child-scoping surface instead of pushing picker-specific filtering into `NewStoryJourneyView`.
  - Preserve the current compatibility behavior for `nil` `childProfileId` series rows; this milestone removes fallback visibility, not legacy row reassignment.
  - Sanitize `NewStoryJourneyView` launch plans through the scoped selected series so stale cross-child `selectedSeriesId` values cannot leak into continuation mode.
- Risks/Notes: Child deletion still needs a dedicated cascade audit. Some profile/privacy mutations still use snapshot writes. `saveRawAudio` still exists as a compatibility field without active behavior.
- Next: M2.7 - Child-delete cascade behavior

### 2026-03-07 - M2.7 Child-delete cascade behavior

- Status: DONE
- Summary: Made child deletion explicit and reload-safe in the active store. `StoryLibraryStore.deleteChildProfile(_:)` now resolves the post-delete profile set and fallback active selection before mutating state, removes only the deleted child's series, and clears only the deleted child's continuity series IDs in deterministic order. Store regressions now cover deleting the active child while preserving another child's stories, deleting a child without wiping another child's continuity, and recreating the fallback profile after the final child is removed.
- Files: `ios/StoryTime/Storage/StoryLibraryStore.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `StoryLibraryStoreTests.testDeletingActiveChildKeepsOtherChildStoriesAndPersistsFallbackSelectionAcrossReload` and `StoryLibraryStoreTests.testDeletingFinalChildRecreatesFallbackProfileAndClearsStoriesAcrossReload`, and extended `StoryLibraryStoreTests.testDeleteChildProfileClearsOnlyRemovedChildContinuityFacts` with reload assertions. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which passed `31` tests.
- Decisions:
  - Keep child deletion on the current store boundary instead of introducing a wider entity-level profile mutation refactor in this milestone.
  - Preserve deterministic fallback selection as the first remaining sorted child when the active child is deleted, and recreate the default fallback profile only when the final child is removed.
  - Keep continuity cleanup scoped to the deleted child's series IDs instead of broad full-library pruning for this milestone.
- Risks/Notes: Continuity provenance across replace, revise, prune, and child-delete flows still needs the dedicated `M2.8` hardening pass. Some profile/privacy mutations still use snapshot writes. `saveRawAudio` still exists as a compatibility field without active behavior.
- Next: M2.8 - Continuity provenance and cleanup

### 2026-03-07 - M2.8 Continuity provenance and cleanup

- Status: DONE
- Summary: Hardened continuity cleanup across the active lifecycle so semantic facts and structural series continuity now stay attributable to the correct `(seriesId, storyId)` pair. `ContinuityMemoryStore` now prunes by explicit pair provenance instead of separate global series and story sets, `StoryLibraryStore` rebuilds structural continuity from retained episode engine memory after append, replace, and retention prune, and repeat-episode revisions now replace the original story's continuity facts while clearing closed open loops from the saved series metadata.
- Files: `ios/StoryTime/Storage/StoryLibraryStore.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `StoryLibraryStoreTests.testReplaceStoryRebuildsContinuityMetadataAcrossReload`, `StoryLibraryStoreTests.testContinuityMemoryStorePrunesBySeriesAndStoryProvenance`, and `StoryLibraryStoreTests.testRetentionPolicyRebuildsSeriesContinuityMetadataAcrossReload`. Added `PracticeSessionViewModelTests.testRepeatEpisodeRevisionReplacesContinuityFactsAndClearsClosedOpenLoops`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/StoryLibraryStoreTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `73` tests.
- Decisions:
  - Use explicit `(seriesId, storyId)` provenance as the cleanup key for semantic continuity instead of separate global series and story ID sets.
  - Rebuild series structural continuity only when retained episodes actually contain engine memory, so legacy migrated series metadata is preserved when no engine-derived continuity exists to recompute from.
  - Keep repeat-episode revisions indexed under the original persisted story ID and replace both semantic continuity facts and structural open-loop metadata for that saved episode.
- Risks/Notes: Some profile/privacy mutations still use snapshot writes. `saveRawAudio` still exists as a compatibility field without active behavior. The next priority is the broader safe application error model for non-startup failures.
- Next: M3.1 - Safe application error model

### 2026-03-07 - M3.1 Safe application error model

- Status: DONE
- Summary: Added the typed iOS app error model for child-safe client-visible failures and routed the remaining non-startup coordinator failure paths through it. `StoryTimeAppErrorCategory` and `StoryTimeAppError` now define explicit startup, moderation block, network failure, backend failure, decode failure, persistence failure, and cancellation categories. `PracticeSessionViewModel` now maps discovery, generation, revision, runtime voice error, and disconnect failures to safe typed copy, records moderation-block notices without failing the session, and restores discovery and revision cancellation to recoverable states instead of failing the session.
- Files: `ios/StoryTime/Models/StoryDomain.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `PracticeSessionViewModelTests.testBlockedGenerationUsesModerationCategoryAndSafeMessage`, `PracticeSessionViewModelTests.testBlockedRevisionUsesModerationCategoryAndSafeMessage`, `PracticeSessionViewModelTests.testGenerationDecodeFailureUsesSafeAppErrorModel`, `PracticeSessionViewModelTests.testDiscoveryCancellationDoesNotFailSession`, and `PracticeSessionViewModelTests.testRevisionCancellationDoesNotFailSession`. Updated blocked-discovery, startup-category, runtime-voice, and failure-regression tests. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `44` tests.
- Decisions:
  - Keep the typed app-error model on the iOS side in `StoryDomain.swift` so the coordinator can stop surfacing raw transport strings before backend error-code alignment lands.
  - Preserve blocked-story product behavior, but record moderation blocks as typed safe notices even when narration continues.
  - Treat cancellation as non-failure and restore an explicit recoverable session state instead of leaving discovery, generation, or revision in ambiguous in-flight states.
- Risks/Notes: `APIClient` still carries raw response bodies in `APIError.invalidResponse`, so `M3.2` still needs to align backend `AppError` responses and client-safe mapping instead of relying on local heuristics. Realtime region handling is still hardcoded to `"US"`.
- Next: M3.2 - Client/backend error mapping

### 2026-03-07 - M3.2 Client/backend error mapping

- Status: DONE
- Summary: Aligned backend `AppError` responses and client presentation around the backend `{ error, message, request_id }` envelope. `APIClient` now parses structured backend error metadata into `APIError.invalidResponse`, keeps raw bodies out of `localizedDescription`, and preserves backend codes/messages/request IDs for higher-level mapping. `PracticeSessionViewModel` now maps backend codes like `rate_limited`, session-token failures, `unsupported_region`, `revision_conflict`, and realtime transport failures into safe client-visible errors instead of relying only on status-code heuristics.
- Files: `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `backend/src/tests/app.integration.test.ts`, `PLANS.md`, `SPRINT.md`
- Tests: Updated `APIClientTests` to assert backend `error/message/request_id` parsing and safe `localizedDescription` behavior without raw bodies. Added `PracticeSessionViewModelTests.testRevisionConflictUsesBackendPublicMessageAndSafeCategory` and `PracticeSessionViewModelTests.testSessionAuthBackendErrorUsesSafeMappedMessage`, and updated the startup invalid-response fixtures to use the structured error case. Updated backend `app.integration.test.ts` assertions for explicit app-error `message/request_id` and internal-error `message/request_id`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `59` tests, and `npm test -- --run src/tests/app.integration.test.ts`, which passed `20` tests.
- Decisions:
  - Keep raw response bodies available inside `APIError.invalidResponse` for debugging and test assertions, but never surface them through `localizedDescription` or coordinator UI copy.
  - Use backend error codes as the primary mapping input in the coordinator and only pass through backend public messages for explicitly safe codes such as `revision_conflict` and realtime startup transport failures.
  - Keep `422` blocked story flows on their existing typed-success decode path instead of routing them through the new API error mapping.
- Risks/Notes: Correlation IDs are now parsed at the API layer, but the client still does not thread them into diagnostics or session tracing. Realtime region handling is still hardcoded to `"US"`.
- Next: M3.3 - Session correlation IDs and tracing

### 2026-03-07 - M3.3 Session correlation IDs and tracing

- Status: DONE
- Summary: Added end-to-end correlation for the live session path without logging sensitive content. `APIClient` now generates per-request `x-request-id` headers, stores backend `session_id` in `AppSession`, and emits structured trace events for startup, voice fetch, realtime session creation, discovery, generation, revision, and embeddings requests. `PracticeSessionViewModel` now records redacted coordinator trace events for startup, discovery, generation, revision, completion, and failure, keyed by backend request ID and session ID instead of transcript or story text. Backend request-context coverage now pins caller-supplied request ID echo behavior on story routes, and analytics tests now cover session-aware request metrics.
- Files: `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`, `ios/StoryTime/App/UITestSeed.swift`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/request-retry-rate.test.ts`, `PLANS.md`, `SPRINT.md`
- Tests: Added `APIClientTests.testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation`, `PracticeSessionViewModelTests.testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation`, and `PracticeSessionViewModelTests.testFailureTraceCapturesBackendRequestCorrelationWithoutTranscriptContent`. Updated backend request-context and analytics coverage in `request-retry-rate.test.ts` and added discovery-route request ID echo coverage in `app.integration.test.ts`. Verified with `npm test -- --run src/tests/app.integration.test.ts src/tests/request-retry-rate.test.ts`, which passed `26` tests, and `xcodebuild test-without-building -xctestrun /Users/rory/Library/Developer/Xcode/DerivedData/StoryTime-ewjpdnxwahsucuewllqrjpithhfm/Build/Products/StoryTime_StoryTime_iphonesimulator26.2-arm64-x86_64.xctestrun -destination 'platform=iOS Simulator,id=D3A74A52-FCFB-4F45-B476-B9DA6E0B42B6' -only-testing:StoryTimeTests/APIClientTests/testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testFailureTraceCapturesBackendRequestCorrelationWithoutTranscriptContent -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionWithRealAPIClientExecutesFullStartupContractSequence`, which passed `4` targeted tests.
- Decisions:
  - Keep trace payloads structured and redacted. Do not store transcript or story text in transport or coordinator trace events.
  - Keep transport-level trace emission in `APIClient` and semantic session trace emission in `PracticeSessionViewModel` instead of collapsing both layers into one log stream.
  - Persist `session_id` in `AppSession` so correlation stays available to client diagnostics without pushing identifiers into UI strings.
- Risks/Notes: Backend lifecycle logging still needs expansion in `M3.4` so correlation metadata shows up consistently in backend operational logs, not only tests and client traces. Realtime region handling is still hardcoded to `"US"`.
- Next: M3.4 - Backend lifecycle logging

### 2026-03-07 - M3.4 Backend lifecycle logging

- Status: DONE
- Summary: Added structured, request-scoped backend lifecycle logs for the active realtime and story pipeline. `RealtimeService`, `StoryDiscoveryService`, and `StoryService` now emit redacted `lifecycle_event` logs for start, completion, blocked, retry, and failure paths across realtime ticket issuance, realtime call proxying, discovery, story generation, and story revision. The logs use request-bound child loggers so request ID, session ID, route, region, install hash, and auth level stay correlated without including transcript text, story text, SDP bodies, or raw upstream response bodies.
- Files: `backend/src/lib/lifecycle.ts`, `backend/src/services/realtimeService.ts`, `backend/src/services/storyDiscoveryService.ts`, `backend/src/services/storyService.ts`, `backend/src/tests/model-services.test.ts`, `backend/src/tests/story-engine-advanced.test.ts`, `backend/src/tests/testHelpers.ts`, `PLANS.md`, `SPRINT.md`
- Tests: Added service-level logging regressions for realtime lifecycle retry/completion redaction, discovery retry redaction, generate retry/completion redaction, and revise failure redaction. Verified with `npm test -- --run src/tests/model-services.test.ts src/tests/story-engine-advanced.test.ts src/tests/request-retry-rate.test.ts src/tests/app.integration.test.ts`, which passed `45` tests.
- Decisions:
  - Keep lifecycle logging independent of analytics flags so operational logs remain available even when usage metering is disabled.
  - Use request-context child loggers for lifecycle logs instead of building a second correlation mechanism.
  - Log only safe metadata such as counts, phases, retry timing, and error codes/status; do not log transcript content, story text, SDP bodies, or raw upstream bodies.
- Risks/Notes: Privacy truthfulness still needs an explicit audit across storage, transport, and logs in `M3.5`, and realtime region handling remains hardcoded to `"US"`.
- Next: M3.5 - Real data-flow and privacy audit

### 2026-03-07 - M3.5 Real data-flow and privacy audit
- Status: DONE
- Summary: Audited the active privacy-relevant data flow across the iOS app, realtime bridge, backend routes, persistence layer, and observability stack. The new audit doc confirms that raw audio is not persisted in active code, but live microphone audio leaves the device during realtime sessions; saved story history stays local after completion, but discovery transcripts, generation inputs, revision inputs, generated story content, and embeddings requests cross the network during processing. The audit also pinned the main copy mismatches for the next milestone: "Stories stay on device" is too broad, "Raw audio is not saved by default" is misleading because there is no active save path at all, and transcript clearing is local-only.
- Files: `docs/privacy-data-flow-audit.md`, `PLANS.md`, `SPRINT.md`
- Tests: No code-path tests were required or added for this milestone because `M3.5` is an audit milestone and no behavior changes landed.
- Decisions:
  - Treat `saveRawAudio` as compatibility-only state until a later removal or explicit product decision.
  - Keep `M3.6` focused on privacy-copy alignment instead of mixing the audit with behavior changes.
- Risks/Notes: Parent-facing trust copy is now the main privacy-truthfulness gap. Realtime region handling is still hardcoded to `"US"`, and the parent trust surface still has no access gate.
- Next: M3.6 - Privacy copy alignment

### 2026-03-07 - M3.6 Privacy copy alignment
- Status: DONE
- Summary: Updated the parent-facing and child-facing privacy language in the home screen, new-story journey, voice session, and parent controls so the app no longer implies the entire story loop stays on device. The copy now states the active behavior directly: raw audio is not saved, story prompts and generated stories are sent for live processing, saved history stays on device after completion, and transcript clearing is local on-screen cleanup when enabled.
- Files: `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `docs/privacy-data-flow-audit.md`, `PLANS.md`, `SPRINT.md`
- Tests: Added `PracticeSessionViewModelTests.testPrivacySummaryMentionsLocalTranscriptClearingWhenEnabled`, updated `PracticeSessionViewModelTests.testPrivacySummaryElseBranchAndMockChildSpeechIdleAreSafe`, and added `StoryTimeUITests.testPrivacyCopyReflectsLiveProcessingAndLocalRetention`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/PracticeSessionViewModelTests`, which passed `49` tests, and `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeUITests/StoryTimeUITests/testPrivacyCopyReflectsLiveProcessingAndLocalRetention`, which passed `1` UI test.
- Decisions:
  - Keep the copy explicit about live processing without adding a new privacy settings surface in this milestone.
  - Keep `saveRawAudio` as compatibility-only schema state for now instead of mixing removal into the copy-alignment pass.
- Risks/Notes: The wording is now aligned to the audited behavior, but region handling is still hardcoded to `"US"` and transport/config hardening is still required. Parent controls still have no access gate.
- Next: M3.7 - Transport and config hardening

### 2026-03-07 - M3.7 Transport and config hardening
- Status: DONE
- Summary: Tightened the remaining client and backend transport/config assumptions without changing the core product loop. The app backend URL is now owned by bundle config plus environment override precedence, app transport security now permits only local networking instead of arbitrary insecure loads, authenticated startup and story requests recover once from stale session tokens by re-bootstrapping session identity, and bridge-load failures now fail immediately instead of waiting only on timeout. Backend env loading now rejects invalid session refresh windows and unsafe production defaults for origin/auth requirements.
- Files: `ios/StoryTime/App/AppConfig.swift`, `ios/StoryTime/App/Info.plist`, `ios/StoryTime/project.yml`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Core/RealtimeVoiceClient.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`, `backend/src/lib/env.ts`, `backend/src/tests/coverage-hardening.test.ts`, `backend/src/tests/auth-security.test.ts`, `PLANS.md`, `SPRINT.md`
- Tests: Added `APIClientTests.testCreateRealtimeSessionRefreshesStaleSessionTokenAndRetriesOnce`, `PracticeSessionViewModelTests.testStartSessionRefreshesStaleSessionTokenBeforeRealtimeStartupFails`, `RealtimeVoiceClientTests.testConnectFailsWhenBridgeNavigationFailsBeforeReady`, and new `SmokeTests` coverage for bundle URL precedence plus ATS config. Updated backend env/auth coverage in `coverage-hardening.test.ts` and `auth-security.test.ts`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests -only-testing:StoryTimeTests/SmokeTests`, which passed `83` tests, and `npm test -- --run src/tests/coverage-hardening.test.ts src/tests/auth-security.test.ts src/tests/app.integration.test.ts`, which passed `36` tests.
- Decisions:
  - Keep region behavior out of this milestone; only isolate backend URL config and transport/auth assumptions here.
  - Keep the deployed backend URL configurable through `StoryTimeAPIBaseURL` with the existing hosted backend as compatibility fallback until a later deployment-config cleanup pass.
  - Recover stale session tokens once inside `APIClient` instead of pushing transport-auth recovery into the coordinator.
- Risks/Notes: The main remaining client transport/config gap is the hardcoded realtime region `"US"`, which is now isolated to `M3.8`. Parent controls still have no lightweight access gate, and the full critical path still lacks a dedicated acceptance harness.
- Next: M3.8 - Region handling alignment

### 2026-03-07 - M3.8 Region handling alignment
- Status: DONE
- Summary: Replaced the remaining hardcoded realtime region path with an explicit region flow owned by backend policy. `APIClient` now resolves region from `/health` metadata or `/v1/session/identity`, stores it alongside session state, sends `x-storytime-region` on follow-on requests, and aligns realtime session request bodies to the same value. Startup unsupported-region failures now preserve the safe region-specific user message.
- Files: `ios/StoryTime/Models/Analysis.swift`, `ios/StoryTime/Models/Scenario.swift`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `backend/src/tests/request-retry-rate.test.ts`, `backend/src/tests/app.integration.test.ts`, `PLANS.md`, `SPRINT.md`
- Tests: Added `APIClientTests.testResolvedHealthRegionPropagatesAcrossBootstrapAndRealtimeSession`, `PracticeSessionViewModelTests.testStartSessionUsesResolvedBackendRegionDuringRealtimeStartup`, `PracticeSessionViewModelTests.testStartupUnsupportedRegionFailureUsesSafeMessage`, backend request-context default-region coverage in `request-retry-rate.test.ts`, and backend integration coverage for region echo during `/v1/session/identity`. Verified with `npm test -- --run src/tests/request-retry-rate.test.ts src/tests/app.integration.test.ts`, which passed `27` tests, and targeted iOS verification via `xcodebuild test-without-building -xctestrun /Users/rory/Library/Developer/Xcode/DerivedData/StoryTime-ewjpdnxwahsucuewllqrjpithhfm/Build/Products/StoryTime_StoryTime_iphonesimulator26.2-arm64-x86_64.xctestrun -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityStoresSessionToken -only-testing:StoryTimeTests/APIClientTests/testResolvedHealthRegionPropagatesAcrossBootstrapAndRealtimeSession -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionUsesResolvedBackendRegionDuringRealtimeStartup -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartupUnsupportedRegionFailureUsesSafeMessage -only-testing:StoryTimeTests/SmokeTests/testAppConfigHasURL`, which passed `5` tests.
- Decisions:
  - Backend policy now owns region choice for the iOS client; the client learns region from backend metadata and does not maintain a separate user-facing region picker.
  - `x-storytime-region` is now the canonical client transport signal for region, and realtime session request bodies are aligned to that same resolved value.
  - Unsupported-region startup failures stay safe and explicit instead of silently falling back to generic startup copy.
- Risks/Notes: Parent controls still have no lightweight access gate, and there is still no dedicated critical-path acceptance harness.
- Next: M3.9 - Lightweight parent access gate

### 2026-03-07 - M3.9 Lightweight parent access gate
- Status: DONE
- Summary: Added a deliberate local confirmation gate around the parent trust surface without widening into broader auth work. `HomeView` now opens a lightweight gate sheet first, and parent controls only open after the parent types `PARENT`. A direct tap on the home-screen parent button no longer opens the trust center directly.
- Files: `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `StoryTimeUITests.testParentControlsRequireDeliberateGateBeforeOpening` and updated the existing parent-controls UI flows to unlock through the new gate before asserting on parent settings. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsRequireDeliberateGateBeforeOpening -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRenderAndAddAChildProfile -only-testing:StoryTimeUITests/StoryTimeUITests/testPrivacyCopyReflectsLiveProcessingAndLocalRetention`, which passed `3` UI tests.
- Decisions:
  - Keep the gate local and friction-based for the current scope instead of introducing stored credentials, biometrics, or backend auth.
  - Use a typed confirmation gate rather than a gesture gate because it is easier to reason about and more reliable under UI automation.
- Risks/Notes: This is a lightweight trust-boundary gate, not strong parent authentication. The main remaining program gap is still the missing critical-path acceptance harness.
- Next: M3.10 - Reliability acceptance harness

### 2026-03-07 - M3.10.1 Acceptance harness foundation and happy path
- Status: DONE
- Summary: Split the oversized acceptance milestone into smaller slices, then landed the first reusable acceptance-harness layer on top of the existing mock API and mock realtime voice core. The new harness runs the no-network happy path through startup, discovery, generation, narration, interruption, revision, completion, and save, then reloads the store to prove the revised story persisted correctly.
- Files: `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `PracticeSessionViewModelTests.testCriticalPathAcceptanceHappyPathExercisesFullCoordinatorLifecycle` and `PracticeSessionViewModelTests.testCriticalPathAcceptanceHappyPathPersistsRevisedStoryAcrossReload`. Verified with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testCriticalPathAcceptanceHappyPathExercisesFullCoordinatorLifecycle -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testCriticalPathAcceptanceHappyPathPersistsRevisedStoryAcrossReload`, which passed `2` tests.
- Decisions:
  - Keep the first acceptance slice inside `PracticeSessionViewModelTests` to avoid xcodeproj churn while still creating a reusable scenario runner.
  - Split the original `M3.10` into happy-path, failure-injection, and child-isolation slices so each run stays bounded and testable.
- Risks/Notes: The acceptance harness now proves the happy path end to end, but failure-injection coverage and child-isolation acceptance coverage still remain before the overall harness milestone is complete.
- Next: M3.10.2 - Failure injection acceptance coverage

## In Progress

- Explicit client session states already exist in `StoryDomain.swift`.
- `PracticeSessionViewModel` already centralizes most discovery, generation, narration, interruption, revision, and completion behavior.
- Phase 1 core voice reliability milestones are now complete and covered by targeted regressions.
- `PracticeSessionViewModel` now derives `phase` from `sessionState`, so future transition work can tighten around the canonical state model without a parallel mutable phase flag.
- Discovery, generation, and narration progression now use explicit source-owned transition guards and stale-result regressions.
- Interruption and revision overlap is now serialized with deferred transcript rejection for generation/revision-origin speech and a bounded single-entry revision queue.
- iOS tests already exist for session progression, interruption, revision queuing, invalid transitions, duplicate completion prevention, API handling, bridge behavior, and story storage.
- Backend tests already exist for auth/security, realtime proxying, discovery, story generation and revision, planner logic, type validation, and app integration.
- The startup sequence and active startup assumptions are now documented in `docs/realtime-startup-audit.md`.
- The startup contract now has dedicated client and backend regression tests.
- The coordinator now uses a typed `StoryTimeAppError` model for startup, moderation, network, backend, decode, and cancellation handling instead of surfacing raw transport strings from non-startup failure paths.
- The story library/profile/privacy path and continuity facts now persist through the Core Data-backed v2 store, and the legacy continuity blob is retired after import.
- The active story lifecycle now persists through direct v2 series and episode operations instead of full-snapshot rewrites.
- Retention pruning and save-history-off cleanup now operate against the migrated entity store and are covered by reload regressions plus shared continuity cleanup assertions.
- Saved-story list visibility and the new-story continuation picker now scope strictly to the active or selected child instead of falling back to another child's series when a child has no stories.
- Child deletion now preserves other-child stories across reload, keeps continuity cleanup scoped to the deleted child's series, and recreates the default fallback profile only when the final child is removed.
- Continuity cleanup is now provenance-safe across replace, revise, prune, delete-series, and child-delete flows, and repeat-episode revisions now clear stale open-loop metadata instead of leaving old future-scene continuity behind.
- The coordinator now exposes a typed `StoryTimeAppError` model, keeps moderation-block notices typed even when the session continues, and restores discovery/generation/revision cancellation to recoverable states instead of failing the session.
- The client now preserves backend error codes, public messages, and request IDs inside `APIError.invalidResponse`, while `PracticeSessionViewModel` maps those structured backend signals into safe app errors instead of raw response-body text.
- The client now generates request IDs, stores backend `session_id`, and records redacted trace events at both the API and coordinator layers so critical-path activity can be correlated without logging transcript content.
- Backend services now emit request-scoped redacted lifecycle logs across realtime, discovery, generate, and revise start/retry/completion/failure paths, and those hooks are pinned by backend service tests.
- The audited privacy copy is now aligned in the home, journey, voice, and parent-control surfaces, and the transport/config plus region-alignment passes are now complete.
- `HomeView` now routes parent controls through a lightweight local confirmation gate before switching the sheet into `ParentTrustCenterView`, so the parent trust surface no longer opens from a single tap.
- The acceptance harness now has a reusable no-network happy-path runner for startup through save; the remaining harness work is failure injection and child-isolation coverage.

## Blockers

- No external blocker is visible in the repository.

## Open Decisions

- Should install identity and session token storage stay in `UserDefaults`, keychain, or a split model after hardening?
- What exact client redaction policy should observability use for transcripts and story text?

## Next Recommended Milestone

M3.10.2 - Failure injection acceptance coverage

The next step is to extend the new acceptance harness with startup failure, disconnect, revision-overlap, and duplicate-completion scenarios so the full hardening work is validated by a repeatable suite instead of only targeted regressions.

## Update Rules

- Read `AGENTS.md` and `SPRINT.md` before updating this file.
- After every run, update milestone statuses here so they match `SPRINT.md`.
- Append new entries to `Completed Work Log`. Do not rewrite or delete prior entries.
- If a milestone is split, update `SPRINT.md` first, then update this file to match the new milestone IDs.
- Record blockers, open decisions, and newly discovered risks when they materially change execution.
- Keep the next recommended milestone aligned with the first incomplete milestone in `SPRINT.md`, unless a blocker is explicitly recorded here.
