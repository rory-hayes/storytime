#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Backend hybrid contract slice"
(
  cd "$ROOT/backend"
  npm test -- --run \
    src/tests/app.integration.test.ts \
    src/tests/model-services.test.ts \
    src/tests/request-retry-rate.test.ts \
    src/tests/types.test.ts
)

echo
echo "==> iOS hybrid unit slice"
xcodebuild test \
  -project "$ROOT/ios/StoryTime/StoryTime.xcodeproj" \
  -scheme StoryTime \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" \
  -only-testing:StoryTimeTests/APIClientTests/testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation \
  -only-testing:StoryTimeTests/APIClientTests/testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages \
  -only-testing:StoryTimeTests/HybridRuntimeContractTests \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNormalSessionProgressionCompletesAndSavesOnce \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartupHealthCheckFailureUsesSafeMessageAndCategory \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testStartupDisconnectBeforeReadyFailsOnceAndLateConnectedDoesNotReviveSession \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionQuestionDoesNotBlindlyStartRevision \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testOverlappingInterruptionsQueueInsteadOfStartingConcurrentRevisions \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testAnswerOnlyResumeCompletesAndSavesOnce \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testPauseAndResumeNarrationPreservesSceneOwnership \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testDuplicateCompletionAndSavePrevention \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testRevisionInvalidatesStalePreloadedFutureSceneAudio \
  -only-testing:StoryTimeTests/PracticeSessionViewModelTests/testExtendModeUsesPreviousRecapAndContinuityEmbeddings

echo
echo "==> iOS hybrid UI isolation slice"
xcodebuild test \
  -project "$ROOT/ios/StoryTime/StoryTime.xcodeproj" \
  -scheme StoryTime \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" \
  -only-testing:StoryTimeUITests/StoryTimeUITests/testSavedStoriesAndPastStoryPickerStayScopedToActiveChild \
  -only-testing:StoryTimeUITests/StoryTimeUITests/testSavedStoriesAndPastStoryPickerReturnWhenSwitchingBackToSeededChild
