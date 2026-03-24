import XCTest
@testable import StoryTime

final class APIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
        ClientLaunchTelemetry.replacePersistentStoreForTesting(userDefaults: .standard)
        ClientLaunchTelemetry.reset()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.storytime.session-token")
        defaults.removeObject(forKey: "com.storytime.session-expiry")
        defaults.removeObject(forKey: "com.storytime.session-id")
        defaults.removeObject(forKey: "com.storytime.session-region")
        defaults.removeObject(forKey: "com.storytime.entitlements.bootstrap.v1")
        defaults.removeObject(forKey: "com.storytime.entitlements.bootstrap.install.v1")
    }

    override func tearDown() {
        URLProtocolStub.reset()
        ClientLaunchTelemetry.replacePersistentStoreForTesting(userDefaults: .standard)
        ClientLaunchTelemetry.reset()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "com.storytime.session-token")
        defaults.removeObject(forKey: "com.storytime.session-expiry")
        defaults.removeObject(forKey: "com.storytime.session-id")
        defaults.removeObject(forKey: "com.storytime.session-region")
        defaults.removeObject(forKey: "com.storytime.entitlements.bootstrap.v1")
        defaults.removeObject(forKey: "com.storytime.entitlements.bootstrap.install.v1")
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
                                "max_story_starts_per_period": 3,
                                "max_continuations_per_period": 3,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 3,
                                "remaining_continuations": 3
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
        XCTAssertEqual(snapshot.maxStoryStartsPerPeriod, 3)
        XCTAssertEqual(snapshot.maxContinuationsPerPeriod, 3)
        XCTAssertEqual(snapshot.maxStoryLengthMinutes, 10)
        XCTAssertEqual(snapshot.usageWindow.durationSeconds, 604_800)
        XCTAssertEqual(snapshot.remainingStoryStarts, 3)
        XCTAssertEqual(snapshot.remainingContinuations, 3)
        XCTAssertTrue(snapshot.canReplaySavedStories)
        XCTAssertEqual(snapshot.usageWindow.kind, .rollingPeriod)
        XCTAssertEqual(AppEntitlements.currentToken, "signed-entitlement-token")
    }

    func testBootstrapSessionIdentityWithoutEntitlementsPreservesInstallFallback() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970

        AppEntitlements.store(
            envelope: EntitlementBootstrapEnvelope(
                snapshot: EntitlementSnapshot(
                    tier: .starter,
                    source: .none,
                    maxChildProfiles: 1,
                    maxStoryStartsPerPeriod: 3,
                    maxContinuationsPerPeriod: 3,
                    maxStoryLengthMinutes: 10,
                    canReplaySavedStories: true,
                    canStartNewStories: true,
                    canContinueSavedSeries: true,
                    effectiveAt: effectiveAt,
                    expiresAt: expiresAt,
                    usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: 604800, resetsAt: nil),
                    remainingStoryStarts: 3,
                    remainingContinuations: 3
                ),
                token: "install-fallback-token",
                expiresAt: expiresAt,
                owner: EntitlementOwner(kind: .install)
            )
        )

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(url.path, "/v1/session/identity")
            return try Self.httpResponse(
                url: url,
                statusCode: 200,
                json: ["session_id": "session-no-entitlements-1", "region": "US"],
                headers: [
                    "x-storytime-session": "signed-session-token",
                    "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                ]
            )
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        try await client.bootstrapSessionIdentity(baseURL: baseURL)

        XCTAssertEqual(AppEntitlements.currentSnapshot?.tier, .starter)
        XCTAssertEqual(AppEntitlements.currentOwner?.kind, .install)
        XCTAssertEqual(AppEntitlements.currentToken, "install-fallback-token")
    }

    func testBootstrapSessionIdentityIncludesParentAuthHeaderAndStoresEntitlementOwner() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(url.path, "/v1/session/identity")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
            return try Self.httpResponse(
                url: url,
                statusCode: 200,
                json: [
                    "session_id": "session-parent-owned-1",
                    "region": "US",
                    "entitlements": [
                        "snapshot": [
                            "tier": "plus",
                            "source": "storekit_verified",
                            "max_child_profiles": 3,
                            "max_story_starts_per_period": 12,
                            "max_continuations_per_period": 12,
                            "max_story_length_minutes": 10,
                            "can_replay_saved_stories": true,
                            "can_start_new_stories": true,
                            "can_continue_saved_series": true,
                            "effective_at": effectiveAt,
                            "expires_at": expiresAt,
                            "usage_window": [
                                "kind": "rolling_period",
                                "duration_seconds": 604800,
                                "resets_at": NSNull()
                            ],
                            "remaining_story_starts": 12,
                            "remaining_continuations": 12
                        ],
                        "token": "signed-parent-entitlement-token",
                        "expires_at": expiresAt,
                        "owner": [
                            "kind": "parent_user",
                            "parent_user_id": "parent-123",
                            "auth_provider": "firebase"
                        ]
                    ]
                ],
                headers: [
                    "x-storytime-session": "signed-session-token",
                    "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                ]
            )
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-123",
            parentAuthTokenProvider: StubParentAuthTokenProvider(token: "parent-token-123")
        )
        try await client.bootstrapSessionIdentity(baseURL: baseURL)

        XCTAssertEqual(AppEntitlements.currentEnvelope?.owner?.kind, .parentUser)
        XCTAssertEqual(AppEntitlements.currentEnvelope?.owner?.parentUserID, "parent-123")
        XCTAssertEqual(AppEntitlements.currentEnvelope?.owner?.authProvider, .firebase)
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
                                "max_story_starts_per_period": 12,
                                "max_continuations_per_period": 12,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 12,
                                "remaining_continuations": 12
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
        XCTAssertEqual(envelope.snapshot.maxStoryStartsPerPeriod, 12)
        XCTAssertEqual(envelope.snapshot.maxContinuationsPerPeriod, 12)
        XCTAssertEqual(envelope.snapshot.maxStoryLengthMinutes, 10)
        XCTAssertEqual(envelope.snapshot.remainingStoryStarts, 12)
        XCTAssertEqual(envelope.snapshot.remainingContinuations, 12)
        XCTAssertEqual(AppEntitlements.currentSnapshot?.tier, .plus)
        XCTAssertEqual(AppEntitlements.currentToken, "refreshed-entitlement-token")
    }

    func testRestoreSyncStoresAuthenticatedOwnerMetadata() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-restore-owner-1", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/sync":
                let body = try Self.requestBody(from: request)
                let decoded = try JSONDecoder().decode(EntitlementSyncRequest.self, from: body)
                XCTAssertEqual(decoded.refreshReason, .restore)
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")

                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "entitlements": [
                            "snapshot": [
                                "tier": "plus",
                                "source": "storekit_verified",
                                "max_child_profiles": 3,
                                "max_story_starts_per_period": 12,
                                "max_continuations_per_period": 12,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 12,
                                "remaining_continuations": 12
                            ],
                            "token": "restore-owner-token",
                            "expires_at": expiresAt,
                            "owner": [
                                "kind": "parent_user",
                                "parent_user_id": "parent-alpha",
                                "auth_provider": "firebase"
                            ]
                        ]
                    ]
                )
            default:
                XCTFail("Unexpected restore sync request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-123",
            parentAuthTokenProvider: StubParentAuthTokenProvider(token: "parent-token-123")
        )
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
                    )
                ]
            )
        )

        XCTAssertEqual(envelope.owner?.kind, .parentUser)
        XCTAssertEqual(envelope.owner?.parentUserID, "parent-alpha")
        XCTAssertEqual(AppEntitlements.currentOwner?.kind, .parentUser)
        XCTAssertEqual(AppEntitlements.currentOwner?.parentUserID, "parent-alpha")
    }

    func testRestoreSyncSurfacesParentMismatchFailure() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-456")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-restore-mismatch-1", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/sync":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 409,
                    json: [
                        "error": "restore_parent_mismatch",
                        "message": "This device already restored Plus for a different parent account. Sign back into that parent account to restore here again. StoryTime won't move restored access between parent accounts on the same device."
                    ]
                )
            default:
                XCTFail("Unexpected restore mismatch request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-restore-mismatch-123",
            parentAuthTokenProvider: StubParentAuthTokenProvider(token: "parent-token-456")
        )

        do {
            _ = try await client.syncEntitlements(
                request: EntitlementSyncRequest(
                    refreshReason: .restore,
                    transactions: [
                        EntitlementSyncTransaction(
                            productID: "storytime.plus.yearly",
                            originalTransactionID: "restore-original-2",
                            latestTransactionID: "restore-latest-2",
                            purchasedAt: Int(Date().addingTimeInterval(-600).timeIntervalSince1970),
                            expiresAt: Int(Date().addingTimeInterval(3_600).timeIntervalSince1970),
                            revokedAt: nil,
                            ownershipType: .familyShared,
                            environment: .sandbox,
                            verificationState: .verified,
                            isActive: true
                        )
                    ]
                )
            )
            XCTFail("Expected restore mismatch to throw")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 409)
            XCTAssertEqual(error.serverCode, "restore_parent_mismatch")
            XCTAssertEqual(
                error.serverMessage,
                "This device already restored Plus for a different parent account. Sign back into that parent account to restore here again. StoryTime won't move restored access between parent accounts on the same device."
            )
        }
    }

    func testSyncAndPreflightSendParentAuthHeaderWhenParentIsSignedIn() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970
        var observedPaths: [String] = []

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            observedPaths.append(url.path)

            switch url.path {
            case "/v1/session/identity":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-sync-parent-1", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/sync":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "entitlements": [
                            "snapshot": [
                                "tier": "plus",
                                "source": "storekit_verified",
                                "max_child_profiles": 3,
                                "max_story_starts_per_period": 12,
                                "max_continuations_per_period": 12,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 12,
                                "remaining_continuations": 12
                            ],
                            "token": "refreshed-entitlement-token",
                            "expires_at": expiresAt,
                            "owner": [
                                "kind": "parent_user",
                                "parent_user_id": "parent-123",
                                "auth_provider": "firebase"
                            ]
                        ]
                    ]
                )
            case "/v1/entitlements/preflight":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-entitlement"), "refreshed-entitlement-token")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "action": "new_story",
                        "allowed": true,
                        "block_reason": NSNull(),
                        "recommended_upgrade_surface": NSNull(),
                        "snapshot": [
                            "tier": "plus",
                            "source": "storekit_verified",
                            "max_child_profiles": 3,
                            "max_story_starts_per_period": 12,
                            "max_continuations_per_period": 12,
                            "max_story_length_minutes": 10,
                            "can_replay_saved_stories": true,
                            "can_start_new_stories": true,
                            "can_continue_saved_series": true,
                            "effective_at": effectiveAt,
                            "expires_at": expiresAt,
                            "usage_window": [
                                "kind": "rolling_period",
                                "duration_seconds": 604800,
                                "resets_at": NSNull()
                            ],
                            "remaining_story_starts": 11,
                            "remaining_continuations": 12
                        ],
                        "entitlements": [
                            "snapshot": [
                                "tier": "plus",
                                "source": "storekit_verified",
                                "max_child_profiles": 3,
                                "max_story_starts_per_period": 12,
                                "max_continuations_per_period": 12,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 11,
                                "remaining_continuations": 12
                            ],
                            "token": "refreshed-preflight-entitlement-token",
                            "expires_at": expiresAt,
                            "owner": [
                                "kind": "parent_user",
                                "parent_user_id": "parent-123",
                                "auth_provider": "firebase"
                            ]
                        ]
                    ]
                )
            default:
                XCTFail("Unexpected request: \(url.absoluteString)")
                throw URLError(.badURL)
            }
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-123",
            parentAuthTokenProvider: StubParentAuthTokenProvider(token: "parent-token-123")
        )

        let syncEnvelope = try await client.syncEntitlements(
            request: EntitlementSyncRequest(
                refreshReason: .purchase,
                transactions: [
                    EntitlementSyncTransaction(
                        productID: "storytime.plus.monthly",
                        originalTransactionID: "original-1",
                        latestTransactionID: "latest-1",
                        purchasedAt: Int(Date().addingTimeInterval(-120).timeIntervalSince1970),
                        expiresAt: Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
                        revokedAt: nil,
                        ownershipType: .purchased,
                        environment: .sandbox,
                        verificationState: .verified,
                        isActive: true
                    )
                ]
            )
        )

        let response = try await client.preflightEntitlements(
            request: EntitlementPreflightRequest(
                action: .newStory,
                childProfileID: "fbeafe23-42d5-4ea7-8035-5680419504e9",
                childProfileCount: 1,
                requestedLengthMinutes: 4
            )
        )

        XCTAssertEqual(observedPaths, ["/v1/session/identity", "/v1/entitlements/sync", "/v1/entitlements/preflight"])
        XCTAssertEqual(syncEnvelope.owner?.kind, .parentUser)
        XCTAssertEqual(syncEnvelope.owner?.parentUserID, "parent-123")
        XCTAssertEqual(response.entitlements?.owner?.kind, .parentUser)
        XCTAssertEqual(response.entitlements?.owner?.parentUserID, "parent-123")
    }

    func testRestoreSyncWithoutParentAuthSurfacesAccountRequirement() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-restore-auth-1", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/sync":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 401,
                    json: [
                        "error": "parent_auth_required",
                        "message": "Sign in to a parent account before restoring Plus."
                    ]
                )
            default:
                XCTFail("Unexpected restore auth request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")

        do {
            _ = try await client.syncEntitlements(
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
                        )
                    ]
                )
            )
            XCTFail("Expected restore sync to require parent auth")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 401)
            XCTAssertEqual(error.serverCode, "parent_auth_required")
            XCTAssertEqual(error.serverMessage, "Sign in to a parent account before restoring Plus.")
        }
    }

    func testRedeemPromoCodeStoresPromoGrantOwnerMetadata() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-promo-1", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/promo/redeem":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                let body = try Self.requestBody(from: request)
                let decoded = try JSONDecoder().decode(PromoCodeRedemptionRequest.self, from: body)
                XCTAssertEqual(decoded.code, "FRIENDS-PLUS-2026")

                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "entitlements": [
                            "snapshot": [
                                "tier": "plus",
                                "source": "promo_grant",
                                "max_child_profiles": 3,
                                "max_story_starts_per_period": 12,
                                "max_continuations_per_period": 12,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 12,
                                "remaining_continuations": 12
                            ],
                            "token": "promo-grant-token",
                            "expires_at": expiresAt,
                            "owner": [
                                "kind": "parent_user",
                                "parent_user_id": "parent-alpha",
                                "auth_provider": "firebase"
                            ]
                        ]
                    ]
                )
            default:
                XCTFail("Unexpected promo request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-123",
            parentAuthTokenProvider: StubParentAuthTokenProvider(token: "parent-token-123")
        )
        let envelope = try await client.redeemPromoCode(request: PromoCodeRedemptionRequest(code: "FRIENDS-PLUS-2026"))

        XCTAssertEqual(envelope.snapshot.source, .promoGrant)
        XCTAssertEqual(envelope.owner?.kind, .parentUser)
        XCTAssertEqual(envelope.owner?.parentUserID, "parent-alpha")
        XCTAssertEqual(AppEntitlements.currentSnapshot?.source, .promoGrant)
        XCTAssertEqual(AppEntitlements.currentOwner?.parentUserID, "parent-alpha")
    }

    func testRedeemPromoCodeSurfacesInvalidPromoFailure() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-promo-2", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/promo/redeem":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 404,
                    json: [
                        "error": "promo_code_invalid",
                        "message": "That promo code isn't valid anymore. Ask a grown-up to check the code and try again."
                    ]
                )
            default:
                XCTFail("Unexpected invalid promo request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-123",
            parentAuthTokenProvider: StubParentAuthTokenProvider(token: "parent-token-123")
        )

        do {
            _ = try await client.redeemPromoCode(request: PromoCodeRedemptionRequest(code: "MISSING-CODE"))
            XCTFail("Expected invalid promo code error")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 404)
            XCTAssertEqual(error.serverCode, "promo_code_invalid")
            XCTAssertEqual(error.serverMessage, "That promo code isn't valid anymore. Ask a grown-up to check the code and try again.")
        }
    }

    func testPurchaseSyncRequiresParentAccountAuthentication() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-parent-auth"))
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-parent-required-1", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/sync":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-parent-auth"))
                return try Self.httpResponse(
                    url: url,
                    statusCode: 401,
                    json: [
                        "error": "parent_auth_required",
                        "message": "Sign in to a parent account before purchasing Plus.",
                        "request_id": "req-parent-auth-required"
                    ]
                )
            default:
                XCTFail("Unexpected request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")

        do {
            _ = try await client.syncEntitlements(
                request: EntitlementSyncRequest(
                    refreshReason: .purchase,
                    transactions: [
                        EntitlementSyncTransaction(
                            productID: "storytime.plus.monthly",
                            originalTransactionID: "original-1",
                            latestTransactionID: "latest-1",
                            purchasedAt: Int(Date().addingTimeInterval(-120).timeIntervalSince1970),
                            expiresAt: Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
                            revokedAt: nil,
                            ownershipType: .purchased,
                            environment: .sandbox,
                            verificationState: .verified,
                            isActive: true
                        )
                    ]
                )
            )
            XCTFail("Expected purchase sync to require authenticated parent identity")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 401)
            XCTAssertEqual(error.serverCode, "parent_auth_required")
            XCTAssertEqual(error.serverMessage, "Sign in to a parent account before purchasing Plus.")
            XCTAssertEqual(error.requestId, "req-parent-auth-required")
        }
    }

    func testPreflightDoesNotHangWhenParentAuthTokenProviderStalls() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-parent-auth"))
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-stalled-parent-auth", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/preflight":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-parent-auth"))
                return try Self.httpResponse(
                    url: url,
                    statusCode: 401,
                    json: [
                        "error": "parent_auth_required",
                        "message": "A grown-up needs to sign in before StoryTime can check this plan."
                    ]
                )
            default:
                XCTFail("Unexpected request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-123",
            parentAuthTokenProvider: HangingParentAuthTokenProvider(),
            parentAuthTokenTimeoutNanoseconds: 50_000_000
        )

        do {
            _ = try await client.preflightEntitlements(
                request: EntitlementPreflightRequest(
                    action: .newStory,
                    childProfileID: UUID().uuidString,
                    childProfileCount: 1,
                    requestedLengthMinutes: 4
                )
            )
            XCTFail("Expected preflight to require authenticated parent identity after token timeout")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 401)
            XCTAssertEqual(error.serverCode, "parent_auth_required")
        }
    }

    func testPreflightTimesOutWhenTransportStalls() async {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-preflight-timeout", "region": "US"],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/preflight":
                Thread.sleep(forTimeInterval: 0.2)
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "allowed": true,
                        "action": "new_story",
                        "snapshot": [
                            "tier": "starter",
                            "source": "none",
                            "max_child_profiles": 1,
                            "max_story_starts_per_period": 3,
                            "max_continuations_per_period": 3,
                            "max_story_length_minutes": 10,
                            "can_replay_saved_stories": true,
                            "can_start_new_stories": true,
                            "can_continue_saved_series": true,
                            "effective_at": Date().addingTimeInterval(-60).timeIntervalSince1970,
                            "expires_at": Date().addingTimeInterval(3600).timeIntervalSince1970,
                            "usage_window": [
                                "kind": "rolling_period",
                                "duration_seconds": 604800,
                                "resets_at": NSNull()
                            ],
                            "remaining_story_starts": 3,
                            "remaining_continuations": 3
                        ]
                    ]
                )
            default:
                XCTFail("Unexpected request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-123",
            requestTimeoutIntervalOverride: 0.05
        )

        do {
            _ = try await client.preflightEntitlements(
                request: EntitlementPreflightRequest(
                    action: .newStory,
                    childProfileID: UUID().uuidString,
                    childProfileCount: 1,
                    requestedLengthMinutes: 4
                )
            )
            XCTFail("Expected preflight transport timeout to fail")
        } catch let error as APIError {
            switch error {
            case .connectionFailed(let candidates):
                XCTAssertEqual(candidates, [baseURL])
            case .invalidResponse:
                XCTFail("Expected connectionFailed for a stalled preflight transport")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPreflightUsesRefreshedEntitlementTokenAfterPurchaseSync() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session_id": "session-purchase-retry",
                        "region": "US",
                        "entitlements": [
                            "snapshot": [
                                "tier": "starter",
                                "source": "none",
                                "max_child_profiles": 1,
                                "max_story_starts_per_period": 1,
                                "max_continuations_per_period": 1,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": false,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 0,
                                "remaining_continuations": 1
                            ],
                            "token": "starter-token",
                            "expires_at": expiresAt
                        ]
                    ],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/sync":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                let body = try Self.requestBody(from: request)
                let decoded = try JSONDecoder().decode(EntitlementSyncRequest.self, from: body)
                XCTAssertEqual(decoded.refreshReason, .purchase)

                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "entitlements": [
                            "snapshot": [
                                "tier": "plus",
                                "source": "storekit_verified",
                                "max_child_profiles": 3,
                                "max_story_starts_per_period": 12,
                                "max_continuations_per_period": 12,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 12,
                                "remaining_continuations": 12
                            ],
                            "token": "plus-token",
                            "expires_at": expiresAt
                        ]
                    ]
                )
            case "/v1/entitlements/preflight":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-entitlement"), "plus-token")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "action": "new_story",
                        "allowed": true,
                        "block_reason": NSNull(),
                        "recommended_upgrade_surface": NSNull(),
                        "snapshot": [
                            "tier": "plus",
                            "source": "storekit_verified",
                            "max_child_profiles": 3,
                            "max_story_starts_per_period": 12,
                            "max_continuations_per_period": 12,
                            "max_story_length_minutes": 10,
                            "can_replay_saved_stories": true,
                            "can_start_new_stories": true,
                            "can_continue_saved_series": true,
                            "effective_at": effectiveAt,
                            "expires_at": expiresAt,
                            "usage_window": [
                                "kind": "rolling_period",
                                "duration_seconds": 604800,
                                "resets_at": NSNull()
                            ],
                            "remaining_story_starts": 11,
                            "remaining_continuations": 12
                        ],
                        "entitlements": [
                            "snapshot": [
                                "tier": "plus",
                                "source": "storekit_verified",
                                "max_child_profiles": 3,
                                "max_story_starts_per_period": 12,
                                "max_continuations_per_period": 12,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 11,
                                "remaining_continuations": 12
                            ],
                            "token": "plus-token-after-preflight",
                            "expires_at": expiresAt
                        ]
                    ]
                )
            default:
                XCTFail("Unexpected purchase retry request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-123",
            parentAuthTokenProvider: StubParentAuthTokenProvider(token: "parent-token-123")
        )
        _ = try await client.syncEntitlements(
            request: EntitlementSyncRequest(
                refreshReason: .purchase,
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
                    )
                ]
            )
        )

        let response = try await client.preflightEntitlements(
            request: EntitlementPreflightRequest(
                action: .newStory,
                childProfileID: "11111111-1111-1111-1111-111111111111",
                childProfileCount: 1,
                requestedLengthMinutes: 4
            )
        )

        XCTAssertTrue(response.allowed)
        XCTAssertEqual(response.snapshot.tier, .plus)
        XCTAssertEqual(AppEntitlements.currentToken, "plus-token-after-preflight")
        XCTAssertEqual(AppEntitlements.currentSnapshot?.tier, .plus)
    }

    func testPreflightUsesRedeemedPromoEntitlementTokenAfterAuthenticatedUnlock() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session_id": "session-promo-retry",
                        "region": "US",
                        "entitlements": [
                            "snapshot": [
                                "tier": "starter",
                                "source": "none",
                                "max_child_profiles": 1,
                                "max_story_starts_per_period": 1,
                                "max_continuations_per_period": 1,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": false,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 0,
                                "remaining_continuations": 1
                            ],
                            "token": "starter-token",
                            "expires_at": expiresAt
                        ]
                    ],
                    headers: [
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/promo/redeem":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                let body = try Self.requestBody(from: request)
                let decoded = try JSONDecoder().decode(PromoCodeRedemptionRequest.self, from: body)
                XCTAssertEqual(decoded.code, "FAMILY-PLUS-2026")

                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "entitlements": [
                            "snapshot": [
                                "tier": "plus",
                                "source": "promo_grant",
                                "max_child_profiles": 3,
                                "max_story_starts_per_period": 12,
                                "max_continuations_per_period": 12,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 12,
                                "remaining_continuations": 12
                            ],
                            "token": "promo-token",
                            "expires_at": expiresAt,
                            "owner": [
                                "kind": "parent_user",
                                "parent_user_id": "parent-123",
                                "auth_provider": "firebase"
                            ]
                        ]
                    ]
                )
            case "/v1/entitlements/preflight":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-parent-auth"), "parent-token-123")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-entitlement"), "promo-token")
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "action": "new_story",
                        "allowed": true,
                        "block_reason": NSNull(),
                        "recommended_upgrade_surface": NSNull(),
                        "snapshot": [
                            "tier": "plus",
                            "source": "promo_grant",
                            "max_child_profiles": 3,
                            "max_story_starts_per_period": 12,
                            "max_continuations_per_period": 12,
                            "max_story_length_minutes": 10,
                            "can_replay_saved_stories": true,
                            "can_start_new_stories": true,
                            "can_continue_saved_series": true,
                            "effective_at": effectiveAt,
                            "expires_at": expiresAt,
                            "usage_window": [
                                "kind": "rolling_period",
                                "duration_seconds": 604800,
                                "resets_at": NSNull()
                            ],
                            "remaining_story_starts": 11,
                            "remaining_continuations": 12
                        ],
                        "entitlements": [
                            "snapshot": [
                                "tier": "plus",
                                "source": "promo_grant",
                                "max_child_profiles": 3,
                                "max_story_starts_per_period": 12,
                                "max_continuations_per_period": 12,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 11,
                                "remaining_continuations": 12
                            ],
                            "token": "promo-token-after-preflight",
                            "expires_at": expiresAt,
                            "owner": [
                                "kind": "parent_user",
                                "parent_user_id": "parent-123",
                                "auth_provider": "firebase"
                            ]
                        ]
                    ]
                )
            default:
                XCTFail("Unexpected promo retry request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(
            baseURLs: [baseURL],
            session: session,
            installId: "install-123",
            parentAuthTokenProvider: StubParentAuthTokenProvider(token: "parent-token-123")
        )
        _ = try await client.redeemPromoCode(request: PromoCodeRedemptionRequest(code: "FAMILY-PLUS-2026"))

        let response = try await client.preflightEntitlements(
            request: EntitlementPreflightRequest(
                action: .newStory,
                childProfileID: "11111111-1111-1111-1111-111111111111",
                childProfileCount: 1,
                requestedLengthMinutes: 4
            )
        )

        XCTAssertTrue(response.allowed)
        XCTAssertEqual(response.snapshot.tier, .plus)
        XCTAssertEqual(response.snapshot.source, .promoGrant)
        XCTAssertEqual(AppEntitlements.currentToken, "promo-token-after-preflight")
        XCTAssertEqual(AppEntitlements.currentSnapshot?.source, .promoGrant)
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
                        ],
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
                            "token": "refreshed-preflight-entitlement-token",
                            "expires_at": expiresAt
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
        XCTAssertEqual(response.entitlements?.token, "refreshed-preflight-entitlement-token")
        XCTAssertEqual(AppEntitlements.currentToken, "refreshed-preflight-entitlement-token")
        XCTAssertEqual(AppEntitlements.currentSnapshot?.remainingContinuations, 0)
    }

    func testEntitlementTraceEventsUseCorrectOperationsForSyncAndPreflight() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970
        var traceEvents: [APIClientTraceEvent] = []

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-entitlement-trace", "region": "US"],
                    headers: [
                        "x-request-id": "req-entitlement-bootstrap",
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/sync":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "entitlements": [
                            "snapshot": [
                                "tier": "starter",
                                "source": "none",
                                "max_child_profiles": 2,
                                "max_story_starts_per_period": 2,
                                "max_continuations_per_period": 1,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 2,
                                "remaining_continuations": 1
                            ],
                            "token": "sync-token",
                            "expires_at": expiresAt
                        ]
                    ],
                    headers: ["x-request-id": "req-entitlement-sync"]
                )
            case "/v1/entitlements/preflight":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "action": "new_story",
                        "allowed": true,
                        "block_reason": NSNull(),
                        "recommended_upgrade_surface": NSNull(),
                        "snapshot": [
                            "tier": "starter",
                            "source": "none",
                            "max_child_profiles": 2,
                            "max_story_starts_per_period": 2,
                            "max_continuations_per_period": 1,
                            "max_story_length_minutes": 10,
                            "can_replay_saved_stories": true,
                            "can_start_new_stories": true,
                            "can_continue_saved_series": true,
                            "effective_at": effectiveAt,
                            "expires_at": expiresAt,
                            "usage_window": [
                                "kind": "rolling_period",
                                "duration_seconds": 604800,
                                "resets_at": NSNull()
                            ],
                            "remaining_story_starts": 1,
                            "remaining_continuations": 1
                        ],
                        "entitlements": [
                            "snapshot": [
                                "tier": "starter",
                                "source": "none",
                                "max_child_profiles": 2,
                                "max_story_starts_per_period": 2,
                                "max_continuations_per_period": 1,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 1,
                                "remaining_continuations": 1
                            ],
                            "token": "preflight-token",
                            "expires_at": expiresAt
                        ]
                    ],
                    headers: ["x-request-id": "req-entitlement-preflight"]
                )
            default:
                XCTFail("Unexpected entitlement trace request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        client.traceHandler = { traceEvents.append($0) }

        _ = try await client.syncEntitlements(
            request: EntitlementSyncRequest(refreshReason: .restore, transactions: [])
        )
        _ = try await client.preflightEntitlements(
            request: EntitlementPreflightRequest(
                action: .newStory,
                childProfileID: "11111111-1111-1111-1111-111111111111",
                childProfileCount: 1,
                requestedLengthMinutes: 4
            )
        )

        let entitlementTraceEvents = traceEvents.filter {
            $0.operation == .entitlementSync || $0.operation == .entitlementPreflight
        }

        XCTAssertEqual(
            entitlementTraceEvents.map(\.operation),
            [.entitlementSync, .entitlementSync, .entitlementPreflight, .entitlementPreflight]
        )
        XCTAssertEqual(
            entitlementTraceEvents.map(\.phase),
            [.started, .completed, .started, .completed]
        )
        XCTAssertEqual(entitlementTraceEvents[1].requestId, "req-entitlement-sync")
        XCTAssertEqual(entitlementTraceEvents[3].requestId, "req-entitlement-preflight")
    }

    func testClientLaunchTelemetryCapturesEntitlementAndParentManagedSurfaceEvents() async throws {
        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        let effectiveAt = Date().addingTimeInterval(-60).timeIntervalSince1970
        let expiresAt = Date().addingTimeInterval(3_600).timeIntervalSince1970

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/v1/session/identity":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-launch-telemetry", "region": "US"],
                    headers: [
                        "x-request-id": "req-launch-bootstrap",
                        "x-storytime-session": "signed-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )
            case "/v1/entitlements/sync":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "entitlements": [
                            "snapshot": [
                                "tier": "starter",
                                "source": "none",
                                "max_child_profiles": 2,
                                "max_story_starts_per_period": 1,
                                "max_continuations_per_period": 1,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 1,
                                "remaining_continuations": 0
                            ],
                            "token": "sync-telemetry-token",
                            "expires_at": expiresAt
                        ]
                    ],
                    headers: ["x-request-id": "req-launch-sync"]
                )
            case "/v1/entitlements/preflight":
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
                            "max_child_profiles": 2,
                            "max_story_starts_per_period": 1,
                            "max_continuations_per_period": 1,
                            "max_story_length_minutes": 10,
                            "can_replay_saved_stories": true,
                            "can_start_new_stories": true,
                            "can_continue_saved_series": true,
                            "effective_at": effectiveAt,
                            "expires_at": expiresAt,
                            "usage_window": [
                                "kind": "rolling_period",
                                "duration_seconds": 604800,
                                "resets_at": NSNull()
                            ],
                            "remaining_story_starts": 1,
                            "remaining_continuations": 0
                        ],
                        "entitlements": [
                            "snapshot": [
                                "tier": "starter",
                                "source": "none",
                                "max_child_profiles": 2,
                                "max_story_starts_per_period": 1,
                                "max_continuations_per_period": 1,
                                "max_story_length_minutes": 10,
                                "can_replay_saved_stories": true,
                                "can_start_new_stories": true,
                                "can_continue_saved_series": true,
                                "effective_at": effectiveAt,
                                "expires_at": expiresAt,
                                "usage_window": [
                                    "kind": "rolling_period",
                                    "duration_seconds": 604800,
                                    "resets_at": NSNull()
                                ],
                                "remaining_story_starts": 1,
                                "remaining_continuations": 0
                            ],
                            "token": "preflight-telemetry-token",
                            "expires_at": expiresAt
                        ]
                    ],
                    headers: ["x-request-id": "req-launch-preflight"]
                )
            default:
                XCTFail("Unexpected launch telemetry request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let syncEnvelope = try await client.syncEntitlements(
            request: EntitlementSyncRequest(refreshReason: .restore, transactions: [])
        )
        let preflightResponse = try await client.preflightEntitlements(
            request: EntitlementPreflightRequest(
                action: .continueStory,
                childProfileID: "11111111-1111-1111-1111-111111111111",
                childProfileCount: 1,
                requestedLengthMinutes: 4,
                selectedSeriesID: "22222222-2222-2222-2222-222222222222"
            )
        )

        ClientLaunchTelemetry.recordBlockedReviewPresented(
            surface: .storySeriesDetail,
            response: preflightResponse
        )
        ClientLaunchTelemetry.recordParentPlanPresented(snapshot: syncEnvelope.snapshot)
        ClientLaunchTelemetry.recordParentPlanRefresh(outcome: .started, snapshot: syncEnvelope.snapshot)
        ClientLaunchTelemetry.recordParentPlanRefresh(outcome: .completed, snapshot: syncEnvelope.snapshot)
        ClientLaunchTelemetry.recordRestorePurchases(outcome: .started, snapshot: syncEnvelope.snapshot)
        ClientLaunchTelemetry.recordRestorePurchases(outcome: .completed, snapshot: syncEnvelope.snapshot)

        let report = ClientLaunchTelemetry.report()

        XCTAssertEqual(report.counters["launch:entitlement_sync:completed"], 1)
        XCTAssertEqual(report.counters["launch_refresh:restore:completed"], 2)
        XCTAssertEqual(report.counters["launch:entitlement_preflight:blocked"], 1)
        XCTAssertEqual(report.counters["launch_action:continue_story:blocked"], 1)
        XCTAssertEqual(report.counters["launch_block:continuations_exhausted"], 2)
        XCTAssertEqual(report.counters["launch_surface:story_series_detail:blocked"], 1)
        XCTAssertEqual(report.counters["launch:blocked_review_presented:presented"], 1)
        XCTAssertEqual(report.counters["launch_surface:story_series_detail:presented"], 1)
        XCTAssertEqual(report.counters["launch:parent_plan_presented:presented"], 1)
        XCTAssertEqual(report.counters["launch:parent_plan_refresh:started"], 1)
        XCTAssertEqual(report.counters["launch:parent_plan_refresh:completed"], 1)
        XCTAssertEqual(report.counters["launch:restore_purchases:started"], 1)
        XCTAssertEqual(report.counters["launch:restore_purchases:completed"], 1)
        XCTAssertEqual(report.counters["launch_surface:parent_trust_center:presented"], 1)
        XCTAssertEqual(report.counters["launch_surface:parent_trust_center:started"], 2)
        XCTAssertEqual(report.counters["launch_surface:parent_trust_center:completed"], 2)

        let sessionSummary = try XCTUnwrap(report.sessions["session-launch-telemetry"])
        XCTAssertEqual(sessionSummary.launchEvents["launch:entitlement_sync:completed"], 1)
        XCTAssertEqual(sessionSummary.launchEvents["refresh:restore:completed"], 2)
        XCTAssertEqual(sessionSummary.launchEvents["action:continue_story:blocked"], 1)
        XCTAssertEqual(sessionSummary.launchEvents["block:continuations_exhausted"], 2)
        XCTAssertEqual(sessionSummary.launchEvents["surface:story_series_detail:presented"], 1)
        XCTAssertEqual(sessionSummary.launchEvents["surface:parent_trust_center:completed"], 2)
        XCTAssertEqual(sessionSummary.lastEntitlementTier, .starter)
        XCTAssertEqual(sessionSummary.remainingStoryStarts, 1)
        XCTAssertEqual(sessionSummary.remainingContinuations, 0)
        XCTAssertEqual(report.events.map(\.name), [
            .entitlementSync,
            .entitlementPreflight,
            .blockedReviewPresented,
            .parentPlanPresented,
            .parentPlanRefresh,
            .parentPlanRefresh,
            .restorePurchases,
            .restorePurchases
        ])
    }

    func testClientLaunchTelemetryPersistsAcrossStoreReload() throws {
        let suiteName = "ClientLaunchTelemetryPersist.\(UUID().uuidString)"
        let alternateSuiteName = "ClientLaunchTelemetryAlternate.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let alternateDefaults = try XCTUnwrap(UserDefaults(suiteName: alternateSuiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            alternateDefaults.removePersistentDomain(forName: alternateSuiteName)
        }

        ClientLaunchTelemetry.replacePersistentStoreForTesting(userDefaults: defaults)
        ClientLaunchTelemetry.reset()
        AppSession.store(sessionId: "session-client-persist")

        let snapshot = EntitlementSnapshot(
            tier: .starter,
            source: .none,
            maxChildProfiles: 1,
            maxStoryStartsPerPeriod: 3,
            maxContinuationsPerPeriod: 3,
            maxStoryLengthMinutes: 10,
            canReplaySavedStories: true,
            canStartNewStories: true,
            canContinueSavedSeries: true,
            effectiveAt: 1_700_000_000,
            expiresAt: 1_700_003_600,
            usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: 604_800, resetsAt: nil),
            remainingStoryStarts: 2,
            remainingContinuations: 1
        )

        ClientLaunchTelemetry.recordParentPlanPresented(snapshot: snapshot)
        ClientLaunchTelemetry.recordRestorePurchases(outcome: .completed, snapshot: snapshot)
        let persisted = ClientLaunchTelemetry.report()

        ClientLaunchTelemetry.replacePersistentStoreForTesting(userDefaults: alternateDefaults)
        XCTAssertTrue(ClientLaunchTelemetry.report().counters.isEmpty)

        ClientLaunchTelemetry.replacePersistentStoreForTesting(userDefaults: defaults)
        XCTAssertEqual(ClientLaunchTelemetry.report(), persisted)
    }

    func testFetchLaunchTelemetryReportJoinsBackendAndPersistedClientTelemetry() async throws {
        let suiteName = "ClientLaunchTelemetryJoined.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        ClientLaunchTelemetry.replacePersistentStoreForTesting(userDefaults: defaults)
        ClientLaunchTelemetry.reset()
        AppSession.store(sessionId: "session-joined-launch")

        let session = makeSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            switch url.path {
            case "/health":
                return try Self.httpResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "ok": true,
                        "default_region": "EU",
                        "allowed_regions": ["US", "EU"],
                        "telemetry": [
                            "counters": [
                                "launch:entitlement_preflight:blocked": 1
                            ],
                            "sessions": [
                                "session-joined-launch": [
                                    "request_count": 2,
                                    "request_duration_ms": 30,
                                    "openai_call_count": 1,
                                    "openai_duration_ms": 20,
                                    "openai_success_count": 1,
                                    "openai_failure_count": 0,
                                    "routes": [
                                        "/v1/entitlements/preflight": 1
                                    ],
                                    "runtime_stage_groups": [
                                        "interaction": [
                                            "call_count": 1,
                                            "duration_ms": 20,
                                            "success_count": 1,
                                            "failure_count": 0
                                        ]
                                    ],
                                    "launch_events": [
                                        "entitlement_preflight:blocked": 1
                                    ],
                                    "last_entitlement_tier": "starter",
                                    "remaining_story_starts": 0,
                                    "remaining_continuations": 1
                                ]
                            ]
                        ]
                    ]
                )
            default:
                XCTFail("Unexpected joined launch telemetry request: \(url.absoluteString)")
                return Self.rawResponse(url: url, statusCode: 404, body: "")
            }
        }

        let snapshot = EntitlementSnapshot(
            tier: .starter,
            source: .none,
            maxChildProfiles: 1,
            maxStoryStartsPerPeriod: 3,
            maxContinuationsPerPeriod: 3,
            maxStoryLengthMinutes: 10,
            canReplaySavedStories: true,
            canStartNewStories: true,
            canContinueSavedSeries: true,
            effectiveAt: 1_700_000_000,
            expiresAt: 1_700_003_600,
            usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: 604_800, resetsAt: nil),
            remainingStoryStarts: 0,
            remainingContinuations: 1
        )
        let sessionResponse = HTTPURLResponse(
            url: baseURL.appending(path: "v1").appending(path: "session").appending(path: "identity"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "x-storytime-session": "joined-launch-token",
                "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
            ]
        )!
        AppSession.store(from: sessionResponse)
        AppSession.store(sessionId: "session-joined-launch")
        ClientLaunchTelemetry.recordParentPlanPresented(snapshot: snapshot)

        let client = APIClient(baseURLs: [baseURL], session: session, installId: "install-123")
        let report = try await client.fetchLaunchTelemetryReport()

        XCTAssertEqual(report.defaultRegion, .eu)
        XCTAssertEqual(report.allowedRegions, [.us, .eu])
        XCTAssertEqual(report.backend?.counters["launch:entitlement_preflight:blocked"], 1)
        XCTAssertEqual(report.backend?.sessions["session-joined-launch"]?.requestCount, 2)
        XCTAssertEqual(report.client.counters["launch:parent_plan_presented:presented"], 1)
        XCTAssertEqual(report.client.sessions["session-joined-launch"]?.lastEntitlementTier, .starter)
        XCTAssertEqual(report.client.events.map(\.name), [.parentPlanPresented])
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

private struct StubParentAuthTokenProvider: ParentAuthTokenProviding {
    let token: String?

    func currentParentAuthToken() async -> String? {
        token
    }
}

private struct HangingParentAuthTokenProvider: ParentAuthTokenProviding {
    func currentParentAuthToken() async -> String? {
        do {
            try await Task.sleep(nanoseconds: .max)
            return nil
        } catch {
            return nil
        }
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
