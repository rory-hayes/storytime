# Privacy Data-Flow Audit

Status: Completed in `M3.5`
Date: 2026-03-07
Scope: Active iOS app in `ios/StoryTime` and active backend in `backend`. `tiny-backend/` is excluded.

## Summary

- Raw audio is not persisted in the active app or backend code, but live microphone audio does leave the device during realtime sessions.
- Saved story history and continuity are stored locally on device after completion, but live discovery prompts, generation inputs, revision inputs, and model outputs cross the network during processing.
- Current privacy copy is only partially truthful:
  - "Raw audio is not saved" is supported.
  - "Stories stay on device" is too broad for the active architecture.
  - "Clear transcripts after each session" only clears the local in-memory session transcript.
- `ParentPrivacySettings.saveRawAudio` is still present in persisted schema for compatibility, but there is no active UI control or behavior path that uses it.

## On-Device Persistence

Active primary local store:

- `storytime-v2.sqlite`
  - child profiles
  - active child selection
  - privacy settings
  - story series and episodes
  - continuity facts
  - migration log

Active bootstrap and identity storage in `UserDefaults`:

- `com.storytime.install-id`
- `com.storytime.session-token`
- `com.storytime.session-expiry`
- `com.storytime.session-id`
- legacy migration-source blobs such as `storytime.library.series.v1`, `storytime.child.profiles.v1`, and `storytime.parent.privacy.v1`

Not persisted in active code:

- raw microphone audio
- SDP offers or answers
- bridge audio levels
- live partial transcripts

Local transcript behavior:

- `PracticeSessionViewModel.applyTerminalTranscriptPolicy()` clears `latestUserTranscript` only when `clearTranscriptsAfterSession` is enabled.
- That setting does not delete already transmitted discovery or revision text from backend or model processing.

## Networked Data Flow

### Client To Backend

Every API request includes:

- `x-storytime-install-id`
- `x-storytime-client`
- `x-request-id`
- `x-storytime-session` after bootstrap succeeds

Startup and identity flow:

- `GET /health`
  - install ID and request ID are still sent by the client
- `GET /v1/voices`
  - install ID and request ID are sent
- `POST /v1/session/identity`
  - install ID is sent
  - backend returns `session_id`, `session_token`, and expiry
- `POST /v1/realtime/session`
  - child profile ID, voice, and region are sent
  - backend returns a signed realtime ticket

Story processing flow:

- `POST /v1/story/discovery`
  - child profile ID
  - live child transcript
  - slot state
  - mode
  - previous episode recap when continuing a series
- `POST /v1/story/generate`
  - child profile ID
  - age band
  - voice
  - length
  - story brief
  - continuity facts
- `POST /v1/story/revise`
  - story ID
  - story title
  - user update
  - completed scenes
  - remaining scenes
- `POST /v1/embeddings/create`
  - continuity fact strings for retrieval

### Realtime Audio Path

Realtime session setup:

- The `WKWebView` bridge calls `navigator.mediaDevices.getUserMedia(...)`.
- The bridge creates a browser `RTCPeerConnection`.
- The bridge sends only the SDP offer to `POST /v1/realtime/call` on StoryTime backend.
- The backend exchanges that offer with OpenAI and returns the answer SDP.

After SDP exchange:

- audio media and realtime data events flow over the WebRTC connection created by the bridge
- the backend is not in the live media path after call setup
- input transcription events and assistant audio events come back to the client over the realtime data or media channels

Implication:

- raw audio is not saved in active code
- raw audio is transmitted off device for live realtime processing

## Logging And Telemetry

Backend request context and logs include:

- request ID
- route
- region
- install hash
- session ID
- auth level

Backend analytics include:

- HTTP request metrics
- OpenAI usage metrics
- security events

Backend lifecycle logs include:

- realtime ticket issuance
- realtime call proxying
- discovery
- generation
- revision
- retry and failure metadata

Backend redaction and logging limits:

- `x-storytime-install-id`, `x-storytime-session`, auth headers, cookies, tickets, and tokens are redacted by `backend/src/lib/logger.ts`
- lifecycle logs intentionally avoid transcript text, story text, SDP bodies, and raw upstream response bodies

Client diagnostics include:

- per-request request IDs
- backend session ID
- operation names
- status codes
- session-state trace events

Client diagnostics do not intentionally log:

- transcript text
- story text
- raw audio

## Claim Review

| Claim | Current source | Audit result | Notes |
| --- | --- | --- | --- |
| "Raw audio is not saved." | `HomeView`, `NewStoryJourneyView`, `VoiceSessionView`, `ParentTrustCenterView` | Supported | No active raw-audio persistence path was found in client or backend code. |
| "Story prompts and generated stories are sent for live processing." | `HomeView`, `NewStoryJourneyView` | Supported | Discovery, generation, revision, and live session processing cross the network during the session. |
| "Saved stories and continuity stay on this device after the session ends." | `ParentTrustCenterView` | Supported | Saved history and continuity facts are stored locally after completion. |
| "The on-screen transcript clears when the session ends." | `PracticeSessionViewModel.privacySummary` | Supported with setting enabled | It clears the local in-memory session transcript, not already transmitted discovery or revision text. |
| "This removes all saved stories and local continuity memory on this device." | Parent deletion copy | Supported for local data | This is accurate for on-device saved story history and local continuity facts. |

## Privacy Copy Applied In M3.6

- Home, journey, voice, and parent-control copy now distinguish local saved history from live session processing.
- Raw-audio copy now states the active behavior directly: raw audio is not saved.
- Transcript-clearing copy now describes local on-screen transcript cleanup instead of implying network recall.
- `saveRawAudio` remains a compatibility-only schema field and is still a separate cleanup decision rather than a current user-facing setting.

## Follow-Up Milestones

- `M3.7 - Transport and config hardening`
- `M3.8 - Region handling alignment`
- `M3.9 - Lightweight parent access gate`
