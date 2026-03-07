# SPRINT.md

## Sprint Goal

Harden StoryTime's active product loop so live voice sessions start reliably, transition deterministically, persist safely, isolate child data correctly, expose only safe errors, and match the app's privacy claims.

## Execution Rules

- Work one milestone per Codex run unless the milestone is explicitly split first.
- Inspect the active code paths before editing.
- Use the active repo as the source of truth, not archived code or stale assumptions.
- If a milestone is too large for one run, split it into smaller milestones here before implementation.
- Do not mark a milestone `DONE` until its definition of done is met and its required tests pass.
- After every run, update both `PLANS.md` and this file.
- Keep `tiny-backend/` out of active implementation and planning except as labeled historical context.

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

### M3.10.2 - Failure injection acceptance coverage

Status: `TODO`

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

### M3.10.3 - Child isolation acceptance coverage and validation command

Status: `TODO`

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
