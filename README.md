# StoryTime

StoryTime is a voice-first iOS app for kid-safe personalised audio stories.

The active product is:
- `ios/StoryTime`: SwiftUI iOS client for story library, voice sessions, continuity memory, and narration.
- `backend`: TypeScript/Express backend for signed session identity, Realtime/WebRTC proxying, moderation, story discovery, story generation, revision, embeddings, and observability.

Archived prototype:
- `tiny-backend`: historical prototype from the earlier 3-endpoint backend concept. It is not part of the active StoryTime architecture and should not receive new work.

## Current Architecture

### iOS app
- SwiftUI application.
- Live voice flow via Realtime/WebRTC bridge.
- Local story library and continuity memory on device.
- Server-issued session token persisted locally and reused on API calls.

### Backend
- Express API in `backend/src`.
- Signed install/session identity.
- Scoped rate limiting.
- Region-aware request policy (`US`, `EU`).
- OpenAI retries, timeouts, structured analytics, and usage metering.
- Secure Realtime call proxy so OpenAI secrets never ship in the app.

## Active Backend APIs

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

## Local Development

### Backend

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

### iOS app

```bash
cd ios/StoryTime
open StoryTime.xcodeproj
```

The backend `.env.example` documents the active runtime variables, including session signing, auth token signing, region policy, retries, and telemetry toggles.

## Deployment

### Vercel
- Active config: `backend/vercel.json`
- Current production alias used by the app: `https://backend-brown-ten-94.vercel.app`

### Render
- Active Blueprint: `render.yaml`
- Root blueprint now targets `backend`, not `tiny-backend`.

## Repo Rules

- Build new backend work in `backend/`.
- Treat `tiny-backend/` as archived reference only.
- If the archived prototype is no longer needed, remove it in a dedicated cleanup pass rather than reviving it implicitly.
