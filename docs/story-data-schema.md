# StoryData Local Schema Design

Date: 2026-03-07
Scope: Active iOS client storage only.
Status: Chosen in M2.2. Storage bootstrap for profiles, active selection, privacy settings, series, and episodes landed in M2.3.1. Continuity migration and legacy continuity-blob retirement landed in M2.3.2.

## Goals

- Replace large serialized blobs in `UserDefaults` with a durable, queryable store for story products.
- Preserve current behavior for:
  - child profile scoping
  - story series and episode ordering
  - repeat and revision replacement semantics
  - continuity linkage and cleanup
  - retention policy enforcement and save-history toggle
- Keep bootstrap/config keys (`com.storytime.install-id`, `com.storytime.session-token`, `com.storytime.session-expiry`) outside the migration surface.

## Chosen store technology

- **Core Data with `NSPersistentContainer`** in the app sandbox.
- Keep on-device vector embeddings in continuity memory for continuity lookup without external services.
- Persist as:
  - `storytime-v2.sqlite` (Core Data store file)
  - lightweight migration metadata record in the same store.

## Data model

### 1) `Profile`

- Primary key: `id` (`UUID`)
- Columns:
  - `displayName` (`String`, required)
  - `age` (`Int16`, required, clamped 3..8 on write)
  - `contentSensitivity` (`String`, enum)
  - `preferredMode` (`String`, enum)
  - `createdAt` (`Date`)
  - `updatedAt` (`Date`)

Behavior:
- At most 3 rows.
- App selects one active profile via `AppState.activeProfileId`.

### 2) `LibrarySettings`

- Single-row table used for settings and active pointers.
- Columns:
  - `activeProfileId` (`UUID`, nullable)
  - `saveStoryHistory` (`Bool`)
  - `retentionPolicy` (`String`)
  - `saveRawAudio` (`Bool`)
  - `clearTranscriptsAfterSession` (`Bool`)
  - `updatedAt` (`Date`)

Behavior:
- Holds app-level booleans currently stored in `ParentPrivacySettings`.
- `saveRawAudio` stays in the schema for migration compatibility only. It does not introduce raw-audio persistence behavior.

### 3) `StorySeries`

- Primary key: `id` (`UUID`)
- Foreign key: `childProfileId` -> `Profile.id` (RESTRICT/DELETE-CASCADE behavior by coordinator)
- Columns:
  - `childProfileId` (`UUID`, nullable for migration compatibility)
  - `title` (`String`)
  - `characterHintsData` (`Binary Data`, JSON payload)
  - `arcSummary` (`String?`)
  - `relationshipFactsData` (`Binary Data`, optional JSON payload)
  - `favoritePlacesData` (`Binary Data`, optional JSON payload)
  - `unresolvedThreadsData` (`Binary Data`, optional JSON payload)
  - `createdAt` (`Date`)
  - `updatedAt` (`Date`)
  - `libraryPosition` (`Int32`) // 0-based library ordering, 0 is most recent

Indices:
- `(childProfileId)`
- `(libraryPosition)`

Behavior:
- `childProfileId` remains nullable during migration so existing fallback visibility is preserved until M2.6 removes it.
- `visibleSeries` can continue the current fallback behavior until M2.6 tightens child scoping.
- `libraryPosition` preserves the current in-memory ordering exactly instead of inferring it only from timestamps.

### 4) `StoryEpisode`

- Primary key: `id` (`UUID`)
- Foreign key: `seriesId` -> `StorySeries.id`
- Columns:
  - `seriesId` (`UUID`, required)
  - `storyId` (`String`, required)
  - `title` (`String`)
  - `scenesData` (`Binary Data`, required JSON payload)
  - `estimatedDurationSec` (`Int32`)
  - `engineData` (`Binary Data`, optional JSON payload)
  - `storyIndex` (`Int32`) // 0-based index inside series
  - `createdAt` (`Date`)

Indices:
- `(seriesId, storyIndex)`
- `(storyId)` for continuation/resume lookups.

Behavior:
- `storyIndex` tracks append/replace behavior deterministically and removes reliance on array position in serialized blobs.
- `engineData` stores `StoryEngineData` as JSON when present and remains nullable because legacy and seeded episodes can omit engine payloads.

### 5) `ContinuityFact`

- Primary key: `id` (`UUID`)
- Foreign key: `seriesId` -> `StorySeries.id`
- Columns:
  - `seriesId` (`UUID`, required)
  - `storyId` (`String`, required)
  - `text` (`String`, required)
  - `embeddingData` (`Binary Data`, required JSON vector payload)
  - `updatedAt` (`Date`)

Indices:
- `(seriesId, storyId)`
- `(seriesId)`
- `(updatedAt)` for cleanup windows.

Behavior:
- Stores the semantic facts used by current continuity retrieval.
- Top-k ranking and cosine similarity stay in app layer against candidate records from `(seriesId, storyId)`.

### 6) `SchemaMigrationLog`

- Primary key: `id` (`UUID`)
- Columns:
  - `toVersion` (`Int16`)
  - `appliedAt` (`Date`)
  - `notes` (`String`)

Behavior:
- One row per completed migration to support startup diagnostics and safe rollback checks.

## Relationship summary

- `Profile 1..* StorySeries`
- `StorySeries 1..* StoryEpisode`
- `StorySeries 1..* ContinuityFact`
- Continuity cleanup always keys on `seriesId` and `storyId` to preserve existing replace/clear/prune behavior.

## Query design notes for M2.2 requirements

- Story history CRUD:
  - Add story -> create `StorySeries` and append `StoryEpisode` row.
  - Extend -> append episode row with new `storyIndex`, move series to `libraryPosition = 0`, and refresh `updatedAt`.
  - Replace -> locate episode by `storyId`, patch mutable fields in place.
  - Delete -> delete `StorySeries` and cascade episode rows.
  - Clear history -> truncate `StorySeries`, `StoryEpisode`, and `ContinuityFact` globally, matching current product behavior.
- Child scoping:
  - M2.3.1 preserves the current fallback behavior for `nil` or unmatched child ownership.
  - M2.6 will tighten active-child visibility to explicit child-scoped queries only.
- Continuity:
  - Index and query `ContinuityFact` by `(seriesId)` and `(storyId)` for all retain/delete/prune operations.
- Retention:
  - `saveStoryHistory == false`: remove all `StorySeries`, `StoryEpisode`, and `ContinuityFact` rows, matching the current clear-history behavior.
  - `retention window`: delete episodes where `createdAt < cutoffDate` then cascade to `StorySeries` empties.

## Migration assumptions recorded for M2.3

- M2.3 migration reads current `UserDefaults` keys as bootstrap source:
  - `storytime.series.library.v1`
  - `storytime.child.profiles.v1`
  - `storytime.active.child.profile.v1`
  - `storytime.parent.privacy.v1`
  - `storytime.continuity.memory.v1`
- Migration must be one-time and idempotent:
  - Keep `SchemaMigrationLog` rows with `toVersion >= 2` once the full library plus continuity store is current.
  - Continuity import records its own completion note in the migration log so relaunch does not re-import stale legacy blobs.
- Corruption handling:
  - Corrupt blobs fall back to defaults for each object set (profiles/settings/series/continuity) and continue migration.
  - Failed blob decode for one source set does not block migration of other valid data sets.
- Compatibility handling:
  - Existing `StorySeries.childProfileId == nil` values remain nullable in the new store until M2.6 removes fallback visibility.
  - `saveRawAudio` is migrated as a compatibility flag only; it does not activate raw-audio retention.
- Rollback behavior:
  - If migration fails after partial write, rollback is implemented by deleting `storytime-v2.sqlite` and rebuilding from whichever source data remains.
  - Legacy library/profile/privacy keys remain migration-source only while compatibility is staged.
  - The legacy continuity blob is removed after successful import into the v2 store.
