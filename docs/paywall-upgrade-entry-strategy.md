# Paywall And Upgrade Entry-Point Strategy

Date: 2026-03-08
Milestone: M8.4 - Paywall and upgrade entry-point strategy

## Scope

This document decides where upgrades should appear in StoryTime and where they should not. It stays strategy-only and does not implement StoreKit, paywalls, entitlement checks, or new UI yet.

Primary code and docs inspected:
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `ios/StoryTime/UITests/StoryTimeUITests.swift`
- `docs/productization-user-journey-alignment.md`
- `docs/monetization-entitlement-architecture.md`
- `docs/onboarding-first-run-audit.md`
- `docs/verification/parent-child-storytelling-ux-audit.md`

## Commands Executed

No new test commands were run in this milestone.

This was a strategy pass grounded in active product surfaces, existing UI evidence, and the already-defined monetization and onboarding direction.

## Current Upgrade Baseline

- VERIFIED BY CODE INSPECTION: there is currently no paywall, upgrade banner, entitlement check, or purchase entry point in the active repo.
- VERIFIED BY CODE INSPECTION: the existing product surfaces that could later host upgrade moments are:
  - `HomeView`
  - `NewStoryJourneyView`
  - `StorySeriesDetailView`
  - `ParentTrustCenterView`
  - a future completion/return surface that does not yet exist
- VERIFIED BY CODE INSPECTION: `VoiceSessionView` begins the live hybrid session immediately and is already part of the child runtime, so it is the wrong place for a first blocking upgrade prompt.
- VERIFIED BY TEST: existing UI coverage proves the child can move from home into story launch and session start, the parent gate is deliberate friction, and saved-series continuation is reachable from the library surface.
- PARTIALLY VERIFIED: the current product surfaces are clear enough to choose upgrade locations, but there is no implemented entitlement or cap messaging yet.

## Upgrade Entry Principles

- VERIFIED BY CODE INSPECTION: upgrades should be parent-managed by default.
- VERIFIED BY CODE INSPECTION: the first blocking checks should happen before cost-bearing runtime work begins.
- VERIFIED BY CODE INSPECTION: the child live session should stay upgrade-free once it has started.
- VERIFIED BY CODE INSPECTION: StoryTime should prefer contextual upgrade moments tied to value:
  - starting a new story
  - continuing a saved series
  - managing family setup in parent controls
  - future repeat-use completion loops
- VERIFIED BY CODE INSPECTION: trust surfaces should not overstate the lightweight `PARENT` gate as secure purchasing authentication.

## Entry-Point Decisions

### 1. First-run onboarding

- PARTIALLY VERIFIED: onboarding can carry light plan framing, but it should not be the first hard-blocking paywall in v1.
- VERIFIED BY CODE INSPECTION: onboarding should focus first on product promise, trust, child setup, and first-story expectations.
- Decision:
  - allow soft plan explanation only
  - allow restore-purchase or "learn about plans" access later
  - do not place a hard paywall before the parent even understands the product

### 2. HomeView

- VERIFIED BY CODE INSPECTION: `HomeView` is the first persistent product surface and can support non-blocking upgrade awareness.
- VERIFIED BY CODE INSPECTION: this is the right place for:
  - a parent-visible plan badge or summary
  - a non-blocking upgrade entry from the header or trust area
  - a future completion-return card if it routes back here
- Decision:
  - `HomeView` may host soft upgrade entry
  - `HomeView` should not be the first hard cap interruption for the child quick-start path by default

### 3. NewStoryJourneyView

- VERIFIED BY CODE INSPECTION: this is the primary preflight surface before StoryTime spends discovery, generation, narration, and revision cost.
- VERIFIED BY CODE INSPECTION: it already explains live processing, continuity, and length, which makes it the best place for explicit cap or plan messaging.
- Decision:
  - `NewStoryJourneyView` is the primary hard-gating surface for:
    - new story start limits
    - continuation-start limits
    - future length-based package messaging
  - if blocked, it should route to a parent-managed upgrade flow before `VoiceSessionView` is launched

### 4. StorySeriesDetailView

- VERIFIED BY CODE INSPECTION: saved-series continuation is a repeat-use value surface, and `New Episode` is a cost-bearing action while `Repeat` is primarily local replay behavior.
- VERIFIED BY CODE INSPECTION: this makes the detail screen a strong contextual upgrade surface.
- Decision:
  - `New Episode` may trigger an upgrade path when continuation entitlement is exhausted
  - `Repeat` should stay available even when paid usage is exhausted, consistent with `M8.2`
  - any upgrade prompt here should explain continuation value, not generic subscription copy

### 5. ParentTrustCenterView

- VERIFIED BY CODE INSPECTION: the parent hub is the correct parent-managed home for account-lite purchase surfaces because it is already where trust, privacy, deletion, and child management live.
- Decision:
  - `ParentTrustCenterView` should be the primary durable upgrade-management surface
  - later implementation can add:
    - current plan state
    - upgrade CTA
    - restore purchases
    - feature comparison
  - trust and privacy settings must remain accessible regardless of paid status

### 6. Completion and repeat-use loop

- PARTIALLY VERIFIED: there is no explicit completion product surface yet, but the saved-story persistence path already exists in the coordinator.
- Decision:
  - a future completion surface is a valid upgrade candidate
  - it should be used only after `M8.7` defines the completion loop clearly
  - it must stay parent-safe and should not interrupt the live child narrative before completion

## Parent-Managed Versus Child-Visible Rules

### Parent-managed by default

- VERIFIED BY CODE INSPECTION: these upgrade contexts should stay parent-managed:
  - onboarding plan explanation
  - parent controls upgrade entry
  - blocked new story start from `NewStoryJourneyView`
  - blocked continuation from `StorySeriesDetailView`
  - restore purchase and plan comparison flows

### Child-visible but non-blocking

- PARTIALLY VERIFIED: later implementation may allow light child-visible plan state in contextual surfaces if it is explanatory rather than transactional.
- Allowed examples:
  - a neutral "Ask a parent to unlock more stories" message
  - a parent-only button or route
- Not allowed:
  - direct child purchase CTA
  - manipulative countdowns, scarcity, or urgency copy

### Explicitly excluded child-visible blocking surfaces

- VERIFIED BY CODE INSPECTION: do not place blocking upgrade prompts inside:
  - `VoiceSessionView`
  - the live interruption path
  - mid-narration or answer-only interactions
  - the `ParentAccessGateView` itself

## Blocking Rules

- VERIFIED BY CODE INSPECTION: hard entitlement checks should run before realtime startup or story discovery begins.
- VERIFIED BY CODE INSPECTION: if a launch is blocked:
  - the child should not enter `VoiceSessionView`
  - the app should route to a parent-managed upgrade explanation
  - the current child and story context should remain visible so the parent understands what was attempted
- VERIFIED BY CODE INSPECTION: replay of already-saved content should remain available even if upgrade-only continuation or new-start counters are exhausted.
- PARTIALLY VERIFIED: the exact blocking copy belongs to later implementation milestones, but the control flow is now defined.

## Copy Principles

- VERIFIED BY CODE INSPECTION: copy should explain the specific blocked value, not sell a generic subscription.
- Recommended framing:
  - for launch caps: "This plan has reached today's new story limit."
  - for continuation caps: "This plan has reached its saved-series continuation limit."
  - for family limits: "This plan supports one child profile."
- VERIFIED BY CODE INSPECTION: copy must stay truthful about runtime behavior:
  - live questions happen before narration
  - raw audio is not saved
  - saved history stays local
  - the parent gate is lightweight friction, not secure identity
- VERIFIED BY CODE INSPECTION: copy should avoid making children responsible for purchase decisions.

## Prioritized Entry-Point Order

- VERIFIED BY CODE INSPECTION: the repo-fit order for upgrade surfaces is:
  1. `NewStoryJourneyView` hard gate for cost-bearing launch
  2. `StorySeriesDetailView` contextual continuation gate for `New Episode`
  3. `ParentTrustCenterView` durable upgrade-management surface
  4. `HomeView` soft awareness and later plan-state summary
  5. future completion loop after `M8.7`

## Surfaces That Should Stay Upgrade-Free

- VERIFIED BY CODE INSPECTION: keep these surfaces free of blocking upgrade UI:
  - `VoiceSessionView`
  - active interruption/revision flows
  - core trust and deletion controls
  - child replay of already-saved content
- PARTIALLY VERIFIED: home may later carry soft plan state, but it should not become an always-on intrusive marketing surface.

## Alignment Outcome

- VERIFIED BY CODE INSPECTION: StoryTime now has explicit upgrade-entry rules instead of an open-ended paywall question.
- VERIFIED BY CODE INSPECTION: pre-session and repeat-use surfaces are the right places for upgrade logic, not the live child session.
- PARTIALLY VERIFIED: the exact UI pattern for each surface is still open and belongs to later implementation milestones.
- UNVERIFIED: the final copy, visual hierarchy, and StoreKit-backed purchase flow because those are not yet implemented in the repo.

## Recommended Next Milestone

`M8.5 - Home and Library product polish pass`

Reason:
- `M8.1` through `M8.4` now define journeys, entitlement architecture, onboarding direction, and upgrade-entry rules.
- The next implementation step should apply that direction to `HomeView` and the saved-library surface without weakening child scoping, trust, or parent controls.
