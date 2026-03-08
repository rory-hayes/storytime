# End-Of-Story And Repeat-Use Loop

Date: 2026-03-08
Milestone: M8.7 - End-of-story and repeat-use loop design pass

## Scope

This document defines the post-story loop that should follow a finished StoryTime session. It stays design-direction only. It does not implement new completion UI, paywall logic, entitlement checks, or navigation changes.

Primary code inspected:
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
- `ios/StoryTime/UITests/StoryTimeUITests.swift`
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`

Supporting docs inspected:
- `docs/productization-user-journey-alignment.md`
- `docs/paywall-upgrade-entry-strategy.md`
- `docs/onboarding-first-run-audit.md`
- `docs/verification/parent-child-storytelling-ux-audit.md`

## Commands Executed

No new test commands were run in this milestone.

This was a design-direction pass grounded in active code paths, existing automated test evidence, and the productization and monetization docs already defined in the repo.

## Current Completion Baseline

- VERIFIED BY CODE INSPECTION: `PracticeSessionViewModel.completeSession(...)` is the current authoritative completion path. It cancels timed work, clears in-flight request ownership, moves the session to `.completed`, updates the prompt and status copy, applies terminal transcript policy, records a completion trace, and persists the completed story if the save strategy allows it.
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testNormalSessionProgressionCompletesAndSavesOnce` proves a normal story run reaches `.completed` and saves once.
- VERIFIED BY TEST: repeat-mode regressions prove the repo already distinguishes repeat replay from continuation-style saving:
  - `testRepeatEpisodeCompletionDoesNotCreateNewHistory`
  - `testRepeatEpisodeRevisionReplacesExistingHistoryWithoutAddingEpisodes`
- VERIFIED BY CODE INSPECTION: `VoiceSessionView` stays on the live session surface after completion. It shows the completed cue state and updated prompt text, but it does not expose a dedicated post-story action card, replay CTA, continue CTA, or explicit return-to-library path.
- PARTIALLY VERIFIED: the completion semantics are solid, but the user-facing completion loop is still under-designed.

## Current Repeat-Use Surfaces

### 1. Return to home and library

- VERIFIED BY CODE INSPECTION: `HomeView` already acts as the app-level return surface and frames saved stories as replay-or-continuation value.
- VERIFIED BY TEST: `StoryTimeUITests.testSavedStoryCardShowsReplayAndContinueAffordanceOnHome` proves the home library already communicates repeat and continue intent for saved series.
- VERIFIED BY CODE INSPECTION: after a finished session, the user reaches this surface only by manual navigation today.

### 2. Saved-series continuation detail

- VERIFIED BY TEST: `StoryTimeUITests.testSeriesDetailPrioritizesContinuationActionsOverContinuityDetails` proves `StorySeriesDetailView` already prioritizes `Repeat` and `New Episode`.
- VERIFIED BY CODE INSPECTION: this detail view is already the strongest repeat-use action surface in the repo because it separates replay and continuation from parent-only management.

### 3. In-session completion state

- VERIFIED BY CODE INSPECTION: the current completion copy is:
  - status: `Story complete`
  - prompt: `The story has ended. You can start another episode.`
- VERIFIED BY CODE INSPECTION: this wording correctly hints at repeat use, but it is not connected to actual next-step controls inside `VoiceSessionView`.
- UNVERIFIED: whether children or parents can reliably infer the best next action from the current completed voice-session state alone.

## Product Gap

- VERIFIED BY CODE INSPECTION: StoryTime already has all three ingredients of a repeat-use loop:
  - completion and save behavior
  - home-level saved-story visibility
  - series-detail replay and new-episode actions
- VERIFIED BY CODE INSPECTION: what is missing is the product bridge between them.
- PARTIALLY VERIFIED: the repo can support repeat use today, but the app does not yet guide the user from "story finished" into "what should happen next."

## End-Of-Story Loop Decisions

### Child-facing loop

- VERIFIED BY CODE INSPECTION: the child should finish on a simple completion state, not an abrupt jump away from the session.
- Decision:
  - the end of a story should first acknowledge completion inside the finished-session surface
  - the next actions should be limited to child-safe choices:
    - `Replay this story`
    - `Start a new episode`
    - `Back to saved stories`
  - these choices should map to already-real product behavior:
    - replay existing content
    - continue the saved series
    - return to the library or home surface

### Parent-facing loop

- VERIFIED BY CODE INSPECTION: a finished session is also a trust and value moment for the parent because it confirms the story saved locally and can be reused.
- Decision:
  - the parent-facing layer should stay secondary, not interruptive
  - parent-relevant reassurance at completion should focus on:
    - the story was saved for this child
    - raw audio was not saved
    - more continuation options live in the saved-story flow
  - any later upgrade moment at completion must remain parent-safe and never block an already-finished child story

## Role Of Each Surface In The Loop

### VoiceSessionView

- VERIFIED BY CODE INSPECTION: this should become the acknowledgement surface for a finished story.
- Decision:
  - `VoiceSessionView` owns the immediate "story finished" moment
  - it should present the child-safe next-step choices after completion in a future implementation milestone
  - it should not host a blocking paywall or transactional purchase flow

### StorySeriesDetailView

- VERIFIED BY CODE INSPECTION: this remains the best deep repeat-use surface once a saved series already exists.
- Decision:
  - `StorySeriesDetailView` should stay the richer continuation destination for families who want more context before replaying or starting a new episode
  - the completion loop may link back to it directly or indirectly through home, but its role remains continuation-focused, not session-finalization focused

### HomeView

- VERIFIED BY CODE INSPECTION: `HomeView` should remain the broad return surface where families can switch children, start over, or pick another saved story.
- Decision:
  - the completion loop should always have a clean path back to `HomeView`
  - home should absorb the "what next" state without forcing the user to rediscover where saved stories live

## Approved Next-Step Hierarchy

- VERIFIED BY CODE INSPECTION: the repo-fit order for post-story actions is:
  1. replay the finished story
  2. start a new episode from the saved series
  3. return to saved stories or home
- Decision:
  - replay should stay the lowest-risk next action because it uses already-saved content
  - new-episode continuation should stay visible because it is the strongest repeat-use value driver
  - return to home should stay available because it preserves child switching and saved-story browsing

## Monetization Alignment

- VERIFIED BY CODE INSPECTION: `docs/paywall-upgrade-entry-strategy.md` already reserves the completion loop as a possible later upgrade moment.
- Decision:
  - completion may become a soft upgrade-awareness surface later
  - it must not become the first place where a completed child story is blocked or emotionally interrupted
  - if a continuation cap exists later, the paywall logic should target the new-episode path, not replay and not the completion acknowledgement itself
- PARTIALLY VERIFIED: the strategy is aligned, but the exact completion-loop upgrade pattern still belongs to later implementation work after trust and privacy refinement.

## Explicit Exclusions

- VERIFIED BY CODE INSPECTION: this milestone does not implement:
  - a new completion card in `VoiceSessionView`
  - navigation changes out of the session on completion
  - StoreKit or entitlement checks
  - upgrade UI
  - parent-summary modals
- VERIFIED BY CODE INSPECTION: this milestone also does not widen completion into new persistence behavior because the save path is already defined and tested.

## Alignment Outcome

- VERIFIED BY TEST: completion correctness, repeat replay, and saved-series continuation are already covered in the repo.
- VERIFIED BY CODE INSPECTION: StoryTime now has an explicit intended end-of-story loop instead of leaving completion as a dead-end prompt.
- PARTIALLY VERIFIED: the exact UI implementation still needs to be built later, but the surface roles and action order are now defined.
- UNVERIFIED: the final visual hierarchy, completion-screen copy, and any upgrade treatment because those are not yet implemented.

## Recommended Next Milestone

`M8.8 - Parent trust and privacy communication refinement`

Reason:
- The completion loop is now defined.
- The next remaining milestone in this phase should tighten parent-facing trust, privacy, and value communication across the surfaces that now carry more product and monetization framing.
