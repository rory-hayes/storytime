# Archived Prototype: tiny-backend

This directory is archived.

It was an earlier minimal backend prototype built around three endpoints:
- `POST /analyzeSpeech`
- `GET /scenarios`
- `POST /sessionMetrics`

That shape does not match the active StoryTime product anymore.

## Status

- Not used by the current iOS app.
- Not used by the active Vercel deployment.
- No longer targeted by the root Render Blueprint.
- Kept only as historical reference while the repo transition settles.

## Active Paths Instead

- Active backend: `../backend`
- Active iOS app: `../ios/StoryTime`

## Do Not

- Do not add new endpoints here.
- Do not update deployment config to point back here.
- Do not treat this directory as the production backend.

If this historical prototype is no longer useful, remove it in a dedicated cleanup pass.
