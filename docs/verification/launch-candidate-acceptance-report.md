# Launch Candidate Acceptance Report

Date: 2026-03-20
Milestone: M10.3 - Commercial launch rerun and blocker closeout

## Outcome

- Launch decision: READY FOR MVP LAUNCH
- Milestone status: DONE
- Reason: the final launch-readiness command pack was rerun after `M10.1` and `M10.2`, every required repo-owned suite is green, the parent-managed purchase blocker is closed, the blocked-to-upgraded-to-unblocked recovery path is directly evidenced, and the remaining gaps are documented as non-blocking or external to repo verification.

## Scope

This report reruns the locked MVP launch checklist from `docs/launch-mvp-scope-and-acceptance-checklist.md` after the commercial-closure sprint. It records the exact commands, evidence labels, the one tightly related test-only unblocker used during the rerun, the remaining non-blocking gaps, and the final repo-grounded launch recommendation.

Primary docs inspected:
- `docs/launch-mvp-scope-and-acceptance-checklist.md`
- `docs/verification/launch-readiness-gap-assessment.md`
- `docs/verification/commercial-upgrade-happy-path-verification.md`
- `docs/verification/launch-confidence-telemetry-report.md`
- `docs/verification/runtime-stage-telemetry-verification.md`
- `docs/monetization-entitlement-architecture.md`

Primary code paths inspected:
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Networking/APIClient.swift`
- `backend/src/app.ts`
- `backend/src/lib/env.ts`

Primary tests inspected:
- `ios/StoryTime/UITests/StoryTimeUITests.swift`
- `ios/StoryTime/Tests/APIClientTests.swift`
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`
- `backend/src/tests/app.integration.test.ts`
- `backend/src/tests/auth-security.test.ts`
- `backend/src/tests/model-services.test.ts`
- `backend/src/tests/request-retry-rate.test.ts`

## Commands Executed

Hybrid runtime baseline:

```bash
/Users/rory/Documents/StoryTime/scripts/run_hybrid_runtime_validation.sh
```

Observed result:
- VERIFIED BY TEST: passed
- Backend hybrid contract slice passed `51` tests
- iOS hybrid unit slice passed `34` tests
- iOS hybrid UI isolation slice passed `2` tests

Backend launch-contract suite:

```bash
cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/app.integration.test.ts src/tests/auth-security.test.ts src/tests/model-services.test.ts src/tests/request-retry-rate.test.ts
```

Observed result:
- VERIFIED BY TEST: passed `56` tests

iOS launch-product unit suite:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests -only-testing:StoryTimeTests/PracticeSessionViewModelTests -only-testing:StoryTimeTests/StoryLibraryStoreTests
```

Observed result:
- VERIFIED BY TEST: passed `131` tests

iOS launch-product UI suite, first rerun:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests
```

Observed result:
- PARTIALLY VERIFIED: executed `38` tests with `1` failure
- Failure was a brittle UI assertion in `StoryTimeUITests.testJourneyReviewLinksToDurableParentPlanSurface`, not a reproduced product regression

Tightly related test-only unblocker:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testJourneyReviewLinksToDurableParentPlanSurface
```

Observed result:
- VERIFIED BY TEST: passed `1` test after aligning the assertion to the existing `scrollToElement(...)` pattern already used for parent-controls controls that may begin off-screen

iOS launch-product UI suite, clean rerun:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests
```

Observed result:
- VERIFIED BY TEST: passed `38` tests

## Checklist Findings

### A. Onboarding, first-run, and parent trust

- VERIFIED BY TEST: fresh install enters the parent-led onboarding flow instead of dropping directly into the child home surface.
  - Evidence: `StoryTimeUITests.testFreshInstallShowsParentLedOnboardingFlow`
- VERIFIED BY TEST: onboarding and parent controls truthfully describe live processing, local history retention, raw-audio handling, and the lightweight local parent gate.
  - Evidence: `StoryTimeUITests.testPrivacyCopyReflectsLiveProcessingAndLocalRetention`, `testParentControlsRequireDeliberateGateBeforeOpening`, and related onboarding assertions in the full UI suite
- VERIFIED BY TEST: parents can edit the fallback child profile and hand off directly into first-story setup.
  - Evidence: `StoryTimeUITests.testOnboardingCanEditFallbackChildProfile` and `testOnboardingHandsOffToFirstStorySetupAndStaysDismissedAfterRelaunch`

### B. Returning-user launch flow and child session boundaries

- VERIFIED BY TEST: returning users bypass onboarding and reach the quick-start path with the pre-session journey still intact.
  - Evidence: `StoryTimeUITests.testOnboardingHandsOffToFirstStorySetupAndStaysDismissedAfterRelaunch`
- VERIFIED BY TEST: `NewStoryJourneyView` still frames live follow-up, parent handoff, continuity choice, and launch guidance before the session starts.
  - Evidence: `testJourneyFramesPreflightParentHandoffAndLengthGuidance`, `testJourneyExplainsFreshStartAndLiveFollowUpBeforeSessionStarts`, and `testJourneyExplainsLiveNarrationAndInterruptionExpectations`
- VERIFIED BY CODE INSPECTION: `VoiceSessionView` remains free of purchase or paywall UI, preserving the parent trust boundary inside the child storytelling flow.
  - Evidence: inspected `VoiceSessionView.swift`
- VERIFIED BY TEST: child-facing session startup and cue-card behavior are green in the final rerun.
  - Evidence: `testVoiceFirstStoryJourney`, `testVoiceSessionShowsListeningCueBeforeNarrationStarts`, and `testVoiceSessionShowsStorytellingCueAfterNarrationStarts`

### C. Billing, entitlements, and commercial closure

- VERIFIED BY TEST: parent-managed purchase completion exists on approved parent surfaces only.
  - Evidence: `StoryTimeUITests.testParentControlsCanCompleteParentManagedPlusPurchase`
- VERIFIED BY TEST: restore and durable plan-state review remain available from parent controls.
  - Evidence: `StoryTimeUITests.testParentControlsShowCurrentPlanAndRestoreEntry` and `testJourneyReviewLinksToDurableParentPlanSurface`
- VERIFIED BY TEST: blocked new-story starts do not enter `VoiceSessionView`, and they can recover after parent-managed purchase.
  - Evidence: `testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview` and `testJourneyBlockedStartCanRecoverAfterParentManagedPurchase`
- VERIFIED BY TEST: blocked saved-series continuation does not remove replay, and continuation can recover after parent-managed purchase.
  - Evidence: `testSeriesDetailBlocksNewEpisodeAndKeepsReplayTruthful`, `testSeriesDetailRepeatRemainsAvailableWhenContinuationIsBlocked`, `testSeriesDetailBlockedContinuationRoutesToParentManagedReview`, and `testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase`
- VERIFIED BY TEST: retry after purchase uses refreshed entitlement state and the normal preflight path instead of bypassing gating.
  - Evidence: `APIClientTests.testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync` plus backend contract coverage in `app.integration.test.ts`
- VERIFIED BY CODE INSPECTION: child-facing runtime surfaces still do not host purchase controls.
  - Evidence: inspected `HomeView.swift`, `NewStoryJourneyView.swift`, `StorySeriesDetailView.swift`, and `VoiceSessionView.swift`

### D. Usage limits and repeat-use loop

- VERIFIED BY TEST: plan limits remain enforced before cost-bearing work begins.
  - Evidence: backend launch-contract suite plus `StoryTimeUITests.testParentControlsGateAddChildWhenPlanLimitIsReached`
- VERIFIED BY TEST: replay, completion-loop actions, and repeat-use affordances stay available after commercial closure work landed.
  - Evidence: `testSavedStoryCardShowsReplayAndContinueAffordanceOnHome`, `testVoiceSessionShowsCompletionLoopAfterStoryFinishes`, `testVoiceSessionCompletionReplayRestartsNarration`, `testVoiceSessionCompletionContinueActionReturnsToSeriesDetail`, and `testVoiceSessionCompletionLibraryActionReturnsToSavedStoriesSurface`
- VERIFIED BY TEST: continuation details remain subordinate to the primary replay and new-episode actions.
  - Evidence: `testSeriesDetailPrioritizesContinuationActionsOverContinuityDetails`

### E. Runtime, persistence, and telemetry confidence

- VERIFIED BY TEST: the hybrid runtime regression baseline remains green after the commercial closure sprint.
  - Evidence: `scripts/run_hybrid_runtime_validation.sh`
- VERIFIED BY TEST: the iOS launch-product unit suite remains green across API, coordinator, and persistence coverage.
  - Evidence: the `131`-test unit rerun
- VERIFIED BY TEST: backend auth, entitlement, request-context, retry/rate-limit, and launch-critical contract behavior remain green.
  - Evidence: the `56`-test backend rerun
- VERIFIED BY TEST and VERIFIED BY CODE INSPECTION: grouped runtime-stage telemetry, narration playback wall-clock timing, and joined launch reporting remain intact.
  - Evidence: `docs/verification/runtime-stage-telemetry-verification.md`, `docs/verification/launch-confidence-telemetry-report.md`, and the green rerun of the active verification suites

## Commercial Threshold Treatment

### VERIFIED BY TEST

- Launch-default cap thresholds: PASS for the locked MVP candidate.
  - Starter defaults remain `1` child, `3` starts, `3` continuations, `10` minutes, `7` days.
  - Plus defaults remain `3` children, `12` starts, `12` continuations, `10` minutes, `7` days.
- Commercial happy-path closure: PASS for the locked MVP candidate.
  - Parent-managed purchase completion exists.
  - Blocked new-story and continuation flows recover after purchase.
  - Retry reuses entitlement refresh plus normal preflight.
- Launch latency budgets: PASS for the locked MVP candidate.
  - The final rerun completed without timeout failures across the active request ceilings.

### VERIFIED BY CODE INSPECTION

- Backend and client sources of truth for plan limits, entitlement handling, and timeout ceilings remain explicit.
  - Evidence: `backend/src/lib/env.ts` and `ios/StoryTime/Networking/APIClient.swift`
- Purchase UI remains absent from child runtime surfaces.
  - Evidence: inspected `VoiceSessionView.swift` and the active launch surfaces

### PARTIALLY VERIFIED

- The launch rerun depended on the seeded test purchase provider for deterministic StoreKit closure inside UI tests.

### UNVERIFIED

- Live App Store product availability and the production App Store purchase sheet were not re-exercised in this repo verification pass.

## Launch Blockers

### VERIFIED BY TEST

- No repo-owned MVP launch blockers were reproduced in the final March 20, 2026 rerun.

### VERIFIED BY CODE INSPECTION

- The parent-managed purchase boundary, child purchase-free runtime, and current entitlement architecture remain aligned with the locked MVP scope.

### PARTIALLY VERIFIED

- External App Store purchase-sheet behavior remains dependent on live StoreKit environment configuration rather than repo-only test control.

### UNVERIFIED

- None beyond the external StoreKit environment gap above.

## Deferred But Not Blocking MVP Scope Changes

- Broader operational dashboards or warehouse reporting remain deferred.
- Richer parent usage-summary surfaces remain deferred.
- Strong parent authentication remains deferred; the `PARENT` gate remains lightweight local friction by design.
- Durable per-scene runtime-stage timeline export remains deferred.
- Broader moderation and backend safety confidence remains partly inspection-based outside the scoped launch rerun.

## Go Or No-Go Decision

- READY FOR MVP LAUNCH

Rationale:
- The full repo-owned launch command pack was rerun after the final commercial blockers were closed.
- Hybrid regression, backend launch contracts, iOS launch-product units, and the full `38`-test UI launch suite are green.
- The two blocker classes from `docs/verification/launch-readiness-gap-assessment.md` are now closed:
  - a parent-managed purchase completion path exists
  - blocked-to-upgraded-to-unblocked recovery is directly verified
- The remaining gaps are either explicitly deferred post-launch or external to repo-only verification. They do not currently invalidate MVP launch readiness in repo terms.

## Post-Launch Follow-Up Queue

- Durable per-scene runtime-stage timeline export
- Broader operational telemetry and dashboarding
- Stronger parent authentication if the trust boundary needs to expand beyond lightweight local friction
- Broader moderation and backend safety verification beyond the current launch-critical slice
