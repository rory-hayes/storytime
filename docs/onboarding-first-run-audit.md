# Onboarding And First-Run Flow Audit

Date: 2026-03-08
Milestone: M8.3 - Onboarding and first-run flow audit and direction

## Scope

This document audits StoryTime's current first-run experience and defines the intended onboarding direction before implementation begins. It stays grounded in the active hybrid runtime, current parent trust surfaces, and the monetization direction already documented in `M8.2`.

Primary code and docs inspected:
- `ios/StoryTime/App/StoryTimeApp.swift`
- `ios/StoryTime/App/ContentView.swift`
- `ios/StoryTime/App/UITestSeed.swift`
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `ios/StoryTime/Storage/StoryLibraryStore.swift`
- `ios/StoryTime/Models/StoryDomain.swift`
- `ios/StoryTime/UITests/StoryTimeUITests.swift`
- `ios/StoryTime/Tests/StoryLibraryStoreTests.swift`
- `docs/productization-user-journey-alignment.md`
- `docs/monetization-entitlement-architecture.md`
- `docs/verification/parent-child-storytelling-ux-audit.md`
- `docs/privacy-data-flow-audit.md`
- `AuditUpdated.md`

## Commands Executed

No new test commands were run in this milestone.

This was an audit-and-direction pass grounded in current repo code, existing automated evidence, and prior verification documents.

## Current First-Run Baseline

- VERIFIED BY CODE INSPECTION: `StoryTimeApp` boots directly into `ContentView`, which renders `HomeView` immediately.
- VERIFIED BY CODE INSPECTION: there is no dedicated onboarding container, first-run modal, or setup state machine in the active app.
- VERIFIED BY CODE INSPECTION: `StoryLibraryStore` creates a default fallback child profile named `Story Explorer` if no child profiles exist yet.
- VERIFIED BY CODE INSPECTION: the default privacy state is already opinionated:
  - saved history on
  - retention `90 days`
  - raw audio not saved
  - clear transcripts after session on
- VERIFIED BY TEST: `StoryLibraryStoreTests.testProfileLifecycleAndLimits` proves a fresh store starts with one fallback profile and supports adding profiles up to the current cap.
- VERIFIED BY TEST: `StoryTimeUITests.testParentControlsRequireDeliberateGateBeforeOpening` proves parent controls are discoverable only through the lightweight `PARENT` gate.
- VERIFIED BY TEST: `StoryTimeUITests.testParentControlsCanRenderAndAddAChildProfile` proves the current parent hub can create a child profile.
- VERIFIED BY TEST: `StoryTimeUITests.testPrivacyCopyReflectsLiveProcessingAndLocalRetention` proves trust and privacy copy is aligned across home, journey, voice session, and parent controls.
- VERIFIED BY CODE INSPECTION: there is still no entitlement, paywall, purchase, or onboarding-specific value framing in the active UI.

## Current First-Run Problems

### 1. Setup order is implicit

- VERIFIED BY CODE INSPECTION: first-time parents land on the same `HomeView` used by returning families.
- VERIFIED BY CODE INSPECTION: the repo currently expects the parent to infer that they should:
  - find the `Parent` button
  - type `PARENT`
  - review privacy defaults
  - optionally rename or replace the fallback child
  - return to home
  - start the first story
- PARTIALLY VERIFIED: the current flow is functional, but it is not explicitly guided as a first-run setup sequence.

### 2. The default fallback child is operational, not product-ready

- VERIFIED BY CODE INSPECTION: `Story Explorer` is a good technical fallback but a weak first-run product identity.
- VERIFIED BY CODE INSPECTION: the fallback profile prevents launch failure, but it can obscure the intended parent action of naming the child and confirming age/sensitivity defaults.
- PARTIALLY VERIFIED: the fallback is useful as a resilience layer and test baseline, but not ideal as the first-run product presentation.

### 3. Value framing arrives too late

- VERIFIED BY CODE INSPECTION: `HomeView` says "Voice stories with parent controls built in", but it does not clearly frame the core promise before setup begins.
- VERIFIED BY CODE INSPECTION: the strongest current value explanation appears later in `NewStoryJourneyView`, which already assumes the user has decided to start.
- PARTIALLY VERIFIED: the product's main promise is visible across the app, but the first-run path does not yet package it into a clear welcome sequence.

### 4. Trust framing is truthful but buried

- VERIFIED BY TEST: privacy and live-processing copy is accurate today.
- VERIFIED BY CODE INSPECTION: trust explanation is spread across:
  - `HomeView` trust card
  - parent gate
  - parent controls
  - `NewStoryJourneyView`
  - `VoiceSessionView`
- PARTIALLY VERIFIED: trust is truthful, but a first-time parent still has to assemble the full story from multiple surfaces.

### 5. There is no first-run bridge between parent setup and child start

- VERIFIED BY CODE INSPECTION: after parent setup, the app simply returns to `HomeView`.
- VERIFIED BY CODE INSPECTION: there is no explicit handoff that says the parent setup is complete and the child can now start a first story.
- UNVERIFIED: whether the best handoff is a dedicated completion state on home, an onboarding checklist, or a first-story starter card.

## Current First-Run Journey In Repo Terms

### Current sequence

- VERIFIED BY CODE INSPECTION: app launch -> `HomeView`
- VERIFIED BY CODE INSPECTION: optional parent discovery -> `ParentAccessGateView`
- VERIFIED BY CODE INSPECTION: `ParentTrustCenterView`
- VERIFIED BY CODE INSPECTION: back to `HomeView`
- VERIFIED BY CODE INSPECTION: `NewStoryJourneyView`
- VERIFIED BY CODE INSPECTION: `VoiceSessionView`

### What is missing

- VERIFIED BY CODE INSPECTION: no welcome layer
- VERIFIED BY CODE INSPECTION: no first-run checklist or progress state
- VERIFIED BY CODE INSPECTION: no explicit "set up your child first" step
- VERIFIED BY CODE INSPECTION: no first-use explanation of how live questions become a story before a parent starts the first session
- VERIFIED BY CODE INSPECTION: no parent-managed upgrade or plan framing yet, which is consistent with `M8.2` remaining architecture-first

## Recommended Onboarding Direction

### Direction summary

- VERIFIED BY CODE INSPECTION: onboarding should be an app-embedded product flow layered on top of `HomeView`, not a detached marketing carousel.
- VERIFIED BY CODE INSPECTION: onboarding should stay parent-led first, because trust defaults, child setup, and future upgrade context are all parent concerns.
- VERIFIED BY CODE INSPECTION: the child should enter the product only after parent setup establishes who the story is for and what the defaults are.

### Recommended first-run sequence

#### Step 1. Parent welcome and product promise

- VERIFIED BY CODE INSPECTION: the first-run experience should open with a parent-facing welcome layer above `HomeView`.
- Proposed purpose:
  - explain the core promise: kids shape the story while it is happening
  - explain that StoryTime asks a few live questions, then narrates with scene-based TTS
  - explain that parent controls and privacy defaults come first

#### Step 2. Trust and privacy setup

- VERIFIED BY CODE INSPECTION: the next step should pull from the current truthful trust copy rather than inventing new claims.
- Proposed content:
  - raw audio is not saved
  - prompts and generated story content are sent for live processing
  - saved stories and continuity stay on device
  - transcript clearing and history retention are parent controls
- Proposed interaction:
  - a simplified first-run trust summary
  - then a path into the existing parent controls for deeper settings if needed

#### Step 3. Child setup

- VERIFIED BY CODE INSPECTION: onboarding should ask the parent to confirm or replace the fallback child before the first story starts.
- Proposed content:
  - child name
  - age
  - sensitivity
  - default story mode
- VERIFIED BY CODE INSPECTION: the existing child profile editor and parent hub already provide most of this structure, so later implementation can reuse those fields instead of inventing a parallel model.

#### Step 4. First story expectation-setting

- VERIFIED BY CODE INSPECTION: onboarding should introduce what happens in the first session before the child reaches `VoiceSessionView`.
- Proposed framing:
  - StoryTime asks up to three live questions
  - the child can interrupt later to ask questions or change what happens next
  - long-form narration is spoken scene by scene
- VERIFIED BY CODE INSPECTION: this should lead naturally into `NewStoryJourneyView`, not replace it.

#### Step 5. Parent handoff to child

- VERIFIED BY CODE INSPECTION: the onboarding flow should end with a clear handoff moment from parent setup into child start.
- Proposed purpose:
  - confirm setup is done
  - point to the first `New Story` action
  - avoid mixing this moment with pricing or upgrade friction in the same step

## Recommended Structural Rules For Implementation

- VERIFIED BY CODE INSPECTION: keep onboarding outside `VoiceSessionView`; the live session is too late for first-run setup.
- VERIFIED BY CODE INSPECTION: keep onboarding parent-managed by default.
- VERIFIED BY CODE INSPECTION: preserve the fallback `Story Explorer` profile as a resilience mechanism, but do not present it as the ideal first-run endpoint.
- VERIFIED BY CODE INSPECTION: reuse current privacy/trust wording where possible so onboarding remains truthful.
- VERIFIED BY CODE INSPECTION: onboarding should prepare users for `NewStoryJourneyView`, not duplicate every configuration choice from it.
- PARTIALLY VERIFIED: later implementation may use a modal, full-screen cover, or embedded card stack on top of `HomeView`; this milestone only defines the direction, not the final container.

## Relationship To Monetization

- VERIFIED BY CODE INSPECTION: onboarding should introduce value and trust before asking for upgrade or purchase decisions.
- VERIFIED BY CODE INSPECTION: any later plan or upgrade explanation should remain parent-managed and should not interrupt the first child session.
- VERIFIED BY CODE INSPECTION: onboarding is a legitimate place to explain what StoryTime is and how parent controls work, but not the place for a hard first-screen paywall in v1.
- PARTIALLY VERIFIED: later milestones may add gentle plan framing or restore-purchase access in onboarding, but the exact upgrade strategy belongs to `M8.4`.

## Current Behavior Versus Intended Direction

- VERIFIED BY CODE INSPECTION: current behavior is "land on home and infer setup."
- VERIFIED BY CODE INSPECTION: intended direction is "parent-led first-run path that frames value, trust, child setup, and first story start explicitly."
- PARTIALLY VERIFIED: the repo already contains most of the building blocks:
  - trust copy
  - parent gate
  - parent controls
  - child profile editor
  - new-story launch summary
- UNVERIFIED: the final onboarding container, screen count, and exact first-run completion moment.

## Alignment Outcome

- VERIFIED BY CODE INSPECTION: StoryTime now has a repo-grounded onboarding direction rather than an implicit setup flow.
- VERIFIED BY CODE INSPECTION: the first-run experience should stay parent-first, trust-first, and launch-bridging.
- PARTIALLY VERIFIED: the implementation shape is constrained enough for later work, but the final UI structure is still open.
- UNVERIFIED: the exact visual onboarding treatment and any future subscription copy inside onboarding.

## Recommended Next Milestone

`M8.4 - Paywall and upgrade entry-point strategy`

Reason:
- `M8.2` now defines package-boundary and entitlement architecture.
- `M8.3` now defines the first-run trust and setup sequence.
- The next step is to decide where upgrade prompts can appear in the active product flow without disrupting child play or overstating the parent gate.
