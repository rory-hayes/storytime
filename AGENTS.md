# AGENTS.md

## Product Mission

StoryTime is a voice-first iOS app for generating child-safe personalized audio stories.

Product position:
- StoryTime lets kids shape the story while it's happening.

Active product loop:
1. A parent configures child profile and privacy defaults.
2. A child starts a new story or continues an existing story series.
3. The app collects a small number of live voice follow-up prompts in interaction mode.
4. The backend generates a structured scene-based story.
5. The app narrates the story scene by scene, with TTS as the target default for long-form narration and realtime reserved for live interaction.
6. The child can interrupt during narration to ask a question, ask for repetition or clarification, or change what happens next.
7. The runtime classifies interruptions before deciding whether to answer or revise, and any revision changes only future scenes unless a milestone explicitly widens scope.
8. Story continuity is stored locally for future episodes.

The hybrid runtime migration is materially stabilized, verified, and acceptance-hardened enough to support the next workstream. The productization groundwork is also complete enough to move into launch readiness. The current mission is to turn the verified runtime and M8 product direction into a launch-ready MVP with explicit onboarding, entitlement and billing foundations, parent-managed upgrade surfaces, enforceable usage limits, a coherent repeat-use loop, and evidence-backed launch acceptance criteria. Stability, correctness, low-latency interaction feel, deterministic session behavior, stage-level telemetry, and cost-aware routing remain gating requirements, but broad core-runtime rescue work is no longer the default next step unless a new defect is discovered.

## Active Code Areas

- Active iOS app: `ios/StoryTime`
- Active backend: `backend`
- Archived code: `tiny-backend/`

`tiny-backend/` is historical only. Do not use it for active planning, implementation, migrations, or tests unless the task explicitly asks for historical context.

Primary active iOS surfaces:
- `ios/StoryTime/Features/Story/HomeView.swift`
- `ios/StoryTime/Features/Story/NewStoryJourneyView.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `ios/StoryTime/Storage/StoryLibraryStore.swift`
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Core/RealtimeVoiceClient.swift`
- `ios/StoryTime/Core/RealtimeVoiceBridgeView.swift`
- `ios/StoryTime/Models/StoryDomain.swift`
- `ios/StoryTime/Models/Analysis.swift`

Primary active backend surfaces:
- `backend/src/app.ts`
- `backend/src/services/realtimeService.ts`
- `backend/src/services/storyDiscoveryService.ts`
- `backend/src/services/storyService.ts`
- `backend/src/services/storyPlannerService.ts`
- `backend/src/services/storyContinuityService.ts`
- `backend/src/lib/auth.ts`
- `backend/src/lib/security.ts`
- `backend/src/lib/requestContext.ts`
- `backend/src/lib/analytics.ts`
- `backend/src/lib/errors.ts`

Primary test surfaces:
- `ios/StoryTime/Tests`
- `backend/src/tests`

## Architecture Summary

- `HomeView` is the active iOS entry surface for child profile selection, privacy controls, saved stories, and the parent hub.
- `NewStoryJourneyView` builds the launch plan for a session, including child selection, mode, continuity reuse, and length.
- `VoiceSessionView` is a thin UI wrapper that starts the session and hosts the active transport surfaces. Today it hosts the hidden `RealtimeVoiceBridgeView` for live interaction while long-form scene narration runs through the coordinator-owned TTS transport.
- `PracticeSessionViewModel` is the active client session coordinator. It owns discovery, generation, narration, interruption, revision, completion, and persistence triggers, and it is the authority boundary for the active hybrid runtime split between interaction mode, narration mode, and story state.
- `VoiceSessionState` in `StoryDomain.swift` is the canonical client state model currently used by the coordinator. Structured story state and scene state are the authoritative control layer for runtime decisions.
- `RealtimeVoiceClient` uses a hidden `WKWebView` bridge to manage microphone capture, the WebRTC peer connection, data channel events, and `/v1/realtime/call` SDP exchange. It is the live interaction transport; long-form scene narration should stay on the TTS path unless a milestone explicitly says otherwise.
- `APIClient` handles backend base URL failover, session identity bootstrap, story endpoints, embeddings, and app install/session headers.
- `StoryLibraryStore` is the active local store for story series, child profiles, privacy settings, and continuity cleanup coordination. Primary story and continuity data now persist through the Core Data-backed `storytime-v2.sqlite` store; `UserDefaults` remains only for install/session bootstrap keys and legacy migration sources.
- The backend `app.ts` owns request context, auth/session identity, rate limiting, structured error responses, and the active HTTP routes.
- `RealtimeService` issues signed realtime tickets and proxies `/v1/realtime/call` to OpenAI.
- `StoryDiscoveryService`, `StoryService`, `StoryPlannerService`, and `StoryContinuityService` make up the active discovery, generation, revision, quality, and continuity pipeline. Backend generation and revision are already scene-based and should stay authoritative as narration transport changes.

## Current Program Priorities

- Launch readiness on top of the verified hybrid runtime and completed M8 productization groundwork
- MVP scope lock and explicit launch acceptance criteria
- Onboarding and first-run clarity
- Billing and entitlement implementation grounded in the active product architecture
- Parent-managed paywall and upgrade surfaces tied to real product moments
- Usage limits and plan enforcement before cost-bearing runtime work begins
- End-of-story repeat-use loop implementation and polish
- Cost, usage, and latency telemetry for commercial confidence
- Evidence-based launch-candidate QA
- Stability
- Correctness
- Deterministic session behavior
- Productization and monetization-aware UX on top of the verified hybrid runtime
- User-journey clarity across onboarding, launch, live session, saved stories, and parent controls
- Entitlement architecture and upgrade-flow planning grounded in real cost telemetry
- Parent trust and privacy communication as product flows, not isolated copy tweaks
- Low-latency live interaction feel
- Hybrid runtime separation between interaction, narration, and story state
- Voice startup reliability
- Cost-aware model routing
- Safe error handling
- Local persistence integrity
- Child-profile data isolation
- Continuity integrity
- Privacy and data-flow truthfulness
- Production hardening
- Observability
- Test coverage

## Non-Goals

- Broad core-runtime refactors without a reproduced defect or explicit reprioritization
- Speculative post-launch package expansion or growth experiments before MVP scope lock
- Marketing-site or acquisition work outside the in-app product flow
- New growth features
- Cloud sync
- Multi-device account systems
- Broad scope expansion

## Core Engineering Principles

- Inspect before editing. Read the active implementation first.
- Use the active codebase as the source of truth. If prompt and repo disagree, the repo wins.
- Preserve existing product behavior unless the milestone explicitly changes it.
- Prefer deterministic behavior over convenience or implicit fallback.
- Prefer narrow, milestone-scoped changes over broad refactors.
- Complete one milestone per run unless the milestone is explicitly split first in `SPRINT.md`.
- If a milestone is too large for one run, split it before implementing.
- Every milestone must include tests and status updates.

## Voice Session Rules

- `PracticeSessionViewModel` is the active client session coordinator. Do not bypass it with UI-only flags or transport-side side effects.
- `VoiceSessionState` in `StoryDomain.swift` is the canonical state model. Keep session states explicit and finite.
- All discovery, generation, narration, interruption, revision, answer, and completion events must route through the coordinator.
- Realtime voice is for live interaction. Do not treat it as the default long-form narration transport in new runtime work.
- TTS is the target default narration mechanism for long-form story delivery. Keep long-form narration scene-based and coordinator-owned.
- Story state and scene state are authoritative. Transport layers must consume coordinator state, not invent their own story progression.
- State transitions must be deterministic. Invalid transitions must fail safely and log context.
- Startup, interruption, revision, and completion side effects must be serialized.
- Do not reintroduce hidden state drift through extra booleans, parallel tasks, or callbacks that mutate UI state directly.
- Separate interaction mode from narration mode explicitly. Mode handoff rules must be testable and finite.
- Interruptions must be classified before deciding whether to answer, repeat, clarify, or revise.
- Answer-only interruptions must avoid unnecessary regeneration or future-scene revision.
- Revision must affect future scenes only unless a milestone explicitly defines an earlier-scene rewrite path and its protections.
- Protect scene index continuity during revise-and-continue flows.
- Resume narration only from an explicit scene boundary owned by story state.
- Completion and save behavior must run once.
- Treat the hidden `WKWebView` bridge and `/v1/realtime/call` SDP contract as critical-path infrastructure. Changes to either side require coordinated client, backend, and test updates.
- Cost-aware model routing is a product requirement. Runtime work must keep live interaction cheap and low latency where possible, and keep heavier model use scoped to the stages that need it.
- All runtime work must preserve determinism and a low-latency interaction feel.

## Persistence And Data Integrity Rules

- `StoryLibraryStore` is the current active store, and primary story plus continuity data should remain in the Core Data-backed v2 store.
- Legacy `UserDefaults` story blobs are migration-source technical debt only; do not treat them as an active primary store.
- New primary story storage must favor durable, queryable storage over large serialized blobs.
- Do not add more primary story or continuity storage to `UserDefaults`.
- Keep app install ID and session token handling separate from primary story storage decisions.
- Persistence changes must include migration, corruption handling, and cleanup behavior.
- Save, replace, delete, and retention flows must keep continuity data consistent with story data.
- Retention settings must actually remove the data they claim to remove.

## Child Safety And Privacy Rules

- Child safety is non-negotiable. Preserve moderation and content guardrails across discovery, generation, and revision.
- Child-profile scoping must be strict. No cross-child fallback visibility for saved stories or continuity data.
- Parent-facing privacy copy must match actual behavior exactly.
- Raw audio is not part of the active saved-story product. Do not introduce raw audio persistence or telemetry.
- Do not log raw audio, secrets, or unredacted child transcript content by default.
- Keep continuity facts safe, stable, and appropriate for retrieval across episodes.
- Treat the parent hub as a trust boundary. Any access control work there must be deliberate and testable.

## Error Handling Rules

- User-facing errors must be safe and concise.
- Never surface raw internal payloads, stack traces, or raw backend bodies directly in the UI.
- Distinguish cancellation from failure.
- Failures must leave the session in a valid terminal or recoverable state.
- Keep backend `AppError` public messages and client error mapping aligned.
- Log enough structured context for debugging without leaking sensitive content.

## Testing Rules

- Every milestone needs tests.
- Every bug fix needs a regression test.
- Do not mark a milestone done unless its required tests pass.
- If a change touches the realtime startup path, update client transport tests and backend realtime contract tests.
- If a change touches session coordination, update `PracticeSessionViewModelTests`.
- If a change touches narration transport, add or update deterministic narration transport tests at the coordinator boundary.
- If a change touches the bridge, update `RealtimeVoiceClientTests`.
- If a change touches API contract handling, update `APIClientTests` and backend route or service tests.
- If a change touches storage or child scoping, update `StoryLibraryStoreTests`.
- If a change touches interruption classification, answer-only behavior, or future-scene revision boundaries, test those coordinator paths explicitly.
- If a change spans client and backend, test both.

## Verification And Measurement Rules

- After hybrid stabilization, verification still matters, but productization and monetization-aware UX are now the default priority unless a new runtime defect is discovered.
- After the M8 groundwork, launch readiness is the default next workstream. Do not reopen broad foundational runtime work unless a new defect is reproduced and recorded in `PLANS.md`.
- Runtime verification reports must label each material behavior as `VERIFIED BY TEST`, `VERIFIED BY CODE INSPECTION`, `PARTIALLY VERIFIED`, or `UNVERIFIED`.
- Verification reports must record the exact commands, test files, docs, and code paths inspected, plus the remaining gaps that still need direct evidence.
- Telemetry milestones must keep runtime stages explicit where applicable. At minimum, preserve stage-based cost and latency attribution for `interaction`, `generation`, `narration`, and `revision`; document supporting stages separately instead of collapsing them into those four.
- Launch-readiness verification must explicitly cover onboarding, entitlement sync, pre-session gating, repeat-use loop behavior, privacy and trust language, and the final launch-candidate QA pass with exact commands and evidence labels.
- Do not default back into broad hybrid-runtime refactors once the baseline is stable; if a new defect is discovered, record it in `PLANS.md` and reprioritize explicitly in `SPRINT.md`.

## Productization, Launch Readiness, And Monetization Rules

- UX work must stay grounded in the current technical architecture: realtime for live interaction, TTS for long-form narration, and story/scene state as the authoritative control layer.
- After the productization groundwork is complete, launch readiness is the default priority. Prefer shipping clarity, enforceable MVP boundaries, and explicit acceptance evidence over speculative expansion.
- Treat onboarding, paywall, entitlements, usage limits, and telemetry as connected product systems. Do not treat them as isolated cosmetic screens or copy-only tasks.
- Monetization work must use model-routing economics and runtime-stage cost telemetry instead of arbitrary package or cap guesses.
- Onboarding, paywall, upgrade, and parent-trust work should be handled as end-to-end product flows across `HomeView`, `NewStoryJourneyView`, `VoiceSessionView`, `StorySeriesDetailView`, and the parent hub, not as isolated cosmetic screens.
- Prefer parent-managed upgrade entry points and trust-sensitive surfaces unless a milestone explicitly defines a child-facing prompt and its protections.
- Billing and provider choices must stay grounded in runtime-stage cost telemetry, pre-session enforcement needs, and truthful parent-managed trust surfaces.
- Final QA and launch-acceptance milestones must define what MVP-launch-ready means in repo terms, including exact commands, evidence labels, remaining gaps, and any go/no-go blockers.
- Verification remains required for productization work: planning milestones must cite repo evidence, and implementation milestones must update the directly affected UI/unit/backend tests as appropriate.

## Documentation And Status Update Rules

- After every run, update `PLANS.md`.
- After every run, update milestone status in `SPRINT.md`.
- Append to history in `PLANS.md`. Do not rewrite prior run entries.
- If session behavior changes, update any related session docs.
- If privacy behavior changes, update code, UI copy, and docs in the same run.
- Only change `AGENTS.md` when repo operating rules change.

## How To Use PLANS.md

- `PLANS.md` is the living status record.
- Read it before choosing work.
- Use it to understand the current phase, active risks, blockers, open decisions, and next recommended milestone.
- Append new completed-work entries after each run.

## How To Use SPRINT.md

- `SPRINT.md` is the execution queue.
- Work the first incomplete milestone unless a blocker or explicit reprioritization is recorded in `PLANS.md`.
- If a milestone is too large, split it into smaller milestones in `SPRINT.md` before editing code.
- Keep milestone status accurate: `TODO`, `IN PROGRESS`, `DONE`, or `BLOCKED`.

## Standard Codex Run Workflow

1. Read `AGENTS.md`, `PLANS.md`, and `SPRINT.md`.
2. Inspect the active code paths for the selected milestone.
3. Confirm scope and dependencies.
4. If the milestone is too large, split it first.
5. Implement one milestone or one explicitly split sub-milestone.
6. Run the required tests.
7. Update `PLANS.md` and `SPRINT.md`.
8. Report outcomes, risks, and remaining blockers.

## Scope Control Rules

- One milestone per run unless the milestone was explicitly split first.
- No unrelated refactors.
- No opportunistic UI redesign.
- No product-surface expansion unless the milestone explicitly requires it.
- Keep changes within the active app and backend.
- If a useful follow-up is discovered, record it in `PLANS.md` or `SPRINT.md` instead of expanding the current run.

## Forbidden Actions

- Do not use `tiny-backend/` for active implementation.
- Do not bypass the active session coordinator.
- Do not weaken child-profile isolation.
- Do not introduce new primary story storage in `UserDefaults`.
- Do not expose raw backend error bodies in the UI.
- Do not ship half-migrations without migration tests and cleanup behavior.
- Do not add scope outside the selected milestone.
- Do not mark milestones done without tests and status updates.

## Completion Checklist

- Active code inspected before editing
- One milestone completed or explicitly split
- Relevant tests run
- `PLANS.md` updated
- `SPRINT.md` updated
- Any related docs updated
- Risks and blockers recorded
- No unrelated scope added
