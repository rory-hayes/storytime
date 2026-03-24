import XCTest
@testable import StoryTime

final class SmokeTests: XCTestCase {
    func testAppConfigHasURL() {
        XCTAssertFalse(AppConfig.candidateAPIBaseURLs.isEmpty)
        XCTAssertTrue(AppConfig.candidateAPIBaseURLs.first?.absoluteString.hasPrefix("http") ?? false)
    }

    func testAppConfigPrefersEnvironmentThenBundleWithoutLocalFallback() {
        let candidates = AppConfig.candidateAPIBaseURLs(
            environment: ["API_BASE_URL": " https://override.example.com/api?debug=1#fragment "],
            infoDictionary: ["StoryTimeAPIBaseURL": "https://bundle.example.com"],
            includeLocalDebugFallback: true
        )

        XCTAssertEqual(
            candidates,
            [
                URL(string: "https://override.example.com/api")!,
                URL(string: "https://bundle.example.com/")!
            ]
        )
    }

    func testAppConfigFallsBackToBundleThenLocalWhenNoEnvironmentOverrideExists() {
        let candidates = AppConfig.candidateAPIBaseURLs(
            environment: [:],
            infoDictionary: ["StoryTimeAPIBaseURL": "https://bundle.example.com"],
            includeLocalDebugFallback: true
        )

        XCTAssertEqual(
            candidates,
            [
                URL(string: "https://bundle.example.com/")!,
                URL(string: "http://127.0.0.1:8787")!
            ]
        )
    }

    func testDeviceLocalhostFallbackIsDisabledByDefault() {
        XCTAssertFalse(
            AppConfig.shouldIncludeLocalDebugFallback(
                environment: [:],
                isDebugBuild: true,
                isSimulatorBuild: false
            )
        )
    }

    func testDeviceLocalhostFallbackCanBeExplicitlyOptedIn() {
        XCTAssertTrue(
            AppConfig.shouldIncludeLocalDebugFallback(
                environment: ["STORYTIME_ALLOW_DEVICE_LOCALHOST_FALLBACK": "1"],
                isDebugBuild: true,
                isSimulatorBuild: false
            )
        )
    }

    func testSimulatorStillAllowsLocalhostFallbackByDefault() {
        XCTAssertTrue(
            AppConfig.shouldIncludeLocalDebugFallback(
                environment: [:],
                isDebugBuild: true,
                isSimulatorBuild: true
            )
        )
    }

    func testAppConfigIgnoresInvalidURLsAndDeduplicates() {
        let candidates = AppConfig.candidateAPIBaseURLs(
            environment: ["API_BASE_URL": "notaurl"],
            infoDictionary: ["StoryTimeAPIBaseURL": "https://backend-brown-ten-94.vercel.app"],
            includeLocalDebugFallback: false
        )

        XCTAssertEqual(candidates, [URL(string: "https://backend-brown-ten-94.vercel.app/")!])
        XCTAssertNil(AppConfig.normalizedBaseURL(from: "ftp://backend.example.com"))
    }

    func testAppConfigDebugCandidateMessagesListBackendTargetsInOrder() {
        let messages = AppConfig.debugCandidateBaseURLMessages(
            baseURLs: [
                URL(string: "https://backend.example.com/")!,
                URL(string: "http://127.0.0.1:8787")!
            ]
        )

        XCTAssertEqual(
            messages,
            [
                "Backend target: https://backend.example.com/",
                "Fallback target 1: http://127.0.0.1:8787"
            ]
        )
    }

    func testInfoPlistUsesLocalNetworkingInsteadOfArbitraryLoads() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let transport = try XCTUnwrap(plist["NSAppTransportSecurity"] as? [String: Any])

        XCTAssertEqual(transport["NSAllowsLocalNetworking"] as? Bool, true)
        XCTAssertNil(transport["NSAllowsArbitraryLoads"])
        XCTAssertEqual(
            plist["StoryTimeAPIBaseURL"] as? String,
            "https://backend-brown-ten-94.vercel.app"
        )
    }

    func testFirstRunExperienceStoreDefaultsToIncompleteAndPersistsCompletion() throws {
        let suiteName = "SmokeTests.FirstRunExperienceStore.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let initialStore = FirstRunExperienceStore(userDefaults: defaults)
        XCTAssertTrue(initialStore.needsOnboarding)
        XCTAssertFalse(initialStore.hasCompletedOnboarding)

        initialStore.completeOnboarding()

        XCTAssertTrue(initialStore.hasCompletedOnboarding)
        XCTAssertFalse(initialStore.needsOnboarding)
        XCTAssertTrue(defaults.bool(forKey: FirstRunExperienceStore.onboardingCompletedKey))

        let reloadedStore = FirstRunExperienceStore(userDefaults: defaults)
        XCTAssertTrue(reloadedStore.hasCompletedOnboarding)
        XCTAssertFalse(reloadedStore.needsOnboarding)
    }

    func testFirstRunActivationGateBlocksAccountStepUntilParentIsSignedIn() {
        let gateState = FirstRunActivationGateState(
            currentStep: .account,
            isParentSignedIn: false,
            selectedPlanChoice: nil
        )

        XCTAssertFalse(gateState.canAdvance)
        XCTAssertFalse(gateState.canFinish)
    }

    func testFirstRunActivationGateBlocksCompletionUntilPlanIsChosen() {
        let gateState = FirstRunActivationGateState(
            currentStep: .completion,
            isParentSignedIn: true,
            selectedPlanChoice: nil
        )

        XCTAssertFalse(gateState.canAdvance)
        XCTAssertFalse(gateState.canFinish)
    }

    func testFirstRunActivationGateAllowsCompletionOnceAccountAndPlanAreReady() {
        let gateState = FirstRunActivationGateState(
            currentStep: .completion,
            isParentSignedIn: true,
            selectedPlanChoice: .starter
        )

        XCTAssertTrue(gateState.canAdvance)
        XCTAssertTrue(gateState.canFinish)
    }

    func testFirstRunActivationGateAllowsCompletionForAuthenticatedPlusPlan() {
        let gateState = FirstRunActivationGateState(
            currentStep: .completion,
            isParentSignedIn: true,
            selectedPlanChoice: .plus
        )

        XCTAssertTrue(gateState.canAdvance)
        XCTAssertTrue(gateState.canFinish)
    }

    func testPlanStatusPresentationSurfacesSafePlanMessages() {
        let connectionMessage = PlanStatusPresentation.launchCheckMessage(
            for: APIError.connectionFailed([URL(string: "https://backend.example.com")!])
        )
        XCTAssertEqual(
            connectionMessage,
            "StoryTime couldn't reach the plan service right now. Ask a grown-up to check the connection and try again."
        )

        let authMessage = PlanStatusPresentation.launchCheckMessage(
            for: APIError.invalidResponse(
                statusCode: 401,
                code: "parent_auth_required",
                message: "Parent authentication required for entitlement route.",
                requestId: "request-123",
                body: "{\"error\":true}"
            )
        )
        XCTAssertEqual(authMessage, "A grown-up needs to sign in before StoryTime can check this plan.")

        let refreshMessage = PlanStatusPresentation.parentPlanRefreshMessage(
            for: APIError.invalidResponse(
                statusCode: 503,
                code: nil,
                message: "Temporary service interruption.",
                requestId: "request-456",
                body: "{\"error\":true}"
            )
        )
        XCTAssertEqual(
            refreshMessage,
            "StoryTime couldn't refresh the current plan right now. Temporary service interruption."
        )
    }

    func testPlanCheckDebugOverlayEnableFlag() {
        XCTAssertFalse(PlanCheckDebugOverlay.isEnabled(environment: [:]))
        XCTAssertTrue(PlanCheckDebugOverlay.isEnabled(environment: ["STORYTIME_DEBUG_PLAN_CHECK_OVERLAY": "1"]))
    }

    func testPlanCheckDebugOverlaySummarizesTraceAndFailuresSafely() {
        let startedMessage = PlanCheckDebugOverlay.traceMessage(
            for: APIClientTraceEvent(
                operation: .sessionBootstrap,
                phase: .started,
                route: "/v1/session/identity",
                requestId: "request-1",
                sessionId: nil,
                statusCode: nil
            )
        )
        XCTAssertEqual(startedMessage, "Checking parent session on /v1/session/identity.")

        let completedMessage = PlanCheckDebugOverlay.traceMessage(
            for: APIClientTraceEvent(
                operation: .entitlementPreflight,
                phase: .completed,
                route: "/v1/entitlements/preflight",
                requestId: "request-2",
                sessionId: "session-1",
                statusCode: 200
            )
        )
        XCTAssertEqual(completedMessage, "Plan service responded (200) on /v1/entitlements/preflight.")

        let failureMessage = PlanCheckDebugOverlay.failureMessage(
            for: APIError.invalidResponse(
                statusCode: 401,
                code: "parent_auth_required",
                message: "Parent authentication required for entitlement route.",
                requestId: "request-3",
                body: "{\"error\":true}"
            )
        )
        XCTAssertEqual(failureMessage, "Displayed error: a grown-up needs to sign in.")
    }

    func testVoiceStartupDebugOverlayEnableFlag() {
        XCTAssertFalse(VoiceStartupDebugOverlay.isEnabled(environment: [:]))
        XCTAssertTrue(VoiceStartupDebugOverlay.isEnabled(environment: ["STORYTIME_DEBUG_VOICE_STARTUP_OVERLAY": "1"]))
    }

    func testVoiceStartupDebugOverlaySummarizesSafeSnapshot() {
        let snapshot = PracticeSessionViewModel.VoiceStartupDebugSnapshot(
            phase: "booting",
            statusMessage: "Connecting live voice",
            errorMessage: "",
            startupStage: "voice-connect",
            lastStartupFailure: "callConnect",
            traceEvents: [
                PracticeSessionViewModel.SessionTraceEvent(
                    kind: .startup,
                    source: "connected",
                    state: "booting",
                    requestId: "request-1",
                    sessionId: "session-1",
                    apiOperation: .realtimeSession,
                    statusCode: 200
                )
            ]
        )

        XCTAssertEqual(
            VoiceStartupDebugOverlay.messages(for: snapshot),
            [
                "Phase: booting",
                "Startup step: voice-connect",
                "Status: Connecting live voice",
                "Startup failure: callConnect",
                "Trace: startup connected (realtimeSession 200)"
            ]
        )
    }

    @MainActor
    func testEntitlementManagerLoadsBootstrapSnapshotFromCache() {
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
                    effectiveAt: Date().timeIntervalSince1970,
                    expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
                    usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: nil, resetsAt: nil),
                    remainingStoryStarts: nil,
                    remainingContinuations: nil
                ),
                token: "bootstrap-entitlement-token",
                expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970
            )
        )

        let manager = EntitlementManager(snapshot: nil)
        manager.reloadFromCache()

        XCTAssertEqual(manager.snapshot?.tier, .starter)
        XCTAssertEqual(manager.snapshot?.maxChildProfiles, 1)
        XCTAssertEqual(AppEntitlements.currentToken, "bootstrap-entitlement-token")

        AppEntitlements.clear()
    }

    func testEntitlementSyncRequestDerivesActiveProductsFromVerifiedActiveTransactions() {
        let request = EntitlementSyncRequest(
            refreshReason: .purchase,
            transactions: [
                EntitlementSyncTransaction(
                    productID: "storytime.plus.monthly",
                    originalTransactionID: "original-1",
                    latestTransactionID: "latest-1",
                    purchasedAt: Int(Date().addingTimeInterval(-600).timeIntervalSince1970),
                    expiresAt: Int(Date().addingTimeInterval(300).timeIntervalSince1970),
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
                    expiresAt: Int(Date().addingTimeInterval(300).timeIntervalSince1970),
                    revokedAt: nil,
                    ownershipType: .purchased,
                    environment: .sandbox,
                    verificationState: .unverified,
                    isActive: true
                ),
                EntitlementSyncTransaction(
                    productID: "storytime.plus.yearly",
                    originalTransactionID: "original-3",
                    latestTransactionID: "latest-3",
                    purchasedAt: Int(Date().addingTimeInterval(-600).timeIntervalSince1970),
                    expiresAt: nil,
                    revokedAt: nil,
                    ownershipType: .familyShared,
                    environment: .sandbox,
                    verificationState: .verified,
                    isActive: false
                )
            ]
        )

        XCTAssertEqual(request.activeProductIDs, ["storytime.plus.monthly"])
    }

    func testEntitlementPreflightRequestBuildsNewStoryContextFromLaunchPlan() {
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: false,
            lengthMinutes: 4
        )

        let request = EntitlementPreflightRequest(plan: plan, childProfileCount: 1)

        XCTAssertEqual(
            request,
            EntitlementPreflightRequest(
                action: .newStory,
                childProfileID: "11111111-1111-1111-1111-111111111111",
                childProfileCount: 1,
                requestedLengthMinutes: 4
            )
        )
    }

    func testEntitlementPreflightRequestBuildsContinuationContextFromLaunchPlan() {
        let plan = StoryLaunchPlan(
            mode: .extend(seriesId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!),
            childProfileId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            experienceMode: .calm,
            usePastStory: true,
            selectedSeriesId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            usePastCharacters: true,
            lengthMinutes: 5
        )

        let request = EntitlementPreflightRequest(plan: plan, childProfileCount: 2)

        XCTAssertEqual(
            request,
            EntitlementPreflightRequest(
                action: .continueStory,
                childProfileID: "11111111-1111-1111-1111-111111111111",
                childProfileCount: 2,
                requestedLengthMinutes: 5,
                selectedSeriesID: "22222222-2222-2222-2222-222222222222"
            )
        )
    }

    func testEntitlementPreflightRequestSkipsRepeatOnlyLaunchPlan() {
        let plan = StoryLaunchPlan(
            mode: .repeatEpisode(seriesId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!),
            childProfileId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            experienceMode: .classic,
            usePastStory: true,
            selectedSeriesId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            usePastCharacters: false,
            lengthMinutes: 3
        )

        XCTAssertNil(EntitlementPreflightRequest(plan: plan, childProfileCount: 1))
    }

    @MainActor
    func testEntitlementManagerRefreshesFromPurchaseState() async throws {
        let provider = StubEntitlementPurchaseStateProvider(
            request: EntitlementSyncRequest(
                refreshReason: .restore,
                transactions: [
                    EntitlementSyncTransaction(
                        productID: "storytime.plus.yearly",
                        originalTransactionID: "original-1",
                        latestTransactionID: "latest-1",
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
        let client = StubEntitlementSyncClient()
        let manager = EntitlementManager(snapshot: nil)

        try await manager.refreshFromPurchaseState(using: client, purchaseStateProvider: provider, reason: .restore)

        XCTAssertEqual(client.lastSyncRequest?.refreshReason, .restore)
        XCTAssertEqual(client.lastSyncRequest?.activeProductIDs, ["storytime.plus.yearly"])
        XCTAssertEqual(manager.snapshot?.tier, .plus)
        XCTAssertEqual(manager.snapshot?.source, .storekitVerified)

        AppEntitlements.clear()
    }

    @MainActor
    func testEntitlementManagerPurchasesAndStoresSyncedSnapshot() async throws {
        let client = StubEntitlementSyncClient()
        let manager = EntitlementManager(snapshot: nil)
        let provider = StubParentManagedPurchaseProvider(
            outcome: .purchased(
                syncRequest: EntitlementSyncRequest(
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
        )

        let outcome = try await manager.purchaseProduct(
            using: client,
            purchaseProvider: provider,
            productID: "storytime.plus.monthly",
            parentAccount: ParentAuthUser(
                uid: "parent-123",
                email: "parent@example.com",
                isAnonymous: false,
                signInMethod: .emailPassword
            )
        )

        XCTAssertEqual(outcome, provider.outcome)
        XCTAssertEqual(provider.purchasedProductID, "storytime.plus.monthly")
        XCTAssertEqual(client.lastSyncRequest?.refreshReason, .purchase)
        XCTAssertEqual(client.lastSyncRequest?.activeProductIDs, ["storytime.plus.monthly"])
        XCTAssertEqual(manager.snapshot?.tier, .plus)
        XCTAssertEqual(manager.snapshot?.source, .storekitVerified)

        AppEntitlements.clear()
    }

    @MainActor
    func testEntitlementManagerDoesNotSyncCancelledPurchase() async throws {
        let client = StubEntitlementSyncClient()
        let manager = EntitlementManager(snapshot: nil)
        let provider = StubParentManagedPurchaseProvider(outcome: .cancelled)

        let outcome = try await manager.purchaseProduct(
            using: client,
            purchaseProvider: provider,
            productID: "storytime.plus.monthly",
            parentAccount: ParentAuthUser(
                uid: "parent-123",
                email: "parent@example.com",
                isAnonymous: false,
                signInMethod: .emailPassword
            )
        )

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertEqual(provider.purchasedProductID, "storytime.plus.monthly")
        XCTAssertNil(client.lastSyncRequest)
        XCTAssertNil(manager.snapshot)
    }

    @MainActor
    func testEntitlementManagerRequiresParentAccountBeforePurchase() async {
        let client = StubEntitlementSyncClient()
        let manager = EntitlementManager(snapshot: nil)
        let provider = StubParentManagedPurchaseProvider(
            outcome: .purchased(
                syncRequest: EntitlementSyncRequest(refreshReason: .purchase, transactions: [])
            )
        )

        do {
            _ = try await manager.purchaseProduct(
                using: client,
                purchaseProvider: provider,
                productID: "storytime.plus.monthly",
                parentAccount: nil
            )
            XCTFail("Expected purchase to require an authenticated parent account")
        } catch let error as ParentManagedPurchaseError {
            XCTAssertEqual(error, .parentAccountRequired)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(provider.purchasedProductID)
        XCTAssertNil(client.lastSyncRequest)
    }

    @MainActor
    func testEntitlementManagerPreflightsAgainstBackendContract() async throws {
        let client = StubEntitlementSyncClient()
        let manager = EntitlementManager(snapshot: nil)
        let request = EntitlementPreflightRequest(
            action: .continueStory,
            childProfileID: "11111111-1111-1111-1111-111111111111",
            childProfileCount: 1,
            requestedLengthMinutes: 4,
            selectedSeriesID: "22222222-2222-2222-2222-222222222222"
        )

        let response = try await client.preflightEntitlements(request: request)
        manager.reloadFromCache()

        XCTAssertEqual(client.lastPreflightRequest, request)
        XCTAssertFalse(response.allowed)
        XCTAssertEqual(response.blockReason, .continuationsExhausted)
        XCTAssertEqual(response.recommendedUpgradeSurface, .storySeriesDetail)
    }
}

private struct StubEntitlementPurchaseStateProvider: EntitlementPurchaseStateProviding {
    let request: EntitlementSyncRequest

    func currentSyncRequest(refreshReason: EntitlementRefreshReason) async throws -> EntitlementSyncRequest {
        XCTAssertEqual(refreshReason, request.refreshReason)
        return request
    }
}

private final class StubParentManagedPurchaseProvider: ParentManagedPurchaseProviding {
    let outcome: ParentManagedPurchaseOutcome
    private(set) var purchasedProductID: String?

    init(outcome: ParentManagedPurchaseOutcome) {
        self.outcome = outcome
    }

    func availableOptions() async throws -> [ParentManagedPurchaseOption] {
        [
            ParentManagedPurchaseOption(
                productID: "storytime.plus.monthly",
                displayName: "Plus Monthly",
                displayPrice: "$4.99"
            )
        ]
    }

    func purchase(productID: String) async throws -> ParentManagedPurchaseOutcome {
        purchasedProductID = productID
        return outcome
    }
}

@MainActor
private final class StubEntitlementSyncClient: APIClienting {
    var traceHandler: ((APIClientTraceEvent) -> Void)?
    var resolvedRegion: StoryTimeRegion? = .us
    var lastSyncRequest: EntitlementSyncRequest?
    var lastPreflightRequest: EntitlementPreflightRequest?

    func prepareConnection() async throws -> URL {
        URL(string: "https://backend.example.com")!
    }

    func bootstrapSessionIdentity(baseURL: URL) async throws {}

    func syncEntitlements(request body: EntitlementSyncRequest) async throws -> EntitlementBootstrapEnvelope {
        lastSyncRequest = body
        let envelope = EntitlementBootstrapEnvelope(
            snapshot: EntitlementSnapshot(
                tier: .plus,
                source: .storekitVerified,
                maxChildProfiles: 3,
                maxStoryStartsPerPeriod: nil,
                maxContinuationsPerPeriod: nil,
                maxStoryLengthMinutes: nil,
                canReplaySavedStories: true,
                canStartNewStories: true,
                canContinueSavedSeries: true,
                effectiveAt: Date().timeIntervalSince1970,
                expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
                usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: nil, resetsAt: nil),
                remainingStoryStarts: nil,
                remainingContinuations: nil
            ),
            token: "stub-plus-token",
            expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970
        )
        AppEntitlements.store(envelope: envelope)
        return envelope
    }

    func redeemPromoCode(request body: PromoCodeRedemptionRequest) async throws -> EntitlementBootstrapEnvelope {
        let envelope = EntitlementBootstrapEnvelope(
            snapshot: EntitlementSnapshot(
                tier: .plus,
                source: .promoGrant,
                maxChildProfiles: 3,
                maxStoryStartsPerPeriod: nil,
                maxContinuationsPerPeriod: nil,
                maxStoryLengthMinutes: nil,
                canReplaySavedStories: true,
                canStartNewStories: true,
                canContinueSavedSeries: true,
                effectiveAt: Date().timeIntervalSince1970,
                expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
                usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: nil, resetsAt: nil),
                remainingStoryStarts: nil,
                remainingContinuations: nil
            ),
            token: "stub-promo-token",
            expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
            owner: EntitlementOwner(kind: .parentUser, parentUserID: "promo-parent", authProvider: .firebase)
        )
        AppEntitlements.store(envelope: envelope)
        return envelope
    }

    func preflightEntitlements(request body: EntitlementPreflightRequest) async throws -> EntitlementPreflightResponse {
        lastPreflightRequest = body
        return EntitlementPreflightResponse(
            action: body.action,
            allowed: false,
            blockReason: .continuationsExhausted,
            recommendedUpgradeSurface: .storySeriesDetail,
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
                effectiveAt: Date().timeIntervalSince1970,
                expiresAt: Date().addingTimeInterval(300).timeIntervalSince1970,
                usageWindow: EntitlementUsageWindow(kind: .rollingPeriod, durationSeconds: nil, resetsAt: nil),
                remainingStoryStarts: 2,
                remainingContinuations: 0
            )
        )
    }

    func fetchVoices() async throws -> [String] { [] }
    func createRealtimeSession(request body: RealtimeSessionRequest) async throws -> RealtimeSessionEnvelope {
        fatalError("Not used in entitlement tests")
    }
    func discoverStoryTurn(request body: DiscoveryRequest) async throws -> DiscoveryEnvelope {
        fatalError("Not used in entitlement tests")
    }
    func generateStory(request body: GenerateStoryRequest) async throws -> GenerateStoryEnvelope {
        fatalError("Not used in entitlement tests")
    }
    func reviseStory(request body: ReviseStoryRequest) async throws -> ReviseStoryEnvelope {
        fatalError("Not used in entitlement tests")
    }
    func createEmbeddings(inputs: [String]) async throws -> [[Double]] {
        fatalError("Not used in entitlement tests")
    }

    func fetchLaunchTelemetryReport() async throws -> LaunchTelemetryJoinedReport {
        LaunchTelemetryJoinedReport(
            defaultRegion: resolvedRegion ?? .us,
            allowedRegions: StoryTimeRegion.allCases,
            backend: nil,
            client: ClientLaunchTelemetry.report()
        )
    }
}
