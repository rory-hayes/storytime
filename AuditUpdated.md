# StoryTime Audit Update

Date: 2026-03-07
Audit type: Fresh current-state audit from source
Scope: Active iOS app in `ios/StoryTime` and active backend in `backend`
Excluded: `tiny-backend` archive

## Executive Summary

StoryTime is a voice-first iOS application for child-safe, personalized storytelling.

The current product loop is:

1. A parent manages child profiles and privacy defaults.
2. A child starts a new story or continues a previous series.
3. The app collects a few live voice inputs.
4. The backend generates a child-safe story.
5. The app narrates the story live.
6. The child can interrupt mid-story to change what happens next.
7. Completed stories and continuity memory are saved locally on the device for future sessions.

The product is functional end to end today, but it is still a single-device, pre-account, voice-session product. The largest current handoff risk is that the backend build passes, but the backend test suite is currently failing on 2 schema tests related to realtime SDP validation.

## What The Application Is For

This application is designed to give children live, personalized spoken story sessions while giving parents lightweight control over:

- which child profile is active
- age and sensitivity defaults
- preferred story mode
- story-history retention
- transcript clearing
- deletion of saved stories and profiles

The product is not a general reading app or audiobook library. It is a live interactive story session product with local history and continuity.

## Current Product Surface

### Primary users

- Child listener
- Parent or guardian

### Active code areas

- iOS app entry: `ios/StoryTime/App`
- Main screens: `ios/StoryTime/Features/Story` and `ios/StoryTime/Features/Voice`
- Voice bridge/runtime: `ios/StoryTime/Core`
- Local persistence: `ios/StoryTime/Storage`
- Backend routes: `backend/src/app.ts`
- Backend services: `backend/src/services`
- Internal audit docs: `docs/`

## Implemented Screens

The current user-facing screens implemented in the active iOS app are:

### 1. Home / Library

Purpose:

- landing screen
- shows active child
- shows privacy summary
- shows past saved story series
- launches new story flow
- opens parent flow

Main elements:

- `Parent` button
- active child card
- horizontal profile switcher when more than one child exists
- trust/privacy summary card
- past stories list
- inline `New Story` button
- floating `+` button

### 2. Parent Access Gate

Purpose:

- lightweight gating step before parent controls open

Current behavior:

- user must type `PARENT`
- button stays disabled until the text matches
- cancel returns to Home

This is a deliberate gate, but it is not secure authentication.

### 3. Parent Controls

Purpose:

- manage privacy settings
- manage child profiles
- manage safety defaults
- delete story history

Implemented controls:

- read-only raw-audio status label: raw audio is not saved
- `Save story history` toggle
- retention picker when history is enabled
- `Clear transcripts after each session` toggle
- child profile list
- active profile switching
- edit child profile
- add child profile
- delete child profile
- edit active child age
- edit active child sensitivity
- edit active child default mode
- delete all saved story history

### 4. Child Profile Editor

Purpose:

- create or edit a child profile

Implemented fields:

- name
- age
- sensitivity
- default story mode

### 5. New Story Journey

Purpose:

- configure a session before voice starts

Implemented controls:

- choose child profile
- choose story mode
- toggle `Use past story`
- toggle `Use old characters`
- pick a prior story when available for the selected child
- choose target length from 1 to 10 minutes
- review privacy copy
- review session preview
- launch voice session

### 6. Voice Session

Purpose:

- run the live story session

Implemented behaviors:

- boot realtime voice session
- show live status message
- show waveform
- show storyteller prompt
- show latest user transcript
- show generated story title once ready
- show current scene number
- narrate story scene by scene
- allow interruption during narration
- apply revision to only future scenes
- continue narration after revision
- show privacy summary and live-processing hint

### 7. Story Series Detail

Purpose:

- inspect a saved series and continue from it

Implemented behaviors:

- show series title
- show episode count
- show associated child profile
- show continuity metadata
- list saved episodes
- `Repeat` latest episode
- `New Episode`
- delete the full series

## Implemented Features And Functionality

### Story Modes

Implemented story modes:

- Classic
- Bedtime
- Calm
- Educational

Each mode has its own tone and lesson directives that feed story generation.

### Child Safety And Sensitivity

Implemented sensitivity levels:

- Standard
- Extra Gentle
- Most Gentle

These settings influence generation instructions and safety tone.

### Child Profiles

Implemented:

- multiple child profiles
- active profile switching
- per-child default mode
- per-child age
- per-child sensitivity
- per-child story scoping

Current constraint:

- maximum 3 child profiles

### Story History And Continuity

Implemented:

- saved series
- saved episodes inside a series
- per-series continuity metadata
- local continuity facts with embeddings
- repeat latest episode
- extend an existing series with a new episode
- replace an episode after revision in repeat mode
- delete one series
- delete all story history
- retention pruning

Continuity data currently includes:

- arc summary
- relationship facts
- favorite places
- unresolved threads
- recap and other engine metadata

### Voice Session Runtime

Implemented:

- health check before session startup
- session identity bootstrap
- voice list fetch
- realtime session ticket request
- WebRTC bridge startup
- startup error mapping to safe user-facing messages
- canonical session state machine
- discovery phase before story generation
- generation phase
- narration phase
- interruption phase
- revision phase
- completion persistence
- failure state
- API and session trace capture for diagnostics

The runtime is materially more mature than the older audit snapshot. The session model is now explicit and coordinated around a single event processor.

### Discovery Flow

Implemented:

- up to 3 follow-up discovery turns
- slot collection for story requirements
- moderation-aware discovery fallback replies
- direct generation when enough detail already exists
- support for extending an existing series with prior recap context

### Generation And Revision

Implemented:

- story generation from brief plus continuity
- scene-based story structure
- revision of only remaining scenes
- queued follow-up revision support
- replacement semantics for repeat-episode edits
- safe fallback copy when moderation blocks or softens output

### Privacy And Data Handling

Implemented and currently accurate:

- raw audio is not saved
- saved stories and continuity remain local on device after session completion
- live microphone audio leaves the device during realtime processing
- spoken prompts, discovery inputs, generation inputs, and revisions are sent over the network for processing
- `clear transcripts after each session` clears the local on-screen transcript state only

### Persistence

Current local persistence stack:

- Core Data backed by `storytime-v2.sqlite`

Stored locally:

- child profiles
- active child selection
- privacy settings
- story series
- story episodes
- continuity facts
- migration log

Compatibility behavior:

- legacy `UserDefaults` blobs are still migration sources
- `saveRawAudio` remains in the schema for compatibility, but is not an active product feature

### Backend Functionality

Current active backend endpoints:

- `GET /health`
- `GET /v1/voices`
- `POST /v1/session/identity`
- `POST /v1/realtime/session`
- `POST /v1/realtime/call`
- `POST /v1/moderation/check`
- `POST /v1/story/discovery`
- `POST /v1/story/generate`
- `POST /v1/story/revise`
- `POST /v1/embeddings/create`

What the backend currently does:

- validates request schemas
- resolves session and region context
- rate limits routes
- issues realtime tickets
- proxies the realtime SDP exchange
- moderates text input
- performs discovery turn analysis
- generates stories
- revises stories
- extracts and enriches continuity metadata
- creates embeddings for continuity retrieval
- records structured lifecycle and analytics events

## User Click Paths

### Path 1: Start A Brand-New Story

1. Open Home
2. Tap `New Story` or `+`
3. Review child, mode, options, and length in New Story Journey
4. Tap `Start Voice Session`
5. Answer live follow-up questions
6. App generates story
7. App narrates story
8. Story saves locally on completion if history is enabled

### Path 2: Start A New Episode In An Existing Series

1. Open Home
2. Tap a saved series card
3. Open Story Series Detail
4. Tap `New Episode`
5. Voice session starts with continuity context from the selected series
6. New episode is added to the existing series on completion

### Path 3: Repeat The Latest Episode

1. Open Home
2. Tap a saved series card
3. Open Story Series Detail
4. Tap `Repeat`
5. Voice session replays the latest saved episode
6. If revised during replay, the episode is replaced rather than appended

### Path 4: Start From A Previous Story During Journey Setup

1. Open Home
2. Tap `New Story` or `+`
3. In New Story Journey, enable `Use past story`
4. Pick a prior story if one exists for the selected child
5. Tap `Start Voice Session`
6. Session launches in extend mode with that series context

### Path 5: Parent Changes Privacy Or Child Settings

1. Open Home
2. Tap `Parent`
3. Type `PARENT`
4. Open Parent Controls
5. Change retention, transcript clearing, child profile data, or active child
6. Changes persist locally

### Path 6: Parent Deletes Story History

1. Open Home
2. Tap `Parent`
3. Type `PARENT`
4. Open Parent Controls
5. Tap `Delete All Saved Story History`
6. Confirm deletion
7. Local saved stories and continuity memory are removed

### Path 7: Parent Deletes A Single Series

1. Open Home
2. Tap a saved series card
3. Open Story Series Detail
4. Tap trash button
5. Confirm deletion
6. Series episodes and continuity metadata for that series are removed locally

## Current Gaps, Constraints, And Risks

These are the main gaps the incoming team should treat as current-state facts.

### 1. Backend test suite is not fully green

Fresh verification result:

- `backend`: build passes
- `backend`: test suite fails

Current failure:

- `backend/src/tests/types.test.ts`
- 2 failing tests
- both failures are around `RealtimeCallRequestSchema` rejecting SDP payloads that the tests expect to be accepted

Observed issue:

- `looksLikeSdp()` now requires both an `m=` line and `a=fingerprint:`
- the tests still expect looser SDP acceptance and byte-preservation behavior

Handoff implication:

- backend is compilable, but not in a clean verified state
- next team should resolve whether the schema tightened intentionally or the tests are stale

### 2. No account system or cloud sync

Not implemented:

- sign in
- multi-user accounts
- multi-device sync
- cloud backup of stories
- shared household state

Current product state is single-device local persistence.

### 3. Parent gate is lightweight only

Current gate:

- type `PARENT`

This is deliberate friction, not secure authentication, and not childproof in any strong sense.

### 4. No recorded-audio library

The product narrates story scenes live, but there is no saved library of recorded audio files for playback later.

`Repeat` uses saved story data, not stored voice recordings.

### 5. No playback transport controls

Not implemented:

- pause
- seek
- rewind
- resume from arbitrary timestamp

The voice experience is session-based rather than media-player-based.

### 6. `saveRawAudio` is not a real feature

The field still exists in the data model for compatibility, but there is no active UI or implementation path that stores raw audio.

This should not be described as a shipped feature.

### 7. Firebase is only initialized

Current Swift code shows:

- FirebaseCore configured at app launch

Not evident in active Swift code:

- Firebase Auth
- Firestore
- Analytics
- Crashlytics
- Remote Config

Handoff implication:

- Firebase is present as initialization/dependency, not as a confirmed active product feature set

### 8. Live processing still leaves the device

Current privacy position is narrower than a general "on-device" claim.

True today:

- raw audio is not saved
- saved history is local
- live audio and story-processing inputs still go over the network

Any handoff or product messaging should keep that distinction explicit.

### 9. Realtime disconnect recovery is limited

Current behavior:

- hard disconnect during session resolves to failure

Not implemented:

- robust reconnect
- seamless session recovery
- rejoin after transport interruption

### 10. Region support exists in backend but is not a user-facing app feature

Current state:

- backend supports `US` and `EU`
- client stores and uses resolved region
- no user-facing region selector exists in the iOS UI

### 11. Child-profile cap is hardcoded

Current limit:

- 3 child profiles

That is product logic, not just UI copy.

## Current Quality And Verification Status

Fresh verification run on 2026-03-07:

### Backend

- `npm run build`: passed
- `npm test`: failed
- Result: 79 passed, 2 failed, 81 total

Failing tests:

- `src/tests/types.test.ts`
- failure topic: realtime SDP schema validation

### iOS

Verification command:

- `xcodebuild test -project ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`

Result:

- passed
- 125 unit tests passed
- 6 UI tests passed

## Handover Recommendations

Recommended first actions for the incoming team:

1. Resolve the backend SDP schema test failure and align `looksLikeSdp()` with the intended realtime contract.
2. Decide whether the parent gate should remain lightweight or become actual protected access.
3. Decide whether the product remains single-device local-only or moves toward accounts and sync.
4. Audit Firebase usage and either implement the intended services or remove unnecessary dependency assumptions from handoff messaging.
5. Keep privacy copy narrowly accurate: local history is on device, live processing is networked.

## Bottom Line

StoryTime currently ships as a compact, working, voice-first iOS storytelling product with:

- parent-managed local privacy controls
- per-child personalization
- live voice discovery
- child-safe generation and revision
- local story history and continuity memory

The main current handoff caveat is not missing surface area in the app. It is that the repo now contains a real verification mismatch in the backend test suite, and the next team should treat that as an active issue at takeover time.
