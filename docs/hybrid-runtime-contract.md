# Hybrid Runtime Contract

## Purpose

StoryTime is moving from a mostly realtime-first narration loop to a hybrid runtime:

- realtime voice for live interaction
- TTS for long-form narration
- structured story and scene state as the authoritative control layer

This contract defines the boundary the next implementation milestones must preserve.

## Current Code Reality

- `VoiceSessionView` starts `PracticeSessionViewModel` and hosts the hidden realtime bridge.
- `PracticeSessionViewModel` already owns discovery, generation, narration, interruption, revision, completion, and save behavior.
- `StoryData` and ordered `StoryScene` arrays already provide the authoritative story structure.
- `currentSceneIndex` is already explicit in the coordinator.
- The current runtime still uses the realtime voice core for long-form narration through `speakAndAwaitCompletion(...)`.
- The current revision path already changes only future scenes by sending `completedScenes` and `remainingScenes` to `/v1/story/revise`.

## Authoritative Runtime Layers

### 1. Interaction mode

Used for:

- setup follow-up questions
- interruption intake during narration
- answer-only handling about the current story
- repeat/clarify handling
- revise-future-scenes requests

Transport rule:

- interaction mode uses realtime voice transport

Ownership rule:

- interaction does not own story progression
- interaction consumes authoritative story and scene state from the coordinator

### 2. Narration mode

Used for:

- long-form scene delivery
- scene-by-scene playback under coordinator control

Transport rule:

- long-form narration defaults to TTS
- realtime audio output is not the default narration path for new runtime work

Ownership rule:

- narration transport does not decide what scene comes next
- the coordinator and scene state decide playback order, pause/resume, and completion

### 3. Story and scene state

Authoritative inputs:

- generated `StoryData`
- ordered `StoryScene` list
- `currentSceneIndex`
- completed scene prefix
- remaining scene suffix

Authority rule:

- story and scene state decide resume boundaries
- completed scenes remain stable unless a later milestone explicitly widens scope
- future-scene revision starts from the current scene boundary and does not rewrite completed scenes

## Contract Types

The contract is now named in `StoryDomain.swift` with:

- `HybridRuntimeMode`
- `HybridInteractionPhase`
- `InterruptionIntent`
- `InterruptionIntentRouteDecision`
- `InterruptionIntentRouter`
- `NarrationResumeDecision`

These types are contract markers for upcoming implementation work. They do not yet replace the current coordinator state machine.

## Mode Mapping To Current Coordinator

- `VoiceSessionState.ready(.discovery)` and `VoiceSessionState.discovering(...)` map to interaction mode for setup follow-up
- `VoiceSessionState.narrating(sceneIndex:)` and `VoiceSessionState.paused(sceneIndex:)` map to narration mode
- `VoiceSessionState.interrupting(sceneIndex:)` maps to interaction intake during active story playback
- `VoiceSessionState.revising(sceneIndex:, ...)` maps to revise-future-scenes handling

Pause and resume are coordinator-owned narration controls inside the active scene boundary. They do not create a separate story-state authority layer or a new interaction mode.

Interruption handoff reuses the warm realtime interaction session. The coordinator must stop or tear down the active TTS playback task, preserve the current scene boundary, and move directly into interruption intake without reconnecting realtime.

The current `VoiceSessionState` remains the canonical runtime state until the later hybrid mode milestones land.

## Interruption Classification Contract

Every narration interruption must be classified before choosing the next path.

Current classifier rule:

- classification is local, deterministic, and transport-independent
- the router consumes trimmed transcript text plus authoritative scene state
- the router always returns explicit answer context
- revision requests return an explicit unavailable result when no future scenes remain
- the coordinator now consults the router at the interruption boundary before choosing any post-handoff path
- unsupported routes remain in interruption intake until their execution milestones land

### `answer_only`

Meaning:

- the child is asking about the current story or current scene
- no story mutation is needed

Rules:

- do not call future-scene revision
- do not regenerate the story
- answer from current story and scene context
- resume narration from the current scene boundary after the answer completes

### `revise_future_scenes`

Meaning:

- the child wants what happens next to change

Rules:

- revise only scenes after the current boundary
- completed scenes remain unchanged
- the current boundary scene remains unchanged unless a later milestone explicitly widens scope
- backend revision keeps using explicit preserved-scene and future-scene boundaries
- narration replays the current boundary scene, then continues into revised future scenes
- if no future scenes remain, the classifier still reports `revise_future_scenes` intent but marks revision unavailable for downstream handling

### `repeat_or_clarify`

Meaning:

- the child wants repetition, clarification, or a replay without changing future story structure

Rules:

- do not mutate future scenes
- do not call revision unless later classification changes
- replay or clarify from the current scene boundary

## Narration Resume Contract

The runtime must resume from an explicit scene boundary, never an implicit transport position.

Initial resume outcomes:

- `replayCurrentScene(sceneIndex:)`
  - used after answer-only or repeat/clarify handling
  - reuses existing future scenes

- `replayCurrentSceneWithRevisedFuture(sceneIndex:, revisedFutureStartIndex:)`
  - used after revise-future-scenes completes
  - preserves the current boundary scene
  - future scenes after the boundary are treated as replaced

- `continueToNextScene(sceneIndex:)`
  - used for normal scene completion without interruption
  - reuses existing future scenes

Coordinator rule:

- post-interruption narration resume must route through `NarrationResumeDecision`
- answer-only and repeat/clarify must use `replayCurrentScene(sceneIndex:)`
- revise-future-scenes must use `replayCurrentSceneWithRevisedFuture(sceneIndex:, revisedFutureStartIndex:)`
- resume decisions do not create new completion semantics; one-time completion/save protection remains coordinator-owned

## Backend And Client Contract Boundaries

### Setup interaction

- realtime session startup remains:
  - `POST /v1/session/identity`
  - `POST /v1/realtime/session`
  - `POST /v1/realtime/call`
- discovery remains scene-agnostic setup interaction

### Answer-only interaction

Initial contract boundary:

- answer-only should be satisfied from current story and scene context
- answer-only must not call `/v1/story/revise`
- any future backend/API surface for answer-only must preserve story immutability and explicit scene context
- current implementation satisfies answer-only locally from `StoryAnswerContext`, answers over the live interaction transport, and resumes narration from the same scene boundary

### Future-scene revision

Current contract now matches the target boundary:

- client sends the first mutable future `currentSceneIndex`
- client sends preserved scenes, including the current boundary scene
- client sends only future scenes in `remainingScenes`
- backend returns revised scenes from `revised_from_scene_index`
- client merges revision results as preserved scenes plus revised future scenes, then replays the current boundary scene

### Narration

Target contract:

- narration transport consumes scene text and authoritative scene index from the coordinator
- narration completion signals must not invent story progression; they only report transport completion for the active scene

## Explicit Non-Goals For M4.1

- no TTS pipeline implementation yet
- no interruption router implementation yet
- no answer-only backend feature build yet
- no pause/resume transport implementation yet
- no preload/cache implementation yet

## Next Milestones Enabled By This Contract

- `M4.2 - Mode transition state model`
- `M4.3 - Scene-state authority and revision boundary contract`
- `M4.4 - TTS narration pipeline`
- `M4.7b - Coordinator route-selection activation`
