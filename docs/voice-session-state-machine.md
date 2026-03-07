# Voice Session State Machine

## State Model

The canonical runtime state now lives in `VoiceSessionState` and `ConversationPhase`.

- `idle`
- `booting`
- `ready(.discovery(stepNumber))`
- `discovering(turnID)`
- `generating`
- `narrating(sceneIndex)`
- `interrupting(sceneIndex)`
- `revising(sceneIndex, queuedUpdates)`
- `completed`
- `failed`

`PracticeSessionViewModel` is now the single session coordinator. Realtime callbacks, transcript events, discovery responses, generation responses, narration completions, and revision responses all route through one event processor instead of mutating unrelated flags.

## Major Risks Removed

- Removed hidden drift between `phase` and side-channel booleans like `pendingAssistantResponse`, `pendingNarrationInterruption`, `isRevisionInFlight`, and `queuedRevisionUpdate`.
- Discovery, generation, revision, and narration now use explicit request or utterance IDs so stale async completions cannot mutate the current session.
- Interruption during narration is serialized through `interrupting -> revising -> narrating`, and interruption during an in-flight revision is queued deterministically instead of starting concurrent revision calls.
- Scene continuity is preserved during revise-and-continue by revising `dropFirst(currentSceneIndex)` and resuming narration from the same scene index.
- Completion persistence is centralized and guarded so save/indexing runs once per session instead of on generate plus every revision.
- Invalid transitions are rejected safely and logged into `invalidTransitionMessages`.

## Known Edge Cases

- A repeat-episode revision now persists once at completion, not during the live revision step. This removes mid-session mutation races but means the library is only updated after the session finishes.
- The realtime bridge still depends on upstream `response.created` and `response.done` ordering to correlate utterance IDs. The client now maps those events explicitly, but if the transport stops emitting one of those events, completion falls back to timeout behavior.
- Voice transport errors still surface as session errors, and a hard disconnect moves the session to `failed`. More granular recovery could be added later, but it is not part of this refactor.
