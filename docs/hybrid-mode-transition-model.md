# Hybrid Mode Transition Model

## Purpose

This document turns the hybrid runtime contract into an explicit mode graph for later implementation milestones.

It does not change the active runtime yet. It defines the allowed handoffs the coordinator must preserve when TTS narration and interruption routing land.

## Active Authority Rule

- `VoiceSessionState` remains the active coordinator state model today.
- `HybridRuntimeStateNode` is the explicit hybrid mode graph derived from the current coordinator.
- The hybrid mode graph exists to pin allowed mode handoffs before transport changes begin.

## Hybrid Mode Nodes

- `setupInteraction(stepNumber:)`
  - live follow-up questions before narration begins
- `narration(sceneIndex:)`
  - long-form scene playback under authoritative scene control
- `interruptionIntake(sceneIndex:)`
  - child interruption captured at the current narration boundary
- `answerOnly(sceneIndex:)`
  - non-mutating answer path about the current story
- `reviseFutureScenes(sceneIndex:)`
  - mutating path for changing what happens next
- `repeatOrClarify(sceneIndex:)`
  - non-mutating repeat or clarify path
- `completed`
- `failed`

## Mapping From Current Coordinator State

- `VoiceSessionState.ready(.discovery(stepNumber:))` -> `setupInteraction(stepNumber:)`
- `VoiceSessionState.narrating(sceneIndex:)` -> `narration(sceneIndex:)`
- `VoiceSessionState.paused(sceneIndex:)` -> `narration(sceneIndex:)`
- `VoiceSessionState.interrupting(sceneIndex:)` -> `interruptionIntake(sceneIndex:)`
- `VoiceSessionState.revising(sceneIndex:, ...)` -> `reviseFutureScenes(sceneIndex:)`
- `VoiceSessionState.completed` -> `completed`
- `VoiceSessionState.failed` -> `failed`

Current coordinator states such as `idle`, `booting`, `discovering`, and `generating` do not yet project to a hybrid mode node because they sit outside the active interaction-versus-narration split.

Pause and resume are explicit coordinator states and controls, but they stay inside the same hybrid narration node because story authority remains at the current scene boundary.

## Allowed Transition Graph

### Setup interaction

- `setupInteraction(stepNumber:)` -> `setupInteraction(stepNumber:)`
  - allowed when moving to the next follow-up step
- `setupInteraction(stepNumber:)` -> `narration(sceneIndex:)`
  - allowed when setup is complete and narration begins
- `setupInteraction(stepNumber:)` -> `failed`

### Narration

- `narration(sceneIndex:)` -> `interruptionIntake(sceneIndex:)`
  - allowed when the child interrupts
- this handoff may begin from either active playback or coordinator-paused playback because both states share the same narration node
- the handoff reuses the already-connected realtime interaction transport rather than reconnecting the session
- `narration(sceneIndex:)` -> `narration(nextSceneIndex)`
  - allowed on normal scene completion when another scene remains
- `narration(sceneIndex:)` -> `completed`
  - allowed on final scene completion
- `narration(sceneIndex:)` -> `failed`

### Interruption intake

- `interruptionIntake(sceneIndex:)` -> `answerOnly(sceneIndex:)`
- `interruptionIntake(sceneIndex:)` -> `reviseFutureScenes(sceneIndex:)`
- `interruptionIntake(sceneIndex:)` -> `repeatOrClarify(sceneIndex:)`
- `interruptionIntake(sceneIndex:)` -> `failed`

No narration resume is allowed directly from interruption intake. The interruption must be classified first.

### Answer-only

- `answerOnly(sceneIndex:)` -> `narration(sceneIndex:)`
  - only via `replayCurrentScene(sceneIndex:)`
- `answerOnly(sceneIndex:)` -> `failed`

Answer-only does not mutate future scenes.

### Revise-future-scenes

- `reviseFutureScenes(sceneIndex:)` -> `narration(sceneIndex:)`
  - only via `replayCurrentSceneWithRevisedFuture(sceneIndex:, revisedFutureStartIndex:)`
- `reviseFutureScenes(sceneIndex:)` -> `failed`

Revision preserves the current scene boundary and changes only later future scenes. Completed scenes remain stable.

### Repeat or clarify

- `repeatOrClarify(sceneIndex:)` -> `narration(sceneIndex:)`
  - only via `replayCurrentScene(sceneIndex:)`
- `repeatOrClarify(sceneIndex:)` -> `failed`

Repeat or clarify does not mutate future scenes.

### Terminal states

- `completed` and `failed` have no outgoing hybrid mode transitions

## Invalid Transition Rules

The following are explicitly invalid:

- routing an interruption while still in `narration(...)`
- resuming narration before interruption classification
- using `replayCurrentSceneWithRevisedFuture(...)` for `answerOnly(...)`
- using `replayCurrentScene(...)` for `reviseFutureScenes(...)`
- starting new narration from `completed` or `failed`

Invalid transitions must fail safely and remain visible in coordinator logging when later milestones wire the mode graph into runtime behavior.

## Terminal Behavior Expectations

- `completed` is final for the active session
- `failed` is final for the active session
- neither terminal node may re-enter narration or interaction without a fresh session start

## Why This Exists Before TTS

The repo still uses realtime audio output for long-form narration today. This transition model exists first so later milestones can move narration to TTS, interruption to realtime interaction, and answer/revision routing into explicit coordinator-owned paths without inventing a second hidden state machine.
