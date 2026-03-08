# PLANS.md

## Product Summary

StoryTime is a voice-first iOS app for generating child-safe personalized audio stories.

Product position in the active codebase and plan:
- StoryTime lets kids shape the story while it's happening.

Current active product shape in code:
- SwiftUI iOS app in `ios/StoryTime`
- TypeScript/Express backend in `backend`
- Hidden `WKWebView` realtime bridge for live voice transport
- Live discovery, generation, narration, interruption, revision, and continuation flow
- Local story continuity and story history stored on device

Archived code in `tiny-backend/` is not part of the active product.

## Current Program Goal

Turn the verified hybrid runtime into a productized, monetization-aware StoryTime experience without weakening the runtime gate.

The current goal is to use the accepted hybrid runtime as the baseline for the next productization phase:
- keep realtime for low-latency live interaction
- keep TTS for long-form scene narration
- keep structured story state and scene state as the authoritative control layer
- use runtime-stage cost and latency telemetry to inform pricing and package boundaries
- define onboarding, upgrade, and parent-trust flows as product journeys rather than isolated screens
- add entitlement and paywall architecture before revenue-facing UI implementation
- polish core child and parent surfaces only on top of the verified runtime baseline

## Current Phase

Phase 7 - Productization, Monetization, And Polished UX

## Overall Status Snapshot

- The active iOS flow is `HomeView` -> `NewStoryJourneyView` -> `VoiceSessionView` -> `PracticeSessionViewModel`.
- The active client session coordinator already uses an explicit `VoiceSessionState` model in `StoryDomain.swift`.
- The active realtime client still uses a hidden `WKWebView` bridge in `RealtimeVoiceClient.swift` and `RealtimeVoiceBridgeView.swift`.
- The active runtime now uses coordinator-owned TTS narration for long-form scene delivery while keeping the realtime bridge for live interaction startup, interruption intake, and short spoken interaction responses.
- Structured story state already exists as `StoryData` plus ordered `StoryScene` arrays, and the coordinator already tracks authoritative `currentSceneIndex` state.
- Revision is already future-scene scoped in active code: the client sends `completedScenes` and `remainingScenes`, and the backend returns revised scenes starting from `current_scene_index`.
- The active backend already exposes `/v1/session/identity`, `/v1/realtime/session`, `/v1/realtime/call`, `/v1/story/discovery`, `/v1/story/generate`, `/v1/story/revise`, and `/v1/embeddings/create`.
- The backend already has signed session identity, signed realtime tickets, request context, and analytics hooks.
- Primary story storage now lives in the Core Data-backed `storytime-v2.sqlite` store; `UserDefaults` remains for install/session bootstrap keys and legacy migration source blobs only.
- The current test baseline already covers key iOS session logic, API handling, bridge behavior, hybrid narration transport, interruption routing, persistence, backend auth/security, discovery, planner logic, story services, and integration routes.
- The stable hybrid validation slice is green through `M5.1`, and the earlier revision-index mismatch was confirmed as regression-fixture drift rather than a live runtime defect.
- The current test baseline is strongest around startup, coordinator determinism, interruption/revision, hybrid narration transport, persistence, child isolation, and backend contract handling.
- `docs/verification/hybrid-runtime-end-to-end-report.md` now records the first explicit post-migration end-to-end verification pass, using the required evidence labels and the current stable validation command results.
- `docs/verification/realtime-voice-determinism-report.md` now refreshes the narrower interaction-path audit for the active hybrid runtime, including the TTS-to-realtime boundary and explicit no-reconnect semantics.
- `docs/verification/runtime-stage-telemetry-verification.md` now records the current stage-based telemetry evidence, including explicit grouped stages for `interaction`, `generation`, `narration`, and `revision` plus supporting-stage treatment for `continuity_retrieval`.
- `docs/verification/hybrid-runtime-validation.md` now defines the explicit hybrid-runtime acceptance regression pack, including the exact command, required covered scenarios, and intentionally excluded cases.
- `docs/verification/parent-child-storytelling-ux-audit.md` now records the first post-verification UX audit for the active parent/child storytelling flow, separating parent trust-boundary issues from child storytelling-loop issues and turning them into small follow-up milestones.
- `docs/productization-user-journey-alignment.md` now maps the active parent/child journeys, value moments, trust moments, friction points, and candidate upgrade moments for the productization phase.
- `docs/monetization-entitlement-architecture.md` now defines the first repo-fit monetization direction, including candidate free versus paid boundaries, the split entitlement ownership model, backend preflight touchpoints, and the main pricing-confidence gaps.
- `docs/onboarding-first-run-audit.md` now defines the first-run direction, including the current implicit setup flow, the role of the fallback `Story Explorer` profile, and the recommended parent-led onboarding sequence before the first story starts.
- `docs/paywall-upgrade-entry-strategy.md` now defines where upgrade prompts belong, which ones stay parent-managed, which surfaces stay upgrade-free, and how hard gates should align to the entitlement preflight model.
- `docs/end-of-story-repeat-use-loop.md` now defines the intended post-story product loop, including how completion should bridge into replay, new-episode continuation, and return-to-library behavior without interrupting the finished child session.
- `HomeView` now carries clearer product framing for the quick-start path, an actionable parent-controls entry inside the trust card, and saved-library summaries that make replay and continuation value explicit without introducing blocking upgrade UI.
- `NewStoryJourneyView` now reads as a clearer preflight setup surface, with explicit parent handoff, story-path setup, length-and-pacing guidance, and live-session expectation framing before the child enters the voice session.
- `VoiceSessionView` now presents a coordinator-derived session cue card and action hint so the live session exposes clearer listening, narration, answer, revision, pause, and failure cues without changing transport or coordinator behavior.
- `StorySeriesDetailView` now leads with continuation actions, frames continuity as next-episode memory, and keeps parent-only history management separate from replay and new-episode intent.
- Parent trust and privacy communication is now more cohesive across `HomeView`, the lightweight parent gate, `ParentTrustCenterView`, `NewStoryJourneyView`, and `VoiceSessionView`, with clearer distinctions between what stays on device, what goes live during a session, and what the `PARENT` check does not claim to be.
- There is currently no StoreKit, subscription, entitlement, paywall, or dedicated first-run onboarding implementation in the active repo; the only monetization groundwork present today is runtime-stage telemetry and cost-driver tracing.

## Current Architectural Notes

- `VoiceSessionView` starts the session in `.task` and hosts the hidden realtime bridge view for live interaction while the coordinator owns long-form narration transport.
- `PracticeSessionViewModel` coordinates boot, discovery, generation, TTS narration, interruption, answer-only handling, future-scene revision, completion, and local save behavior.
- Long-form narration is coordinator-owned through `StoryNarrationTransporting`; realtime interaction is reserved for live startup, interruption intake, and short spoken interaction responses.
- `PracticeSessionViewModel.phase` is now derived from `sessionState` instead of stored separately, so the canonical `VoiceSessionState` is the single source of truth for the active session phase.
- The active hybrid runtime now separates behavior into:
  - interaction mode: live listening, question answering, and interruption intake
  - narration mode: long-form scene playback, targeted to TTS instead of the realtime bridge
  - authoritative story state: generated scenes, current scene index, and future-scene revision ownership
- `PracticeSessionViewModel` now categorizes startup failures explicitly as health check, session bootstrap, realtime session creation, bridge readiness, call connect, and disconnect-before-ready.
- `PracticeSessionViewModel` now maps startup failures to safe child-facing copy and resolves boot-time disconnect and bridge error callbacks immediately instead of letting them race the boot completion path.
- Current interruption handling already uses the hybrid seam: user speech during `.narrating(sceneIndex:)` or `.paused(sceneIndex:)` moves the coordinator into `.interrupting(sceneIndex:)`, then routes answer-only, repeat/clarify, or revise-future-scenes while keeping scene index continuity explicit.
- Answer-only handling is now explicit and deterministic. The coordinator classifies interruption intent before deciding whether to answer locally, replay the current boundary, or call the backend future-scene revision path.
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
- The repo now has an active TTS narration path plus bounded one-scene-ahead prepared narration caching, but it still does not have a broader cloud TTS asset pipeline or persisted scene-audio cache.
- Runtime-stage telemetry is now active and stage-grouped: the client records redacted stage-attributed latency for API and local hybrid work, and the backend usage meter now keys OpenAI usage by detailed runtime stage plus the primary stage groups `interaction`, `generation`, `narration`, and `revision`.
- The active product keeps saved story history and continuity local after completion, but discovery transcripts, generation inputs, revision inputs, generated story content, and embeddings requests cross the network during processing.
- Raw audio is not persisted in active code, but the realtime bridge sends live microphone audio off device over WebRTC after backend-mediated SDP setup.
- `clearTranscriptsAfterSession` currently clears only the local in-memory session transcript, not already transmitted discovery or revision text.
- `PracticeSessionViewModel` now uses the backend-aligned resolved region when creating realtime sessions instead of hardcoding `"US"`.
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
- Phase 1 voice-session reliability hardening, Phase 2 data integrity/isolation hardening, Phase 3 transport/privacy hardening, and the main hybrid migration milestones are complete for the current plan; the next major risk is making UX/productization decisions without outrunning the known runtime exclusions.
- The stable hybrid validation slice is green through `M5.1`, and no live blocker remains from the earlier revision-index mismatch because that issue was regression-fixture drift, not a runtime defect.
- The main remaining runtime risk is still partial verification depth at the bridge layer: the live interaction path lacks a real WebRTC acceptance harness even after the narrower `M6.2` audit.
- Stage-level telemetry is now explicit, but narration is still measured primarily at TTS preparation time rather than full playback wall-clock, and commercialization thresholds remain undecided.
- Story lifecycle writes and retention pruning no longer rewrite the full library snapshot, but some profile/privacy mutations still use snapshot writes.
- Legacy library/profile/privacy blobs are now migration-source only and the legacy continuity blob is retired after import, but install/session bootstrap keys still remain in `UserDefaults` by design.
- Child-profile story visibility, child-delete cascade behavior, and continuity cleanup are now scoped and reload-safe for owned rows, but some profile/privacy mutations still use snapshot writes.
- Legacy `StorySeries.childProfileId == nil` rows are still compatibility-visible until a later cleanup or reassignment pass, so child scoping is strict for owned rows but not yet full legacy remediation.
- Continuity cleanup now follows persisted `(seriesId, storyId)` provenance across replace, revise, prune, delete-series, and child-delete flows, and the audited privacy copy is now aligned to the active behavior.
- `saveRawAudio` exists in the persisted privacy schema but has no active UI or storage behavior, so the privacy-copy pass must resolve whether it stays as compatibility-only state or is removed later.
- `saveRawAudio` still exists as compatibility-only persisted state even though the UI now states the active product behavior directly.
- Parent controls now require a local confirmation gate, but this remains lightweight friction rather than full parent authentication.
- The acceptance pack is now explicit and green, but it still intentionally excludes a live bridge/WebRTC harness, full playback wall-clock narration telemetry, and the broader revised-story persistence acceptance path while revision-index logging noise remains unresolved.
- Saved-story deletion now lives behind the parent trust boundary and the global clear-history scope is explicit, but the parent gate remains lightweight friction rather than strong authentication.
- The launch plan, live session, and saved-story detail now explain the hybrid loop more clearly, `M8.1` maps the current journeys, `M8.2` defines a repo-fit entitlement model, `M8.3` defines the intended first-run sequence, and `M8.4` now defines upgrade-entry rules, but there is still no onboarding, StoreKit, purchase-sync, or paywall implementation in the active repo.
- Runtime-stage telemetry exists and `M8.2` now turns it into package-boundary direction, but the repo still lacks pricing-confidence thresholds, exact cap numbers, and joined session-cost export.
- The current `M8` queue is complete, but the repo still has no onboarding implementation, StoreKit layer, entitlement sync, or paywall UI, so the next run should be a planning pass instead of ad hoc implementation.

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
| M3.10.1a Critical-path verification pass | DONE | Targeted verification report now records flow-by-flow evidence, confidence, and remaining gaps; delete-all-history has new end-to-end UI coverage. |
| M3.10.2 Failure injection acceptance coverage | DONE | Stable hybrid validation slice now covers startup failure, disconnect during narration, revision-overlap queuing, and duplicate-completion/save protection. |
| M3.10.3 Child isolation acceptance coverage and validation command | DONE | Stable hybrid validation command now includes seeded multi-child UI coverage for saved-story and past-story-picker isolation. |
| M5.1 Coordinator revision-index logging hardening | DONE | The known revision-index mismatch was regression-fixture drift only, and the stable hybrid validation slice stays green without the stale log line. |
| M6.1 Hybrid runtime end-to-end verification report | DONE | `docs/verification/hybrid-runtime-end-to-end-report.md` now records the current hybrid-runtime evidence base, coverage labels, and follow-on gaps for `M6.2` through `M6.4`. |
| M6.2 Realtime interaction-path determinism audit | DONE | `docs/verification/realtime-voice-determinism-report.md` now reflects the active hybrid runtime, targeted realtime/backend evidence, explicit TTS-to-realtime handoff findings, and intentional terminal disconnect semantics. |
| M6.3 Stage-level cost and latency telemetry verification | DONE | `docs/verification/runtime-stage-telemetry-verification.md` now records grouped runtime-stage telemetry evidence, support-stage treatment, and the current measurement limits before acceptance-pack consolidation. |
| M6.4 Hybrid runtime acceptance regression pack | DONE | `docs/verification/hybrid-runtime-validation.md` now defines the explicit default runtime gate, and the stable validation command now covers happy path, startup failure, disconnect, answer-only, revise-future-scenes, pause/resume, child isolation, and telemetry assertions. |
| M7.1 UX audit for parent/child storytelling flow | DONE | `docs/verification/parent-child-storytelling-ux-audit.md` now separates parent trust-boundary issues from child storytelling-loop issues and queues the next implementation-ready UX milestones. |
| M7.2 Parent trust-boundary hardening for saved-story management | DONE | Child-facing saved-story detail now defers destructive actions to parent controls, parent controls manage single-series deletion, and the global clear-history copy now states its full on-device scope explicitly. |
| M7.3 Launch-plan clarity for continuity choices | DONE | `NewStoryJourneyView` now explains live follow-up before narration, makes fresh-story versus continue-story behavior explicit, and truthfully scopes character reuse to selected saved-series context. |
| M7.4 Live session interaction-state clarity | DONE | `VoiceSessionView` now exposes a child-facing session cue card plus action hint layer for listening, narration, answer, revision, pause, and failed states without changing coordinator behavior. |
| M7.5 Saved-story detail information hierarchy pass | DONE | `StorySeriesDetailView` now leads with continuation actions, reframes continuity as next-episode memory, and isolates parent-only history management into a secondary section. |
| M8.1 Productization planning and user-journey alignment | DONE | `docs/productization-user-journey-alignment.md` now maps the active journeys, value moments, trust moments, friction points, and candidate upgrade moments across the current surfaces. |
| M8.2 Monetization model and entitlement architecture | DONE | `docs/monetization-entitlement-architecture.md` now defines the first package-boundary candidates, split entitlement ownership, backend preflight shape, and the remaining pricing-confidence gaps before paywall UI work. |
| M8.3 Onboarding and first-run flow audit and direction | DONE | `docs/onboarding-first-run-audit.md` now distinguishes the current implicit first-run path from the intended parent-led onboarding sequence and the supporting trust/value/setup steps. |
| M8.4 Paywall and upgrade entry-point strategy | DONE | `docs/paywall-upgrade-entry-strategy.md` now prioritizes the approved upgrade surfaces, parent-managed versus child-visible rules, hard-gate timing, and explicitly excluded runtime surfaces. |
| M8.5 Home and Library product polish pass | DONE | `HomeView` now frames the quick-start promise more clearly, routes parent controls from the trust card, and makes saved-story replay/continuation value explicit on the home library surface. |
| M8.6 New Story setup polish pass | DONE | `NewStoryJourneyView` now frames pre-session setup as a clearer productized preflight with explicit parent handoff, launch expectations, and length/continuity guidance while preserving truthful hybrid-runtime behavior. |
| M8.7 End-of-story and repeat-use loop design pass | DONE | `docs/end-of-story-repeat-use-loop.md` now defines the completion acknowledgement surface, the approved replay/continue/home next-step order, and the role of later completion-loop upgrade treatment without widening into implementation. |
| M8.8 Parent trust and privacy communication refinement | DONE | Home, the parent gate and hub, setup, and the live session now use tighter trust and privacy language that stays accurate about live processing, on-device retention, and the lightweight parent boundary. |

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

### 2026-03-07 - Backend realtime SDP schema/test alignment
- Status: DONE
- Summary: Fixed the backend verification mismatch without changing the active realtime contract. The `/v1/realtime/call` path already intentionally required real WebRTC SDP with a media section and DTLS fingerprint on both the incoming offer and upstream answer; only `backend/src/tests/types.test.ts` was stale and still accepted a loose `v=0` prefix string. Updated the schema tests to use valid offer SDP, preserved the byte-for-byte trailing-CRLF assertion, and added a focused regression proving truncated SDP without `m=` or `a=fingerprint:` is rejected.
- Files: `backend/src/types.ts`, `backend/src/tests/types.test.ts`, `PLANS.md`, `SPRINT.md`
- Tests: Updated `types.test.ts` to align with the active `/v1/realtime/call` contract and added focused invalid-SDP assertions. Verified with `npm test`, which passed the full backend suite with `82` tests.
- Decisions:
  - Keep the stricter SDP validator. It matches the active route, realtime service, and existing backend integration/service coverage for the WebRTC proxy contract.
  - Treat the previous `types.test.ts` expectations as stale rather than loosening runtime validation for malformed offers.
- Risks/Notes: This run only aligned backend schema tests to the existing realtime contract. The next planned product milestone remains the acceptance-harness failure-injection slice.
- Next: M3.10.2 - Failure injection acceptance coverage

### 2026-03-07 - M3.10.1a Critical-path verification pass
- Status: DONE
- Summary: Ran a focused verification pass against the highest-value StoryTime flows and recorded the results in `docs/verification/critical-path-verification.md`. The pass combined targeted iOS unit tests, UI tests, backend route/service tests, and code-path inspection across the active UI, coordinator, storage, transport, and backend surfaces. The strongest verified areas are startup, happy-path coordinator progression, repeat-mode behavior, delete-all-history cleanup, child-scoped visibility, and transcript-clearing behavior. The main remaining weak spots are failure-injection acceptance coverage, single-series delete UI coverage, and a dedicated end-to-end assertion for launching from a selected prior story during setup.
- Files: `ios/StoryTime/UITests/StoryTimeUITests.swift`, `docs/verification/critical-path-verification.md`, `PLANS.md`, `SPRINT.md`
- Tests: Added `StoryTimeUITests.testDeleteAllSavedStoryHistoryClearsSeededSeriesFromHome`. Verified with targeted backend tests via `npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts`, targeted iOS unit tests for startup/acceptance/repeat/store/privacy flows, and targeted iOS UI tests covering voice journey, parent gate/settings, privacy copy, child scoping, series detail, and delete-all-history.
- Decisions:
  - Keep this run as verification-only plus one high-signal UI regression instead of widening into failure-injection work.
  - Record partial verification explicitly where coverage is indirect rather than claiming full end-to-end assurance.
- Risks/Notes: The next highest-value gap is still the dedicated acceptance-harness failure-injection slice. Single-series delete still lacks its own UI regression, and the prior-story journey launch path is still verified indirectly rather than by a dedicated end-to-end test.
- Next: M3.10.2 - Failure injection acceptance coverage

### 2026-03-07 - M3.10.1b Realtime voice determinism verification pass
- Status: DONE
- Summary: Audited the realtime voice lifecycle across the active iOS coordinator, hidden `WKWebView` bridge, client API startup path, backend realtime routes/services, and the relevant iOS/backend test surfaces. Recorded the results in `docs/verification/realtime-voice-determinism-report.md`, including the exact startup contract, runtime flow, transcript flow, explicit deterministic guards, inferred bridge assumptions, and the remaining weak spots. The pass found one concrete determinism/privacy issue: a late final transcript could still overwrite coordinator transcript state after the session had already failed or completed. Fixed that by only updating `latestUserTranscript` when the active state can legally consume the final transcript, and added a regression proving a late final after failure no longer mutates terminal transcript state.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `docs/verification/realtime-voice-determinism-report.md`, `PLANS.md`, `SPRINT.md`
- Tests: Verified the backend realtime surface with `npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts src/tests/types.test.ts` (`39` tests passed). Verified the iOS realtime surface with targeted `xcodebuild test` slices covering `RealtimeVoiceClientTests`, `APIClientTests`, and `PracticeSessionViewModelTests` (`35` tests passed), plus a focused coordinator rerun after the transcript fix (`7` tests passed). Added `PracticeSessionViewModelTests.testLateTranscriptAfterFailureDoesNotOverwriteLatestTranscript`.
- Decisions:
  - Keep the realtime startup contract unchanged. The current `/v1/realtime/session` plus `/v1/realtime/call` flow, strict SDP validation, and bridge endpoint resolution are coherent and already pinned by tests.
  - Treat runtime disconnect as intentionally terminal for now, but call out the lack of a reconnect path and a live bridge/WebRTC acceptance harness as remaining reliability risks rather than widening this run into transport redesign.
- Risks/Notes: Startup contract coverage is strong, but actual browser/WebRTC event ordering is still only partially verified because the repo lacks a live `WKWebView` transport harness. Revision queue overflow still silently drops updates beyond one queued item, and late-final transcript coverage now exists for failure but not yet for completion.
- Next: M3.10.2 - Failure injection acceptance coverage

### 2026-03-07 - Hybrid runtime planning reset
- Status: DONE
- Summary: Updated the repo control files to reflect the new product direction: StoryTime lets kids shape the story while it is happening, but long-form narration is no longer planned as a mostly realtime-first path. The active code still uses the realtime bridge for both interaction and narration, while `PracticeSessionViewModel`, `StoryData`, `StoryScene`, and the existing revision API already provide the right authoritative scene-state seam for hybrid migration. The repo is now reframed around a split runtime with realtime interaction, TTS narration, and scene-based story state as the control layer.
- Files: `AGENTS.md`, `PLANS.md`, `SPRINT.md`
- Tests: No code changes or test runs were required for this planning-only pass. Planning was grounded in active runtime, backend, and test-surface inspection before updating the control files.
- Decisions:
  - Keep previous hardening milestones valid as the foundation for hybrid migration instead of resetting the sprint.
  - Move the next implementation step to a hybrid runtime contract milestone before resuming additional acceptance-harness expansion on the old mostly-realtime narration model.
- Risks/Notes: The repo still has no TTS narration path, no interruption intent classifier, no narration preload/cache layer, and no runtime-stage cost telemetry. Those are now explicit execution items instead of implied future work.
- Next: M4.1 - Hybrid runtime contract

### 2026-03-07 - M4.1 Hybrid runtime contract
- Status: DONE
- Summary: Completed the first hybrid migration milestone by writing the implementation-facing runtime contract down in repo terms and adding a tiny typed contract surface in code. `docs/hybrid-runtime-contract.md` now defines the split between realtime interaction, TTS narration, and authoritative story/scene state; maps those boundaries onto the current coordinator and backend shapes; and pins the initial rules for answer-only interruptions, future-scene revision, and narration resume. Added `HybridRuntimeMode`, `HybridInteractionPhase`, `InterruptionIntent`, and `NarrationResumeDecision` to `StoryDomain.swift` as contract markers for later milestones, without changing active runtime behavior.
- Files: `docs/hybrid-runtime-contract.md`, `ios/StoryTime/Models/StoryDomain.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added `HybridRuntimeContractTests` in `PracticeSessionViewModelTests.swift` and verified them with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/HybridRuntimeContractTests`, which passed `3` tests.
- Decisions:
  - Keep the current coordinator state machine (`VoiceSessionState`) as the active runtime authority for now; the new hybrid types are contract markers, not a second live state machine.
  - Make answer-only interaction explicitly non-mutating and keep revise-future-scenes aligned with the existing completed-scenes versus remaining-scenes boundary already used by `/v1/story/revise`.
- Risks/Notes: The contract is now explicit, but there is still no TTS transport, no hybrid mode-transition implementation, and no interruption router. The next milestone should turn the contract into an explicit mode graph before transport migration begins.
- Next: M4.2 - Mode transition state model

### 2026-03-07 - M4.2 Mode transition state model
- Status: DONE
- Summary: Turned the hybrid runtime contract into an explicit finite mode graph without changing active runtime behavior. `StoryDomain.swift` now defines `HybridRuntimeStateNode` and `HybridRuntimeTransitionTrigger` as a pure transition layer derived from the existing coordinator model, plus `VoiceSessionState.hybridRuntimeStateNode` for mapping current coordinator states into hybrid nodes. `docs/hybrid-mode-transition-model.md` records the allowed handoffs for setup interaction, narration, interruption intake, answer-only handling, revise-future-scenes handling, repeat/clarify handling, and terminal states, along with the explicitly rejected transitions and boundary-safe resume rules.
- Files: `docs/hybrid-mode-transition-model.md`, `ios/StoryTime/Models/StoryDomain.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Expanded `HybridRuntimeContractTests` in `PracticeSessionViewModelTests.swift` and verified them with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/HybridRuntimeContractTests`, which passed `6` tests.
- Decisions:
  - Keep the hybrid mode graph as a pure derived layer for now rather than replacing `VoiceSessionState` immediately.
  - Require interruption classification before any narration resume, and keep answer-only and repeat/clarify limited to non-mutating replay of the current scene boundary while revise-future-scenes resumes only through `resumeAtRevisedScene`.
- Risks/Notes: The graph is explicit, but the repo still does not implement the hybrid-specific states at runtime, and setup/generating/discovering remain outside the interaction-versus-narration projection except for the current ready/discovery mapping. The next milestone should define scene-state authority and revision boundaries in implementation-ready detail before TTS or routing work begins.
- Next: M4.3 - Scene-state authority and revision boundary contract

### 2026-03-07 - M4.3 Scene-state authority and revision boundary contract
- Status: DONE
- Summary: Defined the implementation-facing authoritative scene-state contract for hybrid runtime work without changing live coordinator behavior. `StoryDomain.swift` now exposes `AuthoritativeStorySceneState`, `StorySceneBoundary`, `StoryAnswerContext`, `StoryRevisionBoundary`, and `StorySceneMutationScope` so the repo has a typed representation of completed scenes, the current narration boundary, remaining scenes, future-only mutation scope, and explicit resume semantics. The revision contract was tightened to match the product rule: answer-only stays read-only, while revise-future-scenes preserves the current boundary scene and mutates only later scenes.
- Files: `docs/hybrid-runtime-contract.md`, `docs/hybrid-mode-transition-model.md`, `docs/hybrid-scene-state-authority.md`, `ios/StoryTime/Models/StoryDomain.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Expanded `HybridRuntimeContractTests` in `PracticeSessionViewModelTests.swift` and verified them with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/HybridRuntimeContractTests`, which passed the contract slice after adding authoritative scene-state, answer-context, and future-scene revision-boundary coverage.
- Decisions:
  - Treat the current boundary scene as stable during revise-future-scenes. Revision now targets only scenes after that boundary, and the resume path replays the current scene before entering revised future scenes.
  - Keep the backend revise wire shape unchanged for now, but pin the hybrid mapping explicitly: `current_scene_index` becomes the first mutable future scene index, `completed_scenes` includes the preserved current boundary scene, and `remaining_scenes` contains only future scenes.
- Risks/Notes: Live coordinator behavior still uses the old revision path and has not yet been migrated to this future-only boundary contract. That migration should happen together with the dedicated narration transport work, not as an isolated runtime change in this milestone.
- Next: M4.4 - TTS narration pipeline

### 2026-03-07 - M4.4 TTS narration pipeline
- Status: DONE
- Summary: Split long-form narration away from realtime voice output by introducing a dedicated narration transport under `PracticeSessionViewModel` authority. `PracticeSessionViewModel` now drives scene playback through `StoryNarrationTransporting`, with production defaulting to `SystemSpeechNarrationTransport` backed by `AVSpeechSynthesizer`. The coordinator still owns scene advancement, interruption, revision, and completion/save behavior, so narration transport completion cannot invent progress outside the authoritative scene state.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added narration-transport coverage to `HybridRuntimeContractTests` and reran the targeted coordinator slice with `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/HybridRuntimeContractTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNormalSessionProgressionCompletesAndSavesOnce -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes`, which passed `14` tests.
- Decisions:
  - Make TTS the default long-form narration path immediately for the active scene while keeping realtime voice reserved for interaction startup and interruption handling.
  - Keep narration transport thin: it reports scene completion or stop, but it does not own scene indexing, revision scope, or completion/save progression.
- Risks/Notes: This milestone uses system speech playback as the initial TTS transport; it does not yet include preload/caching, explicit pause/resume controls, or interruption intent routing. Those behaviors remain downstream hybrid milestones.
- Next: M4.5 - Pause and resume behavior

### 2026-03-07 - M4.5 Pause and resume behavior
- Status: DONE
- Summary: Added deterministic coordinator-owned pause and resume semantics on top of the new TTS narration transport. `VoiceSessionState` now has an explicit `paused(sceneIndex:)` state, `PracticeSessionViewModel` exposes `pauseNarration()` and `resumeNarration()`, and `StoryNarrationTransporting` now supports `pause()` and `resume()` so the active scene can halt and continue without losing authoritative scene ownership. Resume stays boundary-safe: the coordinator keeps the same scene index, the same active scene text, and the same one-time completion/save behavior.
- Files: `docs/hybrid-runtime-contract.md`, `docs/hybrid-mode-transition-model.md`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Models/StoryDomain.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added pause/resume coverage to `PracticeSessionViewModelTests` and extended the hybrid contract assertions, then verified them with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/HybridRuntimeContractTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPauseAndResumeNarrationPreservesSceneOwnership -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPauseAndResumeSingleSceneNarrationDoesNotDuplicateCompletionSideEffects -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNormalSessionProgressionCompletesAndSavesOnce -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes`, which passed `16` tests.
- Decisions:
  - Keep pause as an explicit coordinator state instead of a hidden narration flag so later interruption handoff can build on finite transitions.
  - Keep pause inside hybrid narration mode rather than creating a separate hybrid mode node; pause changes transport activity, not story authority.
- Risks/Notes: Pause and resume are now deterministic, but interruption handoff while paused is still undefined until `M4.6`. The initial transport implementation uses `AVSpeechSynthesizer` pause/continue and does not yet include scene-audio prebuffering or proactive bridge warmup decisions.
- Next: M4.6 - Interruption handoff from TTS to realtime

### 2026-03-07 - M4.6 Interruption handoff from TTS to realtime
- Status: DONE
- Summary: Implemented the first deterministic narration-to-interaction handoff path. `PracticeSessionViewModel` now allows interruption handoff from both active TTS playback and coordinator-paused narration, moving into `interrupting(sceneIndex:)` without losing scene ownership or reconnecting the realtime interaction transport. The handoff tears down the active TTS playback task, keeps the current scene boundary intact, and accepts either speech-start or final-transcript events while paused as valid entry points into interruption intake.
- Files: `docs/hybrid-runtime-contract.md`, `docs/hybrid-mode-transition-model.md`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added paused-handoff regressions to `PracticeSessionViewModelTests` and verified them with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPauseAndResumeNarrationPreservesSceneOwnership -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPauseAndResumeSingleSceneNarrationDoesNotDuplicateCompletionSideEffects -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationHandsOffToInteractionWithoutReconnect -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly`, which passed `5` tests.
- Decisions:
  - Reuse the warm realtime interaction session during interruption handoff instead of reconnecting, so the coordinator owns only one valid handoff path.
  - Keep handoff narrow for this milestone: it moves narration into interruption intake, but it does not classify the interruption intent yet.
- Risks/Notes: The handoff path is now deterministic, but live revision still uses the pre-hybrid request boundary, which is why paused-handoff tests still emit the existing revision-index mismatch log when revision resumes from scene `0`. Intent routing remains the next missing piece.
- Next: M4.7 - Interruption intent router

### 2026-03-07 - M4.7a Deterministic interruption intent classifier
- Status: DONE
- Summary: Split the original `M4.7` into `M4.7a` and `M4.7b`, then completed only the contract-first half. `StoryDomain.swift` now exposes a typed interruption routing decision and a deterministic local router that classifies transcripts into answer-only, revise-future-scenes, or repeat-or-clarify using authoritative scene state instead of transport-side assumptions. The router always returns answer context, only returns a revision boundary for future-scene mutation requests, and explicitly marks revision unavailable when no future scenes remain.
- Files: `docs/hybrid-runtime-contract.md`, `ios/StoryTime/Models/StoryDomain.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added hybrid contract regressions for answer-only, repeat-or-clarify, revise-future-scenes, and revision-unavailable routing, then verified them with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/HybridRuntimeContractTests`, which passed `16` tests.
- Decisions:
  - Keep interruption classification local and deterministic for now instead of introducing a model-backed or backend-backed classifier in the hot path.
  - Preserve route intent even when revision cannot run immediately, so `M4.7b` can decide safe coordinator behavior without re-classifying the transcript.
- Risks/Notes: The coordinator still does not consult the classifier; interruption transcripts still flow into the old revision path at runtime until `M4.7b` lands. The current heuristics are intentionally conservative and implementation-facing, not final product-quality NLU.
- Next: M4.7b - Coordinator route-selection activation

### 2026-03-07 - M4.7b Coordinator route-selection activation
- Status: DONE
- Summary: Wired the coordinator to consult `InterruptionIntentRouter` at the interruption boundary instead of blindly treating every interruption transcript as a revision request. `PracticeSessionViewModel` now exposes a typed `interruptionRouteDecision`, uses it before any path selection, and only continues into the existing revision flow when the routed intent is `revise_future_scenes` and the revision can actually run. Answer-only, repeat-or-clarify, and no-future-scenes mutation requests now remain safely in `interrupting(sceneIndex:)` for downstream execution milestones instead of over-triggering revision.
- Files: `docs/hybrid-runtime-contract.md`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added coordinator regressions for no-blind-revision routing and revision-unavailable waiting, then verified them with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionRevisionWithoutFutureScenesStaysWaiting -only-testing:StoryTimeTests/HybridRuntimeContractTests`, which passed `19` tests.
- Decisions:
  - Keep the existing revise flow active only for immediately valid `revise_future_scenes` routes so product behavior stays stable while the hybrid coordinator stops over-triggering revision.
  - Hold answer-only, repeat-or-clarify, and revision-unavailable routes in `interrupting(sceneIndex:)` with an explicit routed decision until their dedicated execution milestones land.
- Risks/Notes: Answer-only and repeat-or-clarify execution still do not exist, so those routed cases now wait safely but do not yet produce a live response. The revise path still uses the pre-hybrid backend request boundary and will be tightened in `M4.9`.
- Next: M4.8 - Answer-only interruption path

### 2026-03-07 - M4.8 Answer-only interruption path
- Status: DONE
- Summary: Implemented the first routed interruption execution path. `PracticeSessionViewModel` now turns `answer_only` route decisions into a short live response built from `StoryAnswerContext`, speaks that response over the realtime interaction transport, and then resumes narration from the same scene boundary without mutating story state or calling revision. This keeps current-story questions off the regeneration path while preserving deterministic coordinator-owned resume behavior.
- Files: `docs/hybrid-runtime-contract.md`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Updated the routed-interruption regression slice and verified it with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionRevisionWithoutFutureScenesStaysWaiting -only-testing:StoryTimeTests/HybridRuntimeContractTests`, which passed `19` tests. A first attempt failed before test execution because the simulator did not return a process handle; the identical rerun succeeded.
- Decisions:
  - Keep answer-only execution local and deterministic for now by answering from current scene context instead of introducing a backend question-answer surface in this milestone.
  - Resume by replaying the current scene boundary after the answer completes so completed scenes remain stable and future scenes remain untouched.
- Risks/Notes: The live answer text is intentionally simple and scene-summary based; it is deterministic but not yet sophisticated question answering. Repeat-or-clarify still has no execution path, and revise-future-scenes still uses the older backend request boundary until `M4.9`.
- Next: M4.9 - Revise-future-scenes path

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
- The critical-path verification report now captures which top-level flows are fully verified, partially verified, or still indirect, so remaining gaps are explicit instead of assumed.
- The active code already has the right scene-state authority seam for hybrid migration: generated stories are structured into ordered scenes, `currentSceneIndex` is explicit, and revision requests already operate on completed versus remaining scenes.
- The current runtime now separates long-form narration transport from realtime interaction: `PracticeSessionViewModel` uses a dedicated narration transport for scene playback while keeping realtime voice for live interaction and interruption input.
- The new runtime target is explicit: interaction mode, narration mode, and authoritative story/scene state must be separate, with interruption classification deciding answer-only versus repeat/clarify versus future-scene revision.
- Hybrid-specific gaps are now explicit: no scene-ahead preload persistence beyond the in-memory narration transport cache, and no explicit revised-scene cache budgeting beyond the current one-scene-ahead bound.
- The hybrid runtime contract is now recorded in `docs/hybrid-runtime-contract.md` and named in `StoryDomain.swift`, so later milestones can build on stable repo terms instead of informal prompt language.
- The hybrid mode graph is now explicit in `StoryDomain.swift` and documented in `docs/hybrid-mode-transition-model.md`, including the allowed handoffs between setup interaction, narration, interruption intake, answer-only, revise-future-scenes, repeat/clarify, and terminal states.
- The authoritative scene-state contract is now explicit in `StoryDomain.swift` and `docs/hybrid-scene-state-authority.md`, including stable completed/current scene boundaries, read-only answer context, and future-only revision boundaries.
- The coordinator now owns explicit paused narration state and boundary-safe resume semantics, so later interruption handoff work can build on finite pause/resume transitions instead of raw transport stop/start behavior.
- Post-interruption narration resume now routes through explicit `NarrationResumeDecision` handling in the coordinator, with answer-only and repeat/clarify replaying the current boundary scene and revise-future-scenes replaying the current boundary against revised future scenes.

## Blockers

- No external blocker is visible in the repository.

## Open Decisions

- What should the free plan versus paid plan boundary actually be in repo terms: story starts, story minutes, saved-series continuation, multiple child profiles, or some combination of those?
- Which story/session caps are economically safe enough to expose before stronger pricing telemetry or cohort data exists?
- What additional cost telemetry or exported pricing evidence is needed before package boundaries can be treated as commercially confident?
- How should onboarding frame trust, safety, retention, and product value before the first story starts without over-claiming privacy or access control?
- What exact StoreKit product catalog, billing cadence, and naming should the first `Starter` versus `Plus` package set use once pricing confidence is high enough?
- How short should the backend entitlement-snapshot TTL be, and should entitlement preflight reserve a launch slot before realtime startup begins?
- Should first-run onboarding stay as an overlay on `HomeView`, or should it become a dedicated full-screen parent setup flow before the normal home surface is shown?
- When onboarding asks for child setup, should the fallback `Story Explorer` profile be hidden until named, or shown as a recoverable default with clearer parent explanation?
- How should the parent-managed upgrade sheet actually present blocked launch context: inline explanation on `NewStoryJourneyView`, a parent modal above it, or a route into parent controls with preserved launch intent?
- Should `HomeView` stay limited to quick-start framing and trust entry until real entitlement state exists, or should a later milestone add an explicit plan-state summary once purchase and sync infrastructure lands?
- Should `NewStoryJourneyView` eventually expose a direct parent-controls correction path for child setup and privacy changes, or stay as a focused preflight surface that asks parents to back out before changing trust settings?
- Should `Use old characters` remain intentionally gated behind `Use past story`, or should a later milestone support familiar-character reuse for brand-new stories without continuing one saved series?
- Should the live-session cue card remain a passive read-only explanation layer, or should a later milestone add explicit resume/help affordances around paused and failed states?
- Should the saved-story detail screen eventually collapse older episode history or secondary continuity details further on smaller phones, or is the new continuation-first hierarchy sufficient?
- What latency and cost thresholds should count as acceptable for `interaction`, `generation`, `narration`, and `revision` before UX/productization work resumes?
- Is the existing in-process usage meter plus structured logs plus verification docs sufficient for stage-level telemetry, or does the repo need a lightweight exported verification artifact before later commercialization work?
- Should continuity enrichment and moderation provider usage gain first-class supporting-stage attribution, or stay documented as indirect measurement outside the four primary stage groups?
- Should the broader revised-story persistence acceptance path stay outside the default runtime gate until the residual revision-index logging noise is resolved, or should it be stabilized and brought into a later pack revision?
- Which partially verified hybrid-runtime behaviors should stay documented as known limits, and which require new harness work before the runtime is considered materially verified?
- Should the residual `Revision index mismatch` diagnostics that still appear in some passing interaction-path tests be treated as acceptable logging noise, or cleaned up before the `M6.4` acceptance pack freezes its baseline?
- Should the realtime interaction session stay warm during TTS narration, or should the app explicitly suspend and re-arm interaction transport around narration boundaries?
- What is the scene-level TTS preload and caching strategy: pre-generate one scene ahead, multiple scenes ahead, or generate on demand with bounded buffering?
- What interruption-frequency and interruption-length guardrails are needed so answer-only interactions do not collapse narration pacing?
- How should model routing be tiered by runtime stage: discovery, answer-only interaction, future-scene revision, TTS generation, and continuity retrieval?
- Should install identity and session token storage stay in `UserDefaults`, keychain, or a split model after hardening?
- What exact client redaction policy should observability use for transcripts and story text once runtime-stage telemetry is added?

### 2026-03-07 - M4.9 Revise-future-scenes path
- Status: DONE
- Summary: Activated the hybrid future-scene revision contract in the live coordinator path. `PracticeSessionViewModel` now builds revise requests from `StoryRevisionBoundary.makeRequest(userUpdate:)`, which sends the first mutable future scene index, preserves completed scenes plus the current boundary scene, and only sends future scenes as mutable input. Revision resolution now merges preserved scenes with revised future scenes and resumes narration from the preserved current boundary scene instead of treating that scene as regenerated.
- Files: `docs/hybrid-runtime-contract.md`, `docs/hybrid-scene-state-authority.md`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Updated the revise-path coordinator regressions in `PracticeSessionViewModelTests` and verified them with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes -only-testing:StoryTimeTests/HybridRuntimeContractTests`, which passed `17` tests.
- Decisions:
  - The live coordinator now follows the same future-only mutation boundary as the hybrid planning types instead of maintaining a wider legacy revise shape.
  - `revised_from_scene_index` is treated as the first mutable future scene index, while resume still replays the preserved current boundary scene.
- Risks/Notes: The live revise path now matches the hybrid boundary contract, but `M4.10` still needs to consolidate resume behavior across answer-only, repeat/clarify, and revision into one explicit coordinator rule.

### 2026-03-07 - M4.10 Narration resume from correct scene boundary
- Status: DONE
- Summary: Consolidated post-interruption narration resume onto explicit `NarrationResumeDecision` handling in `PracticeSessionViewModel`. Answer-only and repeat-or-clarify now replay the current scene boundary through the same typed resume path, while revise-future-scenes resumes through `replayCurrentSceneWithRevisedFuture(sceneIndex:, revisedFutureStartIndex:)`. This removes the last ad hoc answer-only versus revision resume split and gives repeat-or-clarify a concrete non-mutating runtime path.
- Files: `docs/hybrid-runtime-contract.md`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added repeat-or-clarify and answer-only-after-resume completion regressions to `PracticeSessionViewModelTests` and verified them with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testAnswerOnlyResumeCompletesAndSavesOnce -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testDuplicateCompletionAndSavePrevention -only-testing:StoryTimeTests/HybridRuntimeContractTests`, which passed `21` tests.
- Decisions:
  - Keep interruption resume keyed to `NarrationResumeDecision` instead of separate source-specific coordinator branches.
  - Treat repeat-or-clarify as a non-mutating replay of the current scene boundary until a richer clarify behavior is explicitly scheduled.
- Risks/Notes: Resume behavior is now explicit across interruption outcomes, but scene-ahead audio preload and cache invalidation are still missing and remain the next latency-focused hybrid gap.

### 2026-03-07 - M4.11 Scene audio preload and caching strategy
- Status: DONE
- Summary: Added coordinator-owned one-scene-ahead narration preparation to the hybrid TTS path. `PracticeSessionViewModel` now prepares the active boundary and next upcoming scene as typed `PreparedNarrationScene` payloads, while the narration transport owns a bounded in-memory cache with explicit invalidation when story state changes. Revision now drops stale future-scene prepared payloads and keeps only the current boundary plus the latest upcoming future scene warm.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests: Added preload/cache hit and revision invalidation regressions to `PracticeSessionViewModelTests` and verified them with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRevisionInvalidatesStalePreloadedFutureSceneAudio -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision -only-testing:StoryTimeTests/HybridRuntimeContractTests`, which passed `20` tests.
- Decisions:
  - Keep preload bounded to one scene ahead so cache invalidation stays deterministic around future-scene revision.
  - Treat prepared narration as transport-local ephemeral state rather than persisted audio or story-state data.
- Risks/Notes: The current preload layer caches prepared narration payloads rather than synthesized audio files, so `M4.12` still needs to add stage-level cost visibility before cache depth or synthesis strategy is widened.

### 2026-03-07 - M4.12 Cost telemetry by runtime stage
- Status: DONE
- Summary: Added redacted runtime-stage telemetry across the hybrid stack. `APIClientTraceEvent` now carries runtime-stage attribution, cost-driver classification, and duration for discovery, story generation, revise-future-scenes, and continuity-retrieval requests. `PracticeSessionViewModel` now records local runtime telemetry for answer-only spoken responses, TTS preload work, and combined continuity retrieval timing, while backend analytics also meter OpenAI usage by runtime stage.
- Files: `backend/src/lib/analytics.ts`, `backend/src/services/embeddingsService.ts`, `backend/src/services/storyDiscoveryService.ts`, `backend/src/services/storyService.ts`, `backend/src/tests/request-retry-rate.test.ts`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run src/tests/request-retry-rate.test.ts`, which passed `5` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testExtendModeUsesPreviousRecapAndContinuityEmbeddings`, which passed `4` tests.
- Decisions:
  - Keep runtime telemetry redacted by storing only stage names, safe source labels, cost-driver classes, durations, request IDs, session IDs, status codes, and API operation names.
  - Treat local hybrid work as first-class telemetry alongside remote model calls so answer-only interaction, TTS preparation, and continuity lookup can be compared without introducing raw content logging.
- Risks/Notes: Runtime-stage telemetry is now available, but `M4.13` still needs to consolidate the hybrid validation sweep into one stable command and coverage set.

### 2026-03-07 - M4.13 Hybrid runtime tests and validation command
- Status: DONE
- Summary: Added a stable targeted hybrid validation sweep for future milestones. The repo now includes `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` to run the backend hybrid contract slice and the matching iOS hybrid coordinator/transport slice, plus `/Users/rory/Documents/StoryTime/docs/verification/hybrid-runtime-validation.md` to document the command, its assumptions, and why it is the preferred milestone-level validation layer. I also refreshed the lifecycle trace regression in `PracticeSessionViewModelTests` so the stable slice matches current future-scene revision semantics and hybrid narration timing.
- Files: `docs/verification/hybrid-runtime-validation.md`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `scripts/run_hybrid_runtime_validation.sh`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`
  - Backend step: `npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts src/tests/types.test.ts`, which passed `39` tests.
  - iOS step: the targeted `xcodebuild test` slice inside the script, which passed `27` tests.
- Decisions:
  - Keep the hybrid validation layer targeted and repeatable instead of expanding it to the full backend or iOS suite.
  - Include the lifecycle trace regression in the stable slice so request/session correlation, interruption routing, and post-revision narration remain pinned together.
- Risks/Notes:
  - The stable validation slice is green, but the iOS run still emits the existing `Revision index mismatch. expected=2 actual=1` log during the lifecycle trace regression. The test passes, so this remains a known coordinator logging mismatch rather than part of the current milestone scope.
  - `M3.10.2` can now resume on top of the hybrid validation layer because the migration-reset blocker is cleared.

### 2026-03-07 - M3.10.2 Failure injection acceptance coverage
- Status: DONE
- Summary: Extended the acceptance harness on top of the hybrid validation layer. The targeted iOS slice now explicitly covers startup failure, disconnect during live narration, revision-overlap queuing, and duplicate completion/save protection. I added `testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory` and refreshed the overlapping-revision acceptance regression so it uses the active interruption classifier and future-scene revision boundary instead of the legacy implicit-revision path.
- Files: `docs/verification/hybrid-runtime-validation.md`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `scripts/run_hybrid_runtime_validation.sh`, `PLANS.md`, `SPRINT.md`
- Tests:
  - Backend: `npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts src/tests/types.test.ts`, which passed `39` tests.
  - iOS: `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation -only-testing:StoryTimeTests/HybridRuntimeContractTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartupHealthCheckFailureUsesSafeMessageAndCategory -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartupDisconnectBeforeReadyFailsOnceAndLateConnectedDoesNotReviveSession -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testOverlappingInterruptionsQueueInsteadOfStartingConcurrentRevisions -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testAnswerOnlyResumeCompletesAndSavesOnce -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPauseAndResumeNarrationPreservesSceneOwnership -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testDuplicateCompletionAndSavePrevention -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRevisionInvalidatesStalePreloadedFutureSceneAudio -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testExtendModeUsesPreviousRecapAndContinuityEmbeddings`, which passed `31` tests.
- Decisions:
  - Keep the failure-injection acceptance layer inside the targeted hybrid validation slice rather than creating a second divergent harness.
  - Treat overlap acceptance as a coordinator-routing regression, so the test inputs now use explicit future-scene change requests that the active classifier will route to revision.
- Risks/Notes:
  - The lifecycle trace regression and overlap acceptance still emit the known `Revision index mismatch. expected=2 actual=1` coordinator log while passing. This remains a logging mismatch, not a failing behavior in this milestone.
  - One full script rerun was externally terminated during `xcodebuild`, but the backend step and the identical iOS slice both passed cleanly when rerun directly.

## Next Recommended Milestone

No incomplete milestone remains in `SPRINT.md`.

The next run should be a planning pass to define the next milestone group after the completed `M8` productization slice. It should use the now-verified runtime, the productization and monetization direction docs, and the completed trust/privacy refinements as the baseline instead of starting ad hoc implementation work.

## Update Rules

- Read `AGENTS.md` and `SPRINT.md` before updating this file.
- After every run, update milestone statuses here so they match `SPRINT.md`.
- Append new entries to `Completed Work Log`. Do not rewrite or delete prior entries.
- If a milestone is split, update `SPRINT.md` first, then update this file to match the new milestone IDs.
- Record blockers, open decisions, and newly discovered risks when they materially change execution.
- Keep the next recommended milestone aligned with the first incomplete milestone in `SPRINT.md`, unless a blocker is explicitly recorded here.

### 2026-03-07 - M3.10.3 Child isolation acceptance coverage and validation command
- Status: DONE
- Summary: Finished the critical-path acceptance layer by adding seeded multi-child UI coverage to the stable hybrid validation command. The new UI regression proves saved-story visibility disappears when switching to a different child and reappears, with the same seeded past-story picker option, when switching back to the original child. The stable validation command now exercises backend contract coverage, the targeted hybrid/failure iOS unit slice, and the child-isolation UI acceptance slice together.
- Files: `docs/verification/hybrid-runtime-validation.md`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `scripts/run_hybrid_runtime_validation.sh`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`
  - Backend step: `npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts src/tests/types.test.ts`, which passed `39` tests.
  - iOS unit step: the targeted `xcodebuild test` slice inside the script, which passed `31` tests.
  - iOS UI step: `StoryTimeUITests.testSavedStoriesAndPastStoryPickerStayScopedToActiveChild` and `StoryTimeUITests.testSavedStoriesAndPastStoryPickerReturnWhenSwitchingBackToSeededChild`, which passed `2` tests.
- Decisions:
  - Keep child-isolation acceptance inside the same stable hybrid validation command instead of creating a separate UI-only harness.
  - Use seeded UI coverage for multi-child isolation because it verifies the actual home-screen and new-story surfaces where scoped saved stories and past-story reuse appear.
- Risks/Notes:
  - The first version of the stable command used incomplete `-only-testing` identifiers for the UI bundle and executed `0` UI tests. That wiring issue is now fixed in the script and documented here.
  - The stable validation slice still emits the existing `Revision index mismatch. expected=2 actual=1` coordinator log while passing. This is now queued as the next narrow hardening milestone rather than being widened into the child-isolation milestone.

### 2026-03-07 - M5.1 Coordinator revision-index logging hardening
- Status: DONE
- Summary: Removed the remaining revision-index logging drift from the stable hybrid validation slice by correcting the stale lifecycle regression fixture to match the active future-scene revision boundary. The targeted lifecycle test now explicitly asserts that no `Revision index mismatch` message is recorded, so future drift will fail the regression instead of surfacing only as a passing log line.
- Files: `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation`, which passed `1` test.
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`
  - Backend step inside the validation command: `39` tests passed.
  - iOS unit step inside the validation command: `31` tests passed.
  - iOS UI child-isolation step inside the validation command: `2` tests passed.
- Decisions:
  - Keep the fix scoped to the stale lifecycle regression and explicit assertion coverage rather than weakening the coordinator diagnostic or widening runtime behavior.
  - Treat the earlier mismatch log as a test-fixture drift issue because the active coordinator already enforced the future-scene revision boundary correctly.
- Risks/Notes:
  - The first attempt to run the isolated lifecycle regression in parallel with the full validation command failed with an Xcode `build.db` lock. The required runs were rerun sequentially and passed cleanly.
  - No new product/runtime defect was uncovered in this milestone; the issue was confined to stale regression data.

### 2026-03-07 - Post-M5 verification and measurement planning update
- Status: DONE
- Summary: Updated the repo control files after `M5.1` to move StoryTime into a post-migration verification and measurement workstream. The next milestone group is now explicit: end-to-end hybrid verification report, realtime interaction-path determinism audit, stage-level cost/latency telemetry verification, hybrid runtime acceptance regression pack, and only then a UX audit milestone.
- Files: `AGENTS.md`, `PLANS.md`, `SPRINT.md`
- Tests: No code changes or test runs were required for this planning-only pass. The update was grounded in active inspection of `PracticeSessionViewModel`, `PracticeSessionViewModelTests`, current verification docs, telemetry code, backend analytics hooks, and the current sprint/control files.
- Decisions:
  - Verification and measurement now take priority over UX/design work until the new `M6` milestone group is materially complete.
  - Future runtime verification reports must use explicit evidence labels so partially verified and unverified behavior is visible instead of implied.
  - Telemetry work should stay stage-based and redacted, not broaden into dashboards or productization scope during this group.
- Risks/Notes:
  - The repo already has a stable hybrid validation command and baseline telemetry hooks, so the next risk is not migration churn but incomplete proof and measurement interpretation.
  - UX/productization work now stays queued behind the verification and measurement group unless `SPRINT.md` explicitly reprioritizes it later.
- Next: M6.1 - Hybrid runtime end-to-end verification report

### 2026-03-07 - M6.1 Hybrid runtime end-to-end verification report
- Status: DONE
- Summary: Added `docs/verification/hybrid-runtime-end-to-end-report.md` as the first explicit post-migration verification report for the active hybrid runtime. The report uses the required evidence labels `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, and `UNVERIFIED`; documents the active hybrid loop in repo terms; records the passing stable validation run; and turns the remaining gaps into explicit inputs for `M6.2`, `M6.3`, and `M6.4`.
- Files: `docs/verification/hybrid-runtime-end-to-end-report.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`
  - Backend slice: `39` tests passed.
  - iOS unit slice: `31` tests passed.
  - iOS UI child-isolation slice: `2` tests passed.
- Decisions:
  - Keep `M6.1` report-only and evidence-focused. Do not widen into bridge harness work, telemetry redesign, or acceptance-pack expansion in this milestone.
  - Treat the current stable validation command as the primary automated evidence source, then use code inspection only where the repo still lacks direct harness coverage.
- Risks/Notes:
  - The strongest remaining evidence gap is still the realtime interaction path under real bridge/browser ordering, which is why `M6.2` remains the next milestone.
  - Runtime-stage telemetry exists, but commercialization thresholds and the top-level stage mapping still need the focused verification pass planned for `M6.3`.
- Next: M6.2 - Realtime interaction-path determinism audit

### 2026-03-07 - M6.2 Realtime interaction-path determinism audit
- Status: DONE
- Summary: Refreshed `docs/verification/realtime-voice-determinism-report.md` so it matches the active hybrid runtime instead of the older pre-hybrid audit framing. The report now documents startup determinism, TTS-to-realtime handoff behavior, answer-only and repeat-or-clarify routing, deferred transcript rejection, backend realtime contract guarantees, and the repo-accurate intentional no-reconnect semantics. No new in-scope determinism defect was reproduced, so this milestone stayed verification-only.
- Files: `docs/verification/realtime-voice-determinism-report.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/types.test.ts`, which passed `34` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionWithRealAPIClientExecutesFullStartupContractSequence -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionUsesResolvedBackendRegionDuringRealtimeStartup -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionRefreshesStaleSessionTokenBeforeRealtimeStartupFails -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testAnswerOnlyResumeCompletesAndSavesOnce -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationHandsOffToInteractionWithoutReconnect -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringGenerationIsRejectedAfterNarrationBegins -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testLateTranscriptAfterFailureDoesNotOverwriteLatestTranscript -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionDuringGenerationIsRejectedDeterministically`, which passed `43` tests.
- Decisions:
  - Keep the interaction-path milestone verification-only. Do not widen into reconnect behavior, bridge-harness construction, or unrelated coordinator fixes when the current scoped evidence is already stable.
  - Treat terminal disconnect semantics as intentional current-product behavior and document them explicitly instead of implying recoverability.
- Risks/Notes:
  - The repo still lacks a live `WKWebView`/WebRTC acceptance harness, so bridge/browser ordering remains only partially verified.
  - A broader `PracticeSessionViewModelTests` class run exposed unrelated repeat-history and revision-queue failures outside the scoped interaction-path slice. Those failures did not block `M6.2`, but `M6.4` should decide whether to fix them or exclude them explicitly from the acceptance baseline.
  - Some passing interaction-path tests still emit `Revision index mismatch` diagnostics without reproducing state drift. This remains a residual verification concern rather than a confirmed runtime defect.
- Next: M6.3 - Stage-level cost and latency telemetry verification

### 2026-03-07 - M6.3 Stage-level cost and latency telemetry verification
- Status: DONE
- Summary: Added `docs/verification/runtime-stage-telemetry-verification.md` and tightened the telemetry model so the active hybrid runtime now reports both detailed stages and the primary stage groups `interaction`, `generation`, `narration`, and `revision`. The client now exposes grouped stage attribution alongside existing detailed API and coordinator telemetry, backend analytics now meters grouped stage counters and log fields, and realtime provider usage is explicitly tagged as `interaction`. Supporting work such as `continuity_retrieval` stays separate instead of being collapsed into a misleading primary stage.
- Files: `docs/verification/runtime-stage-telemetry-verification.md`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `backend/src/lib/analytics.ts`, `backend/src/services/realtimeService.ts`, `backend/src/tests/request-retry-rate.test.ts`, `backend/src/tests/model-services.test.ts`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/request-retry-rate.test.ts src/tests/model-services.test.ts`, which passed `13` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation -only-testing:StoryTimeTests/APIClientTests/testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testExtendModeUsesPreviousRecapAndContinuityEmbeddings`, which passed `6` tests.
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed backend `39`, iOS unit `31`, and iOS UI `2` tests.
- Decisions:
  - Keep the primary grouped stage model narrow and product-facing: `interaction`, `generation`, `narration`, and `revision`.
  - Keep `continuity_retrieval` as a supporting stage with no forced primary grouping so telemetry stays truthful instead of over-attributing support work.
  - Keep this milestone verification-grade only; do not widen into dashboards, alerts, or commercialization tooling.
- Risks/Notes:
  - Narration telemetry is still strongest at TTS preparation timing, not complete playback wall-clock measurement.
  - Continuity enrichment and moderation internals still have uneven support-stage attribution and may need explicit acceptance-pack handling.
  - Threshold-based judgments about commercial viability remain undefined and should be settled before productization work starts.
- Next: M6.4 - Hybrid runtime acceptance regression pack

### 2026-03-07 - M6.4 Hybrid runtime acceptance regression pack
- Status: DONE
- Summary: Turned the prior stable validation slice into the explicit default acceptance gate for the active hybrid runtime. `docs/verification/hybrid-runtime-validation.md` now defines the pack in operational terms, names the required covered scenarios, and explicitly lists what remains outside the default gate. The validation command now pins the missing stable assertions from `M6.1` through `M6.3`: an explicit happy-path completion regression and grouped runtime-stage telemetry, while keeping revise-future-scenes covered by its dedicated deterministic tests. To stabilize the gate itself, the command now runs backend, iOS unit, and iOS UI isolation slices as separate steps instead of mixing unit and UI execution in one `xcodebuild` invocation.
- Files: `docs/verification/hybrid-runtime-validation.md`, `scripts/run_hybrid_runtime_validation.sh`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed backend `39`, iOS unit `33`, and iOS UI `2` tests.
- Decisions:
  - Keep the default happy-path acceptance anchor narrow and stable with `PracticeSessionViewModelTests.testNormalSessionProgressionCompletesAndSavesOnce` instead of widening the default gate to the broader revised-story persistence flow while the residual revision-index logging noise remains unresolved.
  - Keep the acceptance command split into backend, iOS unit, and iOS UI slices so pack failures stay attributable and the UI runner cannot destabilize the unit slice.
  - Keep the explicit exclusions in the acceptance-pack doc instead of pretending the repo already has live bridge-harness coverage or playback-wall-clock narration telemetry.
- Risks/Notes:
  - The explicit acceptance pack still intentionally excludes live `WKWebView`/WebRTC ordering, full playback wall-clock narration telemetry, and the broader revised-story persistence acceptance path.
  - Latency/cost thresholds and commercialization judgments remain open even though the runtime gate is now explicit and green.
  - The broader revised-story acceptance path remains outside the default gate until the revision-index logging noise is either fixed or explicitly re-scoped.
- Next: M7.1 - UX audit for parent/child storytelling flow

### 2026-03-08 - M7.1 UX audit for parent/child storytelling flow
- Status: DONE
- Summary: Added `docs/verification/parent-child-storytelling-ux-audit.md` as the first UX/productization audit on top of the verified hybrid runtime baseline. The audit stays implementation-free, separates parent trust-boundary issues from child storytelling-loop issues, uses the required evidence labels, and turns the main findings into small follow-up milestones instead of widening into redesign work. The highest-priority issues are both trust-boundary mismatches: saved-story deletion is still reachable from child-facing story detail, and the parent history sheet currently frames a global clear-history action as if it were scoped only to the active child.
- Files: `docs/verification/parent-child-storytelling-ux-audit.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/StoryLibraryStoreTests/testVisibleSeriesForRequestedChildDoesNotDependOnActiveProfileOrFallback -only-testing:StoryTimeTests/StoryLibraryStoreTests/testClearStoryHistoryPersistsAcrossReload -only-testing:StoryTimeTests/StoryLibraryStoreTests/testPrivacyRetentionAndDeletionControls`, which passed `3` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceFirstStoryJourney -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsRequireDeliberateGateBeforeOpening -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailShowsContinuityAndActionButtons -only-testing:StoryTimeUITests/StoryTimeUITests/testSavedStoriesAndPastStoryPickerStayScopedToActiveChild -only-testing:StoryTimeUITests/StoryTimeUITests/testPrivacyCopyReflectsLiveProcessingAndLocalRetention`, which passed `5` tests.
- Decisions:
  - Keep `M7.1` audit-only. Do not widen into trust-boundary fixes, copy changes, or visual redesign in the same run.
  - Split the next UX/productization work into implementation-ready milestones around trust-boundary hardening, launch clarity, live-session state clarity, and saved-story detail hierarchy instead of one broad redesign milestone.
- Risks/Notes:
  - The parent gate is still lightweight friction rather than strong authentication.
  - Saved-story delete remains reachable from a child-facing surface until `M7.2` lands.
  - The live session is runtime-stable, but its child-facing mode cues remain only partially verified for real comprehensibility.
- Next: M7.2 - Parent trust-boundary hardening for saved-story management

### 2026-03-08 - M7.2 Parent trust-boundary hardening for saved-story management
- Status: DONE
- Summary: Removed destructive saved-story management from the child-facing detail surface and relocated it into the parent hub. `StorySeriesDetailView` now preserves replay and continue actions only, while `ParentTrustCenterView` manages both single-series deletion and device-wide history deletion with copy that explicitly states the global on-device scope. The parent controls flow now matches the repo’s trust-boundary intent without changing store behavior or continuity cleanup semantics.
- Files: `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/StoryLibraryStoreTests/testDeleteSeriesPersistsAcrossReload -only-testing:StoryTimeTests/StoryLibraryStoreTests/testClearStoryHistoryPersistsAcrossReload -only-testing:StoryTimeTests/StoryLibraryStoreTests/testPrivacyRetentionAndDeletionControls`, which passed `3` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsDeleteSingleSeriesAndRemoveItFromHome`, which passed `1` test.
- Decisions:
  - Keep destructive saved-story mutations inside the existing parent-controls surface instead of adding a second child-facing confirmation pattern.
  - Keep device-wide clear-history behavior unchanged for now, but make its on-device global scope explicit in parent-facing copy.
  - Keep child-facing saved-story detail focused on replay and continue actions only.
- Risks/Notes:
  - Targeted UI evidence is green, but combined multi-test UI reruns still showed intermittent simulator runner bootstrap failures unrelated to the product behavior.
  - The parent gate remains lightweight friction rather than strong authentication.
  - Launch-plan and live-session clarity issues remain queued in `M7.3` and `M7.4`.
- Next: M7.3 - Launch-plan clarity for continuity choices

### 2026-03-08 - M7.3 Launch-plan clarity for continuity choices
- Status: DONE
- Summary: Updated `NewStoryJourneyView` so the pre-session setup explains the live follow-up loop and the repo-accurate continuity choices before narration begins. The journey now distinguishes fresh-story versus continue-story behavior, makes the selected saved-series recap path explicit, and truthfully scopes character reuse to the selected saved-series context instead of implying broader reuse behavior. The launch preview now separates live follow-up, story path, and character plan into readable lines without changing any runtime behavior.
- Files: `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyExplainsFreshStartAndLiveFollowUpBeforeSessionStarts -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyExplainsContinueModeAndCharacterReuseChoices -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceFirstStoryJourney`, which passed `3` tests.
- Decisions:
  - Keep `Use old characters` available only when a saved story is selected, because that is the only repo-accurate path where the runtime currently has character hints to reuse.
  - Keep the milestone copy-first and structure-first; do not widen into runtime changes, new launch-plan logic, or live-session redesign.
  - Make the launch preview explicit in three parts: live follow-up before narration, story path, and character plan.
- Risks/Notes:
  - The launch setup is now clearer, but the in-session state expression still depends heavily on shifting text and remains the next UX/productization gap.
  - A later productization decision may still choose to support familiar-character reuse for fresh stories without continuing a saved series, but that would be a new behavior rather than part of this milestone.
- Next: M7.4 - Live session interaction-state clarity

### 2026-03-08 - M7.4 Live session interaction-state clarity
- Status: DONE
- Summary: Added a child-facing session cue layer on top of the stable hybrid runtime without changing coordinator behavior. `VoiceSessionView` now shows a dedicated cue card and action hint that interpret the existing coordinator state for listening, question time, narration, answering, revising, paused, completed, and failed states. `PracticeSessionViewModel` now exposes a derived `sessionCue` so the view reads from deterministic runtime state instead of inventing UI-only flags.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionConnectsAndSpeaksOpeningQuestion -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPauseAndResumeNarrationPreservesSceneOwnership -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testSessionCueExplainsAnswerOnlyInterruptionState -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testOverlappingInterruptionsQueueInsteadOfStartingConcurrentRevisions`, which passed `4` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartupHealthCheckFailureUsesSafeMessageAndCategory`, which passed `1` test.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceSessionShowsListeningCueBeforeNarrationStarts -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceSessionShowsStorytellingCueAfterNarrationStarts`, which passed `2` tests.
- Decisions:
  - Keep the session-state legibility work derived from `PracticeSessionViewModel.sessionState`, `statusMessage`, and safe error copy instead of introducing new UI-only runtime flags.
  - Keep the cue layer informational and child-facing for now; do not widen this milestone into new pause/resume controls or coordinator changes.
  - Use a single accessible cue card surface in UI tests because nested SwiftUI text identifiers were less stable than the combined card label/value.
- Risks/Notes:
  - The simulator accessibility runner still showed intermittent restart behavior during one mixed UI/unit run, but the targeted UI rerun passed cleanly once the cue card carried its own stable accessibility surface.
  - The remaining UX/productization risk in this phase is the saved-story detail hierarchy, not live session state clarity.
- Next: M7.5 - Saved-story detail information hierarchy pass

### 2026-03-08 - M7.5 Saved-story detail information hierarchy pass
- Status: DONE
- Summary: Reworked `StorySeriesDetailView` so the child-facing saved-story detail surface now leads with continuation intent instead of internal continuity metadata. Replay and new-episode actions now sit in a dedicated continuation card with child-scoped language, continuity details are reframed as story memory for the next episode, and parent-only history management is separated into its own lower-priority section instead of being mixed directly into the continuation controls.
- Files: `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailPrioritizesContinuationActionsOverContinuityDetails`, which passed `1` test.
- Decisions:
  - Keep continuity information visible by default, but demote it behind a clearer continuation-first action card instead of collapsing it in the same milestone.
  - Keep parent-only history management as separate explanatory copy on the detail surface instead of reintroducing destructive affordances or extra confirmation flows there.
  - Keep the milestone presentation-only; do not widen into store behavior, deletion routing, or continuity model changes.
- Risks/Notes:
  - The saved-story detail surface is now clearer, but there is no next implementation milestone queued in `SPRINT.md`, so the next work should start with a planning pass instead of more ad hoc productization changes.
  - The parent gate remains lightweight friction rather than strong authentication.
- Next: No incomplete milestone remains in `SPRINT.md`

### 2026-03-08 - Phase 7 productization and monetization queue definition
- Status: DONE
- Summary: Updated the repo control files to start the next workstream after the completed M7 UX hardening slice. The new queue shifts StoryTime from hybrid-runtime rescue into productization, monetization-aware UX, onboarding, paywall strategy, home/setup polish, end-of-story reuse design, and parent-trust communication refinement, while keeping all work grounded in the verified hybrid runtime and existing cost telemetry.
- Files: `AGENTS.md`, `PLANS.md`, `SPRINT.md`
- Tests: No code tests were run because this was a planning-only control-file update.
- Decisions:
  - Start the next phase with productization planning and journey alignment before entitlement or paywall implementation.
  - Treat monetization as an architecture-plus-flow problem that depends on runtime-stage telemetry and model-routing economics, not just a visual paywall pass.
  - Keep onboarding, upgrade, and parent-trust work grouped as product journeys across the active surfaces instead of isolated cosmetic screens.
- Risks/Notes:
  - The repo still has no entitlement or paywall implementation, so `M8.2` and `M8.4` must stay architecture-first before UI implementation widens.
  - Runtime verification remains important, but broad core-runtime refactors are no longer the default next step unless a new defect is discovered.
- Next: M8.1 - Productization planning and user-journey alignment

### 2026-03-08 - M8.1 Productization planning and user-journey alignment
- Status: DONE
- Summary: Added `docs/productization-user-journey-alignment.md` as the baseline product-flow artifact for the next phase. The document maps the current first-time parent path, returning child quick start, new-story launch, live session, saved-series continuation, and completion loop in repo terms; distinguishes `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, and `UNVERIFIED` evidence; and identifies the most credible upgrade moments without widening into entitlement or paywall implementation.
- Files: `docs/productization-user-journey-alignment.md`, `PLANS.md`, `SPRINT.md`
- Tests: No new tests were added or run. This milestone used existing UI, unit, privacy, and telemetry verification artifacts as its required verification method.
- Decisions:
  - Treat `HomeView`, `NewStoryJourneyView`, `VoiceSessionView`, `StorySeriesDetailView`, the parent gate, and the parent hub as one connected product journey rather than separate polish surfaces.
  - Keep live child narration free of speculative paywall behavior for now; the strongest candidate upgrade moments are parent-first setup, pre-session launch, saved-series continuation, parent controls, and a later explicit completion loop.
  - Use `M8.1` as the shared baseline for `M8.2`, `M8.3`, and `M8.4` instead of letting those milestones re-discover the current flow independently.
- Risks/Notes:
  - The repo still has no first-run onboarding surface, entitlement owner, or package-limit messaging, so later M8 work must stay architecture-first before visual implementation widens.
  - The completion/save path is functionally verified, but the post-story user journey is still only partially productized.
- Next: M8.2 - Monetization model and entitlement architecture

### 2026-03-08 - M8.2 Monetization model and entitlement architecture
- Status: DONE
- Summary: Added `docs/monetization-entitlement-architecture.md` to define the first repo-fit monetization direction. The artifact maps the current cost-bearing runtime surfaces, proposes `Starter` versus `Plus` package-boundary candidates, chooses a split entitlement model with StoreKit as purchase truth and a backend-issued entitlement snapshot as enforcement truth, and defines the later client/backend touchpoints needed before any paywall UI or purchase implementation begins.
- Files: `docs/monetization-entitlement-architecture.md`, `PLANS.md`, `SPRINT.md`
- Tests: No new tests were added or run. This milestone used direct code inspection plus the existing telemetry, UX, privacy, and verification artifacts as its required verification method.
- Decisions:
  - Use launch-count and continuation-count limits as the first package levers instead of narration-minute pricing, because the repo does not yet have strong enough playback wall-clock telemetry for a user-facing minute promise.
  - Treat StoreKit 2 on device as purchase truth, but use a backend-issued entitlement snapshot and preflight checks as the enforcement layer for cost-bearing runtime work.
  - Keep monetization out of active child sessions once they have started; the first gating points should stay pre-session or parent-managed.
- Risks/Notes:
  - Exact numeric caps, price points, and billing cadence are still open because the repo has telemetry structure but not yet pricing-confidence thresholds.
  - There is still no StoreKit, entitlement sync, or paywall implementation in active code.
  - Onboarding is now the next key risk because the app still opens directly into `HomeView` without a first-run trust/value frame.
- Next: M8.3 - Onboarding and first-run flow audit and direction

### 2026-03-08 - M8.3 Onboarding and first-run flow audit and direction
- Status: DONE
- Summary: Added `docs/onboarding-first-run-audit.md` as the first explicit onboarding artifact for the productization phase. The document audits the current first-run behavior in repo terms, including the immediate boot into `HomeView`, the fallback `Story Explorer` profile, the lightweight parent gate, and the current trust-copy distribution, then defines a parent-led onboarding direction that frames value, trust, child setup, and first-story launch before any implementation begins.
- Files: `docs/onboarding-first-run-audit.md`, `PLANS.md`, `SPRINT.md`
- Tests: No new tests were added or run. This milestone used direct inspection of the active app surfaces plus existing UI, store, privacy, and verification evidence as its required verification method.
- Decisions:
  - Keep onboarding parent-first and outside `VoiceSessionView`; the live child session is too late for setup, trust explanation, or product framing.
  - Preserve the fallback `Story Explorer` profile as a resilience mechanism, but treat it as an implementation fallback rather than the ideal first-run product state.
  - Use onboarding to bridge into `NewStoryJourneyView` and the first story start, not to duplicate the entire launch-plan surface or introduce a hard paywall.
- Risks/Notes:
  - There is still no first-run implementation, only the direction artifact.
  - The exact onboarding container remains open: overlay on `HomeView` versus dedicated first-run flow.
  - Upgrade placement is now the next key productization risk, because onboarding and monetization rules are defined but still need one explicit entry-point strategy.
- Next: M8.4 - Paywall and upgrade entry-point strategy

### 2026-03-08 - M8.4 Paywall and upgrade entry-point strategy
- Status: DONE
- Summary: Added `docs/paywall-upgrade-entry-strategy.md` to define where upgrade prompts belong in StoryTime and where they do not. The artifact prioritizes `NewStoryJourneyView` as the primary hard-gating surface, `StorySeriesDetailView` as the contextual continuation gate, `ParentTrustCenterView` as the durable parent-managed upgrade surface, and `HomeView` as a soft-awareness surface, while explicitly excluding `VoiceSessionView` and live child runtime paths from blocking upgrade UI.
- Files: `docs/paywall-upgrade-entry-strategy.md`, `PLANS.md`, `SPRINT.md`
- Tests: No new tests were added or run. This milestone used direct inspection of the active app surfaces plus the existing UI, journey, monetization, and onboarding artifacts as its required verification method.
- Decisions:
  - Keep upgrade prompts parent-managed by default and keep hard entitlement checks before realtime startup or story discovery begins.
  - Allow replay of already-saved stories to remain available even if paid new-start or continuation counters are exhausted.
  - Treat `HomeView` as a soft upgrade-awareness surface and defer the exact completion-loop upgrade timing until `M8.7` defines that flow.
- Risks/Notes:
  - The actual blocked-launch UI pattern is still open: inline explanation, parent modal, or route into parent controls.
  - There is still no StoreKit, entitlement preflight, or upgrade UI implementation in the repo.
  - The next implementation risk is preserving the child quick-start path while introducing product framing on `HomeView`.
- Next: M8.5 - Home and Library product polish pass

### 2026-03-08 - M8.5 Home and Library product polish pass
- Status: DONE
- Summary: Polished `HomeView` and the saved-library surface so the app now communicates the quick-start promise, active-child expectations, and replay/continuation value more clearly without widening into paywall or onboarding implementation. The home hero now frames the live-question-plus-scene-narration loop explicitly, the trust card now exposes a clearer parent-controls entry, and saved-story cards now explain that the library supports repeat and continue behavior.
- Files: `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeUITests/StoryTimeUITests/testHomeViewFramesQuickStartLibraryAndParentControls -only-testing:StoryTimeUITests/StoryTimeUITests/testSavedStoryCardShowsReplayAndContinueAffordanceOnHome -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceFirstStoryJourney -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsRequireDeliberateGateBeforeOpening -only-testing:StoryTimeUITests/StoryTimeUITests/testSavedStoriesAndPastStoryPickerStayScopedToActiveChild`, which passed `5` tests.
- Decisions:
  - Keep `HomeView` truthful and lightweight: improve product framing and trust affordances now, but do not add speculative plan badges or blocking upgrade UI before real entitlement state exists.
  - Use the trust card as the actionable parent-entry surface on home, because that aligns with the approved parent-managed flow without overstating the lightweight gate.
  - Keep saved-story polish focused on replay and continuation clarity instead of widening into detail-view or store-behavior changes already handled in earlier milestones.
- Risks/Notes:
  - `HomeView` is clearer, but there is still no entitlement-backed plan state to surface there yet.
  - The next productization risk is now `NewStoryJourneyView`, which still needs a more polished pre-session hierarchy around onboarding, package boundaries, and launch clarity.
- Next: M8.6 - New Story setup polish pass

### 2026-03-08 - M8.6 New Story setup polish pass
- Status: DONE
- Summary: Polished `NewStoryJourneyView` into a clearer pre-session product surface without changing runtime behavior or inventing entitlement logic. The screen now frames setup as a preflight step before live questions, adds explicit parent handoff guidance, explains length and pacing more clearly, and separates the live follow-up, narration, and interruption expectations so the verified hybrid loop is easier to understand before session start.
- Files: `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyFramesPreflightParentHandoffAndLengthGuidance -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyExplainsLiveNarrationAndInterruptionExpectations -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyExplainsFreshStartAndLiveFollowUpBeforeSessionStarts -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyExplainsContinueModeAndCharacterReuseChoices -only-testing:StoryTimeUITests/StoryTimeUITests/testSavedStoriesAndPastStoryPickerStayScopedToActiveChild -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceFirstStoryJourney`, which passed `6` tests.
- Decisions:
  - Keep `NewStoryJourneyView` architecture-truthful and preflight-focused: improve the setup hierarchy and expectation framing now, but do not add fake plan caps, purchase state, or blocking upgrade UI before entitlement infrastructure exists.
  - Use explicit parent handoff language in the setup surface because the onboarding direction is parent-led, but keep the actual live session child-first once `VoiceSessionView` starts.
  - Explain length and pacing in runtime terms rather than price terms, because the repo still lacks entitlement enforcement and user-facing economic thresholds.
- Risks/Notes:
  - The setup flow is now clearer, but there is still no real entitlement or blocked-launch implementation behind the approved preflight upgrade strategy.
  - The next main productization gap is the missing end-of-story and repeat-use loop after a completed session.
- Next: M8.7 - End-of-story and repeat-use loop design pass

### 2026-03-08 - M8.7 End-of-story and repeat-use loop design pass
- Status: DONE
- Summary: Added `docs/end-of-story-repeat-use-loop.md` to define the missing bridge between a finished story session and the repeat-use surfaces that already exist in the repo. The document pins the current completion/save behavior in `PracticeSessionViewModel`, the lack of an explicit post-story UI in `VoiceSessionView`, the existing replay/continue affordances in `HomeView` and `StorySeriesDetailView`, and the intended next-step hierarchy of replay, new episode, and return to saved stories without widening into paywall or navigation implementation.
- Files: `docs/end-of-story-repeat-use-loop.md`, `PLANS.md`, `SPRINT.md`
- Tests: No new tests were added or run. This milestone used direct inspection of completion/save code paths, existing session and UI regressions, and the already-defined journey and upgrade strategy docs as its required verification method.
- Decisions:
  - Treat `VoiceSessionView` as the future completion acknowledgement surface, not the durable library surface and not a blocking upgrade surface.
  - Keep the post-story next-step order explicit: replay first, new episode second, return to saved stories or home third.
  - Reserve any later completion-loop upgrade treatment for the continuation path only; do not interrupt replay or a finished child story with a hard transactional surface.
- Risks/Notes:
  - The completion loop is now defined, but there is still no implemented post-story card or completion navigation in the active UI.
  - Parent trust and privacy communication is now the last major productization gap in the current M8 queue, especially as more surfaces begin to carry setup and upgrade framing.
- Next: M8.8 - Parent trust and privacy communication refinement

### 2026-03-08 - M8.8 Parent trust and privacy communication refinement
- Status: DONE
- Summary: Tightened parent-facing trust and privacy communication across `HomeView`, the lightweight parent gate, `ParentTrustCenterView`, `NewStoryJourneyView`, and `VoiceSessionView` without changing runtime or monetization behavior. The app now describes the parent check as lightweight friction instead of implied authentication, separates what stays on device from what goes live during a session more clearly, keeps setup and parent controls outside the live child story, and aligns the in-session privacy copy to the verified hybrid runtime language.
- Files: `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsRequireDeliberateGateBeforeOpening -only-testing:StoryTimeUITests/StoryTimeUITests/testHomeViewFramesQuickStartLibraryAndParentControls -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyFramesPreflightParentHandoffAndLengthGuidance -only-testing:StoryTimeUITests/StoryTimeUITests/testPrivacyCopyReflectsLiveProcessingAndLocalRetention -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceFirstStoryJourney`, which passed `5` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPrivacySummaryMentionsLocalTranscriptClearingWhenEnabled`, which passed `1` test.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPrivacySummaryElseBranchAndMockChildSpeechIdleAreSafe`, which passed `1` test.
- Decisions:
  - Keep the `PARENT` check framed as lightweight on-device friction and avoid implying account authentication or purchase security.
  - Keep parent controls explicitly outside the live child story instead of introducing parent or upgrade controls into `VoiceSessionView`.
  - Tighten trust language by separating local saved history and continuity from live microphone, prompt, generation, and revision processing rather than relying on one broad privacy sentence per screen.
- Risks/Notes:
  - Trust messaging is now more coherent, but there is still no onboarding implementation, StoreKit layer, entitlement sync, or paywall UI in the active repo.
  - The current sprint queue is now complete; the next run should be a planning pass for the next milestone group instead of more unqueued implementation work.
- Next: No incomplete milestone remains in `SPRINT.md`
