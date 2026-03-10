import XCTest
@testable import StoryTime

final class APIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.storytime.session-token")
        defaults.removeObject(forKey: "com.storytime.session-expiry")
        defaults.removeObject(forKey: "com.storytime.session-id")
        defaults.removeObject(forKey: "com.storytime.session-region")
        defaults.removeObject(forKey: "com.storytime.entitlements.bootstrap.v1")
    }

    override func tearDown() {
        URLProtocolStub.reset()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.storytime.session-token")
        defaults.removeObject(forKey: "com.storytime.session-expiry")
        defaults.removeObject(forKey: "com.storytime.session-id")
        defaults.removeObject(forKey: "com.storytime.session-region")
        defaults.removeObject(forKey: "com.storytime.entitlements.bootstrap.v1")
        super.tearDown()
    }

    func testPrepareConnectionFallsBackToHealthyBaseURLAndCachesIt() async throws {
        let session = makeSession()
        let first = URL(string: "https://one.example.com/")!
        let second = URL(string: "https://two.example.com/")!
        var requests: [String] = []

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            requests.append(url.absoluteString)
            if url.host == "one.example.com" {
                throw URLError(.cannotConnectToHost)
            }

            return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])
        }

        let client = APIClient(baseURLs: [first, second], session: session, installId: "install-123")

        let resolved = try await client.prepareConnection()
        let cached = try await client.prepareConnection()

        XCTAssertEqual(resolved, second)
        XCTAssertEqual(cached, second)
        XCTAssertEqual(requests.filter { $0 == "https://one.example.com/health" }.count, 1)
        XCTAssertEqual(requests.filter { $0 == "https://two.example.com/health" }.count, 2)
    }

    func testFetchVoicesFallsBackOnDecodeError() async throws {
        let session = makeSession()
        let first = URL(string: "https://one.example.com/")!
        let second = URL(string: "https://two.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-install-id"), "install-xyz")
            if url.host == "one.example.com" {
                return Self.rawResponse(url: url, statusCode: 200, body: "not-json")
            }

            return try Self.httpResponse(url: url, statusCode: 200, json: ["language": "en", "voices": ["alloy", "verse"]])
        }

        let client = APIClient(baseURLs: [first, second], session: session, installId: "install-xyz")
        let voices = try await client.fetchVoices()

        XCTAssertEqual(voices, ["alloy", "verse"])
    }

    func testBootstrapSessionIdentityStoresSessionToken() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(url.path, "/v1/session/identity")
            XCTAssertEqual(request.httpMethod, "POST")
            return try Self.httpResponse(
                url: url,
                statusCode: 200,
                json: ["session_id": "session-1", "region": "EU"],
                headers: [
                    "x-storytime-region": "EU",
                    "x-storytime-session": "signed-session-token",
                    "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                ]
            )
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        try await client.bootstrapSessionIdentity(baseURL: baseURL)

        XCTAssertEqual(AppSession.currentToken, "signed-session-token")
        XCTAssertEqual(AppSession.currentSessionId, "session-1")
        XCTAssertEqual(AppSession.currentRegion, .eu)
    }

    func testBootstrapSessionIdentityStoresEntitlementSnapshot() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(url.path, "/v1/session/identity")
            return try Self.httpResponse(
                url: url,
                statusCode: 200,
                json: [
                    "session_id": "session-entitlements-1",
                    "region": "US",
                    "entitlements": [
                        "snapshot": [
                            "tier": "starter",
                            "source": "none",
                            "max_child_profiles": 1,
                            "max_story_starts_per_period": NSNull(),
                            "max_continuations_per_period": NSNull(),
                            "max_story_length_minutes": NSNull(),
                            "can_replay_saved_stories": true,
                            "can_start_new_stories": true,
                            "can_continue_saved_series": true,
                            "effective_at": effectiveAt,
                            "expires_at": expiresAt,
                            "usage_window": [
                                "kind": "rolling_period",
                                "duration_seconds": NSNull(),
                                "resets_at": NSNull()
                            ],
                            "remaining_story_starts": NSNull(),
                            "remaining_continuations": NSNull()
                        ],
                        "token": "signed-entitlement-token",
                        "expires_at": expiresAt
                    ]
                ],
                headers: [
                    "x-storytime-session": "signed-session-token",
                    "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                ]
            )
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        try await client.bootstrapSessionIdentity(baseURL: baseURL)

        let snapshot = try XCTUnwrap(AppEntitlements.currentSnapshot)
        XCTAssertEqual(snapshot.tier, .starter)
        XCTAssertEqual(snapshot.source, .none)
        XCTAssertEqual(snapshot.maxChildProfiles, 1)
        XCTAssertTrue(snapshot.canReplaySavedStories)
        XCTAssertEqual(snapshot.usageWindow.kind, .rollingPeriod)
        XCTAssertEqual(AppEntitlements.currentToken, "signed-entitlement-token")
    }

    func testAppEntitlementsClearsExpiredSnapshot() {
        AppEntitlements.store(
            envelope: EntitlementBootstrapEnvelope(
                snapshot: EntitlementSnapshot(
                    tier: .starter,
                    source: .none,
                    maxChildProfiles: 1,
                    maxStoryStartsPerPeriod: nil,
                    maxContinuationsPerPeriod: nil,
                    maxStoryLengthMinutes: nil,
                    canReplaySavedStories: true,
                    canStartNewStories: true,
                    canContinueSavedSeries: true,
                    effectiveAt: Date().addingTimeInterval(-60).timeIntervalSince1970,
                    expiresAt: Date().addingTimeInterval(-1).timeIntervalSince1970,
                    usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: nil, resetsAt: nil),
                    remainingStoryStarts: nil,
                    remainingContinuations: nil
                ),
                token: "expired-entitlement-token",
                expiresAt: Date().addingTimeInterval(-1).timeIntervalSince1970
            )
        )

        XCTAssertNil(AppEntitlements.currentSnapshot)
        XCTAssertNil(AppEntitlements.currentToken)
    }

    func testSyncEntitlementsPostsNormalizedPurchaseStateAndStoresRefreshedSnapshot() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970
        var sawSyncRequest = false

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-sync-1", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/sync":
                sawSyncRequest = true
                let body = try Self.requestBody(from: request)
                let decoded = try JSONDecoder().decode(EntitlementSyncRequest.self, from: body)
                XCTAssertEqual(decoded.refreshReason, .restore)
                XCTAssertEqual(decoded.activeProductIDs, ["storytime.plus.monthly"])
                XCTAssertEqual(decoded.transactions.count, 2)
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "signed-session-token")

                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "entitlements": [
                            "snapshot": [
                                "tier": "plus",
                                "source": "storekit_verified",
                                "max_child_profiles": 3,
                                "max_story_starts_per_period": NSNull(),
                                "max_continuations_per_period": NSNull(),
                                "max_story_length_minutes": NSNull(),
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": NSNull(),
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": NSNull(),
                                "remaining_continuations": NSNull()
                            ],
                            "token": "refreshed-entitlement-token",
                            "expires_at": expiresAt
                        ]
                    ]
                )
            default:
                XCTFail("Unexpected sync request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let envelope = try await client.syncEntitlements(
            request: EntitlementSyncRequest(
                refreshReason: .restore,
                transactions: [
                    EntitlementSyncTransaction(
                        productID: "storytime.plus.monthly",
                        originalTransactionID: "original-1",
                        latestTransactionID: "latest-1",
                        purchasedAt: Int(Date().addingTimeInterval(-600).timeIntervalSince1970),
                        expiresAt: Int(Date().addingTimeInterval(3_600).timeIntervalSince1970),
                        revokedAt: nil,
                        ownershipType: .purchased,
                        environment: .sandbox,
                        verificationState: .verified,
                        isActive: true
                    ),
                    EntitlementSyncTransaction(
                        productID: "storytime.plus.monthly",
                        originalTransactionID: "original-2",
                        latestTransactionID: "latest-2",
                        purchasedAt: Int(Date().addingTimeInterval(-600).timeIntervalSince1970),
                        expiresAt: Int(Date().addingTimeInterval(3_600).timeIntervalSince1970),
                        revokedAt: nil,
                        ownershipType: .purchased,
                        environment: .sandbox,
                        verificationState: .unverified,
                        isActive: true
                    )
                ]
            )
        )

        XCTAssertTrue(sawSyncRequest)
        XCTAssertEqual(envelope.snapshot.tier, .plus)
        XCTAssertEqual(envelope.snapshot.source, .storekitVerified)
        XCTAssertEqual(AppEntitlements.currentSnapshot?.tier, .plus)
        XCTAssertEqual(AppEntitlements.currentToken, "refreshed-entitlement-token")
    }

    func testPreflightEntitlementsPostsLaunchContextAndDecodesBlockedDecision() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970
        var sawPreflightRequest = false

        AppEntitlements.store(
            envelope: EntitlementBootstrapEnvelope(
                snapshot: EntitlementSnapshot(
                    tier: .starter,
                    source: .none,
                    maxChildProfiles: 1,
                    maxStoryStartsPerPeriod: 3,
                    maxContinuationsPerPeriod: 3,
                    maxStoryLengthMinutes: nil,
                    canReplaySavedStories: true,
                    canStartNewStories: true,
                    canContinueSavedSeries: true,
                    effectiveAt: effectiveAt,
                    expiresAt: expiresAt,
                    usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: nil, resetsAt: nil),
                    remainingStoryStarts: 2,
                    remainingContinuations: 0
                ),
                token: "current-entitlement-token",
                expiresAt: expiresAt
            )
        )

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session_id": "session-preflight-1",
                        "region": "US",
                        "entitlements": [
                            "snapshot": [
                                "tier": "starter",
                                "source": "none",
                                "max_child_profiles": 1,
                                "max_story_starts_per_period": 3,
                                "max_continuations_per_period": 3,
                                "max_story_length_minutes": NSNull(),
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": NSNull(),
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 2,
                                "remaining_continuations": 0
                            ],
                            "token": "current-entitlement-token",
                            "expires_at": expiresAt
                        ]
                    ],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/preflight":
                sawPreflightRequest = true
                let body = try Self.requestBody(from: request)
                let decoded = try JSONDecoder().decode(EntitlementPreflightRequest.self, from: body)
                XCTAssertEqual(decoded.action, .continueStory)
                XCTAssertEqual(decoded.childProfileCount, 1)
                XCTAssertEqual(decoded.requestedLengthMinutes, 4)
                XCTAssertEqual(decoded.selectedSeriesID, "22222222-2222-2222-2222-222222222222")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "signed-session-token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-entitlement"), "current-entitlement-token")

                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "action": "continue_story",
                        "allowed": false,
                        "block_reason": "continuations_exhausted",
                        "recommended_upgrade_surface": "story_series_detail",
                        "snapshot": [
                            "tier": "starter",
                            "source": "none",
                            "max_child_profiles": 1,
                            "max_story_starts_per_period": 3,
                            "max_continuations_per_period": 3,
                            "max_story_length_minutes": NSNull(),
                            "can_replay_saved_stories": true,
                            "can_start_new_stories": true,
                            "can_continue_saved_series": true,
                            "effective_at": effectiveAt,
                            "expires_at": expiresAt,
                            "usage_window": [
                                "kind": "rolling_period",
                                "duration_seconds": NSNull(),
                                "resets_at": NSNull()
                            ],
                            "remaining_story_starts": 2,
                            "remaining_continuations": 0
                        ]
                    ]
                )
            default:
                XCTFail("Unexpected preflight request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let response = try await client.preflightEntitlements(
            request: EntitlementPreflightRequest(
                action: .continueStory,
                childProfileID: "11111111-1111-1111-1111-111111111111",
                childProfileCount: 1,
                requestedLengthMinutes: 4,
                selectedSeriesID: "22222222-2222-2222-2222-222222222222"
            )
        )

        XCTAssertTrue(sawPreflightRequest)
        XCTAssertFalse(response.allowed)
        XCTAssertEqual(response.blockReason, .continuationsExhausted)
        XCTAssertEqual(response.recommendedUpgradeSurface, .storySeriesDetail)
        XCTAssertEqual(response.snapshot.remainingContinuations, 0)
    }

    func testTraceEventsCarryGeneratedRequestIDsAndSessionCorrelation() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var seenHeaderRequestIDs: [String] = []
        var traceEvents: [APIClientTraceEvent] = []

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            let headerRequestID = try XCTUnwrap(request.value(forHTTPHeaderField: "x-request-id"))
            seenHeaderRequestIDs.append(headerRequestID)

            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-trace-1"],
                    headers: [
                        "x-request-id": "req-bootstrap-echo",
                        "x-storytime-session": "trace-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/voices":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "trace-session-token")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["language": "en", "voices": ["alloy"]],
                    headers: ["x-request-id": "req-voices-echo"]
                )
            default:
                XCTFail("Unexpected trace request: \(url.absoluteString)")
                return try Self.httpResponse(url: url, statusCode: 500, json: ["error": "unexpected"])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-trace")
        client.traceHandler = { traceEvents.append($0) }

        try await client.bootstrapSessionIdentity(baseURL: baseURL)
        _ = try await client.fetchVoices()

        XCTAssertEqual(seenHeaderRequestIDs.count, 2)
        XCTAssertTrue(seenHeaderRequestIDs.allSatisfy { !$0.isEmpty })
        XCTAssertNotEqual(seenHeaderRequestIDs[0], seenHeaderRequestIDs[1])
        XCTAssertEqual(AppSession.currentSessionId, "session-trace-1")

        XCTAssertEqual(traceEvents.map(\.operation), [.sessionBootstrap, .sessionBootstrap, .voices, .voices])
        XCTAssertEqual(traceEvents.map(\.phase), [.started, .completed, .started, .completed])
        XCTAssertEqual(traceEvents[0].requestId, seenHeaderRequestIDs[0])
        XCTAssertNil(traceEvents[0].sessionId)
        XCTAssertEqual(traceEvents[1].requestId, "req-bootstrap-echo")
        XCTAssertNil(traceEvents[1].sessionId)
        XCTAssertEqual(traceEvents[2].requestId, seenHeaderRequestIDs[1])
        XCTAssertEqual(traceEvents[2].sessionId, "session-trace-1")
        XCTAssertEqual(traceEvents[3].requestId, "req-voices-echo")
        XCTAssertEqual(traceEvents[3].sessionId, "session-trace-1")
        XCTAssertEqual(traceEvents[3].statusCode, 200)
        XCTAssertEqual(traceEvents.map(\.runtimeStage), [nil, nil, nil, nil])
        XCTAssertEqual(traceEvents.map(\.runtimeStageGroup), [nil, nil, nil, nil])
        XCTAssertEqual(traceEvents.map(\.costDriver), [nil, nil, nil, nil])
        XCTAssertNil(traceEvents[0].durationMs)
        XCTAssertNotNil(traceEvents[1].durationMs)
        XCTAssertNil(traceEvents[2].durationMs)
        XCTAssertNotNil(traceEvents[3].durationMs)
    }

    func testStartupSequenceReusesBootstrappedSessionAcrossVoicesAndRealtimeSession() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var requestPaths: [String] = []

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            requestPaths.append(url.path)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-install-id"), "install-123")

            switch url.path {
            case "/health":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-session"))
                return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])

            case "/v1/session/identity":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-session"))
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-1"],
                    headers: [
                        "x-storytime-session": "startup-sequence-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )

            case "/v1/voices":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "startup-sequence-token")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["language": "en", "voices": ["alloy", "verse"]]
                )

            case "/v1/realtime/session":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "startup-sequence-token")
                let body = try Self.requestBody(from: request)
                let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(payload["child_profile_id"] as? String, "child-startup")
                XCTAssertEqual(payload["voice"] as? String, "verse")
                XCTAssertEqual(payload["region"] as? String, "US")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-startup",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "verse",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )

            default:
                XCTFail("Unexpected startup request: \(url.absoluteString)")
                return try Self.httpResponse(url: url, statusCode: 500, json: ["error": "unexpected"])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")

        let resolved = try await client.prepareConnection()
        try await client.bootstrapSessionIdentity(baseURL: resolved)
        let voices = try await client.fetchVoices()
        let realtime = try await client.createRealtimeSession(
            request: RealtimeSessionRequest(
                childProfileId: "child-startup",
                voice: "verse",
                region: .us
            )
        )

        XCTAssertEqual(resolved, baseURL)
        XCTAssertEqual(voices, ["alloy", "verse"])
        XCTAssertEqual(realtime.session.ticket, "ticket-startup")
        XCTAssertEqual(requestPaths, ["/health", "/v1/session/identity", "/v1/voices", "/v1/realtime/session"])
        XCTAssertEqual(AppSession.currentToken, "startup-sequence-token")
    }

    func testResolvedHealthRegionPropagatesAcrossBootstrapAndRealtimeSession() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var requestPaths: [String] = []

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            requestPaths.append(url.path)

            switch url.path {
            case "/health":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-region"))
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "ok": true,
                        "default_region": "EU",
                        "allowed_regions": ["US", "EU"]
                    ]
                )

            case "/v1/session/identity":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-region"), "EU")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-eu-1", "region": "EU"],
                    headers: [
                        "x-storytime-region": "EU",
                        "x-storytime-session": "region-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )

            case "/v1/voices":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-region"), "EU")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "region-session-token")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["language": "en", "voices": ["alloy"], "regions": ["US", "EU"]]
                )

            case "/v1/realtime/session":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-region"), "EU")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "region-session-token")
                let body = try Self.requestBody(from: request)
                let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(payload["region"] as? String, "EU")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-region",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )

            default:
                XCTFail("Unexpected region request: \(url.absoluteString)")
                return try Self.httpResponse(url: url, statusCode: 500, json: ["error": "unexpected"])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-region")

        let resolved = try await client.prepareConnection()
        try await client.bootstrapSessionIdentity(baseURL: resolved)
        _ = try await client.fetchVoices()
        _ = try await client.createRealtimeSession(
            request: RealtimeSessionRequest(
                childProfileId: "child-region",
                voice: "alloy",
                region: .us
            )
        )

        XCTAssertEqual(requestPaths, ["/health", "/v1/session/identity", "/v1/voices", "/v1/realtime/session"])
        XCTAssertEqual(client.resolvedRegion, .eu)
        XCTAssertEqual(AppSession.currentRegion, .eu)
    }

    func testCreateRealtimeSessionBootstrapsIdentityAndSendsSessionHeader() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var sawRealtimeSessionHeader = false

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            switch url.path {
            case "/v1/session/identity":
                XCTAssertEqual(request.httpMethod, "POST")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-1"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/realtime/session":
                sawRealtimeSessionHeader = request.value(forHTTPHeaderField: "x-storytime-session") == "signed-session-token"
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-123",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )
            default:
                return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let response = try await client.createRealtimeSession(
            request: RealtimeSessionRequest(
                childProfileId: "child-1",
                voice: "alloy",
                region: .us
            )
        )

        XCTAssertEqual(response.session.ticket, "ticket-123")
        XCTAssertEqual(AppSession.currentToken, "signed-session-token")
        XCTAssertTrue(sawRealtimeSessionHeader)
    }

    func testCreateRealtimeSessionRefreshesStaleSessionTokenAndRetriesOnce() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let defaults = UserDefaults.standard
        defaults.set("stale-session-token", forKey: "com.storytime.session-token")
        defaults.set(Date().addingTimeInterval(300).timeIntervalSince1970, forKey: "com.storytime.session-expiry")
        defaults.set("stale-session-id", forKey: "com.storytime.session-id")

        var requestPaths: [String] = []
        var realtimeAttempts = 0

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            requestPaths.append(url.path)

            switch url.path {
            case "/v1/realtime/session":
                realtimeAttempts += 1
                if realtimeAttempts == 1 {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "stale-session-token")
                    return try Self.httpResponse(
                        url: url,
                        statusCode: 401,
                        json: [
                            "error": "invalid_session_token",
                            "message": "Invalid signed token",
                            "request_id": "req-stale-session"
                        ]
                    )
                }

                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "fresh-session-token")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-fresh",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )

            case "/v1/session/identity":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-session"))
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "fresh-session-id"],
                    headers: [
                        "x-storytime-session": "fresh-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )

            default:
                XCTFail("Unexpected request: \(url.absoluteString)")
                return try Self.httpResponse(url: url, statusCode: 500, json: ["error": "unexpected"])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let response = try await client.createRealtimeSession(
            request: RealtimeSessionRequest(
                childProfileId: "child-refresh",
                voice: "alloy",
                region: .us
            )
        )

        XCTAssertEqual(response.session.ticket, "ticket-fresh")
        XCTAssertEqual(requestPaths, ["/v1/realtime/session", "/v1/session/identity", "/v1/realtime/session"])
        XCTAssertEqual(AppSession.currentToken, "fresh-session-token")
        XCTAssertEqual(AppSession.currentSessionId, "fresh-session-id")
    }

    func testCreateRealtimeSessionContinuesWhenLegacyBackendLacksIdentityBootstrap() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var sawRealtimeSessionRequest = false

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(url: url, statusCode: 404, json: ["error": "missing"])
            case "/v1/realtime/session":
                sawRealtimeSessionRequest = true
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-session"))
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-legacy",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )
            default:
                return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-legacy")
        let response = try await client.createRealtimeSession(
            request: RealtimeSessionRequest(
                childProfileId: "child-legacy",
                voice: "alloy",
                region: .us
            )
        )

        XCTAssertTrue(sawRealtimeSessionRequest)
        XCTAssertEqual(response.session.ticket, "ticket-legacy")
        XCTAssertNil(AppSession.currentToken)
    }

    func testCreateRealtimeSessionPreservesAbsoluteEndpointFromBackend() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-1"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/realtime/session":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-absolute",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "https://edge.example.com/v1/realtime/call"
                    ]
                )
            default:
                return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let response = try await client.createRealtimeSession(
            request: RealtimeSessionRequest(
                childProfileId: "child-absolute",
                voice: "alloy",
                region: .us
            )
        )

        XCTAssertEqual(response.endpoint, "https://edge.example.com/v1/realtime/call")
        XCTAssertEqual(AppSession.currentToken, "signed-session-token")
    }

    func testStoryEndpointsDecodeBlocked422ResponsesAndEmbeddings() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let defaults = UserDefaults.standard
        defaults.set("existing-session-token", forKey: "com.storytime.session-token")
        defaults.set(Date().addingTimeInterval(300).timeIntervalSince1970, forKey: "com.storytime.session-expiry")

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "existing-session-token")

            switch url.path {
            case "/v1/story/discovery":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 422,
                    json: [
                        "blocked": true,
                        "safe_message": "Let's keep it gentle.",
                        "data": [
                            "slot_state": [
                                "theme": "",
                                "characters": [],
                                "setting": "",
                                "tone": "",
                                "episode_intent": ""
                            ],
                            "question_count": 1,
                            "ready_to_generate": false,
                            "assistant_message": "Try a friendly idea.",
                            "transcript": "too scary"
                        ]
                    ]
                )
            case "/v1/story/generate":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 422,
                    json: [
                        "blocked": true,
                        "safe_message": "Let's try a softer story idea.",
                        "data": Self.storyJSON(storyId: "blocked-story", title: "Gentle Story")
                    ]
                )
            case "/v1/story/revise":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 422,
                    json: [
                        "blocked": true,
                        "safe_message": "Let's keep the ending friendly.",
                        "data": [
                            "story_id": "story-1",
                            "revised_from_scene_index": 1,
                            "scenes": [
                                ["scene_id": "2", "text": "A softer ending arrived.", "duration_sec": 40]
                            ],
                            "safety": [
                                "input_moderation": "pass",
                                "output_moderation": "pass"
                            ],
                            "engine": NSNull()
                        ]
                    ]
                )
            case "/v1/embeddings/create":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["embeddings": [[0.1, 0.2], [0.3, 0.4]]]
                )
            default:
                return try Self.httpResponse(url: url, statusCode: 200, json: ["ok": true])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let discovery = try await client.discoverStoryTurn(
            request: DiscoveryRequest(
                childProfileId: "child-1",
                transcript: "too scary",
                questionCount: 1,
                slotState: DiscoverySlotState(),
                mode: "new",
                previousEpisodeRecap: nil
            )
        )
        let generated = try await client.generateStory(
            request: GenerateStoryRequest(
                childProfileId: "child-1",
                ageBand: "3-8",
                language: "en",
                lengthMinutes: 4,
                voice: "alloy",
                questionCount: 1,
                storyBrief: StoryBrief(
                    theme: "gentle bedtime",
                    characters: ["Bunny"],
                    setting: "park",
                    tone: "soft",
                    episodeIntent: "standalone",
                    lesson: nil
                ),
                continuityFacts: []
            )
        )
        let revised = try await client.reviseStory(
            request: ReviseStoryRequest(
                storyId: "story-1",
                currentSceneIndex: 1,
                storyTitle: "Gentle Story",
                userUpdate: "Make it softer",
                completedScenes: [],
                remainingScenes: [StoryScene(sceneId: "2", text: "Old ending", durationSec: 40)]
            )
        )
        let embeddings = try await client.createEmbeddings(inputs: ["Bunny", "Fox"])

        XCTAssertTrue(discovery.blocked)
        XCTAssertTrue(generated.blocked)
        XCTAssertTrue(revised.blocked)
        XCTAssertEqual(embeddings.count, 2)
    }

    func testStoryEndpointTraceEventsCarryDetailedAndGroupedRuntimeStages() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var traceEvents: [APIClientTraceEvent] = []

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-stage-1"],
                    headers: [
                        "x-request-id": "req-bootstrap-stage",
                        "x-storytime-session": "session-token-stage",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/story/discovery":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "blocked": false,
                        "safe_message": NSNull(),
                        "data": [
                            "slot_state": [
                                "theme": "lanterns",
                                "characters": ["Bunny"],
                                "setting": "park",
                                "tone": "gentle",
                                "episode_intent": "standalone"
                            ],
                            "question_count": 1,
                            "ready_to_generate": true,
                            "assistant_message": "Ready to go.",
                            "transcript": "Tell a lantern story"
                        ]
                    ],
                    headers: ["x-request-id": "req-discovery-stage"]
                )
            case "/v1/story/generate":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "blocked": false,
                        "safe_message": NSNull(),
                        "data": [
                            "story_id": "story-1",
                            "title": "Lantern Story",
                            "estimated_duration_sec": 120,
                            "scenes": [
                                ["scene_id": "1", "text": "A happy lantern glowed.", "duration_sec": 40]
                            ],
                            "safety": [
                                "input_moderation": "pass",
                                "output_moderation": "pass"
                            ],
                            "engine": NSNull()
                        ]
                    ],
                    headers: ["x-request-id": "req-generate-stage"]
                )
            case "/v1/story/revise":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "blocked": false,
                        "safe_message": NSNull(),
                        "data": [
                            "story_id": "story-1",
                            "revised_from_scene_index": 1,
                            "scenes": [
                                ["scene_id": "2", "text": "A softer ending arrived.", "duration_sec": 40]
                            ],
                            "safety": [
                                "input_moderation": "pass",
                                "output_moderation": "pass"
                            ],
                            "engine": NSNull()
                        ]
                    ],
                    headers: ["x-request-id": "req-revise-stage"]
                )
            case "/v1/embeddings/create":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["embeddings": [[0.1, 0.2]]],
                    headers: ["x-request-id": "req-embeddings-stage"]
                )
            default:
                XCTFail("Unexpected staged trace request: \(url.absoluteString)")
                return try Self.httpResponse(url: url, statusCode: 500, json: ["error": "unexpected"])
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        client.traceHandler = { traceEvents.append($0) }

        _ = try await client.discoverStoryTurn(
            request: DiscoveryRequest(
                childProfileId: "child-1",
                transcript: "Tell a lantern story",
                questionCount: 1,
                slotState: DiscoverySlotState(),
                mode: "new",
                previousEpisodeRecap: nil
            )
        )
        _ = try await client.generateStory(
            request: GenerateStoryRequest(
                childProfileId: "child-1",
                ageBand: "3-8",
                language: "en",
                lengthMinutes: 4,
                voice: "alloy",
                questionCount: 1,
                storyBrief: StoryBrief(
                    theme: "gentle bedtime",
                    characters: ["Bunny"],
                    setting: "park",
                    tone: "soft",
                    episodeIntent: "standalone",
                    lesson: nil
                ),
                continuityFacts: []
            )
        )
        _ = try await client.reviseStory(
            request: ReviseStoryRequest(
                storyId: "story-1",
                currentSceneIndex: 1,
                storyTitle: "Lantern Story",
                userUpdate: "Make it softer",
                completedScenes: [],
                remainingScenes: [StoryScene(sceneId: "2", text: "Old ending", durationSec: 40)]
            )
        )
        _ = try await client.createEmbeddings(inputs: ["Bunny"])

        let completedByOperation = Dictionary(
            uniqueKeysWithValues: traceEvents
                .filter { $0.phase == .completed }
                .map { ($0.operation, $0) }
        )

        XCTAssertEqual(completedByOperation[.storyDiscovery]?.runtimeStage, .discovery)
        XCTAssertEqual(completedByOperation[.storyDiscovery]?.runtimeStageGroup, .interaction)
        XCTAssertEqual(completedByOperation[.storyDiscovery]?.costDriver, .remoteModel)

        XCTAssertEqual(completedByOperation[.storyGeneration]?.runtimeStage, .storyGeneration)
        XCTAssertEqual(completedByOperation[.storyGeneration]?.runtimeStageGroup, .generation)
        XCTAssertEqual(completedByOperation[.storyGeneration]?.costDriver, .remoteModel)

        XCTAssertEqual(completedByOperation[.storyRevision]?.runtimeStage, .reviseFutureScenes)
        XCTAssertEqual(completedByOperation[.storyRevision]?.runtimeStageGroup, .revision)
        XCTAssertEqual(completedByOperation[.storyRevision]?.costDriver, .remoteModel)

        XCTAssertEqual(completedByOperation[.embeddings]?.runtimeStage, .continuityRetrieval)
        XCTAssertNil(completedByOperation[.embeddings]?.runtimeStageGroup)
        XCTAssertEqual(completedByOperation[.embeddings]?.costDriver, .remoteModel)
    }

    func testInvalidResponsesAndSessionTokenLifecycle() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path == "/v1/voices" {
                return try Self.httpResponse(
                    url: url,
                    statusCode: 500,
                    json: [
                        "error": "internal_error",
                        "message": "Unexpected server error",
                        "request_id": "req-500"
                    ]
                )
            }
            return Self.rawResponse(url: url, statusCode: 200, body: "ok")
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")

        do {
            _ = try await client.fetchVoices()
            XCTFail("Expected fetchVoices to fail")
        } catch let error as APIError {
            switch error {
            case .invalidResponse(let statusCode, let code, let message, let requestId, let body):
                XCTAssertEqual(statusCode, 500)
                XCTAssertEqual(code, "internal_error")
                XCTAssertEqual(message, "Unexpected server error")
                XCTAssertEqual(requestId, "req-500")
                XCTAssertTrue(body.contains("\"internal_error\""))
                XCTAssertEqual(error.localizedDescription, "Server returned an error (500). Unexpected server error")
            case .connectionFailed:
                XCTFail("Expected invalidResponse")
            }
        }

        let expiry = Date().addingTimeInterval(-10).timeIntervalSince1970
        UserDefaults.standard.set("expired-token", forKey: "com.storytime.session-token")
        UserDefaults.standard.set(expiry, forKey: "com.storytime.session-expiry")
        XCTAssertNil(AppSession.currentToken)

        let response = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "x-storytime-session": "fresh-token",
                "x-storytime-session-expires-at": String(Date().addingTimeInterval(200).timeIntervalSince1970)
            ]
        )!
        AppSession.store(from: response)
        XCTAssertEqual(AppSession.currentToken, "fresh-token")
        AppSession.clear()
        XCTAssertNil(AppSession.currentToken)
        XCTAssertTrue(APIError.connectionFailed([baseURL]).localizedDescription.contains("Could not connect"))
    }

    func testInvalidResponseLocalizedDescriptionDoesNotExposeRawBodyWhenEnvelopeIsMissing() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path == "/v1/voices" {
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: ["x-request-id": "req-raw-500"]
                )!
                return (response, Data("db password leaked".utf8))
            }
            return Self.rawResponse(url: url, statusCode: 200, body: "ok")
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")

        do {
            _ = try await client.fetchVoices()
            XCTFail("Expected fetchVoices to fail")
        } catch let error as APIError {
            switch error {
            case .invalidResponse(let statusCode, let code, let message, let requestId, let body):
                XCTAssertEqual(statusCode, 500)
                XCTAssertNil(code)
                XCTAssertNil(message)
                XCTAssertEqual(requestId, "req-raw-500")
                XCTAssertEqual(body, "db password leaked")
                XCTAssertEqual(error.localizedDescription, "Server returned an error (500).")
                XCTAssertFalse(error.localizedDescription.contains("db password leaked"))
            case .connectionFailed:
                XCTFail("Expected invalidResponse")
            }
        }
    }

    func testFetchVoicesRetriesOn404FromFirstBaseURL() async throws {
        let session = makeSession()
        let first = URL(string: "https://one.example.com/")!
        let second = URL(string: "https://two.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.host == "one.example.com" {
                return try Self.httpResponse(url: url, statusCode: 404, json: ["error": "missing"])
            }
            return try Self.httpResponse(url: url, statusCode: 200, json: ["language": "en", "voices": ["alloy"]])
        }

        let client = APIClient(baseURLs: [first, second], session: session, installId: "install-123")
        let voices = try await client.fetchVoices()

        XCTAssertEqual(voices, ["alloy"])
    }

    func testFetchVoicesFailsWhenResponseIsNotHTTP() async {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            return (URLResponse(url: url, mimeType: "application/json", expectedContentLength: 0, textEncodingName: nil), Data())
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")

        do {
            _ = try await client.fetchVoices()
            XCTFail("Expected a connection failure")
        } catch let error as APIError {
            switch error {
            case .connectionFailed(let candidates):
                XCTAssertEqual(candidates, [baseURL])
            case .invalidResponse:
                XCTFail("Expected connectionFailed for a non-HTTP response")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPrepareConnectionWithoutCandidateBaseURLsThrowsConnectionFailed() async {
        let client = APIClient(baseURLs: [], session: makeSession(), installId: "install-123")

        do {
            _ = try await client.prepareConnection()
            XCTFail("Expected connection failure")
        } catch let error as APIError {
            switch error {
            case .connectionFailed(let candidates):
                XCTAssertTrue(candidates.isEmpty)
            case .invalidResponse:
                XCTFail("Expected connection failure")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private static func storyJSON(storyId: String, title: String) -> [String: Any] {
        [
            "story_id": storyId,
            "title": title,
            "estimated_duration_sec": 90,
            "scenes": [
                ["scene_id": "1", "text": "A gentle scene", "duration_sec": 45]
            ],
            "safety": [
                "input_moderation": "pass",
                "output_moderation": "pass"
            ],
            "engine": NSNull()
        ]
    }

    private static func httpResponse(
        url: URL,
        statusCode: Int,
        json: Any,
        headers: [String: String] = [:]
    ) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
        return (response, data)
    }

    private static func rawResponse(url: URL, statusCode: Int, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }

    private static func requestBody(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            throw URLError(.badServerResponse)
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            if readCount < 0 {
                throw stream.streamError ?? URLError(.badServerResponse)
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }

        return data
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (URLResponse, Data))?

    static func reset() {
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
