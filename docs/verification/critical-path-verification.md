# Critical Path Verification

Date: 2026-03-07
Milestone: M3.10.1a - Critical-path verification pass

## Scope

This was a targeted verification pass over the highest-value StoryTime product flows, not a broad audit or feature milestone.

Checked areas:
- realtime/session startup path
- discovery -> generation -> narration transition
- interruption -> revision -> resume behavior
- completion/save behavior
- repeat-mode behavior
- parent privacy/settings surface
- delete-all-history flow
- delete-single-series flow
- child-profile story isolation
- continuity cleanup after delete/history wipe
- safe failure behavior
- transcript clearing behavior

Primary evidence sources:
- existing iOS unit tests
- existing iOS UI tests
- existing backend route/service tests
- one new iOS UI regression added in this run
- focused code-path inspection of the active UI, coordinator, storage, transport, and backend service surfaces

## Flows Checked

### 1. Start a brand-new story

Method:
- Automated iOS unit tests:
  - `PracticeSessionViewModelTests.testStartSessionWithRealAPIClientExecutesFullStartupContractSequence`
  - `PracticeSessionViewModelTests.testCriticalPathAcceptanceHappyPathExercisesFullCoordinatorLifecycle`
- Automated iOS UI test:
  - `StoryTimeUITests.testVoiceFirstStoryJourney`
- Automated backend tests:
  - `app.integration.test.ts`
  - `model-services.test.ts`
- Code inspection:
  - `NewStoryJourneyView`
  - `VoiceSessionView`
  - `PracticeSessionViewModel`
  - `APIClient`
  - `RealtimeVoiceClient`

Dependencies and mocks:
- `StartupURLProtocolStub` for real-`APIClient` startup sequencing
- `MockAPIClient` and `MockRealtimeVoiceCore` for coordinator acceptance coverage
- UI test seed data plus UI test mode
- backend `mockServices()` for route contract checks

Result:
- Verified.

Notes:
- Startup is well covered across health check, session bootstrap, voice fetch, realtime session creation, and bridge connect.
- Discovery -> generation -> narration is exercised end to end by the acceptance harness and the live UI smoke path.

Confidence:
- High

### 2. Start a new episode in an existing series

Method:
- Automated iOS UI test:
  - `StoryTimeUITests.testSeriesDetailShowsContinuityAndActionButtons`
- Automated iOS unit/store tests:
  - `StoryLibraryStoreTests.testStoryLifecycleVisibilityAndReplacement`
  - `StoryLibraryStoreTests.testAppendEpisodePersistsAcrossReloadAndMovesSeriesToFront`
- Code inspection:
  - `StorySeriesDetailView`
  - `StoryLibraryStore`

Dependencies and mocks:
- isolated `StoryLibraryStore` temp sqlite + isolated `UserDefaults`
- UI seed series for Milo

Result:
- Partially verified.

Notes:
- The extend/new-episode entry point is present and backed by persistence tests.
- This pass did not run an end-to-end coordinator acceptance scenario starting from the `New Episode` button itself.

Confidence:
- Medium

### 3. Repeat the latest episode

Method:
- Automated iOS unit tests:
  - `PracticeSessionViewModelTests.testRepeatEpisodeModeReplaysLatestEpisode`
  - `PracticeSessionViewModelTests.testRepeatEpisodeCompletionDoesNotCreateNewHistory`
  - `PracticeSessionViewModelTests.testRepeatEpisodeRevisionReplacesExistingHistoryWithoutAddingEpisodes`
  - `PracticeSessionViewModelTests.testRepeatEpisodeRevisionReplacesContinuityFactsAndClearsClosedOpenLoops`
  - `PracticeSessionViewModelTests.testRepeatEpisodeWithoutSourceSeriesFallsBackCleanly`
- Automated iOS store test:
  - `StoryLibraryStoreTests.testRepeatEpisodeDoesNotPersistNewHistoryAcrossReload`
- Code inspection:
  - `StorySeriesDetailView`
  - `PracticeSessionViewModel`
  - `StoryLibraryStore`

Dependencies and mocks:
- `MockAPIClient`
- `MockRealtimeVoiceCore`
- isolated local persistence store

Result:
- Verified.

Notes:
- Repeat-mode behavior is one of the stronger covered areas.
- Both no-save replay and revise-and-replace semantics are pinned.

Confidence:
- High

### 4. Start from a previous story during setup

Method:
- Automated iOS UI tests:
  - `StoryTimeUITests.testVoiceFirstStoryJourney`
  - `StoryTimeUITests.testSavedStoriesAndPastStoryPickerStayScopedToActiveChild`
- Automated store test:
  - `StoryLibraryStoreTests.testReusePastStoryBranchMissingSeriesFallbackAndFinalProfileDeletion`
- Code inspection:
  - `NewStoryJourneyView`
  - `PracticeSessionViewModel`
  - `StoryLibraryStore`

Dependencies and mocks:
- UI seed data
- isolated store tests

Result:
- Partially verified.

Notes:
- The setup UI exposes the past-story picker and enforces child scoping.
- The launch path from the journey into an actual extend-mode session is not directly asserted by a dedicated end-to-end test in this pass.

Confidence:
- Medium

### 5. Parent privacy/settings changes

Method:
- Automated iOS UI tests:
  - `StoryTimeUITests.testParentControlsRequireDeliberateGateBeforeOpening`
  - `StoryTimeUITests.testParentControlsCanRenderAndAddAChildProfile`
  - `StoryTimeUITests.testPrivacyCopyReflectsLiveProcessingAndLocalRetention`
- Automated store test:
  - `StoryLibraryStoreTests.testPrivacyRetentionAndDeletionControls`
- Code inspection:
  - `HomeView`
  - parent controls surface inside `HomeView`
  - `StoryLibraryStore`

Dependencies and mocks:
- UI seed mode
- isolated store persistence

Result:
- Verified for gate access, child profile mutation, and privacy/retention settings surface.

Notes:
- This remains a lightweight local gate, not strong authentication.

Confidence:
- Medium-high

### 6. Delete all story history

Method:
- New automated iOS UI test added in this run:
  - `StoryTimeUITests.testDeleteAllSavedStoryHistoryClearsSeededSeriesFromHome`
- Existing automated store tests:
  - `StoryLibraryStoreTests.testClearStoryHistoryPersistsAcrossReload`
  - `StoryLibraryStoreTests.testClearStoryHistoryClearsSharedContinuityMemory`
- Code inspection:
  - parent controls surface in `HomeView`
  - `StoryLibraryStore`

Dependencies and mocks:
- UI seed mode with one saved Milo series
- isolated store persistence + shared continuity assertions

Result:
- Verified.

Notes:
- This now has both end-to-end UI coverage and persistence/continuity cleanup coverage.

Confidence:
- High

### 7. Delete a single story series

Method:
- Automated store tests:
  - `StoryLibraryStoreTests.testDeleteSeriesPersistsAcrossReload`
  - `StoryLibraryStoreTests.testDeleteSeriesClearsSharedContinuityMemory`
- Automated iOS UI inspection:
  - `StoryTimeUITests.testSeriesDetailShowsContinuityAndActionButtons` confirms the entry surface and delete affordance exists indirectly through the series detail screen
- Code inspection:
  - `StorySeriesDetailView`
  - `StoryLibraryStore`

Dependencies and mocks:
- isolated store persistence
- UI seed mode

Result:
- Partially verified.

Notes:
- Persistence and continuity cleanup are covered.
- A dedicated end-to-end UI assertion for tapping the trash control and confirming the deletion is still missing.

Confidence:
- Medium

## Cross-Cutting Behaviors

### Realtime/session startup path

Result:
- Verified

Evidence:
- `PracticeSessionViewModelTests.testStartSessionWithRealAPIClientExecutesFullStartupContractSequence`
- `PracticeSessionViewModelTests.testStartSessionUsesResolvedBackendRegionDuringRealtimeStartup`
- backend `/v1/session/identity`, `/v1/realtime/session`, and `/v1/realtime/call` route tests
- backend realtime service tests for SDP and safe failure behavior

### Discovery -> generation -> narration transition

Result:
- Verified

Evidence:
- `testCriticalPathAcceptanceHappyPathExercisesFullCoordinatorLifecycle`
- targeted coordinator transition tests
- backend discovery and story generation service tests

### Interruption -> revision -> resume behavior

Result:
- Verified

Evidence:
- `testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes`
- deferred transcript and revision queue tests
- revision service route/service coverage

### Completion/save behavior

Result:
- Verified

Evidence:
- happy-path acceptance persistence test
- repeat completion no-save tests
- store reload regressions

### Continuity cleanup after delete/history wipe

Result:
- Verified for store behavior, partially verified for single-series UI path

Evidence:
- `testClearStoryHistoryClearsSharedContinuityMemory`
- `testDeleteSeriesClearsSharedContinuityMemory`
- repeat continuity replacement tests

### Child-profile data isolation

Result:
- Verified for saved-story visibility and picker scoping

Evidence:
- `testSavedStoriesAndPastStoryPickerStayScopedToActiveChild`
- `testVisibleSeriesForRequestedChildDoesNotDependOnActiveProfileOrFallback`
- delete-child continuity scoping tests

### Safe failure behavior

Result:
- Partially verified in this pass

Evidence:
- existing startup and revision-conflict tests
- backend auth and invalid-request integration tests

Gap:
- The next planned acceptance-harness milestone still needs the dedicated failure-injection slice for startup failure, disconnect, revision overlap, and duplicate completion.

### Transcript clearing behavior

Result:
- Verified

Evidence:
- `testPrivacySummaryMentionsLocalTranscriptClearingWhenEnabled`
- existing completion/failure transcript-clearing regressions in `PracticeSessionViewModelTests`
- privacy copy UI test

## Defects Found

No new product defects were reproduced in this targeted pass.

The main outcome was a coverage finding:
- delete-all-history now had a clear end-to-end UI gap, which was closed in this run with a focused regression test

## Likely Weak Spots

- `New Story Journey` extend-mode launch still lacks a dedicated end-to-end assertion that a selected prior series is the one carried into the launched session.
- Single-series delete still lacks a dedicated UI regression for the trash-button confirmation path.
- Safe failure behavior is strong in targeted unit tests but still not covered by the acceptance harness scenarios planned for `M3.10.2`.

## Overall Confidence By Area

- Startup and realtime contract: High
- Coordinator happy path: High
- Repeat mode and replay persistence: High
- Delete-all-history flow: High
- Child isolation for saved-story visibility: High
- Parent settings surface: Medium-high
- New episode / extend flow from UI entry point: Medium
- Prior-story launch from setup: Medium
- Single-series delete end-to-end UI path: Medium
- Failure injection acceptance coverage: Medium-low

## Recommended Next Milestone

M3.10.2 - Failure injection acceptance coverage

Reason:
- The highest remaining product risk is no longer the happy path. It is recovery and terminal-state correctness under startup failure, disconnect, revision overlap, and duplicate completion/save attempts.
