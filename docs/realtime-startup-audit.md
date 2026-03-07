# Realtime Startup Audit

Date: 2026-03-06
Milestone: M1.1 - Realtime startup flow audit

## Scope

This audit covers the active non-mock startup path:
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Core/RealtimeVoiceClient.swift`
- `ios/StoryTime/Core/RealtimeVoiceBridgeView.swift`
- `backend/src/app.ts`
- `backend/src/services/realtimeService.ts`
- active iOS and backend startup-related tests

`tiny-backend/` is not part of this audit.

## Active Startup Sequence

1. `VoiceSessionView` calls `await viewModel.startSession()` from `.task`.
2. `PracticeSessionViewModel.handleStartRequested()` accepts startup only from `.idle`, `.completed`, or `.failed`.
3. The coordinator resets prior state, enters `.booting`, and chooses mock or realtime mode.
4. Realtime mode calls `APIClient.prepareConnection()` to pick a healthy backend base URL.
5. If needed, the client calls `APIClient.fetchVoices()`.
6. The client calls `APIClient.createRealtimeSession()`:
   - `APIClient.ensureSessionIdentity()` calls `POST /v1/session/identity` unless a cached session token already exists.
   - the client then calls `POST /v1/realtime/session` with `child_profile_id`, `voice`, and region `"US"`.
7. The backend `app.ts` validates install/session identity, request context, and schema, then `RealtimeService.issueSessionTicket()` returns:
   - signed realtime ticket
   - expiry
   - model
   - voice
   - transcription model
   - endpoint `/v1/realtime/call`
8. `PracticeSessionViewModel` calls `RealtimeVoiceClient.connect(baseURL:endpointPath:session:installId:)`.
9. `RealtimeVoiceClient` waits for bridge readiness from the hidden `WKWebView`.
10. The bridge JavaScript:
    - tears down any existing connection
    - requests microphone permission with `getUserMedia`
    - creates `RTCPeerConnection`
    - creates the `oai-events` data channel
    - creates a local SDP offer
    - posts `POST payload.callURL` with JSON `{ ticket, sdp }`
    - includes `x-storytime-install-id`
    - includes `x-storytime-session` only when `AppSession.currentToken` is non-empty
11. The backend `POST /v1/realtime/call` route validates the signed realtime ticket, forwards multipart text fields `sdp` and `session` to OpenAI `/v1/realtime/calls`, and returns `{ answer_sdp }`.
12. The bridge sets the remote description from `answer_sdp`.
13. The bridge waits for `pc.connectionState === "connected"` and posts `{ type: "connected" }` back into Swift.
14. `RealtimeVoiceClient.connect()` resumes.
15. `PracticeSessionViewModel` marks the voice session live and begins the launch flow:
    - replay mode starts narration immediately
    - new or extend mode starts discovery

## Active Contracts And Assumptions

- `VoiceSessionView.task` is the only active UI entrypoint for session startup.
- `PracticeSessionViewModel` assumes startup is complete only when `RealtimeVoiceClient.connect()` returns.
- `PracticeSessionViewModel` currently hardcodes realtime region `"US"` when requesting `/v1/realtime/session`.
- `APIClient` assumes `/v1/session/identity` exists unless the backend returns `404`, `405`, or `501`, in which case it falls back to provisional install-based auth.
- `RealtimeVoiceClient` assumes the backend session response endpoint can be converted into a usable call URL by either:
  - using it directly when it is absolute, or
  - appending it to the selected backend base URL when it is relative
- The hidden bridge assumes:
  - `bridge_ready` fires before `connect`
  - microphone permission is granted through the `WKWebView` delegate
  - `RTCPeerConnection.connectionState` will transition to `"connected"`
  - `/v1/realtime/call` returns JSON with `answer_sdp`
- The bridge HTML is loaded with a hardcoded base URL string `https://backend-brown-ten-94.vercel.app`, which is not derived from the active backend selection.
- Startup error presentation currently assumes `error.localizedDescription` is safe to show.

## Concrete Failing Or Fragile Branches Identified

### 1. Backend realtime upstream failure path is broken

File:
- `backend/src/services/realtimeService.ts`

Branch:
- `fetchOpenAIAnswerSdp()` when `openAIResponse.ok === false`

Problem:
- The code calls `loggerForContext(controller, undefined);` even though `loggerForContext` is not defined anywhere in the backend.
- On an upstream non-OK response from OpenAI, the backend will throw a `ReferenceError` before the intended `AppError("realtime_call_failed")` can be thrown.

Impact:
- This is a concrete startup failure path in the active realtime boot chain.
- It bypasses the intended safe backend error handling for `/v1/realtime/call`.
- It turns a controlled upstream failure into an unhandled backend error path.

### 2. Raw startup errors can still reach the UI

Files:
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`

Problem:
- `APIClient.validate()` throws `APIError.invalidResponse(statusCode:body:)` with the raw backend response body.
- `PracticeSessionViewModel.handleStartRequested()` and other request handlers pass `error.localizedDescription` directly into `failSession(...)`.

Impact:
- Raw backend or proxy payloads can still surface in the UI during startup failures.
- This directly conflicts with the program goal of safe user-facing errors.

### 3. Startup is coupled to hardcoded bridge and region assumptions

Files:
- `ios/StoryTime/Core/RealtimeVoiceClient.swift`
- `ios/StoryTime/Features/Story/PracticeSessionViewModel.swift`

Problem:
- The bridge HTML uses a hardcoded base URL string unrelated to the active backend chosen by `APIClient`.
- Realtime session creation hardcodes region `"US"` instead of deriving it from active policy.

Impact:
- Startup behavior depends on assumptions that are not owned by the backend session response.
- These assumptions are candidates for breakage across environments and deployment configurations.

### 4. Startup regression coverage is fragmented

Files:
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- `ios/StoryTime/Tests/APIClientTests.swift`
- `ios/StoryTime/Tests/RealtimeVoiceClientTests.swift`
- `backend/src/tests/app.integration.test.ts`
- `backend/src/tests/model-services.test.ts`

Problem:
- The repo has good unit and integration coverage for individual startup components.
- It does not yet have a focused milestone-level regression suite for the end-to-end startup sequence and its failure branches.

Impact:
- The next milestone should add targeted startup-path tests after the contract and failure handling are corrected.

## Existing Baseline Tests Relevant To Startup

iOS:
- `PracticeSessionViewModelTests.testStartSessionConnectsAndSpeaksOpeningQuestion`
- `RealtimeVoiceClientTests` connect payload, absolute endpoint, bridge-ready, disconnect, and error tests
- `APIClientTests` for session bootstrap, realtime session creation, legacy identity fallback, and session refresh

Backend:
- `app.integration.test.ts` for `/v1/session/identity`, `/v1/realtime/session`, and `/v1/realtime/call`
- `model-services.test.ts` for realtime ticket issuance, multipart SDP/session forwarding, retry, and invalid ticket rejection
- `auth-security.test.ts` for install/session token validation

## Handoff To M1.2

M1.2 should focus on the active startup contract, not broader session orchestration.

Ordered fix targets:
1. Remove the broken undefined `loggerForContext(...)` call and restore the intended safe `AppError` path for realtime upstream failures.
2. Confirm the exact `/v1/realtime/call` request and response contract across Swift, bridge JavaScript, backend route, and backend service.
3. Decide how bridge origin/base URL should be derived instead of relying on a hardcoded value.
4. Keep the active endpoint and SDP handling tests aligned while that contract is hardened.
