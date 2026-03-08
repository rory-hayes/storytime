# Monetization And Entitlement Architecture

Date: 2026-03-08
Milestone: M8.2 - Monetization model and entitlement architecture

## Scope

This document defines the first repo-grounded monetization model and entitlement architecture for StoryTime. It stays architecture-first and does not widen into StoreKit implementation, paywall UI, or onboarding design execution.

Primary code and docs inspected:
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `ios/StoryTime/Networking/APIClient.swift`
- `backend/src/lib/analytics.ts`
- `docs/productization-user-journey-alignment.md`
- `docs/verification/runtime-stage-telemetry-verification.md`
- `docs/verification/parent-child-storytelling-ux-audit.md`
- `AuditUpdated.md`

## Commands Executed

No new test commands were run in this milestone.

This was an architecture-and-planning pass grounded in current repo code, telemetry definitions, existing automated coverage, and prior verification artifacts.

## Current Monetization Baseline

- VERIFIED BY CODE INSPECTION: the active repo has no StoreKit, subscription, paywall, purchase, or entitlement implementation yet.
- VERIFIED BY CODE INSPECTION: the current runtime has measurable cost-bearing stages for `interaction`, `generation`, `narration`, and `revision`, with supporting-stage measurement for `continuity_retrieval`.
- VERIFIED BY CODE INSPECTION: `HomeView`, `NewStoryJourneyView`, `VoiceSessionView`, `StorySeriesDetailView`, and the parent hub are the real product surfaces later monetization work must plug into.
- VERIFIED BY CODE INSPECTION: `VoiceSessionView` starts the live session immediately when launched, so entitlement enforcement that happens after session start would create child-facing failure at the wrong moment.
- VERIFIED BY CODE INSPECTION: replaying an already-saved story is primarily local-device behavior, while starting a new story or continuing a saved series triggers new remote processing cost.
- VERIFIED BY CODE INSPECTION: the current parent hub already contains one hard product cap, `V1 supports up to 3 child profiles.`
- VERIFIED BY TEST: existing UI coverage proves the active product journey and parent gate are real and stable enough to anchor monetization planning.
- PARTIALLY VERIFIED: stage telemetry exists, but the repo still lacks pricing-confidence thresholds and a joined session-cost export.

## Architecture Decision

- VERIFIED BY CODE INSPECTION: the repo is best served by a split entitlement model:
  - StoreKit 2 on device is the purchase truth.
  - a backend-issued entitlement snapshot is the runtime enforcement truth for expensive flows.
- VERIFIED BY CODE INSPECTION: this split fits the current product better than backend-only ownership because StoryTime has no account system or multi-device sync product today.
- VERIFIED BY CODE INSPECTION: this split fits the current runtime better than device-only gating because the backend is the component that actually spends model cost on discovery, generation, revision, embeddings, and realtime session setup.

Implementation direction:
- The client should resolve active purchases locally from StoreKit 2 and normalize them into a small repo-owned entitlement shape.
- The backend should accept that normalized purchase state, verify it as appropriate, and issue a short-lived signed entitlement snapshot that travels with the existing session/bootstrap model.
- Expensive launch paths should consume the backend snapshot, not raw StoreKit state, when deciding whether a new story start or continuation can proceed.

## Package Boundary Direction

### Recommended v1 package shape

- VERIFIED BY CODE INSPECTION: StoryTime should start with two product tiers, not a large package matrix:
  - `Starter`
  - `Plus`

### Starter

- VERIFIED BY CODE INSPECTION: `Starter` should preserve the core promise that kids can shape the story while it is happening.
- VERIFIED BY CODE INSPECTION: `Starter` should allow:
  - one child profile
  - bounded new story starts in a rolling period
  - bounded saved-series continuation starts in a rolling period
  - replay of already-saved stories
  - parent controls, privacy settings, and local deletion controls
- VERIFIED BY CODE INSPECTION: `Starter` should not depend on a minute-based meter as the primary cap, because the repo does not yet measure narration playback wall-clock well enough for a user-facing minute promise.

### Plus

- VERIFIED BY CODE INSPECTION: `Plus` should unlock:
  - up to the current v1 app cap of three child profiles
  - higher or uncapped new story starts
  - higher or uncapped saved-series continuation
  - the full repeat-use continuity loop as a normal product feature
  - later parent-managed premium surfaces defined in `M8.4`

### Boundaries to avoid in v1

- VERIFIED BY CODE INSPECTION: do not put the first paywall inside `VoiceSessionView` after a child session has already started.
- VERIFIED BY CODE INSPECTION: do not monetize privacy or deletion controls; those are trust features, not upsell features.
- PARTIALLY VERIFIED: do not use narration minutes as the first user-facing package meter until the repo has stronger playback-duration measurement.

## Capability Model

- VERIFIED BY CODE INSPECTION: the entitlement shape should be capability-based instead of screen-based.

Recommended normalized entitlement snapshot:

```text
EntitlementTier
- starter
- plus

EntitlementSnapshot
- tier
- source
- maxChildProfiles
- maxStoryStartsPerPeriod
- maxContinuationsPerPeriod
- maxStoryLengthMinutes
- canReplaySavedStories
- canStartNewStories
- canContinueSavedSeries
- effectiveAt
- expiresAt
- usageWindow
- remainingStoryStarts
- remainingContinuations
```

Recommended source values:
- `storekit_verified`
- `debug_seed`
- `none`

Recommended gating semantics:
- new story start and saved-series continuation are separate counters
- replay stays allowed even when paid usage is exhausted
- story length is a secondary cost lever, not the primary v1 monetization lever

## Client Touchpoints

- VERIFIED BY CODE INSPECTION: `HomeView` should eventually display light product state, but it should not become the first runtime enforcement point.
- VERIFIED BY CODE INSPECTION: `NewStoryJourneyView` is the correct preflight gate for new story starts, continuation starts, and future length-based cap messaging because it already owns the launch plan before `VoiceSessionView` begins live transport.
- VERIFIED BY CODE INSPECTION: `StorySeriesDetailView` is the correct continuation-focused upgrade context for saved-series value, but the actual paywall rules belong to `M8.4`.
- VERIFIED BY CODE INSPECTION: `ParentTrustCenterView` is the correct parent-managed location for subscription status, restore purchases, and plan explanation once those surfaces exist.
- VERIFIED BY CODE INSPECTION: `VoiceSessionView` should remain a child-first session surface and should not be the normal place where monetization blocks first appear.

Recommended client components for later implementation:
- `EntitlementManager`
  - refresh StoreKit state
  - cache the latest normalized snapshot
  - expose parent-safe gating info to SwiftUI
- launch preflight in `NewStoryJourneyView`
  - ask for current entitlement status before setting `shouldStart = true`
  - surface parent-managed upgrade routing if blocked
- parent-managed entitlement management entry
  - likely from `HomeView` and `ParentTrustCenterView`

## Backend Touchpoints

- VERIFIED BY CODE INSPECTION: the backend already has session identity, request context, analytics, and rate-limit infrastructure that can host entitlement enforcement without inventing an unrelated backend shell.

Recommended backend additions for later implementation:
- `POST /v1/entitlements/sync`
  - accepts normalized client purchase state
  - verifies and returns a signed entitlement snapshot
- `POST /v1/entitlements/preflight`
  - accepts the launch intent:
    - new story
    - continue story
    - requested length
    - child profile count context
  - returns allowed or blocked with remaining counters
- session bootstrap enrichment
  - include current entitlement summary in `/v1/session/identity` or a sibling bootstrap response so the client can render cached product state without starting a live session

Enforcement rule:
- VERIFIED BY CODE INSPECTION: the backend should enforce cost-bearing caps before realtime boot or story discovery begins, not after a child session is already in progress.

## Pricing-Confidence Gaps

- PARTIALLY VERIFIED: the repo can measure stage group usage, but it still lacks a durable joined export that explains per-session total cost across on-device and backend work.
- PARTIALLY VERIFIED: the repo can measure TTS preparation timing, but not full narration playback wall-clock, so narration-minute pricing would be weakly grounded today.
- PARTIALLY VERIFIED: the repo does not yet summarize cost by session shape:
  - brand-new story
  - saved-series continuation
  - interruption-heavy session
  - revision-heavy session
- UNVERIFIED: final numeric caps for story starts, continuation starts, or length limits.
- UNVERIFIED: final price points, billing cadence, and regional pricing.

## Recommended Product Rules For Later Milestones

- VERIFIED BY CODE INSPECTION: keep the first upgrade prompts parent-managed by default.
- VERIFIED BY CODE INSPECTION: do not interrupt an in-progress child story with a hard paywall.
- VERIFIED BY CODE INSPECTION: use pre-session and repeat-use surfaces as the first upgrade moments:
  - onboarding or first-run parent flow
  - `NewStoryJourneyView`
  - saved-series continuation
  - parent controls
  - a later explicit completion loop
- PARTIALLY VERIFIED: `HomeView` may show plan state or upgrade explanation, but exact prompt hierarchy should stay for `M8.4` and `M8.5`.

## Alignment Outcome

- VERIFIED BY CODE INSPECTION: StoryTime now has a repo-fit entitlement architecture direction instead of an abstract monetization TODO.
- VERIFIED BY CODE INSPECTION: the first monetization boundaries should be launch-count and continuation-count based, with child-profile count as an additional family-plan lever.
- PARTIALLY VERIFIED: exact numeric package caps remain open because the repo has telemetry structure but not yet pricing-confidence thresholds.
- UNVERIFIED: final paywall design, StoreKit product catalog, and onboarding framing because those belong to later milestones.

## Recommended Next Milestone

`M8.3 - Onboarding and first-run flow audit and direction`

Reason:
- `M8.2` now defines the entitlement owner, gating point, and likely package-boundary levers.
- The next step is to decide how first-time parents should understand trust, value, and future upgrade context before the first story starts.
