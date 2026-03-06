# StoryTime Backend

Active backend for the StoryTime iOS app.

## Responsibilities

- Mint signed session identity tokens tied to app install IDs.
- Mint signed realtime tickets and proxy WebRTC SDP exchange.
- Run moderation for child input and generated output.
- Run discovery slot filling from live transcripts.
- Generate and revise stories.
- Create embeddings for on-device continuity retrieval.
- Emit structured analytics and in-process usage counters.
- Enforce rate limits, retries, timeouts, and region policy.

## Endpoints

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

## Local Run

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

## Test And Build

```bash
cd backend
npm run build
npm test
```

## Important Runtime Variables

Secrets:
- `OPENAI_API_KEY`
- `SESSION_SIGNING_SECRET`
- `AUTH_TOKEN_SECRET`

Region and auth policy:
- `ALLOWED_REGIONS`
- `DEFAULT_REGION`
- `API_AUTH_REQUIRED`
- `TRUST_PROXY`

Resilience and telemetry:
- `OPENAI_MAX_RETRIES`
- `OPENAI_RETRY_BASE_MS`
- `OPENAI_TIMEOUT_MS`
- `ENABLE_USAGE_METERING`
- `ENABLE_STRUCTURED_ANALYTICS`

See `.env.example` for the full active set.

## Deployment

### Vercel

```bash
cd backend
vercel deploy -y
```

### Render
Use the root `../render.yaml` Blueprint.
