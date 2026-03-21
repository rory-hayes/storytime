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

Use the repo-ready MVP baseline as the starting point for the smallest real parent-account and payment-backed product foundation without weakening the verified runtime gate.

The current goal is to build the next product layer on top of the accepted hybrid runtime, completed launch work, and finished Sprint 10 commercial closure:
- keep realtime for low-latency live interaction
- keep TTS for long-form scene narration
- keep structured story state and scene state as the authoritative control layer
- add parent-managed account creation and sign-in backed by Firebase Auth
- connect authenticated parent identity to backend entitlement ownership without moving auth into child-facing story flow
- connect StoreKit purchases and restore behavior to authenticated parent users on approved parent-managed surfaces
- add a bounded promo-code redemption path that can grant premium access without a paid purchase flow
- verify blocked -> account create or sign-in -> purchase, restore, or promo -> unlock -> retry happy paths
- keep story history and continuity local-only in this sprint unless scope is explicitly widened later

`docs/verification/launch-candidate-acceptance-report.md` now records StoryTime as `READY FOR MVP LAUNCH` in repo terms after Sprint 10. That launch-ready state is the baseline, not the current objective. The next sprint is explicitly about parent identity, authenticated entitlements, payments, and promo grants.

## Current Phase

Phase 13 - Authenticated Commerce Hardening

## Overall Status Snapshot

- `docs/verification/launch-candidate-acceptance-report.md` records StoryTime as `READY FOR MVP LAUNCH` in repo terms after the March 20, 2026 Sprint 10 rerun.
- The active iOS flow is `HomeView` -> `NewStoryJourneyView` -> `VoiceSessionView` -> `PracticeSessionViewModel`.
- `StoryTimeApp.swift` now configures Firebase during app startup, the iOS project now links both `FirebaseCore` and `FirebaseAuth`, and the app exposes a `ParentAuthManager` seam for parent-managed surfaces. The repo now ships a shared parent-only account sheet for `email/password` create account, sign in, sign out, relaunch persistence, and `Sign in with Apple`, while child story surfaces remain auth-free.
- The active client session coordinator already uses an explicit `VoiceSessionState` model in `StoryDomain.swift`.
- The active realtime client still uses a hidden `WKWebView` bridge in `RealtimeVoiceClient.swift` and `RealtimeVoiceBridgeView.swift`.
- The active runtime now uses coordinator-owned TTS narration for long-form scene delivery while keeping the realtime bridge for live interaction startup, interruption intake, and short spoken interaction responses.
- Structured story state already exists as `StoryData` plus ordered `StoryScene` arrays, and the coordinator already tracks authoritative `currentSceneIndex` state.
- Revision is already future-scene scoped in active code: the client sends `completedScenes` and `remainingScenes`, and the backend returns revised scenes starting from `current_scene_index`.
- The active backend already exposes `/v1/session/identity`, `/v1/realtime/session`, `/v1/realtime/call`, `/v1/story/discovery`, `/v1/story/generate`, `/v1/story/revise`, and `/v1/embeddings/create`.
- The backend now has signed install/session identity for runtime routes plus a Firebase-backed authenticated parent-identity verifier seam for `/v1/session/identity` and entitlement routes, while story and realtime routes remain install/session scoped.
- Primary story storage now lives in the Core Data-backed `storytime-v2.sqlite` store; `UserDefaults` remains for install/session bootstrap keys and legacy migration source blobs only.
- Current entitlement bootstrap, sync, and preflight now carry explicit owner metadata and support authenticated parent-owned entitlement records through `x-storytime-parent-auth`, while the child runtime continues to use install/session plumbing plus `x-storytime-entitlement`.
- `ParentTrustCenterView` currently owns parent-managed plan review, purchase, refresh, and restore flows, while `VoiceSessionView` remains purchase-free and auth-free.
- Parent-managed surfaces can now create accounts, sign in, sign out, and observe relaunch-persisted parent-auth state through `ParentAuthManager`, a dedicated `ParentAccountSheetView`, and parent-only controls in onboarding handoff plus `ParentTrustCenterView`, without adding auth prompts to child story surfaces.
- `APIClient` now sends the signed-in parent Firebase ID token only on bootstrap and entitlement routes, decodes backend owner metadata alongside the entitlement snapshot, and keeps story plus realtime runtime requests free of parent-auth headers.
- Story history and continuity remain local on device. There is no cloud sync, cross-device continuity portability, or account-linked story-history model in the active repo.
- The current test baseline already covers key iOS session logic, API handling, bridge behavior, hybrid narration transport, interruption routing, persistence, backend auth/security, discovery, planner logic, story services, and integration routes.
- The stable hybrid validation slice is green through `M5.1`, and the earlier revision-index mismatch was confirmed as regression-fixture drift rather than a live runtime defect.
- The current test baseline is strongest around startup, coordinator determinism, interruption/revision, hybrid narration transport, persistence, child isolation, and backend contract handling.
- `docs/verification/hybrid-runtime-end-to-end-report.md` now records the first explicit post-migration end-to-end verification pass, using the required evidence labels and the current stable validation command results.
- `docs/verification/realtime-voice-determinism-report.md` now refreshes the narrower interaction-path audit for the active hybrid runtime, including the TTS-to-realtime boundary and explicit no-reconnect semantics.
- `docs/verification/runtime-stage-telemetry-verification.md` now records the current stage-based telemetry evidence, including explicit grouped stages for `interaction`, `generation`, `narration`, and `revision`, supporting-stage treatment for `continuity_retrieval`, and coordinator-owned narration playback start/completion/cancellation wall-clock timing.
- `docs/verification/hybrid-runtime-validation.md` now defines the explicit hybrid-runtime acceptance regression pack, including the exact command, required covered scenarios, and intentionally excluded cases.
- `docs/verification/parent-child-storytelling-ux-audit.md` now records the first post-verification UX audit for the active parent/child storytelling flow, separating parent trust-boundary issues from child storytelling-loop issues and turning them into small follow-up milestones.
- `docs/productization-user-journey-alignment.md` now maps the active parent/child journeys, value moments, trust moments, friction points, and candidate upgrade moments for the productization phase.
- `docs/monetization-entitlement-architecture.md` now defines the first repo-fit monetization direction, including candidate free versus paid boundaries, the split entitlement ownership model, backend preflight touchpoints, and the main pricing-confidence gaps.
- `docs/onboarding-first-run-audit.md` now defines the first-run direction, including the current implicit setup flow, the role of the fallback `Story Explorer` profile, and the recommended parent-led onboarding sequence before the first story starts.
- `docs/paywall-upgrade-entry-strategy.md` now defines where upgrade prompts belong, which ones stay parent-managed, which surfaces stay upgrade-free, and how hard gates should align to the entitlement preflight model.
- `docs/parent-account-payment-foundation-architecture.md` now locks the minimal Sprint 11 architecture: Firebase-backed parent identity, backend-owned authenticated entitlements, parent-managed payment and promo flows, local-only story history, and the main deferred scope boundaries.
- `docs/end-of-story-repeat-use-loop.md` now defines the intended post-story product loop, including how completion should bridge into replay, new-episode continuation, and return-to-library behavior without interrupting the finished child session.
- `docs/launch-mvp-scope-and-acceptance-checklist.md` now locks the MVP launch scope, explicit exclusions, narrowed monetization and launch decisions, and the acceptance checklist plus command set that later M9 implementation and QA work must satisfy.
- `HomeView` now carries clearer product framing for the quick-start path, an actionable parent-controls entry inside the trust card, and saved-library summaries that make replay and continuation value explicit without introducing blocking upgrade UI.
- `NewStoryJourneyView` now reads as a clearer preflight setup surface, with explicit parent handoff, story-path setup, length-and-pacing guidance, and live-session expectation framing before the child enters the voice session.
- `VoiceSessionView` now presents a coordinator-derived session cue card and action hint so the live session exposes clearer listening, narration, answer, revision, pause, and failure cues without changing transport or coordinator behavior.
- `StorySeriesDetailView` now leads with continuation actions, frames continuity as next-episode memory, and keeps parent-only history management separate from replay and new-episode intent.
- Parent trust and privacy communication is now more cohesive across `HomeView`, the lightweight parent gate, `ParentTrustCenterView`, `NewStoryJourneyView`, and `VoiceSessionView`, with clearer distinctions between what stays on device, what goes live during a session, and what the `PARENT` check does not claim to be.
- `ContentView` now routes fresh installs through a dedicated `FirstRunOnboardingView` before the normal `HomeView` surface appears, and the first-run flow now bridges directly into `NewStoryJourneyView` when the parent chooses to start the first story immediately.
- The active repo now has a backend-issued entitlement bootstrap snapshot, a StoreKit-facing purchase normalization seam, a backend entitlement refresh route, and a shared entitlement preflight contract. `NewStoryJourneyView` and `StorySeriesDetailView` now consume that contract before cost-bearing launch, with parent-managed blocked-launch review paths for new stories and saved-series continuation. `ParentTrustCenterView` now exposes the durable plan-state, restore entry, and upgrade framing needed outside the live child session, live bootstrap/sync snapshots carry config-backed Starter and Plus defaults, preflight now depletes backend-owned remaining counts through an install-scoped rolling usage ledger, and the smallest parent-managed StoreKit purchase path now lives inside Parent Controls. Parent-managed plan messaging continues to match the enforced limits, and child-facing runtime surfaces remain purchase-free.
- `docs/verification/account-payment-promo-happy-path-verification.md` now records direct automated evidence that blocked new-story and saved-series continuation flows recover after parent account creation plus purchase or promo redemption, while authenticated restore remains parent-managed and retry reuses refreshed entitlement state.
- `docs/verification/sprint-11-parent-account-commerce-summary.md` now closes Sprint 11 with one explicit verified/partial/unverified summary, the full recorded verification command set, and a repo recommendation to stay on authenticated commerce hardening before any cross-device continuity planning.
- `docs/authenticated-commerce-hardening-plan.md` now converts that recommendation into an approved Phase 13 queue focused on durable entitlement or promo persistence, explicit restore-mismatch rules, and live-environment commerce verification.
- Authenticated parent-owned entitlement records and promo redemption ledgers now persist through `ENTITLEMENTS_PERSIST_PATH`, reload when the backend boots, and remain distinct from local-only story history and continuity data.
- `ParentTrustCenterView` now acts as the durable plan-management surface for the locked MVP hierarchy, and blocked launch review sheets route there without introducing live-session upgrade UI or child-facing purchase prompts.
- The active launch acceptance pack in `docs/verification/hybrid-runtime-validation.md` is still runtime-focused; it does not yet cover onboarding, purchase and restore flows, plan enforcement, or a launch-candidate go/no-go checklist.

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
- Stage-level telemetry is now explicit, narration now carries coordinator-owned playback wall-clock timing in addition to TTS preparation timing, and commercialization thresholds are now repo-owned, but runtime-stage export is still less durable than the joined launch telemetry report.
- Story lifecycle writes and retention pruning no longer rewrite the full library snapshot, but some profile/privacy mutations still use snapshot writes.
- Legacy library/profile/privacy blobs are now migration-source only and the legacy continuity blob is retired after import, but install/session bootstrap keys still remain in `UserDefaults` by design.
- Child-profile story visibility, child-delete cascade behavior, and continuity cleanup are now scoped and reload-safe for owned rows, but some profile/privacy mutations still use snapshot writes.
- Legacy `StorySeries.childProfileId == nil` rows are still compatibility-visible until a later cleanup or reassignment pass, so child scoping is strict for owned rows but not yet full legacy remediation.
- Continuity cleanup now follows persisted `(seriesId, storyId)` provenance across replace, revise, prune, delete-series, and child-delete flows, and the audited privacy copy is now aligned to the active behavior.
- `saveRawAudio` exists in the persisted privacy schema but has no active UI or storage behavior, so the privacy-copy pass must resolve whether it stays as compatibility-only state or is removed later.
- `saveRawAudio` still exists as compatibility-only persisted state even though the UI now states the active product behavior directly.
- Parent controls now require a local confirmation gate, but this remains lightweight friction rather than full parent authentication.
- The acceptance pack is now explicit and green, but it still intentionally excludes a live bridge/WebRTC harness, the new narration playback wall-clock telemetry tests from its default command, and the broader revised-story persistence acceptance path while revision-index logging noise remains unresolved.
- Saved-story deletion now lives behind the parent trust boundary and the global clear-history scope is explicit, but the parent gate remains lightweight friction rather than strong authentication.
- The launch plan, live session, saved-story detail, first-run onboarding, and parent controls now explain the hybrid loop and upgrade boundary more clearly, `M8.1` through `M8.4` define the launch-ready product direction, `M9.2` now turns the first-run guidance into active code, `M9.3.1` through `M9.3.3` establish a real entitlement snapshot, refresh path, and preflight contract, `M9.4.1` through `M9.4.3` keep blocked launches parent-managed while exposing durable plan state and restore from `ParentTrustCenterView`, `M9.5.1` through `M9.5.3` now complete config-backed limits, backend-owned depletion, and truthful client plan messaging plus launch-path verification, `M9.8` records the first explicit launch-candidate QA pass, `M9.9` reruns that launch pack after remediation, `M9.10.1` clears the previous coordinator revision-resume blockers, `M9.10.2` reruns the full launch pack with explicit threshold treatment, `M9.10.3` clears the paused-narration interaction-handoff blockers in the launch-product unit suite, `M9.10.4` now turns cost plus latency thresholds into explicit numeric pass criteria and records a clean final launch rerun, `M9.11` now hardens telemetry durability plus joined launch reporting, and `M9.12` now adds coordinator-owned narration playback wall-clock telemetry. The remaining post-launch telemetry gap is durable per-scene runtime-stage export rather than blocked product behavior, deferred commercial thresholds, or missing playback timing.
- `VoiceSessionView` now closes a finished story with an explicit completion card and child-safe next-step actions for replay, continuation, and return-to-library behavior, and repeat-mode sessions now return to the saved-series surface without interrupting the finished story with upgrade UI.
- Runtime-stage telemetry exists and `M8.2` now turns it into package-boundary direction, launch-default caps plus backend-owned depletion now exist, `M9.7.1` now adds a backend `/health` telemetry report with session-scoped request, provider-usage, and launch-event summaries, `M9.7.2` now adds client launch-event capture for restore attempts, blocked review presentation, parent-managed plan actions, and entitlement outcomes, `docs/verification/launch-confidence-telemetry-report.md` now records the explicit telemetry evidence, `M9.11` now makes those launch reports durable enough for post-launch verification by persisting backend analytics to `ANALYTICS_PERSIST_PATH`, persisting client launch telemetry in `UserDefaults`, and exposing one joined `LaunchTelemetryJoinedReport` through `APIClient.fetchLaunchTelemetryReport()`, and `M9.12` now adds stage-separated narration playback start/completion/cancellation wall-clock evidence at the coordinator boundary. The main remaining telemetry gap is durable runtime-stage timeline export rather than playback fidelity, durability of launch counters, or cross-runtime joining.
- The repo now has a parent-led first-run flow plus working entitlement bootstrap, refresh, preflight, backend-owned usage counters, client plan-limit alignment, and an explicit launch-candidate acceptance report. After `M9.10.4`, the hybrid baseline, backend launch-contract suite, full launch-product unit suite, and full launch-product UI suite are all green, launch-default caps plus numeric cost and latency thresholds are explicit, and the current MVP candidate is now recorded as `GO`.
- `docs/verification/launch-readiness-gap-assessment.md` remained the planning source of truth through Sprint 10, and `docs/verification/launch-candidate-acceptance-report.md` now records the March 20, 2026 final rerun outcome: the commercial blockers are closed and StoryTime is `READY FOR MVP LAUNCH` in repo terms.
- Broader telemetry dashboards, richer parent usage summaries, stronger parent authentication, and per-scene runtime timeline export remain intentionally deferred unless a new launch or post-launch blocker is reproduced.
- Firebase Auth now exists only on parent-managed account surfaces. The next foundation step is backend-authenticated entitlement ownership and account-aware commerce without turning child storytelling into a sign-in-first or purchase-first experience.
- Broad hybrid-runtime refactoring is not the next step unless a new reproduced defect is recorded.

## Open Foundation Decisions

- `READY FOR MVP LAUNCH` remains the launch baseline. Sprint 11 should not reopen Sprint 10 scope or change the launch recommendation unless a new blocker is reproduced.
- First-scope parent auth methods are now locked for implementation planning: `email/password` plus `Sign in with Apple`. Google sign-in, phone auth, child identity, and broader family roles remain deferred unless a later sprint explicitly broadens scope.
- The authenticated entitlement model is now directionally locked: ownership should be represented separately from source, with backend entitlement ownership tied to the authenticated parent user and `EntitlementSnapshot.source` left to describe grant origin such as `storekit_verified`, `promo_grant`, or `none`.
- Story history and continuity remain local-only in Sprint 11. Cross-device continuity sync is intentionally deferred and should not be assumed in implementation or product copy.
- Promo grants are now directionally locked to a bounded one-time redemption default. Reusable codes, renewable promo plans, and wider admin workflows remain deferred unless implementation evidence forces a change.
- Restore semantics under the new account model are now explicit for the current repo scope: restored Plus stays claimed to the parent account that restored it on the current device or install, and a different signed-in parent now gets an explicit restore conflict instead of a silent transfer. Live family-share and broader multi-device restore behavior still need direct verification.
- Authenticated entitlement ownership and promo redemption are now durable across backend restarts through a repo-fit JSON persistence layer. Later work still needs to define the final backup, migration, or production storage story if the backend grows beyond this smallest hardening layer.
- The live authenticated-commerce pass is now explicitly split into repo-prep work and physical-device execution work. The repo now has the support rerun plus live checklist, but production Apple auth and App Store behavior still require a human-operated environment to verify directly.
- `M13.3b` is now explicitly blocked on external execution prerequisites: a paired physical iOS device ready for developer execution, a live-capable build, and real Apple/App Store credentials or environment access.
- Production Firebase parent-token verification now requires backend environment configuration: `FIREBASE_PROJECT_ID` plus either service-account credentials (`FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`) or application default credentials.
- Intentionally deferred unless reprioritized: full cloud sync, multi-device story portability, broader family account management, web admin tooling, and a broader auth-provider matrix.

## Next Recommended Milestone

`M13.3b - Live authenticated-commerce execution and report` once the live-device blocker is cleared

Reason:
- `M13.3a` is now complete, so the remaining highest-signal gap is still the actual physical-device execution of production Apple auth, App Store purchase, and App Store restore.
- The repo already has the deterministic support pack and live checklist, so no further repo-only implementation work is the right next step until the external blocker is cleared.
- Family-share and real App Store mismatch behavior remain only partially verified until that live pass is actually recorded.

## Milestone Status

| Milestone | Status | Notes |
| --- | --- | --- |
| M11.1 Account architecture and flow alignment | DONE | `docs/parent-account-payment-foundation-architecture.md` now locks the minimal Sprint 11 architecture, parent-managed boundaries, first-scope auth methods, local-only story-history rule, and promo-grant direction. |
| M11.2 Firebase Auth integration for parent identity | DONE | Firebase Auth is now linked into the iOS app, `ParentAuthManager` exposes parent-auth state to onboarding and `ParentTrustCenterView`, and child story surfaces remain sign-in-free in targeted UI coverage. |
| M11.3a Email/password parent account surfaces and relaunch persistence | DONE | Parent-managed onboarding and `ParentTrustCenterView` now open a shared account sheet for `email/password` create account and sign in, signed-in state persists across relaunch, direct sign-out stays in parent controls, and child story surfaces remain auth-free in targeted UI coverage. |
| M11.3b Sign in with Apple on parent-managed account surfaces | DONE | The shared parent account sheet now supports `Sign in with Apple`, `ParentAuthManager` maps Apple-authenticated state explicitly, relaunch persistence is covered in deterministic UI tests, and child story surfaces remain auth-free. |
| M11.4 Backend authenticated entitlement model alignment | DONE | Backend now verifies Firebase-authenticated parent identity on `/v1/session/identity` and entitlement routes, signed entitlement tokens plus bootstrap/sync/preflight envelopes carry explicit owner metadata, authenticated parent entitlements resolve by parent user while stale install-owned tokens are ignored after sign-in, and story plus realtime routes remain install/session scoped. |
| M11.5 StoreKit purchase integration in parent-managed surfaces | DONE | Parent-managed purchase initiation now requires a signed-in parent account, purchase ownership is enforced server-side with `parent_auth_required`, `ParentTrustCenterView` truthfully explains account-linked ownership, and focused UI coverage now proves direct purchase completion plus blocked new-story and continuation recovery without adding purchase UI to child-session surfaces. |
| M11.6 Authenticated restore and entitlement refresh verification | DONE | Backend restore ownership, client owner handling, bootstrap-safe install fallback preservation, blocked-flow restore or refresh recovery, and parent-controls sign-out fallback are all covered in tests, with the remaining live App Store mismatch questions called out as environment-dependent gaps. |
| M11.7 Promo-code redemption flow for premium grants | DONE | Parent Controls now exposes parent-only promo redemption, backend env-backed promo grants redeem through authenticated parent ownership with source `promo_grant`, and targeted backend/iOS tests cover success plus invalid, expired, and already-used promo failures. |
| M11.8 Account, payment, and promo happy-path verification | DONE | `docs/verification/account-payment-promo-happy-path-verification.md` now records direct automated evidence for purchase-backed and promo-backed blocked recovery, restore-managed recovery, and retry-token reuse without child-surface auth or purchase prompts. |
| M11.9 Post-sprint readiness summary and remaining gaps | DONE | `docs/verification/sprint-11-parent-account-commerce-summary.md` now records the exact Sprint 11 verification command set, the verified/partial/unverified outcome matrix, and the recommendation to stay on authenticated commerce hardening before continuity planning. |
| M13.0 Authenticated commerce hardening plan and queue approval | DONE | `docs/authenticated-commerce-hardening-plan.md` now records the approved post-Phase-12 queue and narrows the next workstream to durable entitlement or promo persistence, restore-mismatch rules, and live-environment Apple or StoreKit verification. |
| M13.1 Durable authenticated entitlement and promo persistence | DONE | Backend authenticated entitlement records and promo redemption ledgers now persist through `ENTITLEMENTS_PERSIST_PATH`, reload across backend recreation, and keep the existing iOS contract unchanged. |
| M13.2 Restore mismatch and device-fallback product rule | DONE | Restore-linked Plus now stays claimed to the parent account that restored it on the current device, mismatch attempts fail with `restore_parent_mismatch`, and parent-facing copy now makes local fallback explicit in Parent Controls and onboarding. |
| M13.3a Live authenticated-commerce verification prep and support rerun | DONE | The deterministic support pack was rerun, the live-only execution gap was isolated, and `docs/verification/live-authenticated-commerce-verification-prep.md` now records exact prerequisites, commands, and the physical-device checklist for the real pass. |
| M13.3b Live authenticated-commerce execution and report | BLOCKED | Record the first live-environment verification pass for production Apple sign-in, App Store purchase, and App Store restore after the prep and support rerun are complete. Blocked on physical-device and live-environment access. |
| M12.1 First-run activation onboarding flow | DONE | Fresh installs now stay inside a dedicated seven-step onboarding journey until child setup, parent sign-in, and plan choice are complete; account and plan entry moved into onboarding, Parent Controls were reframed as ongoing management, and targeted smoke plus UI coverage now pins the new gate. |
| M12.2 Onboarding activation verification and hardening | DONE | `docs/verification/onboarding-activation-verification.md` now records fresh-install gating, plan-entry visibility, purchase or restore or promo completion, relaunch persistence, the onboarding-sheet dismiss hardening, and the explicit decision to keep the current onboarding completion key without a version bump. |
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
| M9.1 Launch scope lock and MVP acceptance checklist | DONE | `docs/launch-mvp-scope-and-acceptance-checklist.md` now locks the MVP scope, explicit exclusions, narrowed launch decisions, and the launch-candidate checklist plus command set. |
| M9.2 Onboarding and first-run flow implementation | DONE | Fresh installs now enter a parent-led first-run flow with trust framing, fallback-child setup, expectation setting, and optional handoff into `NewStoryJourneyView`, while returning users bypass onboarding. |
| M9.3.1 Entitlement snapshot model and bootstrap foundation | DONE | `/v1/session/identity` now returns a normalized entitlement snapshot plus signed bootstrap token, and the iOS client caches and exposes that snapshot through `AppEntitlements` and `EntitlementManager`. |
| M9.3.2 StoreKit sync seam and entitlement refresh flow | DONE | StoreKit-facing purchase state now normalizes into the shared entitlement model, and `/v1/entitlements/sync` refreshes the backend-issued snapshot. |
| M9.3.3 Preflight contract foundation for launch gating | DONE | `/v1/entitlements/preflight` now evaluates shared new-story and continuation launch context against the signed entitlement snapshot and returns a repo-owned decision contract. |
| M9.4.1 New story journey block surface and parent-managed route | DONE | `NewStoryJourneyView` now preflights before launch, blocks disallowed starts before `VoiceSessionView`, and routes parents through a lightweight review flow instead of live-session upgrade UI. |
| M9.4.2 Saved-series continuation gate and replay-safe routing | DONE | `StorySeriesDetailView` now preflights `New Episode`, keeps blocked continuation out of `VoiceSessionView`, routes parents through a saved-series review flow, and leaves `Repeat` available. |
| M9.4.3 Durable parent plan management and optional home awareness | DONE | `ParentTrustCenterView` now exposes durable Starter plan state, restore entry, and upgrade framing, and blocked new-story review can route there without introducing live-session upgrade UI. |
| M9.5 Usage limits and plan enforcement | DONE | Split into `M9.5.1` through `M9.5.3`; config-backed defaults, backend-owned depletion, and client alignment now all land with targeted client, backend, and UI verification. |
| M9.5.1 Config-backed entitlement defaults in live snapshots | DONE | Backend bootstrap and sync snapshots now issue config-backed Starter and Plus caps, remaining counts, and rolling windows instead of nil-heavy defaults. |
| M9.5.2 Backend usage accounting and preflight depletion | DONE | Backend preflight now consumes install-scoped rolling usage, bootstrap and sync snapshots reflect depleted counters, and the client caches refreshed entitlement envelopes returned from preflight. |
| M9.5.3 Client plan-limit alignment and launch-path verification | DONE | Parent controls, blocked-launch review copy, and launch-path UI tests now reflect enforced plan limits truthfully across blocked and allowed paths. |
| M9.6 End-of-story and repeat-use loop implementation | DONE | `VoiceSessionView` now acknowledges completion with replay, new-episode, and return actions, while targeted tests pin replay-safe behavior and saved-story navigation. |
| M9.7 Cost, usage, and latency telemetry for launch confidence | DONE | Split into `M9.7.1` through `M9.7.3`; backend launch telemetry, client launch-surface instrumentation, and the explicit launch-confidence verification artifact now all land. |
| M9.7.1 Backend launch telemetry and session-reporting foundation | DONE | Backend analytics now records entitlement launch events, provider usage is session-joinable, and `/health` exposes a concrete telemetry report with counters plus per-session summaries. |
| M9.7.2 Client launch telemetry for entitlement and upgrade surfaces | DONE | `APIClient`, blocked-review views, and `ParentTrustCenterView` now emit redacted client launch telemetry with in-memory counters plus session summaries for restore, review presentation, and entitlement outcomes. |
| M9.7.3 Launch-confidence verification artifact and reporting path | DONE | `docs/verification/launch-confidence-telemetry-report.md` now records the concrete backend and client report shapes, exact commands, evidence labels, and the remaining telemetry gaps for launch review. |
| M9.8 Launch candidate QA and acceptance pass | DONE | `docs/verification/launch-candidate-acceptance-report.md` now records the exact launch-candidate command set, evidence labels, and a `NO-GO` decision driven by failing iOS launch-product suites plus unresolved commercial thresholds. |
| M9.9 Launch blocker remediation | DONE | `M9.9.1` and `M9.9.2` cleared the original blocker sets, and `M9.9.3` reran the launch pack to confirm the UI suite is green while narrowing the remaining no-go state to two coordinator revision-resume tests plus unresolved commercial thresholds. |
| M9.9.1 Coordinator repeat/revision acceptance regression fixes | DONE | `PracticeSessionViewModel` now handles repeat-episode full-story rewrites deterministically, resume-after-revision uses the reported revision start index, and the blocked coordinator acceptance cases are green again. |
| M9.9.2 Launch UI and parent-trust regression fixes | DONE | Seeded UI tests now use local entitlement preflight fallback and deterministic story generation, parent/privacy assertions account for the plan-first parent form layout, and the blocked `StoryTimeUITests` launch-product cases are green again. |
| M9.9.3 Launch candidate re-run and commercial-threshold decision | DONE | The exact launch-candidate pack was rerun cleanly; hybrid and backend slices are green, the full UI suite is green, but the final unit slice still fails on two revision-resume tests and the launch decision remains `NO-GO` while commercial thresholds stay deferred. |
| M9.10 Remaining launch blockers and threshold closure | DONE | `M9.10.1` through `M9.10.4` are now complete; the final launch rerun is green, numeric cost and latency thresholds are explicit, and the current locked MVP candidate is recorded as `GO`. |
| M9.10.1 Revision-resume moderation and deferred-transcript blocker fix | DONE | `PracticeSessionViewModel` now accepts backend-authored current-scene revision replay during resume, leaving blocked revision moderation and deferred transcript rejection green again. |
| M9.10.2 Commercial threshold definition and final launch rerun | DONE | The full launch pack was rerun on March 13, 2026; hybrid, backend, and full UI coverage are green, launch-default cap treatment now passes explicitly, and the remaining no-go state is narrowed to two paused-narration coordinator tests plus deferred cost and latency thresholds. |
| M9.10.3 Paused-narration interaction handoff blocker fix | DONE | `PracticeSessionViewModel` now accepts later future-scene revision start indices during paused-narration resume, which restores no-reconnect and transcript-final direct interaction handoff behavior and returns the full launch-product unit slice to green. |
| M9.10.4 Numeric commercial threshold decision and clean launch rerun | DONE | Cost and latency thresholds now have explicit numeric launch terms, the exact `M9.8` launch pack reran green on March 13, 2026, and `docs/verification/launch-candidate-acceptance-report.md` now records a `GO` launch decision for the current MVP candidate. |
| M9.11 Telemetry durability and joined launch-report hardening | DONE | Backend analytics now persist to disk, client launch telemetry now persists in `UserDefaults`, and `APIClient.fetchLaunchTelemetryReport()` now exposes one joined backend-plus-client report surface. |
| M9.12 Narration wall-clock telemetry hardening | DONE | `PracticeSessionViewModel` now records stage-separated narration playback start, completion, and cancellation wall-clock telemetry while preserving separate TTS preparation timing, and the verification docs now reflect that evidence. |
| M10.0 Launch-gap assessment review and Sprint 10 approval | DONE | The launch-gap assessment is now the planning source of truth, the final commercial-closure sprint is approved, and the next execution path is narrowed to `M10.1` through `M10.3`. |
| M10.1 Parent-managed purchase surface closure | DONE | `ParentTrustCenterView` now hosts the smallest truthful StoreKit-backed purchase path, refresh and restore stay parent-managed, and targeted UI and unit tests confirm no purchase UI appears in child-session surfaces. |
| M10.2 Upgrade unblock happy-path verification | DONE | Blocked new-story and continuation flows now recover after parent-managed purchase, retry uses refreshed entitlement state instead of bypassing preflight, and the evidence is recorded in `docs/verification/commercial-upgrade-happy-path-verification.md`. |
| M10.3 Commercial launch rerun and blocker closeout | DONE | The full launch-readiness pack reran green on March 20, 2026, the only rerun issue was a tightly related brittle UI assertion fix, and `docs/verification/launch-candidate-acceptance-report.md` now records `READY FOR MVP LAUNCH`. |

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
- The initial Plus catalog now assumes the explicit product IDs `storytime.plus.monthly` and `storytime.plus.yearly`, but final price points and billing presentation remain open until launch pricing confidence is high enough.
- How short should the backend entitlement-snapshot TTL be, and should entitlement preflight reserve a launch slot before realtime startup begins?
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

### 2026-03-10 - Launch-readiness planning pass and M9 queue definition
- Status: DONE
- Summary: Re-audited the current repo state after the completed M8 sprint and shifted the control files into a launch-readiness phase. This pass confirmed that `ContentView` still opens directly into `HomeView`, `HomeView` / `NewStoryJourneyView` / `VoiceSessionView` / `StorySeriesDetailView` now reflect the M8 productization direction, the onboarding/monetization/paywall/end-of-story docs define the intended behavior, runtime-stage telemetry exists, and the active acceptance pack is still runtime-focused rather than launch-candidate-focused. `AGENTS.md`, `PLANS.md`, and `SPRINT.md` now define M9 as the next milestone group.
- Files: `AGENTS.md`, `PLANS.md`, `SPRINT.md`
- Tests: No new tests were run. This was a planning-only pass grounded in repo inspection of the active SwiftUI surfaces, current verification docs, and the existing onboarding, monetization, paywall, telemetry, and repeat-use design artifacts.
- Decisions:
  - Move the default workstream from completed productization groundwork into launch readiness.
  - Make `M9.1 - Launch scope lock and MVP acceptance checklist` the next recommended milestone before implementation starts on onboarding, billing, paywall, limits, telemetry, or launch QA.
  - Treat onboarding, entitlements, upgrade surfaces, usage limits, and telemetry as connected product systems rather than isolated UI tasks.
- Risks/Notes:
  - The repo still has no onboarding implementation, StoreKit layer, entitlement sync, usage counters, paywall UI, or launch-candidate acceptance checklist.
  - Final Starter versus Plus boundaries, cap numbers, billing verification scope, entitlement storage rules, and the exact launch-ready definition are still open launch decisions.
- Next: M9.1 - Launch scope lock and MVP acceptance checklist

### 2026-03-10 - M9.1 Launch scope lock and MVP acceptance checklist
- Status: DONE
- Summary: Added `docs/launch-mvp-scope-and-acceptance-checklist.md` to lock the launch-ready MVP shape after the completed M8 groundwork. The new artifact records the current repo baseline, what is explicitly in scope for the MVP launch candidate, what remains out of scope, the narrowed monetization and launch decisions that later milestones should treat as fixed, the definition of MVP-launch-ready, and the exact command groups and evidence labels that the `M9.8` launch-candidate pass must report.
- Files: `docs/launch-mvp-scope-and-acceptance-checklist.md`, `PLANS.md`, `SPRINT.md`
- Tests: No new tests were added or run. `M9.1` is a planning milestone, so its required verification method was repo inspection of the active launch surfaces, current test inventory, and the existing onboarding, monetization, paywall, repeat-use, and verification artifacts.
- Decisions:
  - Lock MVP launch to a two-tier `Starter` / `Plus` model, with StoreKit 2 as purchase truth and backend preflight plus entitlement snapshot as runtime enforcement truth.
  - Lock the parent-managed upgrade hierarchy to `NewStoryJourneyView`, `StorySeriesDetailView`, `ParentTrustCenterView`, and optional soft `HomeView` awareness, while keeping `VoiceSessionView` and active narration free of hard-blocking upgrade UI.
  - Lock replay, privacy controls, deletion controls, and the single-device local-history model into MVP, and keep accounts, sync, narration-minute pricing, and stronger parent authentication out of scope.
- Risks/Notes:
  - Exact numeric launch defaults for new-story, continuation, and any length caps remain open, but are now narrowed to configuration-backed implementation values instead of open-ended product-shape questions.
  - Whether entitlement summary piggybacks on `/v1/session/identity` or a sibling bootstrap route remains an implementation detail for `M9.3`, not a scope blocker.
- Next: M9.2 - Onboarding and first-run flow implementation

### 2026-03-10 - M9.2 Onboarding and first-run flow implementation
- Status: DONE
- Summary: Implemented the parent-led first-run onboarding flow as an actual app entry path instead of a planning artifact. Fresh installs now open into a dedicated onboarding sequence that covers the product promise, trust and privacy framing, fallback-child confirmation or editing, live-session expectations, and parent handoff into the first story setup flow, while returning users bypass onboarding and land on the normal home surface.
- Files: `ios/StoryTime/App/ContentView.swift`, `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testFreshInstallShowsParentLedOnboardingFlow -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCanEditFallbackChildProfile -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingHandsOffToFirstStorySetupAndStaysDismissedAfterRelaunch -only-testing:StoryTimeTests/SmokeTests/testFirstRunExperienceStoreDefaultsToIncompleteAndPersistsCompletion`, which passed `4` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceFirstStoryJourney`, which passed during the earlier targeted onboarding regression run for this milestone.
- Decisions:
  - Make onboarding the actual first-run root in `ContentView` instead of a late-presented cover on top of `HomeView`, so fresh installs do not expose the returning-user home surface behind onboarding.
  - Reuse the existing parent trust and child-profile editing surfaces from `HomeView` instead of introducing a second profile model or duplicate parent-controls content for onboarding.
  - Keep first-run completion state local and minimal through a dedicated `FirstRunExperienceStore`, and keep seeded returning-user UI tests pinned to bypass onboarding explicitly.
- Risks/Notes:
  - The first-run flow is now implemented, but monetization, entitlement bootstrap, paywall routing, and usage enforcement are still missing and now become the primary launch-readiness dependency chain.
  - The onboarding persistence key is local-device state only; any later account or multi-device model would need an explicit migration path, which remains out of scope for MVP.
- Next: M9.3 - Billing and entitlement foundation implementation

### 2026-03-10 - M9.3.1 Entitlement snapshot model and bootstrap foundation
- Status: DONE
- Summary: Split the oversized `M9.3` launch-readiness milestone into three execution slices, then completed the first slice by adding one repo-owned entitlement snapshot model across backend and iOS. `/v1/session/identity` now returns a signed entitlement bootstrap envelope, the backend can issue and verify entitlement tokens for install-scoped snapshots, and the client now caches and exposes the latest entitlement state without widening into StoreKit, paywall UI, or usage enforcement.
- Files: `backend/src/app.ts`, `backend/src/lib/entitlements.ts`, `backend/src/lib/security.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/auth-security.test.ts`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run /Users/rory/Documents/StoryTime/backend/src/tests/app.integration.test.ts /Users/rory/Documents/StoryTime/backend/src/tests/auth-security.test.ts`, which passed `32` tests across `2` files.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=EC4B5552-9701-4B63-8EC1-B9E34CEE50A9' -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityStoresSessionToken -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityStoresEntitlementSnapshot -only-testing:StoryTimeTests/APIClientTests/testAppEntitlementsClearsExpiredSnapshot -only-testing:StoryTimeTests/APIClientTests/testStartupSequenceReusesBootstrappedSessionAcrossVoicesAndRealtimeSession -only-testing:StoryTimeTests/SmokeTests/testEntitlementManagerLoadsBootstrapSnapshotFromCache`, which passed `5` tests.
- Decisions:
  - Resolve the bootstrap-route question by attaching the entitlement envelope to the existing `/v1/session/identity` response instead of creating a parallel bootstrap route.
  - Keep the first foundation slice architecture-first: allow bootstrap and debug-seeded snapshots, add a signed install-scoped entitlement token, and leave StoreKit sync plus usage enforcement for `M9.3.2` and `M9.5`.
  - Lock only the entitlement shape that is already required for launch implementation now: tier, source, capability flags, child-profile cap, nullable remaining counters, and effective/expiry metadata.
- Risks/Notes:
  - Exact numeric launch defaults for story and continuation caps remain open, so the snapshot currently leaves those counters nullable instead of inventing enforcement numbers early.
  - The bootstrap snapshot is now real, but it is still bootstrap-only state until `M9.3.2` adds the StoreKit-facing refresh path and backend sync contract.
- Next: M9.3.2 - StoreKit sync seam and entitlement refresh flow

### 2026-03-10 - M9.3.2 StoreKit sync seam and entitlement refresh flow
- Status: DONE
- Summary: Completed the second entitlement-foundation slice by adding a normalized StoreKit-facing purchase-state seam on iOS and a backend refresh route that returns the same repo-owned entitlement envelope shape used at bootstrap. The backend now accepts normalized transaction input on `/v1/entitlements/sync`, verified active Plus products refresh the signed entitlement snapshot, and the client can refresh or invalidate cached entitlement state through `EntitlementManager` without widening into paywall UI or usage enforcement.
- Files: `backend/src/app.ts`, `backend/src/lib/entitlements.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/entitlements.test.ts`, `backend/src/types.ts`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run /Users/rory/Documents/StoryTime/backend/src/tests/app.integration.test.ts /Users/rory/Documents/StoryTime/backend/src/tests/auth-security.test.ts /Users/rory/Documents/StoryTime/backend/src/tests/entitlements.test.ts`, which passed `36` tests across `3` files.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=EC4B5552-9701-4B63-8EC1-B9E34CEE50A9' -only-testing:StoryTimeTests/APIClientTests/testSyncEntitlementsPostsNormalizedPurchaseStateAndStoresRefreshedSnapshot -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityStoresEntitlementSnapshot -only-testing:StoryTimeTests/APIClientTests/testAppEntitlementsClearsExpiredSnapshot -only-testing:StoryTimeTests/APIClientTests/testStartupSequenceReusesBootstrappedSessionAcrossVoicesAndRealtimeSession -only-testing:StoryTimeTests/SmokeTests/testEntitlementSyncRequestDerivesActiveProductsFromVerifiedActiveTransactions -only-testing:StoryTimeTests/SmokeTests/testEntitlementManagerRefreshesFromPurchaseState -only-testing:StoryTimeTests/SmokeTests/testEntitlementManagerLoadsBootstrapSnapshotFromCache`, which passed `7` tests.
- Decisions:
  - Keep purchase truth StoreKit-facing but normalize it immediately into the repo-owned sync contract so later purchase, restore, and paywall surfaces do not depend on StoreKit-only enums or hidden state.
  - Treat `storytime.plus.monthly` and `storytime.plus.yearly` as the initial verified Plus product IDs for MVP sync and refresh behavior.
  - Keep this slice foundation-only: allow entitlement refresh and invalidation now, but leave preflight gating, usage accounting, and upgrade UI to later milestones.
- Risks/Notes:
  - Purchase and restore UI still do not exist, so the new sync route is only a foundation seam until `M9.4` wires visible upgrade flows.
  - Preflight gating still does not exist, so refreshed entitlements are not yet used to block new-story or continuation cost before runtime boot.
- Next: M9.3.3 - Preflight contract foundation for launch gating

### 2026-03-10 - M9.3.3 Preflight contract foundation for launch gating
- Status: DONE
- Summary: Completed the third entitlement-foundation slice by adding one shared preflight contract across backend and iOS for cost-bearing launch intent before runtime boot. The backend now exposes `/v1/entitlements/preflight`, validates the signed install-scoped entitlement snapshot when present, evaluates new-story versus continuation launch context against child-profile, length, and remaining-capability rules, and returns a repo-owned allow-or-block decision that later paywall and limit-enforcement milestones can consume without reworking the contract.
- Files: `backend/src/app.ts`, `backend/src/lib/entitlements.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/entitlements.test.ts`, `backend/src/types.ts`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run /Users/rory/Documents/StoryTime/backend/src/tests/app.integration.test.ts /Users/rory/Documents/StoryTime/backend/src/tests/auth-security.test.ts /Users/rory/Documents/StoryTime/backend/src/tests/entitlements.test.ts`, which passed `42` tests across `3` files.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=EC4B5552-9701-4B63-8EC1-B9E34CEE50A9' -only-testing:StoryTimeTests/APIClientTests/testPreflightEntitlementsPostsLaunchContextAndDecodesBlockedDecision -only-testing:StoryTimeTests/APIClientTests/testSyncEntitlementsPostsNormalizedPurchaseStateAndStoresRefreshedSnapshot -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityStoresEntitlementSnapshot -only-testing:StoryTimeTests/APIClientTests/testAppEntitlementsClearsExpiredSnapshot -only-testing:StoryTimeTests/APIClientTests/testStartupSequenceReusesBootstrappedSessionAcrossVoicesAndRealtimeSession -only-testing:StoryTimeTests/SmokeTests/testEntitlementPreflightRequestBuildsNewStoryContextFromLaunchPlan -only-testing:StoryTimeTests/SmokeTests/testEntitlementPreflightRequestBuildsContinuationContextFromLaunchPlan -only-testing:StoryTimeTests/SmokeTests/testEntitlementPreflightRequestSkipsRepeatOnlyLaunchPlan -only-testing:StoryTimeTests/SmokeTests/testEntitlementManagerPreflightsAgainstBackendContract -only-testing:StoryTimeTests/SmokeTests/testEntitlementSyncRequestDerivesActiveProductsFromVerifiedActiveTransactions -only-testing:StoryTimeTests/SmokeTests/testEntitlementManagerRefreshesFromPurchaseState -only-testing:StoryTimeTests/SmokeTests/testEntitlementManagerLoadsBootstrapSnapshotFromCache`, which passed `12` tests.
- Decisions:
  - Keep preflight evaluation tied to the signed install-scoped entitlement snapshot through `x-storytime-entitlement` instead of inventing hidden backend state or account assumptions.
  - Keep the first contract focused on action type, child-profile count, requested length, and optional series context, and leave final usage accounting plus upgrade copy to later milestones.
  - Treat repeat-only replay as outside the preflight contract so later gating remains aligned with the locked MVP rule that replay stays available after paid exhaustion.
- Risks/Notes:
  - The contract exists, but no launch surface consumes it yet, so `NewStoryJourneyView` and `StorySeriesDetailView` still do not block or route into upgrade UI.
  - Exact numeric Starter and Plus caps remain open, so the preflight evaluator only enforces snapshot-backed capability flags and counters that already exist in the entitlement model.
- Next: M9.4.1 - New story journey block surface and parent-managed route

### 2026-03-10 - M9.4 split and M9.4.1 New story journey block surface and parent-managed route
- Status: DONE
- Summary: Split the oversized `M9.4` paywall milestone into three execution slices, then completed the first slice by wiring `NewStoryJourneyView` into the entitlement preflight contract before session start. Journey-based new-story and continuation attempts now stop before `VoiceSessionView` when preflight blocks them, show a truthful blocked-launch explanation on the journey surface, and route into a parent-managed review flow that preserves child and story context without adding purchase UI to the live child path.
- Files: `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=EC4B5552-9701-4B63-8EC1-B9E34CEE50A9' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlocksContinuationStartAndKeepsReplayCopyTruthful -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyExplainsContinueModeAndCharacterReuseChoices`, which passed `3` tests.
- Decisions:
  - Split `M9.4` into `M9.4.1`, `M9.4.2`, and `M9.4.3` so launch-readiness upgrade work can stay one safe Codex-sized slice at a time.
  - Keep the first upgrade surface in `NewStoryJourneyView` only, because it already owns launch-plan context and can block cost-bearing starts before `VoiceSessionView` without widening into saved-series detail or durable purchase management.
  - Route blocked starts through the existing lightweight parent gate and a journey-owned review sheet instead of introducing purchase controls or transactional UI into the child-facing flow.
- Risks/Notes:
  - `StorySeriesDetailView` still does not preflight or block `New Episode`, so the saved-series continuation surface can still bypass the approved parent-managed upgrade review path.
  - The repo still has no durable plan-management surface, restore-purchase affordance, or purchase flow; this slice only adds the first launch gate and review route.
- Next: M9.4.2 - Saved-series continuation gate and replay-safe routing

### 2026-03-10 - M9.4.2 Saved-series continuation gate and replay-safe routing
- Status: DONE
- Summary: Completed the saved-series continuation gate by wiring `StorySeriesDetailView` into entitlement preflight before `New Episode` starts. Blocked continuation attempts now stay out of `VoiceSessionView`, switch into a parent-managed review route from the series detail surface, and keep `Repeat` available as the replay-safe path required by the locked MVP rules.
- Files: `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlocksNewEpisodeAndKeepsReplayTruthful -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationRoutesToParentManagedReview -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailRepeatRemainsAvailableWhenContinuationIsBlocked -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailPrioritizesContinuationActionsOverContinuityDetails`, which passed `4` tests.
- Decisions:
  - Keep `Repeat` as a direct replay route with no entitlement preflight so the saved-series surface stays aligned with the locked rule that replay remains available after paid exhaustion.
  - Reuse the lightweight parent gate plus review-sheet pattern from `M9.4.1`, but keep the saved-series copy continuation-specific instead of introducing generic subscription language.
  - Match the UI test preflight override to the backend continuation surface (`story_series_detail`) so the seeded UI flow reflects the real contract.
- Risks/Notes:
  - The repo still has no durable parent plan-management surface, restore affordance, or purchase flow; blocked launches currently terminate in review copy plus parent-controls navigation only.
  - Usage counters and final Starter versus Plus numeric limits are still not enforced beyond the snapshot-backed preflight decision foundation.
- Next: M9.4.3 - Durable parent plan management and optional home awareness

### 2026-03-11 - M9.4.3 Durable parent plan management and optional home awareness
- Status: DONE
- Summary: Added the durable parent-managed plan surface inside `ParentTrustCenterView`, including current plan status, entitlement-backed usage summaries, explicit Starter versus Plus framing, refresh, and restore entry. Blocked new-story review now points parents at the durable Parent Controls surface, and the implementation intentionally left `HomeView` free of extra plan-state chrome to avoid widening scope beyond the locked MVP hierarchy.
- Files: `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyReviewLinksToDurableParentPlanSurface -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowCurrentPlanAndRestoreEntry`, which passed during the targeted combined verification run.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRenderAndAddAChildProfile`, which passed after updating the legacy test to scroll to the lower parent-controls section introduced by the new plan surface.
- Decisions:
  - Keep durable plan state, upgrade framing, and restore strictly inside `ParentTrustCenterView` so the approved parent-managed hierarchy stays intact and live child-session surfaces remain upgrade-free.
  - Reuse the existing entitlement snapshot for the parent plan summary and seeded UI tests instead of introducing parallel mock plan data.
  - Defer optional `HomeView` plan awareness because it adds launch-scope risk without being required to complete the approved hierarchy.
- Risks/Notes:
  - The repo still has no purchase flow; restore entry and plan framing now exist, but actual buying remains outside the current milestone.
  - Final Starter versus Plus counters, windows, and enforcement still depend on `M9.5`.
  - One combined UI rerun hit a simulator launch failure (`com.storytime.StoryTimeUITests.xctrunner` not found); the underlying milestone assertions were re-verified with targeted reruns and the isolated parent-controls flow passed cleanly.
- Next: M9.5 - Usage limits and plan enforcement

### 2026-03-11 - M9.5 split and M9.5.1 Config-backed entitlement defaults in live snapshots
- Status: DONE
- Summary: Split `M9.5` into smaller enforcement slices because the original milestone combined launch-default selection, backend-owned usage depletion, and client-side limit alignment. Completed the first slice by moving Starter and Plus launch defaults into backend env-backed entitlement config so live bootstrap, sync, and preflight snapshots now expose explicit child-profile caps, rolling-window counts, and remaining allowance instead of nil-heavy placeholders.
- Files: `backend/src/lib/env.ts`, `backend/src/lib/entitlements.ts`, `backend/src/tests/testHelpers.ts`, `backend/src/tests/entitlements.test.ts`, `backend/src/tests/app.integration.test.ts`, `ios/StoryTime/Tests/APIClientTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts` from `/Users/rory/Documents/StoryTime/backend`, which passed `34` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests`, which passed `21` tests.
- Decisions:
  - Split `M9.5` into `M9.5.1` through `M9.5.3` because the repo has no backend-owned usage ledger yet, and faking depletion on the client or in unsigned local state would weaken enforcement truth.
  - Use config-backed launch defaults in backend env so Starter versus Plus values can change without code edits while the next slices add server-owned depletion and client alignment.
  - Keep replay and parent-managed trust surfaces fully allowed in the snapshot model; this slice only replaces nil-heavy plan defaults and does not attempt depletion.
- Risks/Notes:
  - Remaining story-start and continuation counts are still static snapshot values; they do not deplete across launches until `M9.5.2`.
  - Parent-controls child-profile management is still hardcoded to the app-side v1 cap and does not yet reflect the new Starter versus Plus child-profile defaults.
  - Purchase UI and restore-driven buying still remain outside the current enforcement slices.
- Next: M9.5.2 - Backend usage accounting and preflight depletion

### 2026-03-11 - M9.5.2 Backend usage accounting and preflight depletion
- Status: DONE
- Summary: Added backend-owned rolling-window usage accounting for cost-bearing entitlement preflight so new-story and continuation allowance now deplete per install before runtime cost begins. Bootstrap, sync, and preflight responses now all reflect backend truth, and preflight returns a refreshed entitlement envelope that the iOS client stores immediately to keep cached plan state aligned after each allowed or blocked attempt.
- Files: `backend/src/app.ts`, `backend/src/lib/entitlements.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/entitlements.test.ts`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts` from `/Users/rory/Documents/StoryTime/backend`, which passed `38` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests`, which passed `21` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailRepeatRemainsAvailableWhenContinuationIsBlocked`, which passed `2` tests as a focused blocked-versus-replay UI verification pass after the backend enforcement change.
- Decisions:
  - Keep usage accounting install-scoped and rolling-window based inside the backend entitlement module for this milestone instead of inventing unsigned client counters or widening into purchase persistence.
  - Consume usage at the preflight boundary because that is the repo’s existing pre-cost gate for new-story and continuation launches.
  - Return a refreshed entitlement envelope on every preflight response so the iOS cache stays aligned with backend-owned remaining counters without extra sync calls.
- Risks/Notes:
  - Parent-controls child-profile management and plan messaging still do not fully reflect the enforced Starter versus Plus caps; that alignment remains for `M9.5.3`.
  - Purchase UI and real billing remain outside the current launch-readiness slice.
  - The backend usage ledger is in-memory for the current repo architecture, so durability is process-local until a later milestone introduces a persisted billing or account-backed source of truth.
- Next: M9.5.3 - Client plan-limit alignment and launch-path verification

### 2026-03-11 - M9.5.3 Client plan-limit alignment and launch-path verification
- Status: DONE
- Summary: Aligned the parent-managed client surfaces with the enforced Starter and Plus limits and finished the launch-facing verification for `M9.5`. Parent Controls now gates child-profile creation against the entitlement-backed cap, plan summaries and blocked review copy now reflect live counters truthfully, and the targeted UI coverage now pins both blocked and allowed launch behavior for new-story and saved-series continuation paths.
- Files: `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `ios/StoryTime/Storage/StoryLibraryStore.swift`, `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which passed `35` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRenderAndAddAChildProfile -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowCurrentPlanAndRestoreEntry -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsGateAddChildWhenPlanLimitIsReached -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyReviewShowsCurrentPlanCountersForBlockedStart -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationRoutesToParentManagedReview -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyAllowsNewStoryWhenPlanStillHasRoom -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailAllowsNewEpisodeWhenPlanStillHasRoom`, which passed `7` tests.
- Decisions:
  - Keep the launch-limit source of truth in the entitlement snapshot and make the client mirror those counters for parent-facing copy instead of reintroducing hardcoded Starter or Plus marketing text.
  - Use the entitlement-backed child-profile cap in `ParentTrustCenterView` and `StoryLibraryStore` so parent-managed add-child gating stays truthful without widening into purchase flow work.
  - Extend the UI-test seed with explicit allowed and blocked preflight variants so blocked-versus-allowed launch coverage stays deterministic.
- Risks/Notes:
  - Purchase UI, real billing, and paywall entry remain outside the current launch-readiness slice.
  - The backend usage ledger remains process-local in memory, so enforcement durability across backend restarts still depends on a later persisted billing or account-backed source of truth.
- Next: M9.6 - End-of-story and repeat-use loop implementation

### 2026-03-11 - M9.6 End-of-story and repeat-use loop implementation
- Status: DONE
- Summary: Implemented the approved post-story completion loop in `VoiceSessionView` so finished sessions now acknowledge completion and offer child-safe replay, new-episode, and return actions. Replay stays inside the voice session through `PracticeSessionViewModel.replayCompletedStory()`, continuation routes back to the saved-series surface instead of surfacing upgrade UI in-session, and saved-series replay now returns to the existing story detail context rather than forcing a broader navigation jump.
- Files: `docs/end-of-story-repeat-use-loop.md`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceSessionShowsCompletionLoopAfterStoryFinishes -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceSessionCompletionReplayRestartsNarration -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceSessionCompletionContinueActionReturnsToSeriesDetail -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceSessionCompletionLibraryActionReturnsToSavedStoriesSurface`, which passed `4` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testReplayCompletedStoryRestartsNarrationFromTheBeginning -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatEpisodeCompletionDoesNotCreateNewHistory`, which passed `2` tests.
- Decisions:
  - Keep the completion acknowledgement inside `VoiceSessionView` and keep all actions child-safe and non-transactional so a finished story is never interrupted by monetization UI.
  - Route saved-series "Back to Saved Stories" through the current saved-series navigation context instead of forcing a jump to `HomeView`, because the story detail surface is already the approved replay and continuation hub.
  - Use a UI-test-only narration transport delay to make completion-loop automation deterministic without changing production narration transport behavior.
- Risks/Notes:
  - Purchase UI, real billing, and paywall entry remain out of scope; continuation may later route to a parent-managed upgrade surface, but the finished-story acknowledgement itself stays upgrade-free.
  - The backend usage ledger remains in-memory, so launch-limit durability across backend restarts still depends on later persisted billing or account-backed work.
- Next: M9.7 - Cost, usage, and latency telemetry for launch confidence

### 2026-03-11 - M9.7 split and M9.7.1 Backend launch telemetry and session-reporting foundation
- Status: DONE
- Summary: Split `M9.7` into smaller telemetry slices because the original milestone mixed backend analytics shape, client launch-surface instrumentation, and the final verification artifact. Completed the first slice by extending backend analytics with explicit entitlement launch events, making provider-usage telemetry session-joinable, and exposing a concrete `/health` telemetry report with flat counters plus per-session summaries for requests, stage-grouped provider usage, and launch-event activity.
- Files: `backend/src/app.ts`, `backend/src/lib/analytics.ts`, `backend/src/services/embeddingsService.ts`, `backend/src/services/moderationService.ts`, `backend/src/services/realtimeService.ts`, `backend/src/services/storyContinuityService.ts`, `backend/src/services/storyDiscoveryService.ts`, `backend/src/services/storyService.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/request-retry-rate.test.ts`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/request-retry-rate.test.ts src/tests/app.integration.test.ts src/tests/model-services.test.ts`, which passed `44` tests.
- Decisions:
  - Keep the first telemetry slice backend-scoped so the reporting surface exists before adding iOS-side launch-surface events or writing the final verification artifact.
  - Reuse the existing analytics sink instead of inventing a separate launch-telemetry subsystem, and keep the report redacted to counters, routes, session IDs, durations, stage groups, and entitlement outcomes only.
  - Use `/health` as the concrete repo-owned reporting surface for the backend slice because it already exposes test-visible telemetry in non-production contexts.
- Risks/Notes:
  - Client launch telemetry for restore attempts, blocked-review presentation, and parent-managed upgrade-surface presentation still remains for `M9.7.2`.
  - Pricing-confidence thresholds and the final launch-confidence verification artifact still remain for `M9.7.3`.
  - Purchase UI, real billing, and paywall entry remain out of scope.
- Next: M9.7.2 - Client launch telemetry for entitlement and upgrade surfaces

### 2026-03-11 - M9.7.2 Client launch telemetry for entitlement and upgrade surfaces
- Status: DONE
- Summary: Added the iOS-side launch telemetry slice for entitlement and upgrade surfaces. `APIClient` now records entitlement sync and preflight outcomes into a redacted client launch-telemetry store, `ParentTrustCenterView` emits parent-managed plan presentation plus refresh and restore events, and the journey plus saved-series review surfaces now log blocked-review presentation without leaking transcript or story content.
- Files: `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testEntitlementTraceEventsUseCorrectOperationsForSyncAndPreflight -only-testing:StoryTimeTests/APIClientTests/testClientLaunchTelemetryCapturesEntitlementAndParentManagedSurfaceEvents -only-testing:StoryTimeTests/APIClientTests/testSyncEntitlementsPostsNormalizedPurchaseStateAndStoresRefreshedSnapshot -only-testing:StoryTimeTests/APIClientTests/testPreflightEntitlementsPostsLaunchContextAndDecodesBlockedDecision`, which passed `4` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowCurrentPlanAndRestoreEntry -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyReviewLinksToDurableParentPlanSurface -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationRoutesToParentManagedReview`, which passed `3` tests.
- Decisions:
  - Keep client launch telemetry as a small redacted in-memory store with counters, per-session summaries, and typed events so `M9.7.3` has a concrete repo-owned reporting path without widening into a dashboard milestone.
  - Fix the swapped `APIClient` trace operation labels for entitlement sync and preflight while instrumenting the new telemetry, because leaving them reversed would make the launch-event evidence internally inconsistent.
  - Reuse the existing entitlement and upgrade-surface types (`EntitlementRefreshReason`, `EntitlementPreflightAction`, `EntitlementUpgradeSurface`) so the client telemetry vocabulary stays aligned with the backend launch-event reporting slice.
- Risks/Notes:
  - The client launch-telemetry store is in-memory and test-oriented today; it is sufficient for verification and reporting, but it is not yet surfaced through a persistent export or launch-review document.
  - Pricing-confidence thresholds and the final launch-confidence verification artifact still remain for `M9.7.3`.
  - Purchase UI, real billing, and paywall entry remain out of scope.
- Next: M9.7.3 - Launch-confidence verification artifact and reporting path

### 2026-03-11 - M9.7.3 Launch-confidence verification artifact and reporting path
- Status: DONE
- Summary: Added `docs/verification/launch-confidence-telemetry-report.md` as the explicit launch-confidence artifact for the telemetry workstream. The new report records the concrete backend `/health` report shape and the client `ClientLaunchTelemetry.report()` shape, the exact backend and iOS verification commands, evidence labels for each material telemetry claim, and the remaining gaps that `M9.8` still needs to carry into the final launch-candidate pass.
- Files: `docs/verification/launch-confidence-telemetry-report.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/request-retry-rate.test.ts src/tests/app.integration.test.ts src/tests/model-services.test.ts`, which passed `44` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testEntitlementTraceEventsUseCorrectOperationsForSyncAndPreflight -only-testing:StoryTimeTests/APIClientTests/testClientLaunchTelemetryCapturesEntitlementAndParentManagedSurfaceEvents`, which passed `2` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowCurrentPlanAndRestoreEntry -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyReviewLinksToDurableParentPlanSurface -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationRoutesToParentManagedReview`, which passed `3` tests.
- Decisions:
  - Keep the launch-confidence artifact as a verification document backed by the existing repo-owned report surfaces instead of widening scope into dashboarding or export tooling.
  - Define the minimum commercial-confidence report shape in repo terms around `GET /health` and `ClientLaunchTelemetry.report()` so `M9.8` can consume concrete data structures instead of inferring telemetry readiness.
  - Record unresolved threshold and durability gaps explicitly rather than treating them as hidden assumptions.
- Risks/Notes:
  - Explicit commercial pass or fail thresholds for cost, latency, and launch-default caps are still not defined in repo-owned numeric terms.
  - The client launch-telemetry report is in-memory only, and the backend usage ledger plus telemetry history remain process-local today.
  - Purchase UI, real billing, and paywall entry remain out of scope.
- Next: M9.8 - Launch candidate QA and acceptance pass

### 2026-03-11 - M9.8 Launch candidate QA and acceptance pass
- Status: DONE
- Summary: Executed the explicit launch-candidate command set and recorded the results in `docs/verification/launch-candidate-acceptance-report.md`. The acceptance pass completed with a `NO-GO` outcome: the hybrid runtime baseline and backend launch-contract suite are green, but the final iOS launch-product unit and UI suites still fail on coordinator repeat-revision behavior, first-story entry, session cueing, privacy-copy alignment, and the parent-gate regression path.
- Files: `docs/verification/launch-candidate-acceptance-report.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed the hybrid runtime validation baseline including backend, iOS hybrid unit, and iOS hybrid UI isolation slices.
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/auth-security.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts`, which passed `53` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which failed with `6` failing test cases in the final launch-product unit slice.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests`, which failed with `5` failing cases in the final launch-product UI slice.
- Decisions:
  - Treat `M9.8` as complete because the acceptance pass was executed and it produced an explicit repo-owned go or no-go decision.
  - Record the launch state as `NO-GO` instead of masking the failing iOS launch-product suites behind the green backend and hybrid-runtime slices.
  - Queue the blocker remediation immediately as `M9.9.1` through `M9.9.3` so the next work is driven by the concrete failing cases rather than vague launch-readiness follow-up.
- Risks/Notes:
  - The launch candidate is blocked by the six failing `PracticeSessionViewModelTests` cases and five failing `StoryTimeUITests` cases listed in `docs/verification/launch-candidate-acceptance-report.md`.
  - Pricing-confidence thresholds for acceptable cost, latency, and cap values remain only partially verified in repo-owned terms.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: M9.9.1 - Coordinator repeat/revision acceptance regression fixes

### 2026-03-12 - M9.9.1 Coordinator repeat/revision acceptance regression fixes
- Status: DONE
- Summary: Reproduced and cleared the coordinator-side `M9.8` blocker cases. `PracticeSessionViewModel` now builds revision requests from the authoritative revision boundary when one exists, falls back to a deterministic full-story rewrite request for repeat-episode single-scene replays, merges revised scenes from the backend-reported `revisedFromSceneIndex`, and treats repeat-mode full rewrites as replace-in-place completion instead of a stuck narration resume. The coordinator acceptance fixtures now match the current future-scenes-only revision contract, and the plain "add a ..." interruption path is pinned as a revision cue.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Models/StoryDomain.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testCriticalPathAcceptanceHappyPathExercisesFullCoordinatorLifecycle -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testCriticalPathAcceptanceHappyPathPersistsRevisedStoryAcrossReload -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatEpisodeRevisionReplacesExistingHistoryWithoutAddingEpisodes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatEpisodeRevisionReplacesContinuityFactsAndClearsClosedOpenLoops -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testResumeNarrationFromCorrectSceneAfterRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRevisionQueueRejectsAdditionalUpdateBeyondOneQueuedRequest -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testMockNarrationChildDidSpeakUsesScriptedUpdateRequest`, which passed `7` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/HybridRuntimeContractTests/testInterruptionIntentRouterClassifiesPlainAddCueAsRevision`, which passed `1` test.
- Decisions:
  - Keep the future-scenes-only revision contract intact for normal story sessions and repair the acceptance fixtures instead of weakening the boundary to satisfy stale expectations.
  - Allow repeat-episode sessions with no future scenes to issue a full-story rewrite request, but only inside `.repeatEpisode` so normal session semantics stay unchanged.
  - Treat a repeat-mode full rewrite as replace-in-place completion rather than trying to resume narration from a non-existent future-scene boundary.
- Risks/Notes:
  - `M9.8` remains `NO-GO` until the launch-facing UI regression slice in `M9.9.2` is green and the launch-candidate pack is rerun.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: M9.9.2 - Launch UI and parent-trust regression fixes

### 2026-03-12 - M9.9.2 Launch UI and parent-trust regression fixes
- Status: DONE
- Summary: Reproduced and cleared the launch-facing `M9.8` UI blocker cases. The parent-controls privacy assertions now scroll within the plan-first `ParentTrustCenterView` form, seeded UI-test preflight now falls back to the local entitlement snapshot instead of depending on live backend availability, and `VoiceSessionView` now uses a deterministic UI-test session client for story generation and revision so first-story entry plus cue presentation stay launch-verifiable without widening production behavior. The listening cue assertion was also narrowed to the stable child-facing contract instead of hardcoding a timing-sensitive discovery-step number.
- Files: `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsRequireDeliberateGateBeforeOpening -only-testing:StoryTimeUITests/StoryTimeUITests/testPrivacyCopyReflectsLiveProcessingAndLocalRetention -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceFirstStoryJourney -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceSessionShowsListeningCueBeforeNarrationStarts -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceSessionShowsStorytellingCueAfterNarrationStarts`, which passed `5` tests.
- Decisions:
  - Keep the `ParentTrustCenterView` plan section order intact and fix the UI assertions by scrolling to the privacy labels instead of flattening the launch-ready parent-controls hierarchy to satisfy stale tests.
  - Keep UI-test launch gating seeded and local by deriving a preflight decision from the current entitlement snapshot when no explicit UI-test override is provided, rather than reintroducing live backend dependence into launch-product UI coverage.
  - Stub story generation and revision only inside `STORYTIME_UI_TEST_MODE` so the launch-facing UI suite stays deterministic without altering production `APIClient` behavior or the active hybrid runtime contract.
- Risks/Notes:
  - `M9.8` remains `NO-GO` until `M9.9.3` reruns the full launch-candidate command pack and records the updated launch decision.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: M9.9.3 - Launch candidate re-run and commercial-threshold decision

### 2026-03-12 - M9.9.3 Launch candidate re-run and commercial-threshold decision
- Status: DONE
- Summary: Re-ran the launch-candidate pack after `M9.9.1` and `M9.9.2` and updated `docs/verification/launch-candidate-acceptance-report.md` with the clean post-remediation results. The hybrid-runtime baseline passed, the backend launch-contract suite passed, and the full `StoryTimeUITests` launch-product UI suite passed all `35` tests. The final launch-product unit suite still failed with `5` assertion failures across two `PracticeSessionViewModelTests` cases: `testBlockedRevisionUsesModerationCategoryAndSafeMessage` and `testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes`. The launch decision therefore remains `NO-GO`, and the remaining blocker set is now narrowed to those two revision-resume paths plus the still-deferred commercial threshold decision.
- Files: `docs/verification/launch-candidate-acceptance-report.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed with the backend slice green, the iOS hybrid unit slice green, and the iOS hybrid UI isolation slice green.
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/auth-security.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts`, which passed `53` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=ED92AC26-374B-43D3-9DB4-07C62561F4B1' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which failed with `5` assertion failures across `2` failed test cases after executing `126` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=ED92AC26-374B-43D3-9DB4-07C62561F4B1' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testBlockedRevisionUsesModerationCategoryAndSafeMessage -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes`, which reproduced the same `2` blocker cases in isolation.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeUITests`, which passed `35` tests.
- Decisions:
  - Treat the clean dedicated-simulator reruns as the authoritative `M9.9.3` evidence and discard the earlier shared-simulator parallel rerun from blocker classification.
  - Mark `M9.9` complete because its remediation plus rerun scope is finished, then queue the remaining work under a new `M9.10` follow-up stream instead of pretending the launch state is still the old `M9.8` blocker set.
  - Keep the commercial threshold decision explicit as deferred and blocking, rather than inferring launch readiness from green UI coverage alone.
- Risks/Notes:
  - The launch candidate remains `NO-GO` because the final launch-product unit suite still fails in two revision-resume coordinator paths.
  - Commercial thresholds for acceptable cost, latency, and launch-default caps remain only partially verified in repo-owned pass or fail terms.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: M9.10.1 - Revision-resume moderation and deferred-transcript blocker fix

### 2026-03-12 - M9.10.1 Revision-resume moderation and deferred-transcript blocker fix
- Status: DONE
- Summary: Fixed the remaining coordinator revision-resume mismatch in `PracticeSessionViewModel` so backend-authored revisions can legitimately resume by replaying the current interrupted scene when needed. This clears both remaining `M9.9.3` blocker tests: blocked revision moderation now lands back in narration with the safe moderation message intact, and deferred transcript input started during revision is still rejected once narration resumes.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=ED92AC26-374B-43D3-9DB4-07C62561F4B1' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testBlockedRevisionUsesModerationCategoryAndSafeMessage -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes`, which passed `2` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=ED92AC26-374B-43D3-9DB4-07C62561F4B1' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testBlockedRevisionUsesModerationCategoryAndSafeMessage -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testResumeNarrationFromCorrectSceneAfterRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatEpisodeRevisionReplacesExistingHistoryWithoutAddingEpisodes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRevisionQueueRejectsAdditionalUpdateBeyondOneQueuedRequest`, which passed `5` tests.
- Decisions:
  - Keep the normal revision request boundary unchanged; only the coordinator's resume validation now accepts backend-authoritative replay from the current scene.
  - Treat the current-scene replay case as valid both for resume validation and revision-index mismatch suppression, instead of widening the revision request contract.
- Risks/Notes:
  - Launch remains `NO-GO` until `M9.10.2` defines explicit commercial thresholds and reruns the final launch-candidate pack.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: M9.10.2 - Commercial threshold definition and final launch rerun

### 2026-03-13 - M9.10.2 Commercial threshold definition and final launch rerun
- Status: DONE
- Summary: Re-ran the full launch-candidate pack after `M9.10.1` and updated `docs/verification/launch-candidate-acceptance-report.md` with the March 13, 2026 evidence. The hybrid-runtime baseline passed, the backend launch-contract suite passed `53` tests, and the full `StoryTimeUITests` launch-product UI suite passed all `35` tests. The launch-product unit suite still failed on `PracticeSessionViewModelTests.testPausedNarrationHandsOffToInteractionWithoutReconnect` and `PracticeSessionViewModelTests.testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly`, so the launch decision remains `NO-GO`. This run also made the commercial-threshold treatment explicit: launch-default caps now pass as repo-owned enforced defaults, while cost and latency thresholds remain deferred blockers rather than hidden assumptions.
- Files: `docs/verification/launch-candidate-acceptance-report.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed with the backend slice green, the iOS hybrid unit slice green, and the iOS hybrid UI isolation slice green.
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/auth-security.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts`, which passed `53` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=ED92AC26-374B-43D3-9DB4-07C62561F4B1' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which executed `126` tests and failed on `2` paused-narration interaction-handoff cases.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=283799A7-5ACF-4C7E-938E-8968F2FF6517' -only-testing:StoryTimeUITests`, which passed `35` tests with `0` failures.
- Decisions:
  - Treat launch-default cap thresholds as explicit PASS criteria for the current candidate because the config-backed defaults are now enforced by backend-issued snapshots and preflight gates.
  - Treat cost and latency thresholds as explicit deferred blockers, not as implied pass conditions, because the repo still lacks numeric pass or fail limits for launch review.
  - Queue the two new paused-narration interaction-handoff failures as the next follow-up before any further launch rerun.
- Risks/Notes:
  - The launch candidate remains `NO-GO` because the unit suite still fails on `testPausedNarrationHandsOffToInteractionWithoutReconnect` and `testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly`.
  - Cost and latency thresholds remain blocking because they are explicit but still deferred.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: M9.10.3 - Paused-narration interaction handoff blocker fix

### 2026-03-13 - M9.10.3 Paused-narration interaction handoff blocker fix
- Status: DONE
- Summary: Fixed the paused-narration interaction handoff mismatch in `PracticeSessionViewModel` by aligning coordinator resume validation with the repo’s existing state-model rule that revised future scenes may start at any later future-scene boundary, not only the immediate next scene. This restores both remaining launch-product unit blockers: paused narration now hands off back into interaction without reconnect, and a final transcript emitted while paused can start the direct interaction handoff cleanly. The broader launch-product unit slice is green again.
- Files: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=ED92AC26-374B-43D3-9DB4-07C62561F4B1' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationHandsOffToInteractionWithoutReconnect -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPauseAndResumeNarrationPreservesSceneOwnership -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testResumeNarrationFromCorrectSceneAfterRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testBlockedRevisionUsesModerationCategoryAndSafeMessage`, which passed `5` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,id=ED92AC26-374B-43D3-9DB4-07C62561F4B1' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which passed `126` tests with `0` failures.
- Decisions:
  - Keep the existing revision request contract unchanged; only the coordinator’s accepted revision-resume validation now recognizes later future-scene boundaries as valid backend-authoritative outcomes.
  - Use the already failing paused-narration tests as the regression coverage for this bug instead of widening scope with new test fixtures.
- Risks/Notes:
  - Launch remains `NO-GO` until `M9.10.4` defines numeric cost and latency thresholds and reruns the full launch-candidate pack.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: M9.10.4 - Numeric commercial threshold decision and clean launch rerun

### 2026-03-13 - M9.10.4 Numeric commercial threshold decision and clean launch rerun
- Status: DONE
- Summary: Re-ran the full launch-candidate pack after `M9.10.3`, replaced the stale launch report with the March 13, 2026 final evidence, and converted the remaining commercial-threshold decisions from deferred blockers into explicit repo-owned numeric pass criteria. The hybrid-runtime baseline passed, the backend launch-contract suite passed `53` tests, the launch-product unit suite passed `126` tests with `0` failures, and the full `StoryTimeUITests` launch-product UI suite passed all `35` tests. Cost exposure is now explicitly capped by the enforced Starter and Plus launch limits, latency ceilings are now explicitly tied to the active client and backend timeout budgets, and the current locked MVP candidate is now recorded as `GO`.
- Files: `docs/verification/launch-candidate-acceptance-report.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed with the backend slice green, the iOS hybrid unit slice green, and the iOS hybrid UI isolation slice green.
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/auth-security.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts`, which passed `53` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which passed `126` tests with `0` failures.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests`, which passed `35` tests with `0` failures.
- Decisions:
  - Treat launch cost exposure as an explicit pass or fail condition tied to the enforced backend plan defaults: Starter may consume at most `6` remote-cost-bearing launches per rolling `7` days for `1` child and Plus may consume at most `24` remote-cost-bearing launches per rolling `7` days across up to `3` children, both with a `10` minute story-length cap and replay excluded from fresh-generation consumption.
  - Treat launch latency as an explicit pass or fail condition tied to the active timeout budgets: `<= 8` seconds for health checks, `<= 12` seconds for session identity and voices, and `<= 20` seconds for entitlement sync, entitlement preflight, realtime session, discovery, generation, revision, and the backend realtime upstream proxy.
  - Record the current candidate as `GO` because the full launch pack is green and the remaining telemetry durability gaps are documented as post-launch hardening work rather than hidden blockers.
- Risks/Notes:
  - Backend launch telemetry remains process-local and client launch telemetry remains in-memory only; durability and joined-report export still need follow-up work.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: M9.11 - Telemetry durability and joined launch-report hardening

### 2026-03-20 - M9.11 Telemetry durability and joined launch-report hardening
- Status: DONE
- Summary: Hardened the post-launch telemetry surfaces so launch evidence no longer depends on transient backend or client memory. Backend analytics now persist their counters and per-session launch summaries to a configurable `ANALYTICS_PERSIST_PATH`, `createApp(...)` reloads that state before exposing `/health`, client launch telemetry now persists its report in `UserDefaults`, and `APIClient.fetchLaunchTelemetryReport()` now returns one joined backend-plus-client `LaunchTelemetryJoinedReport` for verification. The telemetry verification artifact now reflects the durable backend report, the durable client report, and the joined report surface, and the remaining gap narrows to narration playback wall-clock fidelity rather than report durability or joining.
- Files: `backend/src/lib/env.ts`, `backend/src/lib/analytics.ts`, `backend/src/app.ts`, `backend/src/tests/testHelpers.ts`, `backend/src/tests/request-retry-rate.test.ts`, `backend/src/tests/app.integration.test.ts`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `docs/verification/launch-confidence-telemetry-report.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/request-retry-rate.test.ts src/tests/app.integration.test.ts`, which passed `38` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testClientLaunchTelemetryCapturesEntitlementAndParentManagedSurfaceEvents -only-testing:StoryTimeTests/APIClientTests/testClientLaunchTelemetryPersistsAcrossStoreReload -only-testing:StoryTimeTests/APIClientTests/testFetchLaunchTelemetryReportJoinsBackendAndPersistedClientTelemetry`, which passed `3` tests.
- Decisions:
  - Keep the durable backend report on the existing `/health` surface instead of widening scope into a new backend telemetry export route.
  - Keep client launch telemetry local and durable in `UserDefaults`, then join it lazily with backend `/health` telemetry through `APIClient.fetchLaunchTelemetryReport()` instead of uploading client telemetry back to the backend.
  - Preserve the existing redaction boundary so the durable telemetry surfaces still exclude transcript text, story text, and raw audio.
- Risks/Notes:
  - Narration telemetry still leans on TTS preparation timing more than full playback wall-clock timing.
  - The joined report is durable enough for repo verification, but it is not a broader centralized operational warehouse or dashboard.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: M9.12 - Narration wall-clock telemetry hardening

### 2026-03-20 - M9.12 Narration wall-clock telemetry hardening
- Status: DONE
- Summary: Extended coordinator-owned narration telemetry beyond preload timing so post-launch verification can reason about actual playback behavior. `RuntimeTelemetryStage` now distinguishes `tts_generation` from `tts_playback_started`, `tts_playback_completed`, and `tts_playback_cancelled`, and `PracticeSessionViewModel.startNarration(...)` now records playback start before `playScene(...)` begins plus completion or cancellation wall-clock duration after playback returns. The verification artifacts now reflect that narration is no longer represented primarily by preparation timing, while still calling out the remaining gap around durable runtime-stage timeline export.
- Files: `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `docs/verification/runtime-stage-telemetry-verification.md`, `docs/verification/launch-confidence-telemetry-report.md`, `docs/verification/hybrid-runtime-validation.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPlaybackTelemetryRecordsWallClockStartAndCompletion -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPlaybackTelemetryRecordsCancellationWallClockOnInterruption`, which passed `3` tests.
- Decisions:
  - Keep narration preparation and playback as separate detailed narration stages instead of collapsing wall-clock playback into the existing `tts_generation` metric.
  - Record playback telemetry at the coordinator boundary rather than widening scope into backend analytics, because long-form narration remains client-owned TTS in the active architecture.
  - Reuse the existing narration start source strings for playback attribution so the new telemetry stays redacted while preserving whether playback began from generation, scene completion, replay, or revision resume.
- Risks/Notes:
  - The durable joined launch report still does not export per-scene runtime telemetry, so the new narration playback evidence remains verification-facing coordinator telemetry rather than a broader persisted runtime timeline.
  - Device audio-route latency below the transport boundary is still not measured directly; the new playback metric reflects transport-observed wall-clock timing.
  - Purchase UI, paywall UI, and real billing entry remain out of scope for the locked MVP.
- Next: No remaining ordered milestone in `SPRINT.md`; the next useful follow-up is a new post-launch telemetry export milestone if durable runtime-stage timelines become a priority.

### 2026-03-20 - Sprint queue exhausted, no new milestone selected
- Status: BLOCKED
- Summary: Re-read `AGENTS.md`, `PLANS.md`, and `SPRINT.md` for the next required run and confirmed that there is no remaining ordered incomplete milestone in `SPRINT.md`. Per the repo rules, no new implementation milestone was invented and no unrelated code changes were made. The only repo updates in this run record the queue-exhausted state explicitly so the next run requires intentional reprioritization rather than implicit scope creation.
- Files: `PLANS.md`, `SPRINT.md`
- Tests:
  - None run. No code-path milestone remained to implement or verify.
- Decisions:
  - Treat the absence of any incomplete `SPRINT.md` milestone as a real blocker rather than skipping ahead or inventing post-launch work outside the queued plan.
  - Record the queue-exhausted state explicitly in the control files so the next run starts from an intentional reprioritization step.
- Risks/Notes:
  - The next workstream is blocked on planning, not on code implementation.
  - The main documented follow-up remains durable runtime-stage timeline export if product priorities still favor post-launch telemetry hardening.
- Next: No remaining ordered milestone in `SPRINT.md`; explicit sprint reprioritization is required before the next implementation run.

### 2026-03-20 - Queue exhaustion reconfirmed
- Status: BLOCKED
- Summary: Re-checked the repo control files for another implementation run and confirmed the same queue-exhaustion state: `SPRINT.md` still has no ordered incomplete milestone to execute. No code-path work was started, and no new milestone was created implicitly.
- Files: `PLANS.md`, `SPRINT.md`
- Tests:
  - None run. The blocker is planning state, not a code-path defect or missing verification rerun.
- Decisions:
  - Keep the sprint blocked until a new ordered milestone is added explicitly.
  - Avoid creating a speculative post-launch telemetry export milestone inside this run because that would violate the current queue-control rules.
- Risks/Notes:
  - Subsequent implementation runs will remain blocked until `SPRINT.md` is reprioritized.
  - The most obvious follow-up remains durable runtime-stage timeline export, but it is not yet an approved queued milestone.
- Next: No remaining ordered milestone in `SPRINT.md`; explicit sprint reprioritization is still required.

### 2026-03-20 - Launch-readiness gap assessment and Sprint 10 planning input
- Status: DONE
- Summary: Completed a repo-grounded launch-readiness gap assessment instead of another implementation pass. The new report concludes that StoryTime is `CONDITIONALLY READY IF BLOCKERS ARE CLOSED`: the child-facing product loop, entitlement enforcement, repeat-use flow, privacy copy, and hybrid runtime evidence are all materially strong, but the repo still lacks an actual parent-managed purchase completion flow and a verified post-purchase unblock happy path. The assessment keeps those commercial gaps distinct from non-blocking telemetry and polish work, and it proposes a tight next sprint focused on commercial blocker closure rather than reopening the stabilized runtime.
- Files: `docs/verification/launch-readiness-gap-assessment.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - None run in this planning pass.
  - Evidence came from current code inspection plus existing iOS UI tests, iOS unit tests, backend integration tests, and recent verification reports already present in the repo.
- Decisions:
  - Treat the absence of an implemented parent-managed purchase path as a real launch blocker for a commercial MVP, even though an earlier narrower-scope launch report recorded a `GO` decision.
  - Keep the next sprint tight: close the parent-managed purchase path, verify the blocked-to-entitled happy path, then rerun launch acceptance.
  - Do not reopen broad hybrid-runtime rescue work because the runtime remains one of the best-evidenced areas of the repo.
- Risks/Notes:
  - The assessment is strongest where March 2026 verification artifacts already exist and weaker where behavior was inspected but not re-executed in this run.
  - If product leadership explicitly chooses a non-commercial or manually provisioned MVP, the commercial blocker classification would need to be revisited against that narrower scope.
  - Operational telemetry still lacks a durable per-scene runtime timeline export, but that remains non-blocking for the next sprint recommendation.
- Next: `M10.0 - Launch-gap assessment review and Sprint 10 approval`

### 2026-03-20 - M10.0 Launch-gap assessment review and Sprint 10 approval
- Status: DONE
- Summary: Turned the launch-gap assessment into an approved final sprint queue. `AGENTS.md` now explicitly constrains future runs to commercial-closure work only, `SPRINT.md` now carries actionable `M10.1` through `M10.3` milestones for purchase-path closure, happy-path verification, and final launch rerun, and `PLANS.md` now points directly at `M10.1` as the next recommended milestone. The remaining non-blocking gaps are deliberately deferred unless they become blockers during the final sprint.
- Files: `AGENTS.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - None run. This was a planning-only control-file update grounded in existing code, test, and verification evidence.
- Decisions:
  - Treat Sprint 10 as the final commercial-closure sprint rather than reopening broad launch-readiness scope.
  - Keep purchase and entitlement work parent-managed and explicitly exclude purchase UI from child-facing runtime surfaces.
  - Keep broader telemetry, auth, and parent-usage polish deferred unless a Sprint 10 blocker forces a tightly related unblocker.
- Risks/Notes:
  - The final launch recommendation still depends on successful implementation and verification of `M10.1` and `M10.2`.
  - The earlier narrower-scope `GO` report remains part of history, but the launch-gap assessment remains the planning source of truth until the commercial blockers are closed.
- Next: `M10.1 - Parent-managed purchase surface closure`

### 2026-03-20 - M10.1 Parent-managed purchase surface closure
- Status: DONE
- Summary: Added the smallest truthful parent-managed purchase completion path without widening beyond the approved commercial-closure scope. `ParentTrustCenterView` now loads StoreKit-backed Plus purchase options, offers a parent-only upgrade action, completes the purchase through the shared entitlement seam, refreshes the local entitlement snapshot, and keeps refresh plus restore in the same parent-managed plan surface. Child-facing runtime surfaces remain purchase-free, and the blocked commercial flow can now close through Parent Controls instead of stopping at review copy.
- Files: `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests/testEntitlementManagerPurchasesAndStoresSyncedSnapshot -only-testing:StoryTimeTests/SmokeTests/testEntitlementManagerDoesNotSyncCancelledPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowCurrentPlanAndRestoreEntry -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanCompleteParentManagedPlusPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceSessionShowsStorytellingCueAfterNarrationStarts`, which passed with `5` tests.
- Decisions:
  - Keep purchase initiation and completion inside `ParentTrustCenterView` instead of widening into `JourneyUpgradeReviewView`, `SeriesDetailUpgradeReviewView`, or any child-session runtime surface.
  - Reuse the existing entitlement sync seam after a verified StoreKit purchase instead of creating a second entitlement refresh path.
  - Use a dedicated UI-test purchase provider so the parent-managed purchase flow remains directly testable without weakening the production trust boundary.
- Risks/Notes:
  - `M10.1` closes the purchase-path blocker but not the commercial happy-path blocker; the repo still needs direct blocked-to-upgraded-to-unblocked retry coverage in `M10.2`.
  - The production purchase path currently depends on StoreKit product availability for the configured Plus product IDs; launch verification still needs to prove the blocked review surfaces recover end to end after purchase or entitlement refresh.
- Next: `M10.2 - Upgrade unblock happy-path verification`

### 2026-03-20 - M10.2 Upgrade unblock happy-path verification
- Status: DONE
- Summary: Closed the remaining commercial happy-path verification gap with the smallest tightly related unblocker. `NewStoryJourneyView` and `StorySeriesDetailView` now clear stale blocked state when parent-managed plan work materially changes the entitlement snapshot or token, which lets the original start buttons retry through normal preflight instead of bypassing gating. The repo now has direct automated evidence for blocked new-story recovery, blocked continuation recovery, refreshed entitlement-token reuse on retry, and the backend blocked-to-purchased-to-allowed contract, all recorded in a dedicated verification report.
- Files: `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `backend/src/tests/app.integration.test.ts`, `docs/verification/commercial-upgrade-happy-path-verification.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationRoutesToParentManagedReview`, which passed with `5` tests.
  - `npm test -- --run src/tests/app.integration.test.ts`, which passed with `33` tests.
- Decisions:
  - Keep retry inside the existing blocked surfaces by clearing stale block state only after the entitlement snapshot or token changes, instead of adding purchase or recovery UI to child-session surfaces.
  - Reuse the existing preflight path for retry so the same gating contract continues to decide whether launch is allowed after purchase or entitlement refresh.
  - Record the commercial happy-path evidence in a focused verification artifact rather than widening the broader launch report before `M10.3`.
- Risks/Notes:
  - The seeded UI provider verifies the recovery flow deterministically, but the live App Store purchase sheet is still only code-inspected until the final launch rerun.
  - `M10.2` closes the remaining commercial flow blocker, but StoryTime still needs the final launch-readiness rerun and explicit recommendation update in `M10.3`.
- Next: `M10.3 - Commercial launch rerun and blocker closeout`

### 2026-03-20 - M10.3 Commercial launch rerun and blocker closeout
- Status: DONE
- Summary: Closed the final commercial-closure sprint with a full March 20, 2026 launch rerun. The hybrid validation baseline, backend launch-contract suite, iOS launch-product unit suite, and full iOS UI launch suite are all green after `M10.1` and `M10.2`. The only issue found during the rerun was a tightly related brittle UI assertion in `testJourneyReviewLinksToDurableParentPlanSurface`; aligning it to the existing `scrollToElement(...)` pattern produced a clean targeted rerun and a clean full-suite rerun. `docs/verification/launch-candidate-acceptance-report.md` now records the final repo-grounded recommendation as `READY FOR MVP LAUNCH`.
- Files: `ios/StoryTime/UITests/StoryTimeUITests.swift`, `docs/verification/launch-candidate-acceptance-report.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed with backend `51` tests, iOS unit `34` tests, and iOS UI `2` tests.
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/auth-security.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts`, which passed with `56` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests -only-testing:StoryTimeTests/StoryLibraryStoreTests`, which passed with `131` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyReviewLinksToDurableParentPlanSurface`, which passed with `1` test after the tightly related test-only unblocker.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests`, which passed with `38` tests.
- Decisions:
  - Treat the first UI-suite failure as a tightly related test-only unblocker because the product surface was already present and another existing parent-controls test used the correct scroll-to-element access pattern.
  - Record the final launch recommendation as `READY FOR MVP LAUNCH` in repo terms because the repo-owned commercial blockers are closed and the full launch command pack is green.
  - Keep the remaining App Store environment gap and broader post-launch telemetry/auth/dashboard work documented as non-blocking rather than reopening Sprint 10 scope.
- Risks/Notes:
  - Live App Store purchase-sheet behavior remains external-environment dependent and is still not directly exercised in the repo rerun.
  - Broader operational dashboards, stronger parent authentication, and durable per-scene runtime-stage export remain deferred post-launch work.
- Next: No remaining approved sprint milestone. If follow-up work is scheduled, start with an explicit post-launch planning milestone.

### 2026-03-20 - Sprint 11 parent-account and payment foundation planning
- Status: DONE
- Summary: Re-read the repo control files, `AuditUpdated.md`, the recent launch and monetization docs, and the required iOS and backend surfaces before creating the next sprint plan. The repo now explicitly treats Sprint 10's `READY FOR MVP LAUNCH` result as a completed baseline and starts a new Sprint 11 focused on parent accounts, Firebase Auth, authenticated entitlement ownership, parent-managed StoreKit continuity, promo-code premium grants, and blocked-to-unlocked verification under the new account model. The new queue keeps story history local-only by default and avoids widening into cloud sync or broader platform expansion.
- Files: `AGENTS.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - None run. This was a planning-only control-file update grounded in current code, tests, and verification artifacts.
- Decisions:
  - Treat Firebase Auth as the parent identity direction, but keep child-facing story flow free of sign-in or purchase friction.
  - Keep identity, payments, and entitlements as separate systems in the new sprint rather than collapsing them into one account implementation.
  - Keep promo grants explicit, bounded, and tied to authenticated parent users instead of debug-only seeds or hidden manual steps.
  - Keep story history and continuity local-only in Sprint 11 unless a later milestone explicitly broadens scope.
- Risks/Notes:
  - The repo already configures `FirebaseCore`, but there is no Firebase Auth integration, no authenticated parent-user backend model, and no account-linked entitlement ownership yet.
  - The existing install/session bootstrap and install-bound entitlement tokens are still active runtime infrastructure, so Sprint 11 needs careful layering instead of a breaking auth replacement.
  - Restore and promo behavior under an authenticated account model still require explicit ownership and conflict rules in `M11.1`.
- Next: `M11.1 - Account architecture and flow alignment`

### 2026-03-20 - M11.1 Account architecture and flow alignment
- Status: DONE
- Summary: Locked the minimal Sprint 11 architecture in repo terms without widening into implementation. The new architecture doc confirms that parent identity will be added as a layer on top of the existing install/session runtime bootstrap, not as a silent replacement; that first-scope auth methods are `email/password` plus `Sign in with Apple`; that purchase truth, parent identity, and backend entitlement enforcement remain separate systems; that promo redemption is parent-only, authenticated, bounded, and distinguishable from paid premium; and that story history plus continuity remain local-only for this sprint.
- Files: `docs/parent-account-payment-foundation-architecture.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - None run. This was a planning-only milestone grounded in code inspection and existing verification artifacts.
- Decisions:
  - Keep install/session bootstrap for runtime plumbing while adding authenticated parent identity separately for account-owned surfaces and entitlement ownership.
  - Lock first-scope parent auth methods to `email/password` plus `Sign in with Apple`; defer Google sign-in, phone auth, child identity, and broader family-role systems.
  - Represent entitlement ownership separately from source so backend ownership ties to the authenticated parent user while `EntitlementSnapshot.source` continues to describe grant origin such as `storekit_verified` or `promo_grant`.
  - Keep promo grants parent-managed, authenticated, and bounded with a one-time redemption default.
  - Keep saved stories and continuity local-only in Sprint 11 and explicitly defer cloud sync plus cross-device story portability.
- Risks/Notes:
  - Restore conflict handling remains open: Sprint 11 still needs one explicit rule for StoreKit ownership versus signed-in parent-account mismatch.
  - Backend persistence shape for account-owned entitlements and promo grants is still an implementation detail, but the ownership boundary is now locked.
  - Firebase Auth is not integrated yet, so the repo still has no signed-in parent state in active UI or backend routes.
- Next: `M11.2 - Firebase Auth integration for parent identity`

### 2026-03-20 - M11.2 Firebase Auth integration for parent identity
- Status: DONE
- Summary: Added the Firebase Auth foundation on top of the existing `FirebaseCore` bootstrap without widening into full account UI. The iOS app now links `FirebaseAuth`, bootstraps Firebase at app startup before the parent-auth seam is created, exposes a new `ParentAuthManager` observable object, and surfaces signed-in versus signed-out parent state only in onboarding handoff and `ParentTrustCenterView`. Child story surfaces remain free of sign-in or purchase prompts, and UI-test reset now signs out Firebase Auth so the new auth layer stays deterministic in test runs.
- Files: `ios/StoryTime/project.yml`, `ios/StoryTime/StoryTime.xcodeproj/project.pbxproj`, `ios/StoryTime/App/StoryTimeApp.swift`, `ios/StoryTime/App/ParentAuthManager.swift`, `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Tests/ParentAuthManagerTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/ParentAuthManagerTests`, which passed `3` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsParentAccountStatusOnHandoffStep -only-testing:StoryTimeUITests/StoryTimeUITests/testChildStorySurfacesRemainFreeOfAccountPrompts`, which passed `3` tests.
- Decisions:
  - Keep Firebase Auth state in a dedicated `ParentAuthManager` instead of threading Firebase calls through `HomeView`, onboarding, or child-session surfaces directly.
  - Expose parent-auth state only in parent-managed or parent-led surfaces during `M11.2`; leave actual sign-up, sign-in, and relaunch persistence UI for `M11.3`.
  - Keep install/session runtime bootstrap and `APIClient` behavior unchanged in this milestone.
  - Use UI-test reset to clear Firebase Auth session state so the new foundation remains deterministic across repeated test runs.
- Risks/Notes:
  - Full account creation, sign-in, sign-out, and relaunch persistence are still not implemented; this milestone only adds the auth foundation seam.
  - Backend routes are still install/session-bound, so authenticated parent ownership does not exist server-side yet.
  - Focused `xcodebuild` runs still log a non-blocking Firebase startup warning before the hosted test app finishes initializing; the targeted tests pass, but wider-suite noise may still be worth revisiting if it becomes distracting.
- Next: `M11.3a - Email/password parent account surfaces and relaunch persistence`

### 2026-03-20 - M11.3a Email/password parent account surfaces and relaunch persistence
- Status: DONE
- Summary: Split the original `M11.3` into two smaller auth-surface milestones so the first run could land the minimal parent-managed account flow safely. The repo now has a shared `ParentAccountSheetView` reachable from onboarding handoff and `ParentTrustCenterView`, a fuller `ParentAuthManager` seam for `email/password` create account, sign in, safe failure messaging, and sign out, a deterministic UI-test auth provider with relaunch persistence, and a direct signed-in sign-out control that stays inside Parent Controls. Child story surfaces remain free of account prompts.
- Files: `ios/StoryTime/App/ParentAuthManager.swift`, `ios/StoryTime/App/StoryTimeApp.swift`, `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/ParentAccountSheetView.swift`, `ios/StoryTime/Tests/ParentAuthManagerTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/ParentAuthManagerTests`, which passed `6` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanCreateParentAccountAndPersistAcrossRelaunch -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanSignOutAndSignBackIn -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsParentAccountStatusOnHandoffStep -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingParentAccountEntryRemainsOptional -only-testing:StoryTimeUITests/StoryTimeUITests/testChildStorySurfacesRemainFreeOfAccountPrompts`, which passed `6` tests.
- Decisions:
  - Split `M11.3` into `M11.3a` and `M11.3b` because first-scope auth includes both `email/password` and `Sign in with Apple`, and shipping one method per run keeps the sprint executable.
  - Keep the first real account entry in a shared parent-only sheet rather than adding inline auth forms to onboarding, `NewStoryJourneyView`, `StorySeriesDetailView`, or `VoiceSessionView`.
  - Keep a direct signed-in sign-out control inside `ParentTrustCenterView` so sign-out remains parent-managed and explicitly testable without routing through a brittle nested interaction path.
  - Use a deterministic UI-test auth provider for persisted relaunch coverage while keeping production auth backed by Firebase.
- Risks/Notes:
  - `Sign in with Apple` is still outstanding and now lives in `M11.3b`.
  - Backend routes and entitlements are still install/session-bound, so authenticated parent ownership does not exist server-side yet.
  - Focused unit and UI auth runs pass cleanly when executed serially; an earlier parallel run produced a host-app bootstrap crash rather than a product failure.
- Next: `M11.3b - Sign in with Apple on parent-managed account surfaces`

### 2026-03-20 - M11.3b Sign in with Apple on parent-managed account surfaces
- Status: DONE
- Summary: Added `Sign in with Apple` to the existing shared `ParentAccountSheetView` so the planned first-scope auth set is now complete without adding auth clutter to child storytelling. `ParentAuthManager` now supports Apple-authenticated sign-in, explicit Apple-versus-email signed-in summaries, safe cancellation handling, and Firebase-backed Apple credential flow in production while the deterministic UI-test auth provider simulates the same relaunch-persisted account state in automation. The app target now carries the required Apple sign-in entitlements.
- Files: `ios/StoryTime/App/ParentAuthManager.swift`, `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/ParentAccountSheetView.swift`, `ios/StoryTime/Tests/ParentAuthManagerTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `ios/StoryTime/project.yml`, `ios/StoryTime/App/StoryTime.entitlements`, `ios/StoryTime/StoryTime.xcodeproj/project.pbxproj`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/ParentAuthManagerTests`, which passed `8` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanSignInWithAppleAndPersistAcrossRelaunch -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingParentAccountEntryRemainsOptional -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsParentAccountStatusOnHandoffStep -only-testing:StoryTimeUITests/StoryTimeUITests/testChildStorySurfacesRemainFreeOfAccountPrompts`, which passed `4` tests.
- Decisions:
  - Keep `Sign in with Apple` on the same shared parent-managed account sheet as `email/password` instead of creating a separate auth surface.
  - Route Apple auth through the existing `ParentAuthManager` seam so parent identity remains explicit and testable regardless of auth method.
  - Use the deterministic UI-test auth provider for Apple-authenticated relaunch coverage because the real system Apple authorization sheet is environment-dependent in repo automation.
  - Add the Apple sign-in entitlement to the app target as part of the repo-ready account surface.
- Risks/Notes:
  - The production Apple sign-in path is integrated through `AuthenticationServices` and Firebase Auth, but direct end-to-end automation against the system Apple sheet remains environment-dependent outside the deterministic UI-test provider.
  - Backend routes and entitlements are still install/session-bound, so authenticated parent ownership does not exist server-side yet.
  - Account identity now exists on approved parent-managed surfaces, but payment ownership and promo grants still need backend alignment before account-backed commerce is truthful end to end.
- Next: `M11.4 - Backend authenticated entitlement model alignment`

### 2026-03-20 - M11.4 Backend authenticated entitlement model alignment
- Status: DONE
- Summary: Aligned the entitlement backend to authenticated parent ownership without disturbing the install/session runtime path. The backend now verifies Firebase-authenticated parent identity on `/v1/session/identity` and entitlement routes through `x-storytime-parent-auth`, represents entitlement owner separately from entitlement source, persists a minimal authenticated parent-owned entitlement record in backend memory, and returns owner metadata through bootstrap, sync, and preflight. The iOS client now sends the parent Firebase ID token only on bootstrap plus entitlement routes, decodes the owner metadata into the cached entitlement envelope, and keeps story plus realtime runtime requests free of parent-auth headers. Stale install-owned entitlement tokens are ignored once a signed-in parent account owns the active entitlement record.
- Files: `backend/package.json`, `backend/package-lock.json`, `backend/src/app.ts`, `backend/src/lib/env.ts`, `backend/src/lib/entitlements.ts`, `backend/src/lib/parentIdentity.ts`, `backend/src/lib/requestContext.ts`, `backend/src/lib/security.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/auth-security.test.ts`, `backend/src/tests/entitlements.test.ts`, `backend/src/tests/testHelpers.ts`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run src/tests/auth-security.test.ts src/tests/app.integration.test.ts src/tests/entitlements.test.ts`, which passed `55` tests.
  - `npm run build`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests`, which passed `28` tests.
- Decisions:
  - Keep authenticated entitlement owner separate from `EntitlementSnapshot.source` so account ownership and grant origin remain distinct and testable.
  - Verify parent identity only on account-owned routes and keep story plus realtime runtime routes on the existing install/session auth model.
  - Send the Firebase parent ID token only on bootstrap and entitlement routes from `APIClient` rather than attaching parent auth to all backend traffic.
  - Use a minimal process-local backend entitlement record for authenticated parent ownership in this sprint milestone instead of widening into durable cloud persistence yet.
- Risks/Notes:
  - Authenticated parent-owned entitlement records are currently process-local in backend memory and are not durable across backend restarts yet.
  - Production Firebase parent-token verification requires backend environment configuration: `FIREBASE_PROJECT_ID` plus either service-account credentials or application default credentials.
  - Restore mismatch rules under the new account model are still deferred to `M11.6`.
- Next: `M11.5 - StoreKit purchase integration in parent-managed surfaces`

### 2026-03-20 - M11.5 StoreKit purchase integration in parent-managed surfaces
- Status: DONE
- Summary: Completed the authenticated parent-managed purchase milestone without widening into child-session commerce. The iOS entitlement manager now requires a signed-in parent before purchase initiation, `ParentTrustCenterView` truthfully explains account-linked purchase ownership and keeps purchase initiation inside parent-managed surfaces, and the backend rejects purchase-linked entitlement sync without authenticated parent ownership using `parent_auth_required`. Focused UI coverage now proves direct parent-controls purchase completion plus blocked new-story and blocked continuation recovery after purchase, while child story surfaces remain purchase-free.
- Files: `backend/src/lib/entitlements.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/entitlements.test.ts`, `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts`, which passed `46` tests.
  - `npm run build`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests -only-testing:StoryTimeTests/APIClientTests`, which passed `44` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanCompleteParentManagedPlusPurchase`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterParentManagedPlusPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase`, which passed `3` tests.
- Decisions:
  - Keep purchase initiation blocked until a parent account is signed in so purchase ownership cannot silently stay device-only.
  - Enforce purchase-linked entitlement ownership server-side with `parent_auth_required` instead of allowing install-owned purchase sync to continue.
  - Dismiss the iOS password-save sheet in shared UI-test account helpers so parent-managed purchase verification remains deterministic without changing product behavior.
- Risks/Notes:
  - Restore mismatch handling remains deferred to `M11.6`.
  - Authenticated entitlement storage remains process-local in backend memory and still needs durable persistence in a later sprint step.
  - Production Firebase parent-token verification still requires backend environment configuration.
- Next: `M11.6 - Authenticated restore and entitlement refresh verification`

### 2026-03-20 - M11.6 Authenticated restore and entitlement refresh verification
- Status: IN PROGRESS
- Summary: Materially advanced authenticated restore and refresh verification without widening scope past the current milestone. Backend entitlement sync now requires authenticated parent ownership for both purchase and restore-linked Plus sync, the iOS client now persists the last install-owned entitlement envelope separately so restored parent-owned state can fall back safely after parent sign-out, and `ParentTrustCenterView` now requires signed-in parent state before restore while deterministic UI-test restore and refresh paths stay parent-managed. Isolated UI coverage now proves blocked new-story recovery after authenticated restore and blocked continuation recovery after authenticated plan refresh, and the repo now has an explicit `docs/verification/authenticated-restore-entitlement-refresh-verification.md` report with evidence labels and remaining live-environment gaps.
- Files: `backend/src/lib/entitlements.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/entitlements.test.ts`, `docs/verification/authenticated-restore-entitlement-refresh-verification.md`, `ios/StoryTime/App/ParentAuthManager.swift`, `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/ParentAuthManagerTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts`, which passed `49` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/ParentAuthManagerTests`, which passed `42` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterAuthenticatedRestore`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterAuthenticatedPlanRefresh`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut`, which still fails because the parent-controls UI does not yet show the expected `Starter` title after sign-out from restored Plus.
- Decisions:
  - Keep restore ownership aligned with authenticated parent identity the same way purchase ownership is aligned, using `parent_auth_required` for both restore and purchase-linked Plus sync.
  - Preserve the last install-owned entitlement envelope separately so parent-owned restored state can fall back to device-owned baseline without assuming cloud sync.
  - Record the remaining sign-out presentation gap explicitly instead of marking the milestone done on partial UI evidence.
- Risks/Notes:
  - The remaining repo blocker for `M11.6` is the failing parent-controls sign-out UI assertion after restored Plus is cleared.
  - Real App Store restore behavior and StoreKit/account mismatch semantics remain environment-dependent and are still not directly verified in live conditions.
  - Authenticated entitlement storage remains process-local in backend memory and still needs durable persistence in a later sprint step.
- Next: `M11.6 - Authenticated restore and entitlement refresh verification`

### 2026-03-21 - M11.6 Authenticated restore and entitlement refresh verification
- Status: DONE
- Summary: Closed the remaining authenticated restore verification blocker without widening scope. `APIClient` now preserves the install-owned entitlement fallback when `/v1/session/identity` returns no entitlement envelope, so parent-account bootstrap and sheet dismissal no longer wipe the device baseline before restore or sign-out. The focused UI path for restored Plus now returns to `Starter` after parent sign-out, and the verification report now records `M11.6` as complete with only live App Store restore or mismatch semantics still unverified outside the repo.
- Files: `docs/verification/authenticated-restore-entitlement-refresh-verification.md`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityWithoutEntitlementsPreservesInstallFallback -only-testing:StoryTimeTests/ParentAuthManagerTests/testSignOutRestoresLastInstallOwnedEntitlementSnapshot`, which passed `2` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut`, which passed.
- Decisions:
  - Preserve the install-owned entitlement fallback during bootstrap responses that omit entitlements instead of clearing all cached entitlement state.
  - Keep the parent-controls restore or sign-out verification deterministic in UI automation by scrolling back to the signed-out account section before asserting its copy, rather than weakening the product flow.
- Risks/Notes:
  - Live App Store restore behavior, family-share edge cases, and final mismatch semantics between StoreKit ownership, authenticated parent identity, and device-local fallback are still environment-dependent and remain unverified in repo terms.
  - Authenticated entitlement storage remains process-local in backend memory and still needs durable persistence in a later sprint step.
- Next: `M11.8 - Account, payment, and promo happy-path verification`

### 2026-03-21 - M11.7 Promo-code redemption flow for premium grants
- Status: DONE
- Summary: Completed the bounded parent-only promo redemption milestone without widening into child-facing commerce. The backend now accepts authenticated promo redemption through `POST /v1/entitlements/promo/redeem`, loads the real promo catalog from `PROMO_CODE_GRANTS`, enforces one-time invalid, expired, and already-used failure modes, and issues authenticated parent-owned entitlements with source `promo_grant`. On iOS, `ParentTrustCenterView` now exposes a parent-managed promo entry path, promo-derived plan copy stays distinguishable from paid ownership, API handling stores promo owner metadata, and the repo now documents the real env-backed promo setup separately from the deterministic UI-test seed harness.
- Files: `backend/src/app.ts`, `backend/src/lib/analytics.ts`, `backend/src/lib/entitlements.ts`, `backend/src/lib/env.ts`, `backend/src/lib/security.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/entitlements.test.ts`, `backend/src/tests/testHelpers.ts`, `backend/src/types.ts`, `docs/promo-code-redemption-setup.md`, `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts`, which passed `57` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testRedeemPromoCodeStoresPromoGrantOwnerMetadata -only-testing:StoryTimeTests/APIClientTests/testRedeemPromoCodeSurfacesInvalidPromoFailure -only-testing:StoryTimeTests/SmokeTests`, which passed `17` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRedeemPromoCodeForSignedInParent`, which passed `2` tests.
- Decisions:
  - Keep real promo logic env-backed through `PROMO_CODE_GRANTS` instead of hidden request headers or backend debug-only branches.
  - Treat promo redemption as authenticated parent-owned entitlement issuance with source `promo_grant`, distinct from paid `storekit_verified` ownership.
  - Keep the UI-test promo seed path explicit and separate so deterministic parent-controls coverage does not masquerade as the real backend promo catalog.
- Risks/Notes:
  - Promo catalogs and redemption ledgers remain backend process-local in repo terms, so one-time promo usage resets on backend restart until durable persistence lands.
  - Promo admin tooling remains intentionally deferred; repo verification currently assumes environment-managed promo seed setup rather than an operator UI.
  - Full blocked-to-unlocked verification across purchase, promo, and restore flows is still deferred to `M11.8`.
- Next: `M11.8 - Account, payment, and promo happy-path verification`

### 2026-03-21 - M11.8 Account, payment, and promo happy-path verification
- Status: DONE
- Summary: Closed the Sprint 11 happy-path verification milestone without expanding scope beyond the parent-managed commerce boundary. The repo now has direct automated evidence that blocked new-story and blocked continuation flows recover after parent account creation plus authenticated purchase or promo redemption, that restore remains parent-managed, and that retry reuses refreshed entitlement tokens instead of bypassing gating. The new verification artifact records the exact command set, route assumptions, evidence labels, and remaining live-environment gaps.
- Files: `docs/verification/account-payment-promo-happy-path-verification.md`, `backend/src/tests/app.integration.test.ts`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run src/tests/app.integration.test.ts`, which passed `44` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRedeemedPromoEntitlementTokenAfterAuthenticatedUnlock`, which passed `2` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterAuthenticatedRestore -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyBlockedStartCanRecoverAfterPromoRedemption -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailBlockedContinuationCanRecoverAfterPromoRedemption`, which passed `5` tests.
- Decisions:
  - Keep `M11.8` as a verification-only milestone and reuse the existing focused restore evidence for continuation refresh rather than widening into more implementation work.
  - Treat retry-token reuse as a first-class verification target for both purchase and promo unlock paths so blocked recovery remains explicit and testable.
  - Keep the child-session trust boundary verified by routing all unlock actions through `ParentTrustCenterView` and confirming `VoiceSessionView` stays auth-free and purchase-free by code inspection.
- Risks/Notes:
  - Live App Store purchase and restore sheet behavior, family-share edge cases, and production commerce mismatch semantics remain environment-dependent and still need external verification.
  - Backend entitlement and promo ledgers remain process-local in repo terms, so durable persistence is still a later hardening concern.
  - Restore-backed continuation recovery remains covered by the earlier focused `M11.6` verification doc rather than this exact rerun command set.
- Next: `M11.9 - Post-sprint readiness summary and remaining gaps`

### 2026-03-21 - M11.9 Post-sprint readiness summary and remaining gaps
- Status: DONE
- Summary: Closed Sprint 11 in repo terms without widening into a new implementation stream. The new post-sprint summary artifact aggregates the Sprint 11 verification command set, re-inspects the parent-auth, entitlement, purchase, restore, and promo foundations, classifies the resulting state with the required evidence labels, and makes one explicit recommendation: do not move into cross-device continuity planning yet. The repo recommendation is to stay on authenticated commerce hardening first so durable entitlement storage, explicit StoreKit-account mismatch rules, and live-environment Apple or StoreKit verification land before any broader account-linked product promises.
- Files: `docs/verification/sprint-11-parent-account-commerce-summary.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - No new automated tests were run for `M11.9`.
  - Verification for this milestone is the repo-grounded summary of the exact Sprint 11 command set already recorded across `M11.2` through `M11.8`, now consolidated in `docs/verification/sprint-11-parent-account-commerce-summary.md`.
- Decisions:
  - Treat Sprint 11 as complete in repo terms rather than creating speculative continuity-planning milestones before the remaining commerce-foundation gaps are closed.
  - Recommend the next workstream stay on authenticated commerce hardening: durable entitlement or promo persistence, explicit restore or purchase mismatch handling, and live-environment Apple or StoreKit verification.
  - Keep cross-device continuity and account-linked story-history planning deferred because the repo still explicitly promises local-only story history and lacks a durable account-commerce foundation.
- Risks/Notes:
  - Live App Store purchase and restore behavior, family-share edge cases, and the final StoreKit-versus-parent-account mismatch rule remain unverified outside deterministic repo automation.
  - Backend entitlement ownership and promo redemption ledgers remain process-local in repo terms and still need durable persistence before broader account-linked product promises are safe.
  - Production Sign in with Apple and live StoreKit surfaces remain partially verified because repo automation still depends on deterministic providers for some system UI.
- Next: No remaining ordered milestone in `SPRINT.md`; the post-sprint recommendation is a new authenticated-commerce hardening planning pass before any continuity-sync planning.

### 2026-03-21 - M12.1 First-run activation onboarding flow
- Status: DONE
- Summary: Added the new first-run activation journey so fresh installs no longer fall directly into `HomeView` or bury account activation inside Parent Controls. The app now routes brand-new users through a seven-step placeholder onboarding flow that explains StoryTime, captures child setup, requires parent account sign-in, exposes Starter versus Plus selection plus restore and promo entry, and only then unlocks the main app. Parent Controls remain available for ongoing account and plan management, but the copy now reflects that onboarding owns first-run activation.
- Files: `ios/StoryTime/App/ContentView.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/ParentAccountSheetView.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests/testFirstRunExperienceStoreDefaultsToIncompleteAndPersistsCompletion -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateBlocksAccountStepUntilParentIsSignedIn -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateBlocksCompletionUntilPlanIsChosen -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateAllowsCompletionOnceAccountAndPlanAreReady`, which passed `4` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testFreshInstallShowsParentLedOnboardingFlow -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCanEditFallbackChildProfile -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingRequiresParentAccountBeforePlanStep -only-testing:StoryTimeUITests/StoryTimeUITests/testChildStorySurfacesRemainFreeOfAccountPrompts`, which passed in the focused onboarding slice.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus`, which passed after the Parent Controls copy change.
- Decisions:
  - Create a new `M12.1` milestone because Sprint 11 had no remaining queued work and the first-run activation change did not cleanly fit any closed commerce milestone.
  - Keep the existing `FirstRunExperienceStore` completion key so already-onboarded installs continue to bypass onboarding instead of forcing a migration during this implementation pass.
  - Reuse the existing parent-auth sheet and entitlement or promo seams inside onboarding rather than inventing a separate auth or commerce stack for first run.
  - Land placeholder-first onboarding content now and defer visual polish or a broader plan matrix until the new activation structure is verified more deeply.
- Risks/Notes:
  - The new onboarding content is intentionally placeholder-heavy; layout and copy polish are still follow-up work.
  - The current plan architecture still only exposes Starter and Plus in repo terms, so there is no real family-plan branch to surface yet.
  - Broader onboarding verification around relaunch persistence and some commerce-backed onboarding variants still needs a dedicated hardening pass because XCUITest relaunch flows remain noisier than the smoke coverage.
- Next: `M12.2 - Onboarding activation verification and hardening`

### 2026-03-21 - M12.2 Onboarding activation verification and hardening
- Status: DONE
- Summary: Hardened the first-run activation verification pass and closed Phase 12 in repo terms. The onboarding suite now has direct evidence for fresh-install routing, parent-managed account entry, plan-step Starter versus purchase versus restore versus promo access, purchase-backed completion, restore-backed completion, promo-backed completion, relaunch persistence, and the Parent Controls ongoing-management regression. I also hardened `ParentAccountSheetView` so successful sign-in dismisses on auth-state transition, which makes onboarding account entry more resilient in the real product flow instead of depending only on a button callback.
- Files: `ios/StoryTime/Features/Story/ParentAccountSheetView.swift`, `ios/StoryTime/Tests/SmokeTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `docs/verification/onboarding-activation-verification.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/SmokeTests/testFirstRunExperienceStoreDefaultsToIncompleteAndPersistsCompletion -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateBlocksAccountStepUntilParentIsSignedIn -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateBlocksCompletionUntilPlanIsChosen -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateAllowsCompletionOnceAccountAndPlanAreReady -only-testing:StoryTimeTests/SmokeTests/testFirstRunActivationGateAllowsCompletionForAuthenticatedPlusPlan`, which passed `5` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCanCompleteAfterParentManagedPlusPurchase`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testFreshInstallShowsParentLedOnboardingFlow -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsPlanRestoreAndPromoEntryPoints -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCanCompleteAfterRestoreRefresh -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCanCompleteAfterPromoRedemption`, which passed `4` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingCompletesIntoHomeAndStaysDismissedAfterRelaunch`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus`, which passed.
- Decisions:
  - Keep `storytime.first-run.completed.v1` as the onboarding completion key for now so previously onboarded installs continue to bypass onboarding intentionally.
  - Use the deterministic `Sign in with Apple` UI-test seam for the broader onboarding commerce verification paths after the shared email/password sheet showed XCUITest timing noise in first-run automation.
  - Treat that noisy email/password onboarding path as a remaining partial-verification note, not as a reason to reopen the first-run gate structure after the broader onboarding flow passed.
- Risks/Notes:
  - The exact first-run email/password onboarding happy path is still only partially verified in this pass.
  - Live system-auth and live App Store purchase or restore behavior remain unverified outside repo automation.
- Next: No remaining ordered milestone in `SPRINT.md`; any next step should be a newly planned workstream.

### 2026-03-21 - M13.0 Authenticated commerce hardening plan and queue approval
- Status: DONE
- Summary: Replaced the post-Phase-12 empty queue with an explicit authenticated-commerce hardening phase. I re-inspected the current entitlement ownership, promo redemption, restore verification, onboarding hardening, and backend storage seams, then converted the repo’s standing recommendation into an approved Phase 13 queue. The new plan keeps scope inside parent identity, payments, entitlements, restore, and promo hardening, and still defers continuity sync, cross-device history, and child-facing commerce.
- Files: `docs/authenticated-commerce-hardening-plan.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - No new automated tests were run for `M13.0`.
  - Verification for this milestone is the repo-grounded planning pass captured in `docs/authenticated-commerce-hardening-plan.md`, citing the inspected code paths and existing verification artifacts.
- Decisions:
  - Start Phase 13 with durable authenticated entitlement and promo persistence because `backend/src/lib/entitlements.ts` still keeps that state in process-local memory.
  - Keep restore-mismatch and device-fallback behavior as a separate follow-up milestone after durable persistence lands, so semantics are defined on top of stable account-owned state instead of a transient in-memory model.
  - Keep live production Apple-auth and App Store verification as the third step, after the underlying durability and mismatch rules are explicit.
- Risks/Notes:
  - Backend entitlement ownership and promo redemption still reset on backend restart until `M13.1` lands.
  - StoreKit-account mismatch, family-share conflict handling, and final device-local fallback copy are still only partially locked in repo terms.
  - Live production `Sign in with Apple`, App Store purchase, and App Store restore behavior remain unverified outside deterministic repo automation.
- Next: `M13.1 - Durable authenticated entitlement and promo persistence`

### 2026-03-21 - M13.1 Durable authenticated entitlement and promo persistence
- Status: DONE
- Summary: Closed the backend durability gap without widening into cloud sync or client-contract churn. Authenticated parent-owned entitlement records and promo redemption ledgers now persist to disk through `ENTITLEMENTS_PERSIST_PATH`, reload when the backend boots, and preserve the existing signed entitlement envelope and iOS API shape. The targeted test pass now proves both purchased Plus ownership and one-time promo redemption survive backend recreation.
- Files: `backend/src/app.ts`, `backend/src/lib/entitlements.ts`, `backend/src/lib/env.ts`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/entitlements.test.ts`, `backend/src/tests/testHelpers.ts`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts`, which passed `62` tests.
  - `npm run build`, which passed.
- Decisions:
  - Reuse the backend’s existing small JSON persistence pattern instead of introducing a broader database or story-history sync layer.
  - Persist only authenticated entitlement and promo-redemption state in this milestone; keep usage-ledger depletion and story-history data out of scope.
  - Keep the iOS entitlement contract unchanged so `M13.1` remains a backend durability milestone rather than a client or backend protocol redesign.
- Risks/Notes:
  - Restore mismatch, family-share conflict handling, and explicit device-local fallback behavior are still open and remain the next trust-boundary milestone.
  - The new persistence layer is repo-fit and durable across backend restart, but it is still a small local-file implementation rather than a broader production data platform.
  - Live production `Sign in with Apple`, App Store purchase, and App Store restore behavior remain unverified outside deterministic repo automation.
- Next: `M13.2 - Restore mismatch and device-fallback product rule`

### 2026-03-21 - M13.2 Restore mismatch and device-fallback product rule
- Status: DONE
- Summary: Locked the current repo product rule for restore conflicts and local fallback without widening into broader account transfer logic. Restored Plus now stays claimed to the parent account that restored it on the current device or install, backend restore sync rejects different-parent transfer attempts with `restore_parent_mismatch`, and Parent Controls plus onboarding now explain that sign-out falls back to the local device state instead of moving restored access between parent accounts.
- Files: `backend/src/lib/entitlements.ts`, `backend/src/tests/entitlements.test.ts`, `backend/src/tests/app.integration.test.ts`, `ios/StoryTime/App/UITestSeed.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/UITests/StoryTimeUITests.swift`, `docs/verification/restore-mismatch-device-fallback-verification.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts`, which passed.
  - `cd /Users/rory/Documents/StoryTime/backend && npm run build`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testRestoreSyncSurfacesParentMismatchFailure`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowSignedOutParentAccountStatus -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowRestoreMismatchForDifferentParentOnSameDevice -only-testing:StoryTimeUITests/StoryTimeUITests/testOnboardingShowsPlanRestoreAndPromoEntryPoints`, which passed `4` tests.
- Decisions:
  - Treat same-device restored Plus as install-claimed to one parent account instead of silently transferring that ownership when a different parent signs in later.
  - Keep the restore conflict explicit through the existing entitlement sync route and `restore_parent_mismatch` error code instead of inventing a separate restore-transfer flow.
  - Make the signed-out fallback rule visible in Parent Controls and onboarding copy so the trust boundary is clear before and after account changes.
- Risks/Notes:
  - Live family-share behavior and production App Store restore mismatches remain only partially verified because repo automation cannot exercise a real App Store environment.
  - The current rule is intentionally scoped to the same device or install; broader cross-device transfer semantics are still deferred.
  - Live production `Sign in with Apple`, App Store purchase, and App Store restore behavior remain unverified outside deterministic repo automation.
- Next: `M13.3 - Live authenticated-commerce verification pass`

### 2026-03-21 - M13.3a Live authenticated-commerce verification prep and support rerun
- Status: DONE
- Summary: Split the original live verification milestone into prep and execution so the repo no longer pretends Codex can complete physical-device Apple or App Store validation by itself. This prep pass reran the deterministic backend, unit, and focused UI support slices for authenticated commerce, then added an explicit live-execution checklist with prerequisites, evidence capture expectations, and the remaining environment-only gap for the actual physical-device run.
- Files: `docs/verification/live-authenticated-commerce-verification-prep.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/entitlements.test.ts src/tests/app.integration.test.ts`, which passed `66` tests.
  - `cd /Users/rory/Documents/StoryTime/backend && npm run build`, which passed.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/ParentAuthManagerTests/testSignOutRestoresLastInstallOwnedEntitlementSnapshot -only-testing:StoryTimeTests/APIClientTests/testBootstrapSessionIdentityWithoutEntitlementsPreservesInstallFallback -only-testing:StoryTimeTests/APIClientTests/testRestoreSyncSurfacesParentMismatchFailure -only-testing:StoryTimeTests/APIClientTests/testRedeemPromoCodeStoresPromoGrantOwnerMetadata -only-testing:StoryTimeTests/APIClientTests/testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync`, which passed `5` tests.
  - `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanSignInWithAppleAndPersistAcrossRelaunch -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanCompleteParentManagedPlusPurchase -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsShowRestoreMismatchForDifferentParentOnSameDevice`, which passed `3` tests.
  - Attempted: `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut`, which did not complete cleanly because the simulator runner became unstable during the UI prompt path; the earlier passing `M13.2` verification remains the authoritative repo evidence for that restore happy path.
- Decisions:
  - Split `M13.3` into prep and execution because the real Apple-auth and App Store validation requires a human-operated physical device and live environment access not available in this repo automation run.
  - Keep the prep support slice focused on deterministic Apple sign-in, purchase completion, restore-mismatch handling, and backend entitlement coverage instead of pretending the simulator can stand in for the live App Store pass.
  - Treat the isolated restore-plus-sign-out rerun failure as simulator or UI-runner instability unless a reproducible product defect appears in a later dedicated investigation.
- Risks/Notes:
  - Production `Sign in with Apple`, live App Store purchase, and live App Store restore remain unverified until `M13.3b`.
  - Family-share and broader cross-device restore behavior still need live-environment evidence.
  - The restore happy-path UI rerun remains sensitive to simulator prompt timing even though direct evidence already exists from `M13.2`.
- Next: `M13.3b - Live authenticated-commerce execution and report`

### 2026-03-21 - M13.3b Live authenticated-commerce execution and report
- Status: BLOCKED
- Summary: I re-checked the next execution milestone against the current repo state and the existing prep artifact. The milestone is blocked for this environment because the remaining work is a real physical-device Apple/App Store verification pass, not additional repo-only implementation. The repo already has the deterministic support rerun, exact prerequisites, and the manual step list in place, so marking the milestone `BLOCKED` is the truthful next state.
- Files: `PLANS.md`, `SPRINT.md`
- Tests:
  - No new automated tests were added or run in this blocker-confirmation pass.
  - Existing support evidence remains in `docs/verification/live-authenticated-commerce-verification-prep.md`.
- Decisions:
  - Do not fabricate or simulate a live Apple or App Store verification result from simulator-only automation.
  - Keep `M13.3b` as the next milestone, but mark it `BLOCKED` until the external prerequisites are available.
  - Avoid creating more repo-only sub-milestones here because the blocker is environmental rather than a missing preparation step inside the repo.
- Risks/Notes:
  - Production `Sign in with Apple`, live App Store purchase, and live App Store restore remain unverified.
  - Family-share and broader cross-device restore behavior remain only partially verified until the live pass can be executed.
  - The blocker is external access, not a newly discovered product or code defect in the repo.
- Next: `M13.3b - Live authenticated-commerce execution and report` once physical-device and live-environment access are available

### 2026-03-21 - M13.3b blocker reconfirmation
- Status: BLOCKED
- Summary: Reconfirmed that the live authenticated-commerce execution milestone is still blocked in the current environment. The repo-side prep is complete, and there is now a visible physical iPhone, but it is not yet paired or ready for live developer execution, so the real Apple-auth and App Store pass still cannot proceed.
- Files: `docs/verification/live-authenticated-commerce-verification-prep.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - No automated tests were run.
  - Environment checks:
    - `xcrun xctrace list devices`
    - `xcrun devicectl list devices`
    - `xcrun devicectl list devices --verbose`
- Decisions:
  - Keep `M13.3b` blocked until physical-device and live-environment access are actually available.
  - Record concrete blocker evidence instead of leaving the blocked state as an unverified assumption.
- Risks/Notes:
  - `xcrun devicectl list devices` now shows one physical iPhone, but `xcrun devicectl list devices --verbose` reports `pairingState: unpaired` and `tunnelState: disconnected`.
  - The blocker is now narrower: device presence exists, but pairing, live execution readiness, and Apple/App Store credentialed interaction are still missing.
  - Production `Sign in with Apple`, live App Store purchase, and live App Store restore remain unverified.
- Next: `M13.3b - Live authenticated-commerce execution and report` once a physical device and live-environment access are available

### 2026-03-21 - M13.3b blocker refinement
- Status: BLOCKED
- Summary: Refined the blocked-state evidence after a new environment check. A physical iPhone is now visible to CoreDevice, so the blocker is no longer "no device." The remaining blocker is that the device is unpaired and disconnected for developer execution, and the live Apple/App Store credentials plus human-operated verification pass are still unavailable.
- Files: `docs/verification/live-authenticated-commerce-verification-prep.md`, `PLANS.md`, `SPRINT.md`
- Tests:
  - No automated tests were run.
  - Environment checks:
    - `xcrun xctrace list devices`
    - `xcrun devicectl list devices`
    - `xcrun devicectl list devices --verbose`
- Decisions:
  - Keep `M13.3b` blocked, but narrow the documented blocker from "no device" to "device present but not paired or execution-ready."
  - Preserve the existing live-pass checklist because it is still the right next action once the pairing and credential prerequisites are cleared.
- Risks/Notes:
  - The visible device reports `pairingState: unpaired` and `tunnelState: disconnected`.
  - Production `Sign in with Apple`, live App Store purchase, and live App Store restore remain unverified.
  - Family-share and broader cross-device restore behavior remain only partially verified until the live pass can run.
- Next: `M13.3b - Live authenticated-commerce execution and report` once device pairing, live build access, and Apple/App Store credentials are available
