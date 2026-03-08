# Parent/Child Storytelling UX Audit

Date: 2026-03-08
Milestone: M7.1 - UX audit for parent/child storytelling flow

## Scope

This audit reviews the active parent and child storytelling flow on top of the verified hybrid runtime baseline. It does not start redesign or implementation work.

Primary surfaces inspected:
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `ios/StoryTime/Storage/StoryLibraryStore.swift`

Primary verification artifacts inspected:
- `docs/privacy-data-flow-audit.md`
- `docs/verification/critical-path-verification.md`
- `docs/verification/hybrid-runtime-end-to-end-report.md`
- `docs/verification/hybrid-runtime-validation.md`
- `ios/StoryTime/UITests/StoryTimeUITests.swift`
- `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`

## Commands Executed

Store and scoping evidence:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/StoryLibraryStoreTests/testVisibleSeriesForRequestedChildDoesNotDependOnActiveProfileOrFallback -only-testing:StoryTimeTests/StoryLibraryStoreTests/testClearStoryHistoryPersistsAcrossReload -only-testing:StoryTimeTests/StoryLibraryStoreTests/testPrivacyRetentionAndDeletionControls
```

Observed result:
- `3` tests passed

UI flow evidence:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeUITests/StoryTimeUITests/testVoiceFirstStoryJourney -only-testing:StoryTimeUITests/StoryTimeUITests/testParentControlsRequireDeliberateGateBeforeOpening -only-testing:StoryTimeUITests/StoryTimeUITests/testSeriesDetailShowsContinuityAndActionButtons -only-testing:StoryTimeUITests/StoryTimeUITests/testSavedStoriesAndPastStoryPickerStayScopedToActiveChild -only-testing:StoryTimeUITests/StoryTimeUITests/testPrivacyCopyReflectsLiveProcessingAndLocalRetention
```

Observed result:
- `5` tests passed

## Current Flow Summary

The active user path in code is:
- `HomeView` for active child selection, privacy summary, saved stories, and parent entry
- `NewStoryJourneyView` for launch setup and continuity choices
- `VoiceSessionView` for the live hybrid session
- `StorySeriesDetailView` for saved-story replay, continue, and deletion
- `ParentTrustCenterView` for privacy, profile, and history controls behind the lightweight local gate

The runtime baseline under this audit is already verified:
- realtime for live interaction
- TTS for long-form narration
- story state and scene state as the authority boundary

## Prioritized Findings

### Parent Trust-Boundary Issues

#### P1. Saved-story deletion is reachable outside the parent gate

- VERIFIED BY CODE INSPECTION: `HomeView` links directly into `StorySeriesDetailView`, and `StorySeriesDetailView` exposes a destructive trash action in the navigation toolbar without routing through `ParentAccessGateView` or `ParentTrustCenterView`.
- VERIFIED BY TEST: `StoryTimeUITests.testSeriesDetailShowsContinuityAndActionButtons` proves the child-facing saved-story detail screen is reachable from the home surface and exposes its action row.
- PARTIALLY VERIFIED: this run did not add a dedicated end-to-end UI assertion for tapping the trash control and confirming deletion, but the bypass is already explicit in active code.

Why this matters:
- The repo now treats the parent hub as a trust boundary, but one of the highest-impact saved-history mutations still sits on the child-facing path.

Recommendation:
- Queue the next implementation milestone around parent-gated saved-story management before broader UX polish.

#### P1. Parent history copy is scoped to the active child, but the action clears all saved history

- VERIFIED BY CODE INSPECTION: `ParentTrustCenterView` shows `"\(store.visibleSeries.count) saved series for the active child"`, while `StoryLibraryStore.clearStoryHistory()` clears the full `series` collection and shared continuity store.
- VERIFIED BY TEST: `StoryLibraryStoreTests.testClearStoryHistoryPersistsAcrossReload` confirms the clear-history action wipes persisted story history, and `StoryLibraryStoreTests.testPrivacyRetentionAndDeletionControls` covers the privacy/control surface behavior.

Why this matters:
- The current wording implies an active-child-scoped action, but the underlying behavior is global. That is a trust issue, not just a copy polish issue.

Recommendation:
- Clarify whether the product wants global delete or active-child delete, then align the UI language and control placement to that actual scope.

#### P2. The parent gate is deliberate friction, not strong authentication

- VERIFIED BY TEST: `StoryTimeUITests.testParentControlsRequireDeliberateGateBeforeOpening` proves the gate blocks direct entry until `PARENT` is typed.
- VERIFIED BY CODE INSPECTION: the gate is a local keyword check in `ParentAccessGateView`, with no stronger auth or parental verification.

Why this matters:
- The gate is appropriate as lightweight friction, but future trust-sensitive UX work should not overstate it as real access control.

Recommendation:
- Keep the gate language honest and treat it as a friction layer unless a later milestone intentionally strengthens it.

### Child Storytelling-Loop Issues

#### P2. Launch setup does not clearly explain how continuity choices affect the live story loop

- VERIFIED BY TEST: `StoryTimeUITests.testVoiceFirstStoryJourney` proves the setup screen can move a child from home into the live session successfully.
- VERIFIED BY CODE INSPECTION: `NewStoryJourneyView` presents separate `Use past story` and `Use old characters` toggles plus a text-only `Session preview`, but it does not clearly explain how those choices change the next live interaction or what happens when only one of those toggles is enabled.
- PARTIALLY VERIFIED: this run did not add dedicated UX comprehension coverage for the continuity-choice combinations because that belongs to a later implementation milestone.

Why this matters:
- The core product promise is that kids shape the story while it is happening. The current launch screen is operational, but it explains settings more than it explains the live storytelling loop the child is about to enter.

Recommendation:
- Prioritize a small launch-clarity milestone instead of broad redesign.

#### P2. The live session relies on shifting status text more than explicit mode cues

- VERIFIED BY CODE INSPECTION: `VoiceSessionView` exposes the hybrid session mostly through `statusMessage`, `aiPrompt`, the waveform, and transcript text. `PracticeSessionViewModel` transitions through listening, narrating, answering, revising, pausing, and failure states, but those mode changes are largely conveyed as text swaps.
- PARTIALLY VERIFIED: existing UI tests validate copy presence and end-to-end launch, but they do not yet prove that interaction mode, narration mode, answer-only mode, and revision mode feel distinct enough on screen.
- UNVERIFIED: whether the current child-facing mode cues are strong enough for real comprehension without user confusion.

Why this matters:
- The runtime itself is deterministic, but the child-facing expression of that runtime is still thin. A reliable hybrid model can still feel confusing if the mode handoff is not legible.

Recommendation:
- Treat this as its own small UX milestone after the parent trust-boundary fixes.

#### P2. Saved-story detail mixes child replay actions, continuity metadata, and destructive affordances in one screen

- VERIFIED BY TEST: `StoryTimeUITests.testSeriesDetailShowsContinuityAndActionButtons` proves the detail screen shows continuity information plus `Repeat` and `New Episode` actions.
- VERIFIED BY CODE INSPECTION: `StorySeriesDetailView` combines action buttons, `Series memory`, relationship facts, open threads, and a destructive delete affordance in the same child-reachable surface.
- PARTIALLY VERIFIED: there is no dedicated audit-harness evidence yet for whether children or parents interpret this information hierarchy correctly.

Why this matters:
- This screen currently acts as both a child continuation surface and a history-management surface. That creates avoidable ambiguity even before any visual redesign begins.

Recommendation:
- Split continuation clarity from deletion/control concerns in a later milestone instead of trying to redesign the full detail page at once.

## Lower-Priority Observations

- VERIFIED BY TEST: privacy copy is now aligned across home, journey, parent controls, and voice session via `StoryTimeUITests.testPrivacyCopyReflectsLiveProcessingAndLocalRetention`.
- VERIFIED BY TEST: child scoping for saved stories and past-story reuse remains strong through `StoryTimeUITests.testSavedStoriesAndPastStoryPickerStayScopedToActiveChild` and `StoryLibraryStoreTests.testVisibleSeriesForRequestedChildDoesNotDependOnActiveProfileOrFallback`.
- PARTIALLY VERIFIED: the child flow is operational and scoped correctly, but “what happens next” clarity remains weaker than the underlying runtime stability.

## Recommended Follow-Up Milestones

### M7.2 - Parent trust-boundary hardening for saved-story management

Focus:
- gate or relocate child-reachable destructive story-history actions
- resolve the active-child versus global delete-history scope mismatch
- keep trust-boundary copy aligned to the actual behavior

### M7.3 - Launch-plan clarity for continuity choices

Focus:
- clarify new story versus continue story versus reuse characters
- make the live interaction loop more explicit before session start
- preserve current runtime behavior while improving choice legibility

### M7.4 - Live session interaction-state clarity

Focus:
- make narration versus listening versus answer/revision states legible on screen
- keep child-facing recovery and interruption cues simple
- do not widen into transport or runtime behavior changes

### M7.5 - Saved-story detail information hierarchy pass

Focus:
- separate continuation actions from destructive/history-management controls
- make continuity metadata feel intentional instead of internal
- keep replay and continue actions explicit without reopening runtime logic

## Audit Outcome

- VERIFIED BY TEST: the current parent/child flow is operational, privacy copy is aligned, child scoping is enforced, and the main voice-first journey still works on the verified hybrid runtime baseline.
- VERIFIED BY CODE INSPECTION: the highest-value next UX work is not broad visual redesign. It is trust-boundary cleanup plus clearer explanation of the live hybrid storytelling loop.
- PARTIALLY VERIFIED: some of the most important UX risks are interaction and trust-boundary issues exposed by active code structure rather than by failing regressions.
- UNVERIFIED: whether the current child-facing cues are sufficiently understandable in real use, because the repo does not contain direct user-comprehension evidence.
