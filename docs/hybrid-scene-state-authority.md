# Hybrid Scene-State Authority

## Purpose

This document defines the authoritative scene-state contract for the hybrid runtime.

It pins:

- how scene progress is represented
- what answer-only interactions may read
- what revise-future-scenes interactions may mutate
- where narration resumes after each interaction path

## Active Authority Rule

- `StoryData` remains the authoritative ordered scene list.
- `AuthoritativeStorySceneState` is the implementation-facing snapshot for the current narration boundary.
- The coordinator owns when this snapshot is created and advanced.
- Transport does not own scene progression.

## Authoritative Scene Snapshot

`AuthoritativeStorySceneState` is built from:

- `storyId`
- `storyTitle`
- `scenes`
- `currentSceneIndex`

From that snapshot, the contract exposes four distinct slices:

- `completedScenes`
  - `scenes.prefix(currentSceneIndex)`
  - these scenes are stable and already behind the active narration boundary
- `currentScene`
  - `scenes[currentSceneIndex]`
  - this is the active narration boundary scene
- `remainingScenes`
  - `scenes.suffix(from: currentSceneIndex)`
  - this includes the current scene plus later scenes
- `futureScenes`
  - `scenes.suffix(from: currentSceneIndex + 1)`
  - this excludes the current boundary scene and includes only what happens next

## Resume Boundary Rule

The current boundary is represented by `StorySceneBoundary`:

- `sceneIndex`
- `sceneId`

Narration always resumes from an explicit boundary, never an implicit playback offset.

## Answer-Only Contract

`StoryAnswerContext` is a read-only projection of authoritative scene state.

It includes:

- the current boundary
- completed scenes
- the current scene
- remaining scenes
- future scenes

Mutation rule:

- `answerOnly` uses `StorySceneMutationScope.none`
- it may reference story state for context
- it must not change future scenes

Resume rule:

- answer-only resumes with `replayCurrentScene(sceneIndex:)`

## Revise-Future-Scenes Contract

`StoryRevisionBoundary` exists only when there is at least one future scene after the current boundary.

It includes:

- `resumeBoundary`
  - the current scene that remains stable
- `preservedScenes`
  - `completedScenes + currentScene`
- `futureScenes`
  - only scenes after the current boundary
- `mutationScope`
  - `futureScenes(startingAt: currentSceneIndex + 1)`

Mutation rule:

- revise-future-scenes preserves all completed scenes
- revise-future-scenes preserves the current boundary scene
- revise-future-scenes mutates only scenes after the current boundary

Resume rule:

- revision resumes with `replayCurrentSceneWithRevisedFuture(sceneIndex:, revisedFutureStartIndex:)`
- the child hears the current boundary scene from the top again
- subsequent scenes may be replaced by the revision result

## Backend Request Mapping

`StoryRevisionBoundary.makeRequest(userUpdate:)` maps the hybrid contract onto the existing client/backend revise request shape:

- `current_scene_index`
  - first mutable future scene index
- `completed_scenes`
  - all preserved scenes, including the current boundary scene
- `remaining_scenes`
  - only future scenes after the current boundary

This keeps the wire shape stable while making the hybrid mutation boundary explicit.

Runtime activation rule:

- the live revise path must build its request from `StoryRevisionBoundary.makeRequest(userUpdate:)`
- revision results must merge as `preservedScenes + revisedFutureScenes`
- the coordinator resumes from the preserved current boundary scene after revision resolves

## Final-Scene Rule

If the current scene is already the final scene:

- `futureScenes` is empty
- `revisionBoundary` is `nil`

That means a child interruption at the final scene should route to answer-only or repeat/clarify, not revise-future-scenes, unless a later milestone explicitly widens mutation scope.
