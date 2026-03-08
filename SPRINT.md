# SPRINT.md

## Sprint Goal

Use the verified hybrid-runtime baseline to define and ship the next productization, monetization, and polished-UX milestone set without weakening the runtime gate.

## Execution Rules

- Work one milestone per Codex run unless the milestone is explicitly split first.
- Inspect the active code paths before editing.
- Use the active repo as the source of truth, not archived code or stale assumptions.
- If a milestone is too large for one run, split it into smaller milestones here before implementation.
- Do not mark a milestone `DONE` until its definition of done is met and its required tests pass.
- After every run, update both `PLANS.md` and this file.
- Keep `tiny-backend/` out of active implementation and planning except as labeled historical context.
- The hybrid runtime baseline is established; prioritize productization, monetization-aware UX, onboarding, and parent-trust flows unless a new runtime defect is explicitly recorded in `PLANS.md`.

## Status Legend

- `TODO`
- `IN PROGRESS`
- `DONE`
- `BLOCKED`

## Phase 1 - Core Voice Reliability

### M1.1 - Realtime startup flow audit

Status: `DONE`

Goal:
- Map and reproduce the active startup path end to end so the failing branch is concrete before changing code.

Concrete tasks:
- Trace the active startup path from `VoiceSessionView.task` through `PracticeSessionViewModel.startSession()`.
- Trace `APIClient.prepareConnection()`, `/v1/session/identity`, `/v1/realtime/session`, `RealtimeVoiceClient.connect()`, the hidden `WKWebView` bridge, and `/v1/realtime/call`.
- Record the exact current assumptions around base URL, endpoint path, session header, install header, and SDP exchange.
- Identify the currently failing startup branch and capture the reproduction steps in `PLANS.md`.
- Note transport/config smells already present in code, including the hardcoded bridge base URL and hardcoded client realtime region.

Required tests:
- None required to start the audit.
- If a failing startup path is reproduced in a test during the audit, add the failing regression test and leave the milestone `IN PROGRESS` until the fix lands.

Dependencies:
- None

Definition of done:
- The startup sequence is documented in repo terms.
- The failing path is narrowed to a specific branch or assumption.
- The next startup milestone can be implemented without re-discovery.

Completion notes:
- Audit captured in `docs/realtime-startup-audit.md`.
- Concrete failing branch identified in `backend/src/services/realtimeService.ts`: upstream non-OK responses currently hit an undefined `loggerForContext(...)` call before the intended `AppError`.
- Additional startup assumptions recorded: hardcoded bridge base URL, hardcoded realtime region `"US"`, and raw error propagation through `localizedDescription`.

### M1.2 - `/v1/realtime/call` contract and SDP handling

Status: `DONE`

Goal:
- Make the iOS bridge, backend proxy, and OpenAI call contract consistent and deterministic.

Concrete tasks:
- Confirm the request and response contract between `RealtimeVoiceClient` bridge JavaScript and `backend/src/services/realtimeService.ts`.
- Harden SDP offer and answer handling so line endings and body shape are preserved exactly.
- Verify absolute and relative call endpoint handling from `RealtimeVoiceClient.connect()`.
- Remove or isolate any startup assumptions that are not actually owned by the backend session response.
- Keep the backend proxy contract explicit and minimal.

Required tests:
- `RealtimeVoiceClientTests` for call URL construction and connect payload handling
- `APIClientTests` for realtime session bootstrap behavior
- backend realtime service tests for multipart field handling and invalid SDP rejection
- backend integration tests for `/v1/realtime/call`

Dependencies:
- M1.1

Definition of done:
- The `/v1/realtime/call` contract is explicit and stable.
- Client and backend tests cover the active SDP path.
- Startup no longer depends on ambiguous contract behavior.

Completion notes:
- `RealtimeVoiceClient.connect()` now resolves absolute, root-relative, and path-relative call endpoints explicitly.
- The embedded realtime bridge now uses a local secure origin instead of a deployment-specific backend base URL.
- `APIClient` preserves absolute realtime call endpoints returned by `/v1/realtime/session`.
- `RealtimeService` now cleanly returns `AppError` on upstream rejection and rejects invalid upstream answer SDP.
- Verified by targeted iOS tests in `APIClientTests` and `RealtimeVoiceClientTests`, plus backend service and integration tests for `/v1/realtime/call`.
- 2026-03-07 follow-up: backend schema tests now pin the same WebRTC SDP requirement as the runtime contract. `types.test.ts` uses valid offer SDP with both `m=` and `a=fingerprint:` and explicitly rejects truncated payloads that omit either line.

### M1.3 - Safe startup failure states

Status: `DONE`

Goal:
- Ensure startup failures end in safe, deterministic states and never surface raw internal payloads.

Concrete tasks:
- Separate startup failures for health check, session bootstrap, realtime session creation, bridge readiness, call connect, and disconnect-before-ready.
- Replace raw `localizedDescription` user-facing startup failures with safe presentation.
- Ensure stale startup callbacks cannot revive a failed or cancelled session.
- Ensure disconnect and bridge error events during boot resolve once.
- Keep child-facing copy simple and safe.

Required tests:
- client tests for each startup failure branch
- regression test proving raw backend body text is not shown in UI
- backend tests if public error payload shape changes

Dependencies:
- M1.1
- M1.2

Definition of done:
- Startup failures are categorized.
- The session lands in one valid failure state.
- UI shows safe error copy only.

Completion notes:
- `PracticeSessionViewModel` now distinguishes startup failures for health check, session bootstrap, realtime session creation, bridge readiness, call connect, and disconnect-before-ready.
- Startup failures now use safe child-facing copy instead of raw `localizedDescription`.
- Boot-time disconnect and bridge error callbacks now resolve immediately, and stale startup callbacks no longer revive a failed boot.
- `RealtimeVoiceClient` now throws typed boot-time errors for bridge-ready timeout, bridge-ready failure, and disconnect-before-ready.
- Verified by targeted `PracticeSessionViewModelTests`, `APIClientTests`, and `RealtimeVoiceClientTests`.

### M1.4 - Startup-path tests

Status: `DONE`

Goal:
- Add a dedicated regression test layer for the startup path.

Concrete tasks:
- Add deterministic client tests spanning `PracticeSessionViewModel`, `APIClient`, and mock voice transport startup.
- Add tests for late ready/disconnect/error callbacks during boot.
- Add backend route tests for missing install ID, invalid session token, unsupported region, and invalid realtime call payloads that matter to startup.
- Add at least one startup test that exercises the full active contract sequence without the real network.

Required tests:
- new startup regression tests in `PracticeSessionViewModelTests`
- `APIClientTests`
- `RealtimeVoiceClientTests`
- backend integration or service tests for startup route behavior

Dependencies:
- M1.2
- M1.3

Definition of done:
- Startup has its own repeatable regression suite.
- The currently failing startup path is protected by tests.

Completion notes:
- `PracticeSessionViewModelTests` now exercises the full active startup contract with the real `APIClient` over a stubbed `URLSession`, covering health check, session bootstrap, voice catalog fetch, realtime session creation, and voice connect without the real network.
- `APIClientTests` now pin the startup request order and session-header reuse across prepare connection, session bootstrap, voice catalog, and realtime session creation.
- `RealtimeVoiceClientTests` now verify bridge readiness gating before the startup connect command is sent.
- Backend integration tests now cover missing install ID on `/v1/session/identity` and invalid session token rejection on `/v1/realtime/session`, alongside the existing unsupported-region and invalid-call-payload coverage.

### M1.5 - Canonical voice session state model cleanup

Status: `DONE`

Goal:
- Finish consolidating client session behavior around the explicit `VoiceSessionState` model.

Concrete tasks:
- Remove remaining duplicate or ambiguous session flags where possible.
- Keep `VoiceSessionState` and `ConversationPhase` aligned and minimal.
- Keep the coordinator as the only place that advances session state.
- Make invalid transitions log consistently with enough context.

Required tests:
- valid transition coverage
- invalid transition rejection coverage
- terminal-state restart coverage

Dependencies:
- M1.3

Definition of done:
- Session state is controlled by the canonical model only.
- No critical transition depends on out-of-band flags.

Completion notes:
- `PracticeSessionViewModel.phase` is now derived from `sessionState` instead of stored as a parallel mutable flag.
- Discovery, generation, revision, startup-attempt, and terminal-state guards now validate exact `VoiceSessionState` cases instead of broader phase checks.
- Transition and invalid-transition logs now include full canonical state context, including scene indices, ready-step numbers, and queued revision counts.
- Verified by `PracticeSessionViewModelTests` coverage for canonical state progression, invalid transition rejection with state context, and clean restart from the completed terminal state.

### M1.6 - Deterministic discovery, generation, and narration transitions

Status: `DONE`

Goal:
- Make discovery, generation, and narration progression explicit and race-resistant.

Concrete tasks:
- Ensure discovery results cannot trigger generation twice.
- Ensure generation cannot start before discovery completion.
- Ensure narration start only occurs from valid generating or revising states.
- Harden stale result rejection for discovery and generation callbacks.

Required tests:
- normal discovery-to-generation path
- discovery blocked path
- stale discovery result rejection
- stale generation result rejection
- narration start only from valid states

Dependencies:
- M1.5

Definition of done:
- Discovery, generation, and narration have explicit allowed transitions.
- Overlapping async completions cannot advance the session incorrectly.

Completion notes:
- Live generation now starts only from the matching discovery result, and mock generation only from the final ready discovery step instead of any generic `.ready` state.
- Generation request inputs are now snapped at kickoff before async continuity work starts, so late generation work cannot inherit later session mutations.
- Narration start now validates explicit source states for replay boot, generation resolution, revision resolution, and prior scene completion instead of coarse phase buckets.
- Verified by new `PracticeSessionViewModelTests` coverage for no generation before discovery resolution, stale discovery result rejection after failure, and stale generation result rejection without late narration.

### M1.7 - Interruption and revision serialization

Status: `DONE`

Goal:
- Keep interruption, revision, and continue behavior deterministic under overlap.

Concrete tasks:
- Ensure interruptions during narration, generation, and in-flight revision are serialized or rejected deliberately.
- Keep queued revision updates explicit and bounded.
- Ensure revise-and-continue resumes from the correct scene index every time.
- Ensure interruption cancellation of assistant speech is deterministic.

Required tests:
- interruption during narration
- interruption during generation
- interruption during in-flight revision
- queued revision ordering
- resume narration from correct scene after revision

Dependencies:
- M1.6

Definition of done:
- Only one revision request owns the future scene set at a time.
- Resume position is correct after every accepted revision.

Completion notes:
- Speech that starts during `.generating` or `.revising` now carries a deferred origin policy, so a late transcript final is rejected if the session has already advanced to narration instead of being reinterpreted under the new state.
- Revision queueing is now explicitly bounded to one pending update, and overflow is rejected with logging instead of silently growing the queue of future-scene work.
- Narration interruption tests now assert assistant speech cancellation exactly once, so cancellation behavior is pinned to a deterministic single cancel call.
- Verified by new `PracticeSessionViewModelTests` coverage for late generation-origin transcript rejection, late revision-origin transcript rejection, and queue overflow rejection.

### M1.8 - Duplicate completion and save prevention

Status: `DONE`

Goal:
- Ensure completion, save, and replay terminal behavior happen once.

Concrete tasks:
- Keep completion side effects centralized.
- Prevent duplicate save from narration completion races, disconnects, or replay flows.
- Make repeat-episode behavior explicit so it does not create or overwrite incorrect history.
- Keep transcript clearing behavior aligned with terminal transitions.

Required tests:
- duplicate completion rejection
- duplicate save rejection
- replay flow save behavior
- transcript clearing on completion when enabled

Dependencies:
- M1.6
- M1.7

Definition of done:
- Completion and save happen once.
- Terminal transitions cannot replay side effects.

Completion notes:
- `completeSession()` now only accepts explicit non-terminal source states, so late terminal paths cannot flip `.failed` into `.completed` or replay completion side effects.
- Transcript clearing now follows terminal session end instead of only successful completion, keeping the privacy setting aligned across completion and failure.
- Replay completion now leaves history unchanged, while repeat-episode revisions replace the existing episode instead of adding duplicate history.
- Verified by updated `PracticeSessionViewModelTests` coverage for duplicate completion/save prevention, replay-without-save, replay-with-replace, and terminal transcript clearing.

## Phase 2 - Data Integrity And Isolation

### M2.1 - Persistence audit

Status: `DONE`

Goal:
- Document the exact current local storage surface and invariants before migration.

Concrete tasks:
- Inventory every active `UserDefaults` key used for story data, profiles, privacy, install identity, session token, and continuity.
- Identify which data is primary product data versus bootstrap or config data.
- Record current save, replace, delete, clear-history, and retention paths.
- Record where continuity cleanup depends on story library state.

Required tests:
- none required for the audit itself
- if audit reveals untested critical behavior, add the missing baseline tests and leave the milestone `IN PROGRESS`

Dependencies:
- None

Definition of done:
- The active local storage surface is documented.
- Migration work can proceed without rediscovery.

Completion notes:
- `docs/persistence-audit.md` now inventories the active iOS persistence surface, including all active `UserDefaults` keys, primary product data versus bootstrap/config data, and the active save, replace, delete, clear-history, and retention cleanup paths.
- `StoryLibraryStoreTests` now pin shared continuity cleanup for clear-history, delete-series, retention prune, and child-delete cascade.
- `StoryLibraryStore.addStory(...)` now keeps pre-save series pruning semantics while deferring continuity sync until after the library mutation, and async continuity prune tasks now re-read the latest persisted library snapshot when they execute.
- `StoryLibraryStoreTests.testAddStoryPreservesImmediateContinuityIndexingAfterSave` now protects the former stale-prune race as a passing regression.

### M2.2 - Local schema design for story data

Status: `DONE`

Goal:
- Choose the durable/queryable local schema for primary story storage.

Concrete tasks:
- Define the target storage model for child profiles, story series, episodes, privacy settings, and continuity facts.
- Keep child scoping and retention cleanup explicit in the schema.
- Keep install identity and session token storage decisions separate from primary story data.
- Record the migration plan and rollback assumptions in `PLANS.md`.

Required tests:
- schema or repository tests for basic create/read/update/delete operations if code lands
- migration-plan test design notes recorded in `PLANS.md`

Dependencies:
- M2.1

Definition of done:
- The target local schema is chosen and documented.
- Migration implementation can begin without re-arguing the storage model.

Completion notes:
- Chosen target store: `Core Data` with `storytime-v2.sqlite`.
- New schema entities are defined in `docs/story-data-schema.md`: `Profile`, `LibrarySettings`, `StorySeries`, `StoryEpisode`, `ContinuityFact`, `SchemaMigrationLog`.
- The schema records explicit series ordering with `libraryPosition` and keeps `storyIndex` for episode ordering.
- Child scoping is intentionally staged: the schema keeps `childProfileId` nullable for migration compatibility now, and `M2.6` removes fallback visibility.
- Continuity linkage remains explicit by `(seriesId, storyId)` for replace/delete/prune correctness.
- Migration plan and rollback assumptions are captured in `docs/story-data-schema.md` and `PLANS.md`.

### M2.3.1 - Core Data bootstrap for library, profile, and privacy data

Status: `DONE`

Goal:
- Replace the interim file-backed v2 snapshot with the chosen Core Data-backed library store for story series, child profiles, active child selection, and privacy settings.

Concrete tasks:
- Replace the current v2 snapshot backend with a Core Data-backed store file.
- Keep `StoryLibraryStore` behavior stable while migrating legacy `storytime.*.v1` library/profile/privacy keys into the new store.
- Preserve corruption fallback and idempotent relaunch behavior for legacy imports.
- Keep the legacy keys as read source only; do not make them the primary write path again.

Required tests:
- migration from populated `UserDefaults`
- corrupted source data fallback
- idempotent re-launch after migration
- direct v2 store reload regression

Dependencies:
- M2.2

Definition of done:
- Existing users keep their story library, child profiles, active child selection, and privacy settings across relaunch.
- Those library/profile/privacy reads and writes no longer depend on large serialized `UserDefaults` blobs.

Completion notes:
- `StoryLibraryV2Storage` now persists the v2 snapshot through a Core Data-backed `storytime-v2.sqlite` store instead of a flat JSON blob file.
- The Core Data schema currently stores library settings, child profiles, story series, story episodes, and migration metadata, with `libraryPosition` preserving current series ordering.
- `StoryLibraryStore` still bootstraps from legacy `UserDefaults` only when the v2 store is absent or older than the current migration version.
- Store tests now cover migration from populated legacy defaults, corrupted legacy fallback, idempotent relaunch, and direct v2 snapshot reload against the Core Data backend.

### M2.3.2 - Continuity migration and legacy blob retirement

Status: `DONE`

Goal:
- Finish the migration away from `UserDefaults` for the remaining primary story data and remove residual legacy bootstrap dependence.

Concrete tasks:
- Migrate `ContinuityMemoryStore` off `storytime.continuity.memory.v1` and into the v2 local store.
- Keep continuity cleanup, retention prune, and child-delete behavior aligned with the migrated library store.
- Retire remaining legacy read paths once the v2 store is confirmed current.
- Preserve corruption fallback and idempotent relaunch behavior for the full migrated store.

Required tests:
- continuity migration from populated `UserDefaults`
- corrupted continuity source fallback
- idempotent re-launch after full migration

Dependencies:
- M2.3.1

Definition of done:
- Continuity facts and library/profile/privacy data no longer depend on `UserDefaults`.
- Legacy `storytime.*.v1` blobs are migration source only, not active primary storage.

Completion notes:
- `ContinuityMemoryStore` now persists semantic continuity facts through the Core Data-backed `storytime-v2.sqlite` store instead of `storytime.continuity.memory.v1`.
- Continuity migration now records its own completion note in the v2 migration log, removes the legacy continuity blob after successful import, and falls back safely on corrupt legacy continuity data.
- Existing v1 Core Data snapshot installs now upgrade in place to the current migration version instead of re-bootstraping library/profile/privacy data from legacy defaults during the continuity cutover.
- Verified by new `StoryLibraryStoreTests` coverage for continuity migration from legacy defaults, corrupt continuity fallback, idempotent relaunch, and in-place v1 snapshot upgrade, plus the targeted `PracticeSessionViewModelTests` suite.

### M2.4 - Save, load, and delete flow migration

Status: `DONE`

Goal:
- Move the active story lifecycle onto the new local store.

Concrete tasks:
- Replace whole-snapshot rewrites with entity-level add, extend, replace, repeat, delete-series, clear-history, and read flows on the new store.
- Keep continuation metadata and story-series ordering consistent.
- Keep save behavior atomic enough to avoid partial story writes.

Required tests:
- save new series
- append episode
- replace episode
- delete series
- clear history
- repeat episode no-save behavior

Dependencies:
- M2.3.2

Definition of done:
- Active story lifecycle reads and writes use entity-level operations on the new store.
- Whole-snapshot rewrites are no longer the active library persistence path.

Completion notes:
- `StoryLibraryStore` now persists story lifecycle mutations through direct v2 series and episode operations for new series, append, replace, delete-series, clear-history, and repeat-no-save flows instead of rewriting the full library snapshot.
- Reload regressions now prove those flows survive a fresh store load directly from the Core Data-backed `StoredStorySeries` and `StoredStoryEpisode` rows.
- Retention pruning still uses collection-level series replacement for now, which is deferred to `M2.5`.

### M2.5 - Retention pruning hardening

Status: `DONE`

Goal:
- Keep retention pruning correct after storage migration.

Concrete tasks:
- Re-implement retention pruning against the new local store.
- Ensure pruning updates continuity cleanup consistently.
- Ensure "save story history off" truly removes retained story history from the active primary store.

Required tests:
- retention by cutoff date
- save-history-off cleanup
- continuity prune after retention

Dependencies:
- M2.4

Definition of done:
- Retention settings enforce actual data removal in the active store.

Completion notes:
- Retention pruning now updates the v2 story store through selective series and episode deletion plus episode-order compaction instead of collection-level replacement writes.
- Save-history-off cleanup now clears persisted story rows and shared continuity before the disabled setting is reloaded.
- Reload regressions now cover cutoff-based pruning, continuity cleanup after pruning, and save-history-off cleanup across a fresh store load.

### M2.6 - Active-child library scoping fix

Status: `DONE`

Goal:
- Enforce strict active-child library visibility.

Concrete tasks:
- Remove the current `visibleSeries` fallback that shows all series when a child has no matches.
- Update empty-state behavior for children with no saved stories.
- Audit story selection in `NewStoryJourneyView` so it respects strict child scoping.
- Update any tests that currently encode the fallback behavior.

Required tests:
- active child with no stories shows empty state, not all series
- past-story picker only shows series for the active child
- cross-child visibility regression tests

Dependencies:
- M2.1

Definition of done:
- No saved story list or picker crosses child boundaries by fallback.

Completion notes:
- `StoryLibraryStore.visibleSeries` no longer falls back to all series when the active child has no matches, and `visibleSeries(for:)` now scopes continuation choices to an explicitly selected child.
- `NewStoryJourneyView` now derives its continuation selection from the selected child's scoped series and sanitizes stale `selectedSeriesId` values before building the launch plan.
- `HomeView` and `NewStoryJourneyView` now expose regression-covered empty states for the no-stories child path instead of leaking another child's seeded series.
- Verified by updated `StoryLibraryStoreTests` plus a focused `StoryTimeUITests` regression that switches from Milo to Nora and asserts both saved-story list and past-story picker stay empty.

### M2.7 - Child-delete cascade behavior

Status: `DONE`

Goal:
- Keep child deletion scoped, complete, and non-destructive to other children.

Concrete tasks:
- Audit child-profile deletion across stories, continuity, active profile selection, and fallback profile creation.
- Ensure deleting one child does not affect another child's stories or continuity.
- Make the final-profile fallback behavior explicit and tested.

Required tests:
- delete one child keeps other child's stories
- delete child clears only matching continuity
- delete final child recreates expected fallback profile state

Dependencies:
- M2.6

Definition of done:
- Child deletion is fully scoped and predictable.

Completion notes:
- `StoryLibraryStore.deleteChildProfile(_:)` now resolves the remaining profile set, active-profile fallback, and removed series IDs before mutating state, so delete semantics are explicit instead of relying on incidental array mutation order.
- Reload regressions now prove that deleting the active child preserves another child's stories, deleting a child clears only matching continuity, and deleting the final child recreates the default fallback profile with no retained stories.
- The milestone intentionally keeps continuity cleanup scoped to the deleted child's series IDs; broader continuity provenance remains in `M2.8`.

### M2.8 - Continuity provenance and cleanup

Status: `DONE`

Goal:
- Keep continuity facts attributable, clean, and aligned with migrated story state.

Concrete tasks:
- Preserve story and series provenance for continuity facts.
- Ensure replace, delete, prune, and child-delete flows remove or update continuity correctly.
- Ensure revised stories do not leave stale future-scene continuity behind.

Required tests:
- replace story continuity update
- delete series continuity cleanup
- retention prune continuity cleanup
- revised-story continuity integrity

Dependencies:
- M2.4
- M2.5
- M2.7

Definition of done:
- Continuity data stays attributable and cleanup-safe across the full lifecycle.

Completion notes:
- `ContinuityMemoryStore` now prunes semantic continuity by explicit `(seriesId, storyId)` provenance instead of separate global series and story sets, so cleanup remains correct even if story IDs collide across series.
- `StoryLibraryStore` now rebuilds series structural continuity from retained episode engine memory after append, replace, and retention prune, while preserving migrated legacy continuity metadata when there is no engine-derived memory to recompute from.
- Repeat-episode revisions now replace the original story's semantic continuity facts and clear closed open loops from the saved series metadata instead of leaving stale future-scene continuity behind.
- Verified by new `StoryLibraryStoreTests` coverage for replace-story continuity rebuild, pair-scoped provenance pruning, and retention-prune structural cleanup, plus `PracticeSessionViewModelTests` coverage for revised-story continuity replacement.

## Phase 3 - Safety, Privacy, And Production Hardening

### M3.1 - Safe application error model

Status: `DONE`

Goal:
- Define the safe client-visible error model for the app.

Concrete tasks:
- Define app-level error categories for startup, moderation block, network failure, backend failure, decode failure, persistence failure, and cancellation.
- Ensure child-facing copy stays safe and simple.
- Ensure errors do not leave the session in ambiguous states.

Required tests:
- error-category mapping tests
- blocked story path tests
- cancellation is not failure tests

Dependencies:
- M1.3

Definition of done:
- The app has a safe, explicit error model instead of raw transport strings.

Completion notes:
- `StoryTimeAppErrorCategory` and `StoryTimeAppError` now define the active client-safe error model for startup, moderation block, network failure, backend failure, decode failure, persistence failure, and cancellation.
- `PracticeSessionViewModel` now maps non-startup discovery, generation, revision, runtime voice error, and disconnect paths onto safe typed copy instead of surfacing raw transport strings.
- Blocked discovery, generation, and revision flows now record typed moderation notices without failing the session, and discovery/revision cancellation now restores explicit recoverable states instead of failing the session.
- Verified by expanded `PracticeSessionViewModelTests` coverage for category mapping, blocked-story paths, safe runtime voice errors, and cancellation-not-failure recovery.

### M3.2 - Client/backend error mapping

Status: `DONE`

Goal:
- Align backend `AppError` responses and client error presentation.

Concrete tasks:
- Map backend error codes and public messages into client-safe errors.
- Stop using raw backend response bodies as user-facing text.
- Verify blocked `422` story flows still decode correctly while non-blocking failures stay safe.

Required tests:
- `APIClientTests`
- `PracticeSessionViewModelTests`
- backend route tests if response payloads change

Dependencies:
- M3.1

Definition of done:
- Client and backend error handling are aligned and safe.

Completion notes:
- `APIClient` now parses backend `{ error, message, request_id }` envelopes into structured `APIError.invalidResponse` values, preserves backend code/message/request ID for higher-level mapping, and keeps `localizedDescription` free of raw response bodies.
- `PracticeSessionViewModel` now maps backend codes like `rate_limited`, session-token failures, `unsupported_region`, `revision_conflict`, and realtime transport failures into safe client-visible errors instead of relying only on generic status-code heuristics.
- `422` blocked discovery/generation/revision flows still stay on the typed-success decode path, while non-blocking failures now use the structured backend error envelope.
- Verified by targeted `APIClientTests`, `PracticeSessionViewModelTests`, and backend `app.integration.test.ts` coverage for explicit app-error `message/request_id` and safe internal-error envelopes.

### M3.3 - Session correlation IDs and tracing

Status: `DONE`

Goal:
- Make live session activity traceable across client and backend without leaking content.

Concrete tasks:
- Carry request IDs and session IDs into client diagnostics where useful.
- Keep correlation fields structured and redacted.
- Add coordinator event tracing for startup, discovery, generation, revision, completion, and failure.

Required tests:
- client tracing tests
- backend request context and analytics tests

Dependencies:
- M1.4
- M3.2

Definition of done:
- Critical-path events can be correlated end to end without logging sensitive content.

Completion notes:
- `APIClient` now generates per-request `x-request-id` headers, stores backend `session_id` in `AppSession`, and emits structured transport trace events across startup, voices, realtime session creation, discovery, generation, revision, and embeddings requests.
- `PracticeSessionViewModel` now records redacted coordinator trace events for startup, discovery, generation, revision, completion, and failure, keyed by backend request ID and session ID instead of transcript or story text.
- Backend request-context tests now pin caller-supplied request ID echo behavior on story routes, and analytics tests now cover session-aware request metrics alongside request IDs.
- Verified by targeted `APIClientTests`, `PracticeSessionViewModelTests`, backend `app.integration.test.ts`, and backend `request-retry-rate.test.ts` coverage.

### M3.4 - Backend lifecycle logging

Status: `DONE`

Goal:
- Strengthen backend lifecycle logging for the active realtime and story pipeline.

Concrete tasks:
- Add structured lifecycle logs around realtime ticket issuance, realtime call proxying, discovery, generate, revise, retry, and failure paths.
- Keep logs request-scoped and redacted.
- Avoid logging transcripts or story text by default.

Required tests:
- analytics/logging unit tests where practical
- route or service tests covering success and failure logging hooks

Dependencies:
- M3.3

Definition of done:
- Backend lifecycle events are logged consistently and safely.

Completion notes:
- Added `lifecycle_event` backend logging helpers that use request-scoped child loggers and emit structured start, completed, blocked, retrying, and failed events.
- `RealtimeService`, `StoryDiscoveryService`, and `StoryService` now log realtime ticket issuance, realtime call proxying, discovery, generate, and revise lifecycle hooks with correlation metadata already present in request context.
- Lifecycle logs stay redacted by design: they use counts, retry timing, safe error codes/status, and other metadata instead of transcript text, story text, SDP bodies, or raw upstream response bodies.
- Verified by targeted backend service tests for realtime lifecycle logging, discovery retry logging, generate completion logging, revise failure logging, and the existing request-context/integration coverage.

### M3.5 - Real data-flow and privacy audit

Status: `DONE`

Goal:
- Verify that the product's actual storage, transport, and logging match its privacy claims.

Concrete tasks:
- Audit raw audio handling, transcript handling, story retention, continuity retention, telemetry, and install/session identifiers.
- Verify which data remains on device and which crosses the network.
- Record any mismatch between UI copy and code behavior.

Required tests:
- none for the audit itself
- add regression tests for any mismatches that are fixed during the audit

Dependencies:
- M2.8
- M3.3

Definition of done:
- Real data flow is documented and mismatches are identified explicitly.

Completion notes:
- Audit captured in `docs/privacy-data-flow-audit.md`.
- Confirmed that raw audio is not persisted in active code, but live microphone audio leaves the device during realtime sessions after backend-mediated SDP setup.
- Confirmed that saved story history and continuity remain local after completion, while discovery transcripts, generation inputs, revision inputs, generated story content, and embeddings requests cross the network during processing.
- Recorded the active privacy-copy mismatches for `M3.6`: "Stories stay on device" is too broad, "Raw audio is not saved by default" is misleading because there is no active raw-audio save path, and transcript clearing is local-only.

### M3.6 - Privacy copy alignment

Status: `DONE`

Goal:
- Align parent-facing and child-facing privacy language with actual behavior.

Concrete tasks:
- Update privacy copy in `HomeView`, `NewStoryJourneyView`, `VoiceSessionView`, and `ParentTrustCenterView` as needed.
- Remove ambiguous claims or settings.
- Keep docs aligned with the final implementation.

Required tests:
- UI or unit tests covering privacy setting behavior where available
- regression tests for transcript clearing if behavior changes

Dependencies:
- M3.5

Definition of done:
- Privacy copy matches actual behavior exactly.

Completion notes:
- Updated `HomeView`, `NewStoryJourneyView`, `VoiceSessionView`, `PracticeSessionViewModel.privacySummary`, and `ParentTrustCenterView` so the active copy no longer implies the full story loop stays on device.
- Parent-facing and child-facing copy now states the current behavior directly: raw audio is not saved, story prompts and generated stories are sent for live processing, saved history stays on device after completion, and transcript clearing is local on-screen cleanup when enabled.
- Added accessibility identifiers for the updated privacy surfaces and verified them with a focused UI regression plus `PracticeSessionViewModelTests` coverage for both privacy-summary branches.

### M3.7 - Transport and config hardening

Status: `DONE`

Goal:
- Tighten fragile transport and deployment assumptions.

Concrete tasks:
- Remove or isolate hardcoded realtime startup assumptions that do not belong in client code.
- Review `RealtimeVoiceClient` bridge loading assumptions.
- Tighten backend env validation and unsafe defaults where needed.
- Review session TTL and refresh behavior against the live startup path.

Required tests:
- backend env and auth tests
- client startup regression tests affected by transport changes

Dependencies:
- M1.2
- M3.4

Definition of done:
- Startup and backend config rely on explicit, tested assumptions.

Completion notes:
- `AppConfig` now reads the deployed backend URL from the app bundle `StoryTimeAPIBaseURL` key with explicit environment override precedence instead of depending only on an inline deployment URL in code.
- The iOS app now uses `NSAllowsLocalNetworking` instead of global `NSAllowsArbitraryLoads`, so loopback development stays available without broad insecure transport allowance.
- `APIClient` now recovers once from stale or missing session-token failures on authenticated realtime/story/embeddings requests by clearing the old token, re-bootstrapping `/v1/session/identity`, and retrying the request.
- `RealtimeVoiceClient` now fails bridge readiness immediately on navigation failure and web-content termination instead of waiting only for the ready-timeout path.
- Backend env loading now rejects unsafe session refresh windows and production defaults that leave CORS wildcarded or session auth disabled.

### M3.8 - Region handling alignment

Status: `DONE`

Goal:
- Align client and backend region behavior.

Concrete tasks:
- Replace the current client hardcoded realtime region with an explicit aligned approach.
- Ensure client request headers and body region values match backend policy.
- Keep unsupported-region failures safe and testable.

Required tests:
- client tests for region propagation
- backend auth/request-context tests for region enforcement

Dependencies:
- M3.7

Definition of done:
- Region behavior is explicit and consistent across client and backend.

Completion notes:
- `APIClient` now resolves processing region from backend `/health` metadata or `/v1/session/identity`, stores it alongside session state, and sends `x-storytime-region` on follow-on requests.
- `PracticeSessionViewModel` no longer hardcodes `"US"` for realtime startup; the realtime session body now aligns to the same resolved region value as the request header.
- Startup unsupported-region failures now preserve the safe region-specific message instead of collapsing into generic startup copy.
- Verified by new iOS regressions for region propagation and unsupported-region startup handling, plus backend request-context default-region and `/v1/session/identity` region-echo coverage.

### M3.9 - Lightweight parent access gate

Status: `DONE`

Goal:
- Add a minimal parent access gate around the parent trust surface.

Concrete tasks:
- Define the lightest acceptable access gate for the current product scope.
- Apply it to the `ParentTrustCenterView` entry path without redesigning the product.
- Keep the gate testable and easy to reason about.

Required tests:
- unit or UI tests for parent gate entry behavior
- regression tests ensuring children cannot open parent controls directly without the gate once implemented

Dependencies:
- None

Definition of done:
- Parent controls have a deliberate access gate and tests cover the entry behavior.

Completion notes:
- `HomeView` now presents a local gate sheet before switching to `ParentTrustCenterView`.
- The shipped gate is intentionally lightweight: the parent must type `PARENT` before the trust surface opens.
- UI regressions now prove the parent trust surface does not open directly from a single tap and that the existing parent-control flows still work after gated entry.

### M3.10.1 - Acceptance harness foundation and happy path

Status: `DONE`

Goal:
- Create the reusable acceptance harness foundation and cover the full happy-path critical loop once.

Concrete tasks:
- Add a dedicated acceptance-harness layer on top of the existing mock API and mock voice transport.
- Cover startup, discovery, generation, narration, interruption, revision, completion, and save in one repeatable happy-path scenario.
- Keep the harness isolated from network and persisted state left by other tests.

Required tests:
- critical-path happy-path acceptance suite

Dependencies:
- M1.8
- M2.8
- M3.8

Definition of done:
- A reusable acceptance harness exists and the full happy-path critical loop is covered end to end.

Completion notes:
- `PracticeSessionViewModelTests` now includes a reusable happy-path acceptance runner built on top of the existing mock API and mock realtime voice core.
- The new acceptance slice covers startup, discovery, generation, narration, interruption, revision, completion, and save in one no-network scenario.
- The acceptance suite now reloads `StoryLibraryStore` after completion to prove the revised story persists correctly for the active child.

### M3.10.1a - Critical-path verification pass

Status: `DONE`

Goal:
- Verify the current highest-value StoryTime flows explicitly and record what is fully covered, indirectly covered, or still unverified.

Concrete tasks:
- Review the active critical-path tests, mocks, and stubs across iOS and backend.
- Run targeted verification for startup, happy path, repeat mode, parent controls, delete flows, and child-scoped visibility.
- Add one small high-signal regression if an obvious coverage gap appears during the pass.
- Record the results in `docs/verification/critical-path-verification.md`.

Required tests:
- targeted iOS unit tests for startup, coordinator happy path, repeat mode, store cleanup, and privacy summary behavior
- targeted iOS UI tests for home/journey/parent/series-detail/delete flows
- targeted backend route/service tests for startup, realtime contract, discovery, and story service contracts

Dependencies:
- M3.10.1

Definition of done:
- The repo contains a concrete critical-path verification report.
- Flow-by-flow confidence and remaining gaps are explicit.
- Any obvious high-signal gap addressed in-scope is covered by test.

Completion notes:
- Added `docs/verification/critical-path-verification.md` with per-flow methods, results, confidence, defects, and remaining gaps.
- Added `StoryTimeUITests.testDeleteAllSavedStoryHistoryClearsSeededSeriesFromHome` so the parent-surface delete-all-history flow now has end-to-end UI coverage in addition to store cleanup tests.
- Verification found no new reproduced product defects; the main remaining gaps are the planned failure-injection acceptance slice, a dedicated single-series delete UI regression, and a dedicated end-to-end assertion for launching from a selected prior story during setup.

### M3.10.1b - Realtime voice determinism verification pass

Status: `DONE`

Goal:
- Audit the end-to-end realtime voice lifecycle for contract correctness, deterministic transitions, transcript safety, and transport assumptions.

Concrete tasks:
- Inspect the active iOS realtime transport, hidden bridge, coordinator state machine, and backend realtime routes/services.
- Run targeted backend realtime route/service/type tests plus targeted iOS realtime client/API/coordinator tests.
- Add one small regression if the audit finds a concrete determinism gap on the active voice path.
- Record the results in `docs/verification/realtime-voice-determinism-report.md`.

Required tests:
- targeted backend realtime route/service/type tests
- targeted iOS realtime client/API/coordinator tests
- focused coordinator regression for any in-scope determinism bug found during the pass

Dependencies:
- M3.10.1

Definition of done:
- The repo contains a concrete realtime determinism report.
- Startup contract, runtime flow, transcript flow, and remaining realtime risks are explicit.
- Any small in-scope determinism fix found during verification is covered by regression.

Completion notes:
- Added `docs/verification/realtime-voice-determinism-report.md` with startup-contract, event-flow, transcript-flow, determinism, weak-spot, and confidence findings.
- Added `PracticeSessionViewModelTests.testLateTranscriptAfterFailureDoesNotOverwriteLatestTranscript` and tightened `handleTranscriptFinal` so terminal or deferred-rejected final transcripts no longer mutate coordinator transcript state.
- Verification confirmed strong startup-contract coverage across `APIClientTests`, `RealtimeVoiceClientTests`, and backend realtime route/service/type tests, but also documented that the hidden `WKWebView` bridge still lacks a live WebRTC acceptance harness and that runtime disconnect remains intentionally terminal.

## Phase 4 - Hybrid Runtime Migration

### M4.1 - Hybrid runtime contract

Status: `DONE`

Goal:
- Define the hybrid runtime contract in repo terms before transport changes begin.

Concrete tasks:
- Document the runtime split between interaction mode, narration mode, and authoritative story/scene state.
- Define which coordinator responsibilities stay in `PracticeSessionViewModel` and which transport responsibilities belong to realtime interaction versus TTS narration.
- Define the initial backend/client contract boundaries for answer-only interactions, future-scene revision, and narration resume.
- Record the contract in repo docs and align `PLANS.md` and `SPRINT.md` language if the implementation-facing terms change during the write-up.

Required tests:
- none required unless a tiny supporting type/doc test lands with the contract

Dependencies:
- M3.10.1b

Definition of done:
- The hybrid runtime contract is explicit enough to implement against without re-arguing core boundaries.
- Interaction mode, narration mode, and authoritative story state each have clear ownership.

Completion notes:
- Added `docs/hybrid-runtime-contract.md` to pin the hybrid runtime boundary in repo terms: realtime interaction, TTS long-form narration, scene-based story authority, interruption classification outputs, and narration resume rules.
- Added typed contract markers in `StoryDomain.swift`: `HybridRuntimeMode`, `HybridInteractionPhase`, `InterruptionIntent`, and `NarrationResumeDecision`.
- Added `HybridRuntimeContractTests` inside `PracticeSessionViewModelTests.swift` to pin the contract semantics for transport expectations, future-scene mutation boundaries, and narration resume boundaries.

### M4.2 - Mode transition state model

Status: `DONE`

Goal:
- Define and pin the allowed transitions between hybrid interaction and narration modes.

Concrete tasks:
- Extend the current coordinator state model into explicit hybrid mode transitions without introducing parallel mutable flags.
- Define entry and exit rules for setup interaction, narration playback, interruption intake, answer-only handling, revise-future-scenes handling, and narration resume.
- Record invalid transition rules and terminal behavior expectations for hybrid mode handoffs.

Required tests:
- state-model tests or coordinator tests for allowed and rejected mode transitions if code lands

Dependencies:
- M4.1

Definition of done:
- The hybrid mode graph is finite, explicit, and implementation-ready.
- Invalid handoffs are defined before code lands.

Completion notes:
- Added `HybridRuntimeStateNode`, `HybridRuntimeTransitionTrigger`, and `VoiceSessionState.hybridRuntimeStateNode` to `StoryDomain.swift` so the hybrid mode graph is explicit without introducing a second live coordinator state machine.
- Added `docs/hybrid-mode-transition-model.md` to record the allowed mode graph, current coordinator-state mapping, invalid handoffs, and terminal expectations for hybrid runtime work.
- Expanded `HybridRuntimeContractTests` in `PracticeSessionViewModelTests.swift` to pin current-state mapping, the main hybrid flow, and rejected handoffs.

### M4.3 - Scene-state authority and revision boundary contract

Status: `DONE`

Goal:
- Define exactly how scene state owns narration progress, answer context, and future-scene revision boundaries.

Concrete tasks:
- Pin the authoritative scene-state structure the coordinator must use during hybrid narration.
- Define how the current scene, completed scenes, remaining scenes, and resume boundary are represented.
- Define the rule that revision changes future scenes only unless a later milestone explicitly widens scope.
- Define how answer-only interactions may reference story state without mutating future scenes.

Required tests:
- coordinator or type tests for scene-boundary ownership if code lands
- backend contract tests if revise request or response shapes change

Dependencies:
- M4.1
- M4.2

Definition of done:
- Scene-state authority and revision boundaries are explicit and testable.
- Resume-from-boundary behavior can be implemented without ambiguity.

Completion notes:
- Added `AuthoritativeStorySceneState`, `StorySceneBoundary`, `StoryAnswerContext`, `StoryRevisionBoundary`, and `StorySceneMutationScope` to `StoryDomain.swift` so completed scenes, the current boundary scene, remaining scenes, future-only mutation scope, and resume semantics are explicit in code.
- Added `docs/hybrid-scene-state-authority.md` and aligned the earlier hybrid contract docs so answer-only remains read-only while revise-future-scenes preserves the current boundary scene and mutates only later scenes.
- Expanded `HybridRuntimeContractTests` in `PracticeSessionViewModelTests.swift` to pin the new authoritative scene-state slices, answer-context immutability, future-only revision request mapping, and final-scene no-revision behavior.

### M4.4 - TTS narration pipeline

Status: `DONE`

Goal:
- Replace long-form scene narration with a dedicated TTS pipeline while preserving coordinator authority.

Concrete tasks:
- Add a narration transport abstraction for scene playback that is separate from realtime interaction transport.
- Implement initial TTS generation/playback for one scene at a time under coordinator control.
- Keep narration progress keyed to scene state rather than transport callbacks inventing progression.
- Preserve existing completion/save protections while switching narration transport.

Required tests:
- narration transport tests for single-scene playback start/finish
- coordinator tests proving scene progression still follows authoritative state

Dependencies:
- M4.2
- M4.3

Definition of done:
- Long-form narration plays through the TTS path for the active scene under coordinator control.
- Realtime interaction transport is no longer the default long-form narration path.

Completion notes:
- `PracticeSessionViewModel` now owns a dedicated `StoryNarrationTransporting` abstraction for scene playback instead of treating realtime voice output as the default narration path.
- Production narration now defaults to a `SystemSpeechNarrationTransport` backed by `AVSpeechSynthesizer`, while realtime remains available for live interaction and interruption handling.
- Narration progression remains coordinator-owned: the transport only reports active-scene completion, and the coordinator still decides scene advancement, interruption, revision, and completion/save behavior.
- Targeted hybrid contract and coordinator regressions passed after the transport split, including narration-transport and interruption/revision coverage.

### M4.5 - Pause and resume behavior

Status: `DONE`

Goal:
- Make narration pause and resume deterministic at explicit scene boundaries.

Concrete tasks:
- Define pause semantics for active scene playback versus boundary-safe resume.
- Implement coordinator-owned pause and resume controls for narration transport.
- Ensure pause/resume preserves current scene index and does not duplicate completion side effects.

Required tests:
- coordinator tests for pause, resume, and duplicate-finish rejection
- narration transport tests for pause/resume signaling

Dependencies:
- M4.4

Definition of done:
- Narration can pause and resume without losing scene ownership or replaying terminal side effects.

Completion notes:
- `VoiceSessionState` now includes an explicit `paused(sceneIndex:)` narration state so pause/resume remains finite and coordinator-owned instead of hiding behind transport booleans.
- `PracticeSessionViewModel` now exposes deterministic `pauseNarration()` and `resumeNarration()` controls that preserve the active scene boundary and keep completion/save behavior single-run.
- The narration transport contract now supports `pause()` and `resume()` so TTS playback can halt and continue without handing scene ownership to the transport layer.
- Targeted coordinator and hybrid contract regressions passed, including pause/resume ownership and single-completion coverage.

### M4.6 - Interruption handoff from TTS to realtime

Status: `DONE`

Goal:
- Make interruption during TTS narration hand off cleanly into realtime interaction mode.

Concrete tasks:
- Stop or pause TTS playback deterministically when the child interrupts.
- Transition from narration mode into interaction mode without losing current scene boundary.
- Keep the realtime transport ready for interruption intake according to the hybrid contract.

Required tests:
- coordinator tests for narration-to-interaction handoff
- transport tests for TTS stop/pause plus realtime interaction activation

Dependencies:
- M4.4
- M4.5

Definition of done:
- TTS narration interruption produces one valid interaction handoff path with correct scene ownership preserved.

Completion notes:
- `PracticeSessionViewModel` now accepts narration interruption handoff from both `narrating(sceneIndex:)` and `paused(sceneIndex:)`, preserving the current scene boundary while moving into `interrupting(sceneIndex:)`.
- The coordinator tears down the active TTS playback task deterministically during handoff and reuses the already-connected realtime interaction transport instead of reconnecting.
- Final transcripts received while paused now trigger the same valid interruption-intake path as speech-start events, so paused narration can move directly into live interaction handling.
- Targeted coordinator regressions passed for paused-to-interaction handoff, transcript-driven handoff, and no-reconnect behavior.

### M4.7a - Deterministic interruption intent classifier

Status: `DONE`

Goal:
- Add a deterministic, implementation-facing interruption intent classifier before path execution work begins.

Concrete tasks:
- Add an interruption intent router contract that produces explicit outputs for answer-only, revise-future-scenes, and repeat/clarify.
- Define the minimum story-state context each route needs from transcript input plus current scene authority.
- Keep classification local, deterministic, and cheap enough for live interaction.

Required tests:
- router contract tests across answer-only, revise-future-scenes, and repeat/clarify cases
- tests for revision-unavailable output when no future scenes remain

Dependencies:
- M4.1
- M4.2
- M4.3
- M4.6

Definition of done:
- Every interruption transcript can be mapped to an explicit intent plus required story-state context.
- The router outputs are explicit, deterministic, and transport-independent.

Completion notes:
- `StoryDomain.swift` now exposes `InterruptionIntentRouteDecision` and `InterruptionIntentRouter`, keeping interruption classification local, deterministic, and transport-independent.
- The router always returns explicit answer context, returns revision boundary data only for future-scene mutation requests, and marks revision unavailable when no future scenes remain.
- Hybrid contract tests now cover answer-only, repeat-or-clarify, revise-future-scenes, and revision-unavailable outputs.

### M4.7b - Coordinator route-selection activation

Status: `DONE`

Goal:
- Make the coordinator consult the interruption classifier before choosing any post-handoff path.

Concrete tasks:
- Invoke the classifier at the coordinator interruption boundary using authoritative story state.
- Surface explicit route outputs for downstream answer-only, revise-future-scenes, or repeat/clarify handling.
- Keep unsupported routes in a safe waiting state until their execution milestones land.

Required tests:
- coordinator tests proving interruption transcripts are classified before path selection
- regression tests that revision is no longer chosen blindly for every interruption

Dependencies:
- M4.7a

Definition of done:
- The coordinator no longer treats every interruption as an implicit revision request.
- Classified route outputs are available for downstream interruption-path milestones.

Completion notes:
- `PracticeSessionViewModel` now consults `InterruptionIntentRouter` at the interruption boundary instead of routing every transcript directly into revision.
- The coordinator now surfaces `interruptionRouteDecision` as an explicit typed output for downstream answer-only, repeat-or-clarify, and revise-future-scenes handling.
- Only immediately applicable revise-future-scenes requests continue into the existing revision path; answer-only, repeat-or-clarify, and revision-unavailable cases remain safely in `interrupting(sceneIndex:)` until their execution milestones land.
- Targeted coordinator regressions now cover routed revision, no-blind-revision for answer-only interruptions, and safe waiting when no future scenes remain.

### M4.8 - Answer-only interruption path

Status: `DONE`

Goal:
- Handle current-story questions without unnecessary story regeneration.

Concrete tasks:
- Implement an answer-only path that uses current story/scene context without mutating future scenes.
- Keep answer-only responses short, live, and clearly separate from narration progress.
- Return to narration mode cleanly when the answer path completes.

Required tests:
- coordinator tests proving answer-only handling does not trigger revision or story replacement
- tests for resume to the same scene boundary after answer-only interaction

Dependencies:
- M4.7b

Definition of done:
- Question-answer interruptions are handled without regeneration and without corrupting narration state.

Completion notes:
- `PracticeSessionViewModel` now answers `answer_only` interruption routes from local `StoryAnswerContext` instead of falling through to revision.
- Answer-only responses are delivered over the live interaction transport, remain non-mutating, and resume narration from the same scene boundary after the short response completes.
- Targeted coordinator regressions now verify no revision request is sent for current-story questions, the generated story stays unchanged, and narration replays the current scene boundary after the answer.

### M4.9 - Revise-future-scenes path

Status: `DONE`

Goal:
- Preserve the current future-scene revision behavior under the hybrid runtime.

Concrete tasks:
- Route revise-future-scenes interruptions through the existing revision boundary contract.
- Keep completed scenes fixed and revise only the remaining scenes.
- Preserve continuity and repeat-mode invariants while the narration transport is no longer realtime-led.

Required tests:
- coordinator tests for revise-future-scenes ownership and resume index
- backend tests if revision request or response contracts change

Dependencies:
- M4.7b

Definition of done:
- Hybrid revision still changes only future scenes and leaves completed scenes untouched.

Completion notes:
- `PracticeSessionViewModel` now submits live revise requests through `StoryRevisionBoundary.makeRequest(userUpdate:)` instead of the pre-hybrid current-scene request shape.
- Live revision now preserves the current narration boundary scene on merge, replaces only future scenes, and expects `revised_from_scene_index` to point at the first mutable future scene.
- Targeted coordinator regressions now verify preserved-scene request ownership, future-scene-only mutation, and resume from the unchanged current boundary scene.

### M4.10 - Narration resume from correct scene boundary

Status: `DONE`

Goal:
- Resume narration from the correct post-interaction boundary after answer-only or revision flows.

Concrete tasks:
- Implement distinct resume rules for answer-only, repeat/clarify, and revise-future-scenes outcomes.
- Keep resume behavior keyed to authoritative scene state rather than transport assumptions.
- Ensure completion and save still run exactly once after resumed narration.

Required tests:
- coordinator tests for resume after each interruption outcome
- regression tests for duplicate completion/save protection after resume

Dependencies:
- M4.8
- M4.9

Definition of done:
- Every interruption outcome resumes narration from the correct scene boundary without duplicate side effects.

Completion notes:
- `PracticeSessionViewModel` now routes post-interruption narration through a typed `NarrationResumeDecision` instead of separate answer-only and revision-specific resume branches.
- Answer-only and repeat-or-clarify now both replay the current scene boundary explicitly, while revise-future-scenes resumes through `replayCurrentSceneWithRevisedFuture(sceneIndex:, revisedFutureStartIndex:)`.
- Repeat-or-clarify now has a concrete runtime path that replays the active scene boundary without sending a revise request, and resumed narration keeps the existing one-time completion/save protection intact.

### M4.11 - Scene audio preload and caching strategy

Status: `DONE`

Goal:
- Reduce narration stalls without weakening authoritative scene ownership.

Concrete tasks:
- Implement scene-ahead TTS preload and caching for upcoming scenes under coordinator control.
- Bound cache lifetime and invalidation rules so revised future scenes cannot reuse stale audio.
- Define fallback behavior when preload misses or TTS generation lags.

Required tests:
- narration transport tests for cache hit, cache miss, and invalidation on revision
- coordinator tests ensuring revised scenes invalidate stale preloaded audio

Dependencies:
- M4.4
- M4.9

Definition of done:
- Upcoming scene audio can be preloaded and invalidated safely when story state changes.

Completion notes:
- `PracticeSessionViewModel` now manages one-scene-ahead narration preparation under coordinator control and starts each scene through a typed `PreparedNarrationScene`.
- The narration transport now supports prepare, play, and invalidate operations so preloaded scene payloads stay bounded and transport-local instead of leaking into story-state authority.
- Revision now invalidates stale future-scene prepared payloads while keeping the current boundary scene warm, and the targeted regression slice covers cache hit, cache miss, and revision invalidation behavior.

### M4.12 - Cost telemetry by runtime stage

Status: `DONE`

Goal:
- Make runtime cost visible by interaction, narration, and revision stage.

Concrete tasks:
- Add telemetry boundaries for discovery, answer-only interaction, revise-future-scenes, TTS generation, and continuity retrieval.
- Keep telemetry redacted and aligned with privacy rules.
- Expose enough structured data to compare routing cost and latency by runtime stage.

Required tests:
- client or backend telemetry tests for runtime-stage attribution
- regression tests proving no transcript or raw audio content is logged

Dependencies:
- M4.4
- M4.7

Definition of done:
- Runtime-stage cost and latency can be measured without leaking sensitive content.

Completion notes:
- `APIClientTraceEvent` now carries runtime-stage attribution, redacted cost-driver classification, and per-request duration for discovery, story generation, revise-future-scenes, and continuity-retrieval API work.
- `PracticeSessionViewModel` now records redacted runtime telemetry for local hybrid stages as well, including answer-only interaction playback, one-scene-ahead TTS preparation, and combined continuity retrieval timing.
- Backend analytics now meter OpenAI usage by runtime stage in addition to operation, so stage-level usage snapshots can be compared without logging transcript or raw audio content.

### M4.13 - Hybrid runtime tests and validation command

Status: `DONE`

Goal:
- Establish the repeatable validation layer for the hybrid runtime.

Concrete tasks:
- Add targeted hybrid coordinator coverage for narration transport, interruption routing, answer-only handling, revision, and resume.
- Add backend tests for any new interaction or routing contracts.
- Document the stable targeted validation command future hybrid milestones should run.

Required tests:
- hybrid coordinator test slice
- hybrid transport test slice
- backend contract tests for any hybrid APIs added

Dependencies:
- M4.8
- M4.9
- M4.10
- M4.11
- M4.12

Definition of done:
- The hybrid runtime has a stable, repeatable validation surface for future milestones.

Completion notes:
- Added `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` as the stable targeted hybrid validation command for future milestones.
- Added `/Users/rory/Documents/StoryTime/docs/verification/hybrid-runtime-validation.md` to document the command, its coverage, and when to use it instead of the full suite.
- Refreshed the lifecycle trace regression in `PracticeSessionViewModelTests` so the stable validation slice matches current future-scene revision semantics and hybrid narration timing.
- Verified the command end to end with:
  - `npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts src/tests/types.test.ts`, which passed `39` backend tests.
  - the targeted iOS `xcodebuild test` slice in the new script, which passed `27` tests.

### M3.10.2 - Failure injection acceptance coverage

Status: `DONE`

Goal:
- Extend the acceptance harness to cover the highest-risk failure paths.

Concrete tasks:
- Add failure injections for startup failure, disconnect during session, revision overlap, and duplicate completion/save attempts.
- Verify the acceptance harness asserts safe recoverable or terminal states instead of only targeted unit regressions.
- Keep failure scenarios fast enough for regular milestone validation.

Required tests:
- startup failure acceptance suite
- revision overlap acceptance suite
- duplicate completion acceptance suite

Dependencies:
- M3.10.1

Definition of done:
- The acceptance harness covers the main failure modes that have historically caused drift or duplicate side effects.

Completion notes:
- Extended the targeted hybrid validation slice to cover startup failure, disconnect during live narration, revision-overlap queuing, and duplicate completion/save protection.
- Added `testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory` to pin terminal behavior and no-save guarantees after a mid-narration disconnect.
- Refreshed the overlapping-revision acceptance test to use the active interruption router and future-scene revision boundary instead of the legacy implicit-revision path.
- Updated `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` and `/Users/rory/Documents/StoryTime/docs/verification/hybrid-runtime-validation.md` so the stable validation layer now includes the failure-injection acceptance slice.
- Verified:
  - backend hybrid contract slice: `39` tests passed
  - targeted iOS hybrid + failure-injection slice: `31` tests passed
  - note: an earlier end-to-end script rerun was externally terminated during `xcodebuild`; the identical iOS command rerun passed cleanly.

### M3.10.3 - Child isolation acceptance coverage and validation command

Status: `DONE`

Goal:
- Finish the acceptance layer with multi-child isolation coverage and a stable validation entry point.

Concrete tasks:
- Add a multi-child acceptance scenario that proves saved-story visibility and persistence remain scoped during the critical loop.
- Document and pin the targeted acceptance test command future milestones should run.
- Keep the acceptance layer small enough to stay in regular milestone validation.

Required tests:
- child-isolation acceptance suite
- targeted acceptance harness command regression

Dependencies:
- M3.10.1
- M3.10.2

Definition of done:
- The critical-path acceptance harness covers happy path, failure injection, child isolation, and has a stable validation command for future runs.

Notes:
- This milestone should build on the same hybrid runtime validation layer established in `M4.13` and expanded in `M3.10.2`.
- Completed 2026-03-07 with a seeded multi-child UI acceptance slice added to the stable validation command.
- Validation command result:
  - backend hybrid contract slice: `39` tests passed
  - targeted iOS hybrid + failure-injection slice: `31` tests passed
  - seeded child-isolation UI slice: `2` tests passed
- The first UI-targeted command wiring used incomplete `-only-testing` identifiers and executed `0` UI tests; the script now targets the `StoryTimeUITests/StoryTimeUITests/...` bundle path explicitly.

### M5.1 - Coordinator revision-index logging hardening

Status: `DONE`

Goal:
- Remove the remaining revision-index logging drift from the stable hybrid validation slice.

Concrete tasks:
- Reproduce the passing `Revision index mismatch. expected=2 actual=1` coordinator log inside the current hybrid acceptance slice.
- Align revision resume logging with the active future-scene revision boundary so passing runs do not emit misleading mismatch diagnostics.
- Keep the change scoped to logging and coordinator diagnostics unless a real state bug is uncovered.

Required tests:
- targeted hybrid validation command regression
- coordinator lifecycle trace regression

Dependencies:
- M3.10.3

Definition of done:
- The stable hybrid validation command stays green and no longer emits the known revision-index mismatch log during passing runs.

Notes:
- This is intentionally a narrow post-acceptance hardening milestone, not a broader runtime redesign.
- Completed 2026-03-07 by correcting the stale lifecycle regression fixture to use the active future-scene revision boundary.
- Added an explicit lifecycle assertion that no `Revision index mismatch` message is recorded in `invalidTransitionMessages`.
- Validation results:
  - targeted lifecycle trace regression: `1` test passed
  - stable hybrid validation command: backend `39` tests passed, targeted iOS hybrid slice `31` tests passed, child-isolation UI slice `2` tests passed
- The first attempt to run the isolated lifecycle regression in parallel with the full validation command failed with an Xcode `build.db` lock; the required runs were rerun sequentially and passed cleanly.

## Phase 5 - Hybrid Runtime Verification And Measurement

### M6.1 - Hybrid runtime end-to-end verification report

Status: `DONE`

Goal:
- Produce a repo-grounded verification report for the active hybrid runtime before more implementation or UX work continues.

Concrete tasks:
- Inspect the active hybrid runtime surfaces in `PracticeSessionViewModel.swift`, `StoryDomain.swift`, the narration transport layer, and the current docs under `docs/verification/`.
- Run the stable hybrid validation command and any narrow supporting test reruns needed to support the report.
- Write or update a report in `docs/verification/` that labels each major hybrid-runtime behavior as `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, or `UNVERIFIED`.
- Cover at minimum startup, discovery-to-generation handoff, long-form narration, interruption routing, answer-only handling, revise-future-scenes, narration resume, completion/save, child isolation, and privacy/telemetry touchpoints.
- Record the specific partially verified and unverified areas that should feed `M6.2`, `M6.3`, and `M6.4`.

Required tests:
- `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`
- targeted iOS or backend reruns only if the report relies on narrower evidence than the stable slice

Dependencies:
- M5.1

Definition of done:
- The repo contains a current end-to-end hybrid-runtime verification report.
- Every material runtime behavior is tagged with one of the required evidence labels.
- The next verification, telemetry, and acceptance gaps are explicit enough to execute without rediscovery.

Notes:
- This is a verification/reporting milestone, not a runtime redesign milestone.

Completion notes:
- Added `docs/verification/hybrid-runtime-end-to-end-report.md` as the first explicit post-migration verification report for the active hybrid runtime.
- The report labels each covered hybrid behavior as `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, or `UNVERIFIED`, and it records the follow-on gaps that feed `M6.2`, `M6.3`, and `M6.4`.
- Verified with `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed:
  - backend slice: `39` tests
  - iOS unit slice: `31` tests
  - iOS UI child-isolation slice: `2` tests

### M6.2 - Realtime interaction-path determinism audit

Status: `DONE`

Goal:
- Verify that the live interaction path remains deterministic inside the hybrid runtime, especially at TTS-to-realtime boundaries.

Concrete tasks:
- Audit the interaction startup, interruption handoff, answer-only response path, revise-future-scenes path, and disconnect behavior across `PracticeSessionViewModel`, `RealtimeVoiceClient`, `RealtimeVoiceBridgeView`, `APIClient`, and backend realtime routes/services.
- Use the `M6.1` report to focus on the interaction-path areas still marked `PARTIALLY VERIFIED` or `UNVERIFIED`.
- Run targeted coordinator, realtime client, API client, and backend realtime tests; add one narrow regression if the audit finds a concrete determinism defect in scope.
- Write or update a deterministic interaction-path report in `docs/verification/` with the same evidence-label taxonomy and explicit remaining harness gaps.
- Make the intentional no-reconnect or terminal-disconnect semantics explicit if they remain the chosen product behavior.

Required tests:
- targeted `PracticeSessionViewModelTests`
- `RealtimeVoiceClientTests`
- `APIClientTests`
- backend realtime route, service, and type tests
- `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` if interaction-path behavior changes in scope

Dependencies:
- M6.1

Definition of done:
- The repo contains a current realtime interaction-path determinism audit for the hybrid runtime.
- Handoff, ordering, and terminal interaction semantics are evidenced explicitly.
- Any small determinism bug found in scope is pinned by regression.

Completion notes:
- Refreshed `docs/verification/realtime-voice-determinism-report.md` so it matches the active hybrid runtime and explicitly covers startup, TTS-to-realtime handoff, answer-only, repeat-or-clarify, deferred transcript rejection, backend realtime contract handling, and intentional no-reconnect semantics.
- Verified the backend realtime route/service/type slice with `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/model-services.test.ts src/tests/types.test.ts`, which passed `34` tests.
- Verified the scoped iOS interaction-path slice with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/RealtimeVoiceClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionWithRealAPIClientExecutesFullStartupContractSequence -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionUsesResolvedBackendRegionDuringRealtimeStartup -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartSessionRefreshesStaleSessionTokenBeforeRealtimeStartupFails -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testAnswerOnlyResumeCompletesAndSavesOnce -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationHandsOffToInteractionWithoutReconnect -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringGenerationIsRejectedAfterNarrationBegins -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testLateTranscriptAfterFailureDoesNotOverwriteLatestTranscript -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionDuringGenerationIsRejectedDeterministically`, which passed `43` tests.
- No new in-scope determinism defect was reproduced, so this milestone stayed verification-only and did not widen into reconnect or bridge-harness implementation work.

### M6.3 - Stage-level cost and latency telemetry verification

Status: `DONE`

Goal:
- Make the active hybrid runtime measurable by stage without widening into dashboards or product-surface work.

Concrete tasks:
- Audit current client and backend telemetry coverage for `interaction`, `generation`, `narration`, and `revision`, and document how supporting stages such as discovery or continuity retrieval map alongside them.
- Tighten stage naming or fill the smallest remaining instrumentation gaps so cost and latency can be compared across the required runtime stages with redacted data only.
- Add or update docs that explain where the stage metrics come from, what is measured on-device versus on-backend, and which stage readings are still indirect or estimated.
- Add or update tests for stage attribution, redaction, and analytics meter output.
- Record any remaining commercialization, threshold, or export questions in `PLANS.md` instead of building dashboards or alerting in this milestone.

Required tests:
- `APIClientTests`
- `PracticeSessionViewModelTests`
- backend analytics/request tests, including `backend/src/tests/request-retry-rate.test.ts`
- any touched backend service tests for runtime-stage attribution
- `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` if telemetry changes touch the active hybrid validation slice

Dependencies:
- M6.1
- M6.2

Definition of done:
- Stage-based telemetry is explicit and consistent for `interaction`, `generation`, `narration`, and `revision`.
- The repo documents what can be measured today and what remains indirect.
- Telemetry tests prove attribution stays redacted and stage-correct.

Notes:
- Do not add dashboards, alerts, or product analytics expansion here. Keep the milestone scoped to verification-grade telemetry.

Completion notes:
- Added `docs/verification/runtime-stage-telemetry-verification.md` as the current telemetry audit for the active hybrid runtime, using the required evidence labels and distinguishing the four primary stage groups from supporting stages.
- `APIClientTraceEvent` and coordinator runtime telemetry now expose grouped stage attribution for `interaction`, `generation`, `narration`, and `revision`, while `continuity_retrieval` remains a deliberate supporting stage with no forced primary grouping.
- Backend analytics now emits grouped stage counters and log fields in addition to detailed runtime stages, and realtime provider usage is now explicitly attributed to `interaction`.
- Verified the targeted backend telemetry slice with `cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/request-retry-rate.test.ts src/tests/model-services.test.ts`, which passed `13` tests.
- Verified the targeted iOS telemetry slice with `xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation -only-testing:StoryTimeTests/APIClientTests/testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testExtendModeUsesPreviousRecapAndContinuityEmbeddings`, which passed `6` tests.
- Re-ran `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed backend `39`, iOS unit `31`, and iOS UI `2` tests.

### M6.4 - Hybrid runtime acceptance regression pack

Status: `DONE`

Goal:
- Consolidate the active hybrid runtime into an explicit acceptance regression pack that future runtime work must keep green.

Concrete tasks:
- Review the gaps and follow-ups from `M6.1`, `M6.2`, and `M6.3`, then add the smallest missing high-signal regression scenarios to the stable validation command or its adjacent targeted commands.
- Ensure the acceptance pack covers, at minimum, happy path, startup failure, disconnect during narration, interruption answer-only handling, revise-future-scenes, pause/resume, child isolation, and any stable telemetry assertions added in `M6.3`.
- Update `docs/verification/hybrid-runtime-validation.md` so it describes the acceptance pack scope, the exact commands to run, and what remains intentionally outside the pack.
- Keep the acceptance pack small enough for routine milestone validation; do not widen it into a full-suite UX or productization test run.

Required tests:
- `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`
- any new targeted acceptance, transport, or UI slices added in scope

Dependencies:
- M6.1
- M6.2
- M6.3

Definition of done:
- The repo has an explicit hybrid-runtime acceptance regression pack and a documented command path for running it.
- The pack covers the required hybrid-runtime scenarios and names the excluded cases explicitly.
- Future hybrid milestones can point to this pack as the default validation gate instead of rebuilding their own ad hoc slice.

Completion notes:
- Updated `docs/verification/hybrid-runtime-validation.md` so it now defines the explicit default acceptance pack for the active hybrid runtime, including covered scenarios, excluded cases, and why the command is the default gate.
- The stable validation command now includes an explicit happy-path completion regression and the grouped runtime-stage telemetry assertion added during `M6.3`.
- To stabilize the gate itself, `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh` now runs backend, iOS unit, and iOS UI isolation slices as separate steps instead of mixing unit and UI execution in one `xcodebuild` run.
- Verified `/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh`, which passed backend `39`, iOS unit `33`, and iOS UI `2` tests.

## Phase 6 - UX And Productization Readiness

### M7.1 - UX audit for parent/child storytelling flow

Status: `DONE`

Goal:
- Audit the current parent and child storytelling flow only after the verification and measurement milestone group is materially complete.

Concrete tasks:
- Review the active `HomeView` -> `NewStoryJourneyView` -> `VoiceSessionView` -> parent controls flow using the now-verified hybrid runtime assumptions.
- Audit parent trust/privacy surfaces, child setup flow, launch clarity, interruption feel, and saved-story continuation cues without widening into redesign or feature implementation.
- Produce a prioritized UX audit document that distinguishes parent trust-boundary issues from child storytelling-loop issues.
- Record recommended follow-up milestones in repo terms, but do not start redesign or implementation work in this milestone.

Required tests:
- none required for the audit itself
- if a tiny supporting doc or copy correction lands during the audit, run only the directly affected UI or unit tests before marking the milestone done

Dependencies:
- M6.1
- M6.2
- M6.3
- M6.4

Definition of done:
- The repo contains a current UX audit grounded in the verified hybrid runtime.
- Parent-flow and child-flow issues are prioritized separately.
- The next UX/productization milestone set can start without reopening hybrid-runtime reliability questions.

Notes:
- Do not start this milestone until the `M6` verification and measurement group is materially complete unless `PLANS.md` records an explicit reprioritization.

Completion notes:
- Added `docs/verification/parent-child-storytelling-ux-audit.md` as the repo-grounded audit for the active `HomeView` -> `NewStoryJourneyView` -> `VoiceSessionView` -> saved-story/parent-controls flow.
- The audit separates parent trust-boundary issues from child storytelling-loop issues and uses the required evidence labels `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, and `UNVERIFIED`.
- The highest-priority findings are trust-boundary mismatches: saved-story deletion remains reachable outside the parent gate, and parent history copy is scoped to the active child even though the underlying clear-history action is global.
- Verified the audit against targeted store and UI evidence: `StoryLibraryStoreTests` passed `3` tests and `StoryTimeUITests` passed `5` tests.

### M7.2 - Parent trust-boundary hardening for saved-story management

Status: `DONE`

Goal:
- Align saved-story management with the repo’s parent trust boundary before broader UX polish starts.

Concrete tasks:
- Audit every saved-story delete or destructive-history affordance reachable from child-facing surfaces.
- Decide whether destructive history actions belong behind the existing parent gate, inside the parent hub only, or behind a narrower local confirmation pattern.
- Align the “Delete All Saved Story History” copy and behavior scope so active-child wording does not mask a global delete action.
- Keep child-facing replay and continue entry paths intact while removing or gating trust-sensitive mutations.

Required tests:
- `StoryTimeUITests` coverage for any gated or relocated saved-story delete flows
- `StoryLibraryStoreTests` if delete-history behavior scope changes
- targeted UI tests for the parent gate if routing changes

Dependencies:
- M7.1

Definition of done:
- Child-facing surfaces no longer expose trust-sensitive saved-story mutations ambiguously.
- Delete-history scope is explicit and aligned between UI copy and underlying behavior.
- Parent trust-boundary behavior is regression-covered.

Completion notes:
- `StorySeriesDetailView` now keeps replay and continue actions on the child-facing saved-story surface while removing the delete affordance from that surface entirely.
- `ParentTrustCenterView` now owns single-series deletion plus the existing device-wide clear-history action, and the parent copy now explicitly states that delete-all applies across all children on this device.
- Verified by targeted persistence regressions in `StoryLibraryStoreTests` (`3` passed) and the focused parent-controls single-series delete UI regression in `StoryTimeUITests` (`1` passed). Broader multi-test UI reruns still showed intermittent simulator-runner bootstrap failures unrelated to the feature behavior.

### M7.3 - Launch-plan clarity for continuity choices

Status: `DONE`

Goal:
- Make the pre-session setup explain the live storytelling loop and continuity choices more clearly without changing the hybrid runtime behavior.

Concrete tasks:
- Clarify how `Use past story`, `Use old characters`, and extend-mode selection interact in `NewStoryJourneyView`.
- Strengthen the launch summary so it explains what the child should expect from the live follow-up phase before narration begins.
- Keep privacy and child-scoping copy accurate while improving continuity-choice legibility.

Required tests:
- directly affected `StoryTimeUITests`
- targeted unit tests only if launch-plan summary or selection state logic changes

Dependencies:
- M7.1

Definition of done:
- The launch screen explains the continuity choices in repo-accurate terms.
- The live interaction loop is clearer before the child starts the session.
- Continuation-choice behavior remains scoped and regression-covered.

Completion notes:
- `NewStoryJourneyView` now explains the live follow-up loop before narration, clarifies fresh-story versus continue-story behavior, and keeps character reuse scoped to a selected saved series with reusable hints.
- The launch preview now separates live follow-up, story path, and character plan into explicit lines instead of relying only on one compressed preview sentence.
- Verified by targeted `StoryTimeUITests` coverage for fresh-start explanation, continue-story explanation, and the existing happy-path launch flow (`3` passed).

### M7.4 - Live session interaction-state clarity

Status: `DONE`

Goal:
- Make the hybrid live session easier for a child to understand without changing its deterministic runtime behavior.

Concrete tasks:
- Audit and tighten the visible cues for listening, narrating, answering, revising, paused, and failed states in `VoiceSessionView`.
- Make interruption and resume cues easier to follow without reworking coordinator logic or transport behavior.
- Keep privacy and live-processing copy truthful while improving the child-facing session affordances.

Required tests:
- directly affected `StoryTimeUITests`
- targeted `PracticeSessionViewModelTests` only if status/cue behavior changes at the coordinator boundary

Dependencies:
- M7.1

Definition of done:
- The child-facing session UI distinguishes the main hybrid states clearly.
- Interruption and recovery cues are more legible without weakening runtime determinism.
- The updated cues are regression-covered where practical.

Completion notes:
- `VoiceSessionView` now shows a dedicated session cue card plus a matching action hint that interpret the existing coordinator state without changing runtime behavior.
- `PracticeSessionViewModel` now exposes a derived `sessionCue` for listening, question time, narration, answering, revising, paused, completed, and failed states, keeping the UI tied to deterministic coordinator state instead of new flags.
- Verified by targeted `PracticeSessionViewModelTests` (`5` passed across the session-cue and startup-failure slices) and targeted `StoryTimeUITests` for listening and storytelling cue visibility (`2` passed).

### M7.5 - Saved-story detail information hierarchy pass

Status: `DONE`

Goal:
- Separate continuation cues from history-management concerns on the saved-story detail surface.

Concrete tasks:
- Rework `StorySeriesDetailView` so replay and new-episode actions are clear before continuity metadata or destructive controls.
- Make continuity information feel intentional and understandable instead of internal or mixed with trust-sensitive actions.
- Keep saved-story continuation behavior intact and scoped to the correct child.

Required tests:
- directly affected `StoryTimeUITests`
- `StoryLibraryStoreTests` only if story-history behavior changes

Dependencies:
- M7.1
- M7.2

Definition of done:
- Saved-story detail has a clearer action hierarchy.
- Continuation actions and history-management concerns are no longer conflated.
- The resulting surface is regression-covered where practical.

Completion notes:
- `StorySeriesDetailView` now leads with a dedicated continuation card for replay and new-episode intent, reframes continuity as story memory for the next episode, and keeps parent-only history management in a separate lower-priority section.
- Verified by targeted `StoryTimeUITests` coverage for the saved-story detail hierarchy (`1` passed).
- The current `SPRINT.md` queue has no remaining incomplete milestone after `M7.5`; the next run should be a planning pass to define the next milestone group before more implementation work starts.

## Phase 7 - Productization, Monetization, And Polished UX

### M8.1 - Productization planning and user-journey alignment

Status: `DONE`

Goal:
- Define the repo-grounded StoryTime product journey so later monetization and polish work stays coherent across parent and child flows.

Concrete tasks:
- Inspect the active parent and child journey across `HomeView`, `ParentAccessGateView`, `ParentTrustCenterView`, `NewStoryJourneyView`, `VoiceSessionView`, and `StorySeriesDetailView`.
- Map the key user journeys: first-time parent setup, returning child story start, saved-series continuation, session completion, and parent-management return path.
- Record the current value moments, trust moments, friction points, and candidate upgrade moments without starting implementation work.
- Capture technical constraints that later productization work must respect, especially the verified hybrid runtime split and local-only saved history.

Required tests or verification method:
- repo inspection across the active surfaces, relevant verification docs, and existing UI/unit evidence
- planning artifact in `docs/` or equivalent repo documentation with explicit source references

Dependencies:
- M7.5

Definition of done:
- The active StoryTime user journeys are documented in repo terms.
- The next productization and monetization milestones have a shared product-flow baseline.
- Future runs can implement later M8 milestones without re-discovering the current product shape.

Completion notes:
- Added `docs/productization-user-journey-alignment.md` to map the current parent and child journeys, value moments, trust moments, friction points, and candidate upgrade moments in repo terms.
- The artifact stays grounded in the verified hybrid runtime, current privacy/trust surfaces, and existing automated evidence instead of speculative redesign.
- No new tests were run because `M8.1` is a planning milestone; verification came from existing UI/unit/verification artifacts plus direct code inspection.

### M8.2 - Monetization model and entitlement architecture

Status: `DONE`

Goal:
- Define the first monetization model and entitlement architecture that fit StoryTime's current runtime economics and technical boundaries.

Concrete tasks:
- Inspect runtime-stage telemetry and cost-driver evidence in the client, backend, and `docs/verification/runtime-stage-telemetry-verification.md`.
- Propose repo-grounded free versus paid boundaries, including candidate limits around story starts, session minutes, saved-series continuation, child profiles, or retention features.
- Define the entitlement source of truth and the client/backend touchpoints needed for later implementation.
- Record what is still unknown for pricing confidence and which telemetry gaps matter before final package decisions.

Required tests or verification method:
- code and doc inspection of telemetry, request tracing, and active app surfaces
- architecture/planning document that references the inspected telemetry and runtime-cost evidence

Dependencies:
- M8.1
- M6.3

Definition of done:
- The repo has an explicit monetization and entitlement architecture direction.
- Package-boundary candidates are grounded in current runtime-stage telemetry rather than guesswork.
- Follow-on paywall and product polish milestones have a clear entitlement baseline.

Completion notes:
- Added `docs/monetization-entitlement-architecture.md` to define the first repo-fit monetization direction, including `Starter` versus `Plus` package-boundary candidates, launch-count and continuation-count as the first cap levers, and the main pricing-confidence gaps that still remain.
- Chose a split entitlement model: StoreKit 2 on device as purchase truth, plus a backend-issued entitlement snapshot and preflight checks as the enforcement layer for cost-bearing runtime work.
- No new tests were run because `M8.2` is an architecture and planning milestone; verification came from direct inspection of the active telemetry code, product surfaces, `AuditUpdated.md`, and existing verification artifacts.

### M8.3 - Onboarding and first-run flow audit and direction

Status: `DONE`

Goal:
- Define how first-time parents and first-time children should enter StoryTime before any onboarding implementation begins.

Concrete tasks:
- Audit the current first-run experience when the app opens into `HomeView` without saved stories or prior setup context.
- Review parent gate, parent controls, trust copy, child profile setup, and new-story launch to identify missing onboarding structure.
- Define the intended first-run sequence, including value framing, trust framing, child setup, and the first story start.
- Keep the direction grounded in current runtime behavior and privacy truthfulness.

Required tests or verification method:
- repo inspection of current first-run surfaces plus existing UI and privacy-verification evidence
- audit/design-direction document with explicit notes about what is current behavior versus proposed product flow

Dependencies:
- M8.1

Definition of done:
- The repo has a first-run and onboarding direction that future implementation work can follow.
- Trust, safety, and value framing are defined for the start of the product journey.
- The audit distinguishes current behavior from later design intent clearly.

Completion notes:
- Added `docs/onboarding-first-run-audit.md` to audit the current implicit first-run path, including the immediate boot into `HomeView`, the fallback `Story Explorer` profile, the parent gate, and the current trust-copy distribution across the app.
- The artifact defines a parent-led onboarding direction with explicit stages for welcome/value framing, trust and privacy setup, child setup, first-session expectation-setting, and the handoff into the first story start.
- No new tests were run because `M8.3` is an audit and direction milestone; verification came from direct inspection of the active surfaces, `AuditUpdated.md`, and the existing UI/store/privacy evidence already present in the repo.

### M8.4 - Paywall and upgrade entry-point strategy

Status: `DONE`

Goal:
- Decide where and how upgrades should appear in StoryTime without breaking child flow or parent trust.

Concrete tasks:
- Use the M8.1 journey map, M8.2 entitlement model, and M8.3 onboarding direction to inventory candidate upgrade moments.
- Decide which upgrade prompts must remain parent-managed versus child-visible.
- Define upgrade-entry rules for home, new-story setup, completion/replay loops, and parent controls.
- Record blocking rules, copy principles, and UX constraints for future paywall implementation.

Required tests or verification method:
- code and flow inspection only in this milestone
- strategy document covering entry points, ownership, gating rules, and excluded surfaces

Dependencies:
- M8.1
- M8.2
- M8.3

Definition of done:
- Upgrade entry points are explicit and prioritized.
- Parent-managed versus child-visible upgrade behavior is defined.
- Later implementation work can add paywall surfaces without reopening the product-flow strategy.

Completion notes:
- Added `docs/paywall-upgrade-entry-strategy.md` to define the approved upgrade surfaces, including `NewStoryJourneyView` as the primary preflight hard gate, `StorySeriesDetailView` as the contextual continuation gate, `ParentTrustCenterView` as the durable parent-managed upgrade surface, and `HomeView` as a soft-awareness surface.
- The strategy explicitly keeps `VoiceSessionView`, live interruption paths, and already-saved story replay free of blocking upgrade UI so the child runtime remains clean.
- No new tests were run because `M8.4` is a strategy milestone; verification came from direct inspection of the active surfaces plus the existing journey, monetization, onboarding, and UI evidence already present in the repo.

### M8.5 - Home and Library product polish pass

Status: `DONE`

Goal:
- Refine the home and saved-library surfaces so StoryTime feels more productized without weakening child scoping, trust, or parent controls.

Concrete tasks:
- Apply the approved productization direction to `HomeView` and the saved-story library surface.
- Improve value framing, active-child clarity, saved-story affordances, and any approved upgrade entry points on the home screen.
- Preserve parent gate behavior and child-profile scoping while improving hierarchy and polish.

Required tests or verification method:
- directly affected `StoryTimeUITests`
- `StoryLibraryStoreTests` only if scoping, retention, or saved-story behavior changes

Dependencies:
- M8.1
- M8.4

Definition of done:
- `HomeView` and the saved-library surface reflect the approved product direction.
- Any new home-surface upgrade or trust affordance is regression-covered.
- Child scoping and parent-boundary behavior remain intact.

Completion notes:
- `HomeView` now frames the quick-start loop more clearly with explicit live-question and scene-by-scene narration copy, while keeping the primary `Start New Story` path intact.
- The trust card now includes a direct parent-controls entry that still routes through the existing lightweight parent gate instead of inventing a new trust or upgrade flow.
- The saved-library section now explains replay and continuation value on home, and each saved-story card explicitly signals that the child can repeat or continue from the library surface.
- Verified by targeted `StoryTimeUITests` coverage for the new home framing and saved-story affordances, plus regressions for the existing quick-start path, parent gate, and child-scoped saved-story behavior.

### M8.6 - New Story setup polish pass

Status: `DONE`

Goal:
- Refine the pre-session setup experience so it aligns with onboarding, monetization boundaries, and the verified hybrid loop.

Concrete tasks:
- Apply the approved product direction to `NewStoryJourneyView`.
- Improve hierarchy around child choice, continuity setup, package limits or entitlement messaging, and session expectations.
- Preserve privacy truthfulness and child scoping while adding any approved upgrade or cap messaging.

Required tests or verification method:
- directly affected `StoryTimeUITests`
- targeted unit tests only if launch-plan or selection-state logic changes

Dependencies:
- M8.1
- M8.3
- M8.4

Definition of done:
- The setup flow is more productized and coherent.
- Any package-boundary messaging or upgrade hook is regression-covered.
- The launch flow still reflects the current hybrid runtime accurately.

Completion notes:
- `NewStoryJourneyView` now presents setup as a clearer preflight step before the live questions begin, with explicit parent handoff guidance instead of reading like a loose configuration form.
- The setup surface now separates story-path choice, length-and-pacing guidance, and what-happens-next expectations so the hybrid runtime is easier to understand before session start.
- The milestone stayed architecture-truthful: no fake entitlement state, no StoreKit UI, and no blocking upgrade logic was added before real preflight enforcement exists.
- Verified by targeted `StoryTimeUITests` coverage for the new preflight framing and expectation copy, plus existing regressions for fresh-start launch, continue-mode guidance, child-scoped saved-series selection, and the quick-start voice journey.

### M8.7 - End-of-story and repeat-use loop design pass

Status: `DONE`

Goal:
- Define the post-story loop that should drive replay, continuation, return-to-library behavior, and future repeat use.

Concrete tasks:
- Inspect the current completion, save, replay, continue, and series-detail return paths in the coordinator and UI.
- Define the intended end-of-story product flow for child and parent perspectives, including repeat, continue, saved-story return, and any approved upgrade moments.
- Record how completion should connect back to the home/library surface and saved-series continuation.
- Keep the work design-direction only unless a tiny documentation correction is required.

Required tests or verification method:
- repo inspection of completion/save paths, saved-story surfaces, and current verification evidence
- design-direction document with explicit current-state references

Dependencies:
- M8.1
- M8.2

Definition of done:
- The post-story loop is defined in repo terms and ready for later implementation.
- Replay, continuation, and return-surface roles are explicit.
- Later polish work can follow one documented loop instead of ad hoc screen decisions.

Completion notes:
- Captured in `docs/end-of-story-repeat-use-loop.md`.
- The doc pins the current authoritative completion/save behavior in `PracticeSessionViewModel`, the absence of an explicit post-story action surface in `VoiceSessionView`, and the existing replay/continue surfaces in `HomeView` and `StorySeriesDetailView`.
- The approved post-story action order is now explicit: replay the finished story, start a new episode from the saved series, or return to saved stories and home.

### M8.8 - Parent trust and privacy communication refinement

Status: `DONE`

Goal:
- Refine trust, privacy, and parent-facing communication so it supports productization and monetization without overstating the app's protections or data behavior.

Concrete tasks:
- Apply the approved trust and product-flow direction to parent-facing copy and hierarchy across `HomeView`, `ParentAccessGateView`, `ParentTrustCenterView`, `NewStoryJourneyView`, and `VoiceSessionView`.
- Keep privacy statements exact, especially around raw audio, live processing, retention, deletion, and local history.
- Integrate any approved parent-managed upgrade communication without weakening the trust boundary.

Required tests or verification method:
- directly affected `StoryTimeUITests`
- targeted unit tests if privacy-summary strings or trust-state helpers change
- update related docs if privacy or trust framing changes materially

Dependencies:
- M8.3
- M8.4
- M8.5
- M8.6

Definition of done:
- Parent trust and privacy communication is cohesive across the product.
- Upgrade language, if added, stays parent-managed and repo-accurate.
- The refined communication is regression-covered where practical.

Completion notes:
- `HomeView`, the lightweight parent gate, `ParentTrustCenterView`, `NewStoryJourneyView`, and `VoiceSessionView` now use tighter trust and privacy copy that stays accurate about raw audio, live processing, on-device history, and the limited role of the `PARENT` check.
- Parent-facing communication now separates what stays on device from what goes live during a session, and the setup plus live-session surfaces now say more clearly that parent controls stay outside the live child story.
- Verified by targeted `StoryTimeUITests` coverage for the gate, home, setup footer, and privacy-copy path (`5` passed) plus targeted `PracticeSessionViewModelTests` coverage for both privacy-summary branches (`2` passed across two focused runs).
- The current sprint queue is complete after `M8.8`; the next run should start with a planning pass instead of more unqueued implementation work.
