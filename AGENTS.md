# AGENTS.md

## Product Mission

StoryTime is a voice-first iOS app for generating child-safe personalized audio stories.

Active product loop:
1. A parent configures child profile and privacy defaults.
2. A child starts a new story or continues an existing story series.
3. The app collects a small number of live voice follow-up prompts.
4. The backend generates a structured story.
5. The app narrates the story scene by scene in a live voice session.
6. The child can interrupt during narration and ask for changes.
7. The backend revises only the remaining story scenes.
8. Story continuity is stored locally for future episodes.

The current mission is to harden this loop. Stability and correctness take priority over feature expansion.

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
- `VoiceSessionView` is a thin UI wrapper that starts the session and hosts a hidden `RealtimeVoiceBridgeView`.
- `PracticeSessionViewModel` is the active client session coordinator. It owns discovery, generation, narration, interruption, revision, completion, and persistence triggers.
- `VoiceSessionState` in `StoryDomain.swift` is the canonical client state model currently used by the coordinator.
- `RealtimeVoiceClient` uses a hidden `WKWebView` bridge to manage microphone capture, the WebRTC peer connection, data channel events, and `/v1/realtime/call` SDP exchange.
- `APIClient` handles backend base URL failover, session identity bootstrap, story endpoints, embeddings, and app install/session headers.
- `StoryLibraryStore` is the active local store for story series, child profiles, privacy settings, and continuity cleanup coordination. It currently persists large blobs in `UserDefaults`.
- The backend `app.ts` owns request context, auth/session identity, rate limiting, structured error responses, and the active HTTP routes.
- `RealtimeService` issues signed realtime tickets and proxies `/v1/realtime/call` to OpenAI.
- `StoryDiscoveryService`, `StoryService`, `StoryPlannerService`, and `StoryContinuityService` make up the active discovery, generation, revision, quality, and continuity pipeline.

## Current Program Priorities

- Stability
- Correctness
- Deterministic session behavior
- Voice startup reliability
- Safe error handling
- Local persistence integrity
- Child-profile data isolation
- Continuity integrity
- Privacy and data-flow truthfulness
- Production hardening
- Observability
- Test coverage

## Non-Goals

- UI polish
- Marketing or onboarding work
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
- All discovery, generation, narration, interruption, revision, and completion events must route through the coordinator.
- State transitions must be deterministic. Invalid transitions must fail safely and log context.
- Startup, interruption, revision, and completion side effects must be serialized.
- Do not reintroduce hidden state drift through extra booleans, parallel tasks, or callbacks that mutate UI state directly.
- Protect scene index continuity during revise-and-continue flows.
- Completion and save behavior must run once.
- Treat the hidden `WKWebView` bridge and `/v1/realtime/call` SDP contract as critical-path infrastructure. Changes to either side require coordinated client, backend, and test updates.

## Persistence And Data Integrity Rules

- `StoryLibraryStore` is the current active store, but its use of large serialized `UserDefaults` blobs is technical debt.
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
- If a change touches the bridge, update `RealtimeVoiceClientTests`.
- If a change touches API contract handling, update `APIClientTests` and backend route or service tests.
- If a change touches storage or child scoping, update `StoryLibraryStoreTests`.
- If a change spans client and backend, test both.

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
