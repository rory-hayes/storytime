# Persistence Audit

Date: 2026-03-07
Status: Done
Scope: Active iOS persistence only. `tiny-backend/` is excluded.

## Active persisted keys

| Key | Owner | Payload | Classification | Active read/write paths |
| --- | --- | --- | --- | --- |
| `storytime.series.library.v1` | `StoryLibraryStore` | `[StorySeries]` JSON blob | Primary product data | `loadSeries()`, `persistSeries()`, add/replace/delete/retention flows |
| `storytime.child.profiles.v1` | `StoryLibraryStore` | `[ChildProfile]` JSON blob | Primary product data | `loadProfiles()`, `persistProfiles()`, add/update/delete profile flows |
| `storytime.active.child.profile.v1` | `StoryLibraryStore` | Active child UUID string | Primary product data / selection state | `loadProfiles()`, `persistActiveProfile()`, profile select/delete fallback |
| `storytime.parent.privacy.v1` | `StoryLibraryStore` | `ParentPrivacySettings` JSON blob | Primary product data / privacy config | `loadPrivacySettings()`, `persistPrivacySettings()`, privacy toggles |
| `storytime.continuity.memory.v1` | `ContinuityMemoryStore` | `[ContinuityFactRecord]` JSON blob | Primary product data / semantic continuity | `init`, `persist()`, replace/clear/prune flows |
| `com.storytime.install-id` | `AppInstall` | Install UUID string | Bootstrap/config | Lazily created in `AppInstall.identity` |
| `com.storytime.session-token` | `AppSession` | Session token string | Bootstrap/config | `AppSession.currentToken`, `AppSession.store(from:)`, `AppSession.clear()` |
| `com.storytime.session-expiry` | `AppSession` | Unix timestamp double | Bootstrap/config | `AppSession.currentToken`, `AppSession.store(from:)`, `AppSession.clear()` |

## What is primary product data today

- Story series and episodes
- Child profiles
- Active child selection
- Parent privacy settings
- Continuity facts and embeddings

## What is bootstrap/config today

- Install identity
- Session token and expiry

## Save and replace paths

- Session completion flows through `PracticeSessionViewModel.persistCompletedStoryIfNeeded()`.
- New and extend sessions call `StoryLibraryStore.addStory(...)`.
- Repeat replay alone saves nothing.
- Repeat replay plus accepted revision calls `StoryLibraryStore.replaceStory(...)`.
- Continuity indexing happens after a successful save or replace:
  - `PracticeSessionViewModel.indexContinuityMemory(for:seriesId:)`
  - `ContinuityMemoryStore.replaceFacts(seriesId:storyId:texts:embeddings:)`

## Delete, clear, and retention paths

- Delete one series:
  - `StoryLibraryStore.deleteSeries(_:)`
  - removes the series blob entry
  - asynchronously calls `ContinuityMemoryStore.shared.clearSeries(id)`
- Clear all story history:
  - `StoryLibraryStore.clearStoryHistory()`
  - empties the series blob
  - asynchronously calls `ContinuityMemoryStore.shared.clearAll()`
- Delete child profile:
  - `StoryLibraryStore.deleteChildProfile(_:)`
  - removes matching series for that child
  - asynchronously calls `ContinuityMemoryStore.shared.clearSeries(...)` for each removed series
  - creates a default fallback profile if the last child is deleted
- Retention pruning:
  - `StoryLibraryStore.applyRetentionPolicy()`
  - prunes old episodes from `series`
  - drops empty series
  - calls `syncContinuityMemoryWithLibrary()`
  - `syncContinuityMemoryWithLibrary()` asynchronously calls `ContinuityMemoryStore.shared.prune(toSeriesIDs:storyIDs:)`
- Save-story-history off:
  - `setSaveStoryHistory(false)` persists privacy settings
  - `applyRetentionPolicy()` clears all `series`
  - asynchronously calls `ContinuityMemoryStore.shared.clearAll()`

## Current invariants

- `StoryLibraryStore` is the only active owner of story history, child profiles, active child selection, and privacy persistence.
- `ContinuityMemoryStore` is the only active owner of semantic continuity embeddings.
- If `saveStoryHistory == false`, new story saves and replacements return `nil` and no story history is retained.
- `clearTranscriptsAfterSession` affects in-memory session transcript clearing only. No transcript blob is persisted.
- Corrupt `series`, `profiles`, or `privacy` blobs fall back to defaults or empty state on load.
- Expired session tokens are cleared on read by `AppSession.currentToken`.

## Current risks and migration constraints

- Primary story data is still stored as large serialized `UserDefaults` blobs with no query surface, partial update path, or schema migration layer.
- `StoryLibraryStore.visibleSeries` falls back across children when the active child has no direct matches. This weakens isolation and is already called out for `M2.6`.
- `StoryLibraryStore` cleanup flows call `ContinuityMemoryStore.shared` directly instead of a store-scoped injected dependency. In the active app both use `UserDefaults.standard`, but this is a coupling point for migration and tests.
- `saveRawAudio` exists in `ParentPrivacySettings` and test seed data, but there is no active UI toggle or persistence behavior that uses it.
- `loadSeries()` and `ContinuityMemoryStore.init` silently drop corrupt data in memory. The corrected empty state is only persisted on the next write, not immediately on load.

## Existing baseline coverage

- `StoryLibraryStoreTests` already cover:
  - profile lifecycle
  - story save, extend, replace, and repeat-no-save behavior
  - retention policy pruning
  - story history clear and delete flows at the series array level
  - corrupt series/profile/privacy blob fallback
- `APIClientTests` and `RealtimeVoiceClientTests` cover:
  - install/session token storage and expiry behavior
- Added during this audit:
  - `StoryLibraryStoreTests.testClearStoryHistoryClearsSharedContinuityMemory`
  - `StoryLibraryStoreTests.testDeleteSeriesClearsSharedContinuityMemory`
  - `StoryLibraryStoreTests.testRetentionPolicyPrunesSharedContinuityFactsToLibraryStories`
  - `StoryLibraryStoreTests.testDeleteChildProfileClearsOnlyRemovedChildContinuityFacts`
  - `StoryLibraryStoreTests.testAddStoryPreservesImmediateContinuityIndexingAfterSave`

## Audit closure notes

- Cleanup baselines for clear-history, delete-series, retention-prune, and child-delete cascade are now pinned.
- `StoryLibraryStore.addStory(...)` still prunes expired series before saving, preserving prior retention semantics, but continuity sync now runs after the library mutation and re-reads the latest persisted library snapshot when the async prune task executes.
- The stale post-save continuity prune race discovered during the audit is now fixed, so migration work can proceed without rediscovery.

## Handoff to M2.2

- Keep `com.storytime.install-id`, `com.storytime.session-token`, and `com.storytime.session-expiry` out of the primary story-store migration decision.
- Treat `StorySeries`, `StoryEpisode`, `ChildProfile`, `ParentPrivacySettings`, and `ContinuityFactRecord` as the active data model inputs for the replacement schema.
- The replacement design must preserve:
  - active-child scoping
  - retention cleanup
  - story-to-continuity linkage by `seriesId` and `storyId`
  - repeat replay no-save behavior
  - repeat revision replace behavior
