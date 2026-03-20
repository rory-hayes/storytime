# Launch Readiness Gap Assessment

Date: 2026-03-20

## Scope

- What was inspected:
  - Repo control files: `AGENTS.md`, `PLANS.md`, `SPRINT.md`, `AuditUpdated.md`
  - Primary iOS product surfaces: `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `ios/StoryTime/App/ContentView.swift`
  - Entitlement and telemetry code: `ios/StoryTime/Networking/APIClient.swift`, `backend/src/app.ts`, `backend/src/lib/env.ts`
  - Relevant tests: `ios/StoryTime/UITests/StoryTimeUITests.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`, `backend/src/tests/app.integration.test.ts`, `backend/src/tests/request-retry-rate.test.ts`
  - Recent verification and product docs: `docs/verification/launch-candidate-acceptance-report.md`, `docs/verification/launch-confidence-telemetry-report.md`, `docs/verification/runtime-stage-telemetry-verification.md`, `docs/verification/realtime-voice-determinism-report.md`, `docs/verification/parent-child-storytelling-ux-audit.md`, `docs/onboarding-first-run-audit.md`, `docs/launch-mvp-scope-and-acceptance-checklist.md`, `docs/monetization-entitlement-architecture.md`, `docs/paywall-upgrade-entry-strategy.md`, `docs/end-of-story-repeat-use-loop.md`
- What was not inspected:
  - Every backend generation, moderation, and continuity implementation detail
  - App Store Connect product configuration, production billing setup, or any live provider dashboard
  - Full fresh reruns of the launch suite in this assessment pass
- Limitations of the assessment:
  - This pass is primarily code inspection plus review of existing verification artifacts.
  - Conclusions are strongest where recent tests and verification reports already exist in the repo.
  - Conclusions are weaker where launch behavior depends on code paths that are present but not re-executed in this run, especially commercial upgrade completion.

## Current Product Summary

StoryTime currently presents a parent-led first-run onboarding flow, a parent-managed home surface, a pre-session story setup journey, a live voice session that uses realtime for short interaction and coordinator-owned TTS for long-form narration, a saved-story detail flow with replay and continuation, and a parent trust surface for privacy, deletion, child-profile management, and plan-state review. Story state and scene state remain authoritative in `PracticeSessionViewModel`, interruptions are routed through explicit answer-only or future-scene revision decisions, and replay plus saved continuity stay local to the device. The repo also includes entitlement bootstrap, entitlement sync, backend preflight enforcement, restore handling, launch telemetry, and recent verification artifacts. The main missing product system is a real parent-managed purchase completion flow that can turn a blocked review into an actual upgrade.

## Assessment By Category

### Product Flow Completeness

- First-run onboarding and parent handoff
  - Current state: implemented. `ContentView` routes fresh installs into `FirstRunOnboardingView`, which explains trust and privacy, confirms a fallback child profile, and hands off into the first story setup flow.
  - Evidence: `ios/StoryTime/App/ContentView.swift`, `ios/StoryTime/Features/Story/HomeView.swift`, `StoryTimeUITests.testFreshInstallShowsParentLedOnboardingFlow`, `StoryTimeUITests.testOnboardingHandsOffToFirstStorySetupAndStaysDismissedAfterRelaunch`
  - Status: COMPLETE
  - Notes: Repo evidence supports a parent-led first-run without putting purchase friction inside the child session.

- Home, saved-library, and parent entry flow
  - Current state: implemented. `HomeView` exposes active-child selection, saved stories, privacy framing, and the parent access gate into `ParentTrustCenterView`.
  - Evidence: `ios/StoryTime/Features/Story/HomeView.swift`, `StoryTimeUITests.testPrivacyCopyReflectsLiveProcessingAndLocalRetention`
  - Status: COMPLETE
  - Notes: Copy is explicit that raw audio is not saved and that parent controls are the management boundary.

- New story setup and blocked-launch handling
  - Current state: implemented for both allowed and blocked paths. `NewStoryJourneyView` performs entitlement preflight before launch and routes blocked starts into `JourneyUpgradeReviewView`.
  - Evidence: `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `StoryTimeUITests.testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview`, backend `/v1/entitlements/preflight` tests in `backend/src/tests/app.integration.test.ts`
  - Status: PARTIALLY COMPLETE
  - Notes: The flow correctly prevents expensive work before session start, but the blocked path ends in review plus routing to parent controls rather than a full purchase completion path.

- Voice session, narration, interruption, and revision flow
  - Current state: implemented and well verified. `VoiceSessionView` remains a thin wrapper around the session coordinator. `PracticeSessionViewModel` keeps realtime interaction separate from long-form TTS narration and applies revision only to future scenes.
  - Evidence: `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `PracticeSessionViewModelTests.testPausedNarrationHandsOffToInteractionWithoutReconnect`, `PracticeSessionViewModelTests.testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly`, `PracticeSessionViewModelTests.testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes`
  - Status: COMPLETE
  - Notes: This is the strongest part of the current repo state.

- End-of-story repeat-use loop
  - Current state: implemented. Finished sessions surface replay, new episode, and library return actions.
  - Evidence: `ios/StoryTime/Features/Voice/VoiceSessionView.swift`, `docs/end-of-story-repeat-use-loop.md`, `StoryTimeUITests.testVoiceSessionShowsCompletionLoopAfterStoryFinishes`
  - Status: COMPLETE
  - Notes: Repeat use is present and does not move the first upgrade prompt into the child completion acknowledgement.

- Saved-series continuation surface
  - Current state: implemented for replay and continuation gating. `StorySeriesDetailView` keeps replay available even when the plan blocks a new episode.
  - Evidence: `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`, `StoryTimeUITests.testSeriesDetailBlocksNewEpisodeAndKeepsReplayTruthful`
  - Status: PARTIALLY COMPLETE
  - Notes: The blocked continuation path is truthful and parent-managed, but like the journey block flow it stops at review rather than purchase completion.

- Parent controls, trust, and local data management
  - Current state: implemented. `ParentTrustCenterView` supports plan-state review, restore, privacy settings, retention toggles, child-profile management, and deletion of local story history.
  - Evidence: `ios/StoryTime/Features/Story/HomeView.swift`, `StoryTimeUITests.testParentControlsShowCurrentPlanAndRestoreEntry`, `StoryTimeUITests.testParentControlsGateAddChildWhenPlanLimitIsReached`
  - Status: PARTIALLY COMPLETE
  - Notes: Privacy and management are present, but plan management still lacks a direct purchase path.

### Monetization And Commercial Readiness

- Pricing and plan surfaces
  - Current state: Starter and Plus are named and summarized in `ParentTrustCenterView`, `JourneyUpgradeReviewView`, and `SeriesDetailUpgradeReviewView`.
  - Evidence: `ios/StoryTime/Features/Story/HomeView.swift`, `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`, `ios/StoryTime/Features/Story/StorySeriesDetailView.swift`
  - Status: PARTIALLY COMPLETE
  - Notes: The repo can explain plans and limits, but not complete an upgrade.

- Entitlement model and enforcement
  - Current state: implemented. StoreKit-backed purchase-state normalization, entitlement bootstrap, backend sync, and preflight gating are present.
  - Evidence: `ios/StoryTime/Networking/APIClient.swift`, `ios/StoryTime/Tests/APIClientTests.swift`, `backend/src/tests/app.integration.test.ts`, `backend/src/lib/env.ts`
  - Status: COMPLETE
  - Notes: The enforcement architecture is repo-real, not just planned.

- Limits and pre-session enforcement
  - Current state: implemented. Child-profile count, story starts, continuations, and story-length caps are represented in the entitlement snapshot and enforced before realtime or discovery begins.
  - Evidence: `backend/src/lib/env.ts`, `backend/src/tests/app.integration.test.ts`, `StoryTimeUITests.testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview`, `StoryTimeUITests.testSeriesDetailBlocksNewEpisodeAndKeepsReplayTruthful`
  - Status: COMPLETE
  - Notes: This materially reduces cost risk at launch.

- Billing integration
  - Current state: foundations exist, purchase completion does not. The repo can restore purchases and sync current entitlements, but there is no visible product catalog, purchase CTA, or `Product.purchase()` path.
  - Evidence: `ParentTrustCenterView` exposes `Refresh Plan Status` and `Restore Purchases` only; `StoreKitEntitlementStateProvider` reads `Transaction.currentEntitlements`; `docs/paywall-upgrade-entry-strategy.md` still marks the final StoreKit-backed purchase flow as unimplemented and `UNVERIFIED`
  - Status: MISSING
  - Notes: This is the clearest commercial launch gap.

- Upgrade points and parent-managed routing
  - Current state: implemented in principle. Blocked journey and continuation flows route to parent-managed review, and the live child session remains free of upgrade UI.
  - Evidence: `JourneyUpgradeReviewView`, `SeriesDetailUpgradeReviewView`, `ParentTrustCenterView`, `StoryTimeUITests.testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview`
  - Status: PARTIALLY COMPLETE
  - Notes: The routing is correct, but the destination is incomplete because it does not close the upgrade loop.

- Usage and cost visibility
  - Current state: partially implemented. The repo exposes remaining starts and continuations to parents and records launch telemetry plus runtime-stage telemetry for verification.
  - Evidence: `ParentTrustCenterView`, `docs/verification/launch-confidence-telemetry-report.md`, `docs/verification/runtime-stage-telemetry-verification.md`
  - Status: PARTIALLY COMPLETE
  - Notes: Visibility is good enough for internal verification, but not yet a polished parent-facing usage dashboard.

### Runtime And Operational Readiness

- Hybrid runtime stability
  - Current state: strongly evidenced by recent verification artifacts and tests. Realtime remains limited to live interaction, TTS remains the long-form narration default, and state is coordinator-owned.
  - Evidence: `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`, `docs/verification/realtime-voice-determinism-report.md`, `docs/verification/launch-candidate-acceptance-report.md`
  - Status: COMPLETE
  - Notes: The current architecture matches the stated product and runtime position.

- Interruption and revision behavior
  - Current state: implemented and covered. Answer-only handling, pause or resume behavior, and future-scene revision boundaries are explicit.
  - Evidence: `PracticeSessionViewModel.swift`, `PracticeSessionViewModelTests` interruption and resume tests, `docs/verification/realtime-voice-determinism-report.md`
  - Status: COMPLETE
  - Notes: This is a launch strength.

- Observability and telemetry
  - Current state: materially improved. Backend launch telemetry now persists, client launch telemetry persists locally, and narration playback telemetry records start, completion, and cancellation wall-clock timing.
  - Evidence: `docs/verification/launch-confidence-telemetry-report.md`, `docs/verification/runtime-stage-telemetry-verification.md`, `APIClient.swift`, `PracticeSessionViewModel.swift`
  - Status: PARTIALLY COMPLETE
  - Notes: The repo still lacks a durable per-scene runtime timeline export and broader operational aggregation.

- Regression coverage
  - Current state: strong for the active product loop. The repo contains targeted UI, unit, and backend integration coverage for onboarding, blocked launches, repeat-use, entitlement routes, and hybrid runtime determinism.
  - Evidence: `StoryTimeUITests.swift`, `APIClientTests.swift`, `PracticeSessionViewModelTests.swift`, `backend/src/tests/app.integration.test.ts`, `docs/verification/launch-candidate-acceptance-report.md`
  - Status: COMPLETE
  - Notes: This assessment did not rerun the full suite, so confidence relies on existing March 2026 evidence.

- Failure handling and safe fallback
  - Current state: implemented. Startup and session failures are mapped into explicit session states and concise user-facing errors; blocked commercial flows stop before the child session starts.
  - Evidence: `PracticeSessionViewModel.swift`, `APIClient.swift`, `docs/verification/realtime-voice-determinism-report.md`
  - Status: COMPLETE
  - Notes: Failure handling looks launch-appropriate from the inspected paths.

### Privacy / Trust / Safety Readiness

- Privacy copy accuracy
  - Current state: strong and repo-grounded. Home, onboarding, voice session, and parent controls all describe local storage versus live processing in aligned terms.
  - Evidence: `ios/StoryTime/Features/Story/HomeView.swift`, `docs/onboarding-first-run-audit.md`, `StoryTimeUITests.testPrivacyCopyReflectsLiveProcessingAndLocalRetention`
  - Status: COMPLETE
  - Notes: Copy explicitly says raw audio is not saved.

- Parent gate clarity
  - Current state: implemented and honest. The `PARENT` gate is framed as lightweight friction rather than secure purchase authentication.
  - Evidence: `ParentAccessGateView` copy in `HomeView.swift`, `docs/launch-mvp-scope-and-acceptance-checklist.md`
  - Status: COMPLETE
  - Notes: Truthfulness is good; security strength is intentionally limited.

- Deletion and retention communication
  - Current state: implemented. Parent controls describe local deletion scope and device-local continuity removal, with retention toggles and destructive confirmations.
  - Evidence: `ParentTrustCenterView` in `HomeView.swift`
  - Status: COMPLETE
  - Notes: This matches the current local-first data model.

- Live processing communication
  - Current state: implemented. Parent controls and onboarding explain that microphone audio, prompts, generation, and revisions go live during a session.
  - Evidence: `HomeView.swift`, `docs/onboarding-first-run-audit.md`, `StoryTimeUITests.testPrivacyCopyReflectsLiveProcessingAndLocalRetention`
  - Status: COMPLETE
  - Notes: This is materially better than many products at the same stage.

- Child safety and broader trust evidence
  - Current state: partially evidenced in this assessment. The repo still appears to preserve child-safe routing and parent-managed boundaries, but this pass did not re-audit the full moderation and content-safety backend.
  - Evidence: architecture rules in `AGENTS.md`, parent-managed surfaces in the iOS code, recent verification docs
  - Status: PARTIALLY COMPLETE
  - Notes: Trust copy is strong; end-to-end safety verification beyond the inspected paths should not be overclaimed.

## Launch Blockers

1. There is no implemented parent-managed purchase completion flow for blocked upgrade moments.
   - Evidence: `JourneyUpgradeReviewView` and `SeriesDetailUpgradeReviewView` only route to `ParentTrustCenterView`; `ParentTrustCenterView` exposes plan review, refresh, and restore, but no purchase CTA or product selection.
   - Why this blocks launch: for a commercial MVP with Starter and Plus positioning, parents can be told that upgrades exist but cannot complete one in-app.

2. The repo lacks an end-to-end verified upgrade happy path from blocked preflight to successful entitlement unlock.
   - Evidence: current tests cover blocked routing, restore entry, entitlement sync, and preflight enforcement, but not a fresh purchase flow that clears a block and retries successfully.
   - Why this blocks launch: commercial gating is only half-closed. The enforcement side exists, but the recovery path is not repo-proven.

## Important But Non-Blocking Gaps

1. The durable joined launch report still does not export a per-scene runtime timeline. Evidence: `docs/verification/runtime-stage-telemetry-verification.md`.
2. Launch telemetry is verification-friendly but not yet a broader operational dashboard or warehouse. Evidence: `docs/verification/launch-confidence-telemetry-report.md`.
3. Parent plan visibility exists, but parent-facing usage summaries are still functional rather than polished. Evidence: `ParentTrustCenterView`.
4. The lightweight `PARENT` gate is honest but intentionally not a strong account or purchase-auth boundary. Evidence: `ParentAccessGateView` copy and launch-scope docs.
5. Child comprehension of the current cueing and interruption language is evidenced by UI presence and test coverage, not by fresh user research in this pass. Evidence: `docs/verification/parent-child-storytelling-ux-audit.md`.

## Post-Launch / Deferrable Items

1. Stronger parent authentication or account-linked management beyond the lightweight `PARENT` gate.
2. Durable cross-runtime telemetry aggregation and dashboarding outside repo-owned verification reports.
3. Lower-level device audio-route latency measurement beyond coordinator-observed playback timing.
4. Additional plan merchandising, pricing experimentation, or growth-oriented upgrade polish after the core purchase loop works.

## MVP Launch Recommendation

CONDITIONALLY READY IF BLOCKERS ARE CLOSED

The core child-facing product loop appears materially launch-capable: onboarding exists, parent trust copy is accurate, session architecture matches the intended hybrid runtime, runtime determinism is strongly evidenced, repeat use is present, and entitlement enforcement is real. However, the repo is not yet fully commercially launch-ready because blocked upgrade paths stop at plan review and restore rather than an actual purchase completion flow, and there is no end-to-end verified upgrade happy path. If StoryTime were launching as a locked non-commercial or manually provisioned MVP, the current repo would be close. For the stated launch-readiness mission with parent-managed upgrade surfaces and billing foundations, the remaining commercial blockers should be closed first.

## Recommended Next Sprint

1. `M10.1 - Parent-managed purchase surface closure`
   - Goal: implement the smallest truthful in-app purchase path inside parent-managed surfaces only.
   - Rough order: first.
2. `M10.2 - Upgrade unblock happy-path verification`
   - Goal: prove that a blocked story start or blocked continuation can succeed after purchase or entitlement refresh without leaking purchase UI into the child session.
   - Rough order: second.
3. `M10.3 - Commercial launch rerun and blocker closeout`
   - Goal: rerun the launch-readiness verification pack with the commercial blockers closed and record a fresh launch recommendation.
   - Rough order: third.

## Confidence And Evidence Notes

- Strongly evidenced conclusions:
  - onboarding, blocked preflight routing, repeat-use loop, privacy copy, entitlement enforcement, restore entry, and hybrid runtime behavior
  - basis: current iOS UI tests, current unit and backend tests, and recent verification reports from March 2026
- More inspection-driven conclusions:
  - absence of a real purchase CTA or product selection flow
  - incompleteness of the parent-managed upgrade destination
  - lack of a verified post-purchase unblock path
- Caution:
  - this report does not re-run the full launch suite
  - this report does not inspect external billing configuration or live production operations
  - the earlier `docs/verification/launch-candidate-acceptance-report.md` recorded a `GO` outcome for a more narrowly locked scope; this assessment is intentionally stricter about commercial launch closure
