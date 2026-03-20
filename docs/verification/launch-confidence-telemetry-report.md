# Launch-Confidence Telemetry Report

Date: 2026-03-20
Milestone: M9.11 - Telemetry durability and joined launch-report hardening

## Scope

This report verifies that the repo's launch telemetry now survives process restarts or app reloads and can be inspected through one joined backend-plus-client report shape. It stays scoped to telemetry durability, joined reporting, and verification evidence. It does not widen into dashboards, alerting, or post-launch BI tooling.

Primary code paths inspected:
- `backend/src/lib/env.ts`
- `backend/src/lib/analytics.ts`
- `backend/src/app.ts`
- `ios/StoryTime/Networking/APIClient.swift`
- `ios/StoryTime/Features/Voice/VoiceSessionView.swift`

Primary tests and verification artifacts inspected:
- `backend/src/tests/request-retry-rate.test.ts`
- `backend/src/tests/app.integration.test.ts`
- `ios/StoryTime/Tests/APIClientTests.swift`
- `ios/StoryTime/Tests/PracticeSessionViewModelTests.swift`
- `ios/StoryTime/Tests/SmokeTests.swift`
- `docs/verification/runtime-stage-telemetry-verification.md`
- `docs/verification/launch-candidate-acceptance-report.md`

## Commands Executed

Backend telemetry durability slice:

```bash
cd /Users/rory/Documents/StoryTime/backend && npm test -- --run src/tests/request-retry-rate.test.ts src/tests/app.integration.test.ts
```

Observed result:
- `38` tests passed

Client telemetry durability and joined-report slice:

```bash
xcodebuild test -project /Users/rory/Documents/StoryTime/ios/StoryTime/StoryTime.xcodeproj -scheme StoryTime -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:StoryTimeTests/APIClientTests/testClientLaunchTelemetryCapturesEntitlementAndParentManagedSurfaceEvents -only-testing:StoryTimeTests/APIClientTests/testClientLaunchTelemetryPersistsAcrossStoreReload -only-testing:StoryTimeTests/APIClientTests/testFetchLaunchTelemetryReportJoinsBackendAndPersistedClientTelemetry
```

Observed result:
- `3` tests passed

## Concrete Reporting Surfaces

### 1. Durable backend launch report

- VERIFIED BY TEST: `backend/src/tests/request-retry-rate.test.ts` now proves `AnalyticsSink` reloads persisted counters and per-session summaries from disk.
- VERIFIED BY TEST: `backend/src/tests/app.integration.test.ts` now proves `/health` still exposes launch telemetry after the in-memory analytics state is reset and the app is recreated against the same `ANALYTICS_PERSIST_PATH`.
- VERIFIED BY CODE INSPECTION: `backend/src/lib/analytics.ts` persists `AnalyticsReport` state to `ANALYTICS_PERSIST_PATH`, and `backend/src/app.ts` reloads that state during app creation before `/health` returns `analytics.report()`.

### 2. Durable client launch report

- VERIFIED BY TEST: `ios/StoryTime/Tests/APIClientTests.swift` now proves `ClientLaunchTelemetry` survives store replacement and reload when backed by `UserDefaults`.
- VERIFIED BY CODE INSPECTION: `ClientLaunchTelemetry` persists its `ClientLaunchTelemetryReport` under `com.storytime.client-launch-telemetry.v1`, reloads that report at initialization, and keeps the durable report shape aligned with the in-memory one.

### 3. Joined backend-plus-client launch report

- VERIFIED BY TEST: `ios/StoryTime/Tests/APIClientTests.swift` now proves `APIClient.fetchLaunchTelemetryReport()` joins backend `/health` telemetry with the persisted client launch-telemetry report in one `LaunchTelemetryJoinedReport`.
- VERIFIED BY CODE INSPECTION: `BackendHealthEnvelope` now decodes `telemetry`, `APIClienting` exposes `fetchLaunchTelemetryReport()`, `APIClient` returns the joined report, and the UI-test wrapper plus test doubles conform to the same surface without changing production behavior.

## Verification Findings

### 1. Backend launch telemetry now survives backend restarts

- VERIFIED BY TEST: persisted backend analytics survive an in-memory reset and an app recreation when the same `ANALYTICS_PERSIST_PATH` is used.
- VERIFIED BY CODE INSPECTION: request metrics, OpenAI usage, security events, and launch events all flow through the same persisted `AnalyticsReport`.

### 2. Client launch telemetry now survives app-side reloads

- VERIFIED BY TEST: the client launch-telemetry report persists across store reload and restore in the targeted `APIClientTests` slice.
- VERIFIED BY CODE INSPECTION: persistence is tied to `UserDefaults` and stores only redacted counters, session summaries, and event metadata.

### 3. The repo now has one joined launch-report surface

- VERIFIED BY TEST: `LaunchTelemetryJoinedReport` returns:
  - backend default region and allowed regions
  - backend counters and per-session summaries from `/health`
  - client counters, per-session summaries, and ordered launch events from `ClientLaunchTelemetry.report()`
- VERIFIED BY CODE INSPECTION: the joined report stays read-only and verification-oriented; it does not upload client telemetry back to the backend or introduce raw content logging.

### 4. Redaction and child-safety boundaries remain intact

- VERIFIED BY CODE INSPECTION: the persisted backend and client reports are still limited to counters, routes, durations, launch-event names, block reasons, upgrade surfaces, tiers, and remaining counters.
- VERIFIED BY CODE INSPECTION: no raw transcript text, story text, or raw audio was added to telemetry persistence or the joined report.

## Remaining Gaps

- VERIFIED BY TEST and VERIFIED BY CODE INSPECTION: narration playback wall-clock timing is now covered through the targeted coordinator evidence recorded in `docs/verification/runtime-stage-telemetry-verification.md`.
- UNVERIFIED: centralized historical aggregation across multiple devices or backend deployments; the joined report is durable enough for repo verification, but it is not a broader ops warehouse or dashboard.
- PARTIALLY VERIFIED: the joined launch report remains launch-review oriented and still does not export full per-scene runtime-stage timelines alongside the durable launch counters.
