# Productization User-Journey Alignment

Date: 2026-03-08
Milestone: M8.1 - Productization planning and user-journey alignment

## Scope

This document defines the current StoryTime product journey in repo terms so later monetization, onboarding, paywall, and polish work can stay aligned to the verified hybrid runtime instead of drifting into isolated screen work.

Primary surfaces inspected:
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`

Supporting surfaces inspected:
- parent access gate and `ParentTrustCenterView` in `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Storage/StoryLibraryStore.swift`
- `ios/StoryTime/UITests/StoryTimeUITests.swift`
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`

Supporting docs inspected:
- `docs/verification/parent-child-storytelling-ux-audit.md`
- `docs/verification/runtime-stage-telemetry-verification.md`
- `docs/privacy-data-flow-audit.md`
- `docs/verification/hybrid-runtime-validation.md`

## Commands Executed

No new test commands were run in this milestone.

This was a planning-only pass grounded in existing repo code, existing automated test coverage, and prior verification artifacts.

## Product Baseline

- VERIFIED BY CODE INSPECTION: the active app still opens into `HomeView`, launches a session through `NewStoryJourneyView`, runs live story sessions in `VoiceSessionView`, and manages saved-series follow-up in `StorySeriesDetailView`.
- VERIFIED BY CODE INSPECTION: the product remains architecturally hybrid:
  - realtime for live interaction
  - TTS for long-form narration
  - story and scene state as the authoritative control layer
- VERIFIED BY CODE INSPECTION: there is currently no entitlement, subscription, StoreKit, paywall, or dedicated first-run onboarding implementation in the active repo.
- VERIFIED BY CODE INSPECTION: the repo already has stage-level telemetry and cost-driver tracing, which is the main monetization groundwork available today.

## Journey Map

### 1. First-Time Parent Entry

Current path:
- app opens to `HomeView`
- parent sees active child card, trust summary, and empty or seeded story history
- parent must discover `Parent` to open the lightweight access gate
- parent enters `PARENT`
- parent reaches `ParentTrustCenterView` to manage profiles, privacy, retention, and saved-story deletion

Evidence:
- VERIFIED BY CODE INSPECTION: `HomeView` exposes trust summary and the parent button, but there is no dedicated first-run onboarding sequence or guided setup state before the main home surface appears.
- VERIFIED BY TEST: `StoryTimeUITests.testParentControlsRequireDeliberateGateBeforeOpening` proves the lightweight parent gate blocks direct entry until the confirmation text is typed.
- VERIFIED BY TEST: `StoryTimeUITests.testParentControlsCanRenderAndAddAChildProfile` proves the parent surface can create a child profile from the existing hub.
- PARTIALLY VERIFIED: the repo supports parent setup tasks, but it does not currently verify a cohesive first-run setup journey from a true empty install through first story start.

Product meaning:
- This is the first trust moment and the first candidate place to explain value, safety, and pricing.
- Because it currently begins inside the regular home surface, later onboarding work must decide whether to add a guided first-run layer or keep setup embedded in home plus parent controls.

### 2. Returning Child Quick Start

Current path:
- child lands on `HomeView`
- child sees active child, trust summary, and past stories
- child can tap `New Story` inline or the floating plus button
- child enters `NewStoryJourneyView`
- child starts a voice session

Evidence:
- VERIFIED BY TEST: `StoryTimeUITests.testVoiceFirstStoryJourney` proves the child can move from home into the new-story setup and reach a generated story.
- VERIFIED BY CODE INSPECTION: `HomeView` already highlights the active child and exposes one clear primary action, but it does not yet frame package boundaries, onboarding hints, or upgrade moments.
- PARTIALLY VERIFIED: the quick-start path is operational, but the repo does not yet prove whether the home surface explains value or package limits clearly enough for a productized launch.

Product meaning:
- This is the fastest value path in the current app.
- Future home polish and upgrade-entry work should protect this path instead of burying it under parent or monetization clutter.

### 3. New Story Setup And Launch

Current path:
- child or parent selects child profile, story mode, continuity choices, and target length in `NewStoryJourneyView`
- the screen explains the live follow-up loop, continuity plan, and privacy summary
- `Start Voice Session` launches the hybrid runtime

Evidence:
- VERIFIED BY CODE INSPECTION: `NewStoryJourneyView` already separates child choice, mode, continuity options, privacy, and a launch summary.
- VERIFIED BY TEST: the current UI test suite proves the screen can explain fresh start, continue mode, and character reuse choices, and can still launch the main voice journey.
- VERIFIED BY TEST: `StoryTimeUITests.testSavedStoriesAndPastStoryPickerStayScopedToActiveChild` proves continuation choices stay child-scoped.
- PARTIALLY VERIFIED: there is no package-limit or entitlement messaging yet, so the current setup flow is product-readable but not monetization-ready.

Product meaning:
- This is the strongest candidate parent-managed upgrade or limit-explanation surface before cost is incurred.
- Later entitlement work should use this surface carefully because it already explains live processing, saved continuity, and story scope.

### 4. Live Story Session

Current path:
- `VoiceSessionView` starts the coordinator
- the child sees the session cue card, waveform, prompt, transcript, story title, scene progress, and privacy summary
- the session transitions from listening to storytelling and can accept interruptions

Evidence:
- VERIFIED BY TEST: `StoryTimeUITests.testVoiceSessionShowsListeningCueBeforeNarrationStarts` proves the pre-narration interaction cue is visible.
- VERIFIED BY TEST: `StoryTimeUITests.testVoiceSessionShowsStorytellingCueAfterNarrationStarts` proves the storytelling cue is visible after narration begins.
- VERIFIED BY CODE INSPECTION: `VoiceSessionView` accurately reflects the verified hybrid runtime rather than inventing a separate UI-only flow.
- PARTIALLY VERIFIED: the repo shows the core live value loop clearly enough for current use, but it does not yet define any pricing boundary, usage-meter, or parent-managed upgrade behavior during or around live sessions.
- UNVERIFIED: whether future in-session upsell should exist at all. The current product architecture and child-safety stance may imply that upgrades should stay outside the live child session.

Product meaning:
- This is the core value moment: kids shape the story while it is happening.
- Productization should protect this surface from noisy monetization patterns and treat it as a child-first experience.

### 5. Saved-Series Continuation

Current path:
- child returns to `HomeView`
- child opens a saved series from the library
- `StorySeriesDetailView` now prioritizes `Repeat` and `New Episode`
- continuity remains visible as secondary support for the next episode

Evidence:
- VERIFIED BY TEST: `StoryTimeUITests.testSeriesDetailPrioritizesContinuationActionsOverContinuityDetails` proves the saved-story detail surface now leads with continuation actions and keeps management concerns secondary.
- VERIFIED BY CODE INSPECTION: the detail view is now much closer to a product continuation surface than a mixed history-management screen.
- PARTIALLY VERIFIED: the repo does not yet define whether saved-series continuation is a free feature, a premium feature, or a capped feature.

Product meaning:
- This is one of the clearest candidate upgrade moments because it represents repeat use, continuity value, and saved-story depth.
- Any paywall or upgrade treatment here must stay parent-safe and preserve child scoping.

### 6. Session Completion And Return Loop

Current path:
- `PracticeSessionViewModel.completeSession(...)` sets `.completed`, updates status and prompt, applies transcript policy, records completion trace, and persists the completed story
- the story is saved locally if completion strategy allows it
- the current UI remains inside the voice session until the user navigates away

Evidence:
- VERIFIED BY TEST: `PracticeSessionViewModelTests.testNormalSessionProgressionCompletesAndSavesOnce` proves a normal session reaches completion and saves once.
- VERIFIED BY CODE INSPECTION: `completeSession(...)` and `persistCompletedStoryIfNeeded()` implement persistence and completion semantics, but there is no explicit post-story product surface or designed return-to-library loop yet.
- PARTIALLY VERIFIED: completion correctness is well tested, but the user-facing completion journey is not yet productized.

Product meaning:
- This is the main missing repeat-use journey in the current app.
- Later productization work should decide what comes after a finished story: replay, continue, saved-series return, parent summary, or upgrade moment.

## Value Moments

- VERIFIED BY TEST: the child can get from home to a generated story successfully.
- VERIFIED BY CODE INSPECTION: StoryTime's clearest current value moments are:
  - fast new-story start from home
  - live follow-up before narration
  - visible storytelling state in-session
  - saved-series replay and new-episode continuation
- PARTIALLY VERIFIED: those value moments are operational, but not yet organized into a first-run narrative or monetization-aware product structure.

## Trust Moments

- VERIFIED BY TEST: parent access requires deliberate friction through the lightweight gate.
- VERIFIED BY TEST: privacy copy is aligned across home, journey, voice session, and parent controls.
- VERIFIED BY CODE INSPECTION: parent trust is currently communicated through the trust summary on home, the parent gate, and the parent hub's privacy and retention controls.
- PARTIALLY VERIFIED: the parent-trust journey is truthful, but it is still embedded inside the main app flow rather than framed as a dedicated onboarding or subscription-management path.

## Friction Points

- VERIFIED BY CODE INSPECTION: the app still lands directly in `HomeView`, so a first-time parent has to infer setup order from the existing home and parent surfaces.
- VERIFIED BY CODE INSPECTION: there is no explicit entitlement model, package boundary, or usage-cap messaging anywhere in the active UI.
- VERIFIED BY CODE INSPECTION: the post-story return path is functional but under-designed from a product perspective.
- PARTIALLY VERIFIED: current friction is visible in code structure and surface hierarchy, but the repo has no direct user-research evidence for which friction points hurt the most in real use.

## Candidate Upgrade Moments

- VERIFIED BY CODE INSPECTION: the most repo-credible upgrade candidates are outside the active child narration path:
  - parent-first or first-run setup
  - `NewStoryJourneyView` before session start
  - saved-series continuation or repeat-use surfaces
  - parent controls / trust center
  - post-story completion loop once it exists as a clearer product surface
- UNVERIFIED: any child-visible in-session paywall or interruption because the repo currently has no such flow, and the product's child-safety posture may make that undesirable.

## Constraints For Later M8 Milestones

- VERIFIED BY CODE INSPECTION: monetization must stay grounded in the active hybrid runtime:
  - realtime interaction has live cost
  - TTS narration has narration-stage cost
  - the repo already traces stage-level cost drivers rather than assuming free usage
- VERIFIED BY CODE INSPECTION: saved stories, continuity, and parent privacy controls are local-device features today.
- VERIFIED BY CODE INSPECTION: the parent gate is lightweight friction, not strong authentication, so later trust or purchase language must not overstate it.
- VERIFIED BY CODE INSPECTION: there is no entitlement backend or client purchase layer yet, so `M8.2` must stay architecture-first before any UI paywall implementation.
- PARTIALLY VERIFIED: the telemetry model is good enough to inform pricing discussion, but the repo still lacks pass/fail economic thresholds.

## Alignment Outcome

- VERIFIED BY TEST: StoryTime already delivers the core child value loop, parent gate, trust copy, child scoping, and saved-series continuation baseline.
- VERIFIED BY CODE INSPECTION: the next productization work should treat the app as a set of connected journeys, not disconnected screens.
- PARTIALLY VERIFIED: the right upgrade surfaces are visible in the current flow, but package boundaries and entitlement ownership still need explicit architecture work.
- UNVERIFIED: the final monetization shape, onboarding framing, and upgrade timing because those choices are not yet implemented in the repo.

## Recommended Next Milestones

- `M8.2 - Monetization model and entitlement architecture`
- `M8.3 - Onboarding and first-run flow audit and direction`
- `M8.4 - Paywall and upgrade entry-point strategy`

Reason:
- `M8.1` now establishes the current journeys, value moments, trust moments, friction points, and likely upgrade moments in repo terms.
- The next work should define entitlement and pricing boundaries before visual paywall or polish implementation widens.
