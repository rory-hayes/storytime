import Combine
import Foundation
#if canImport(StoreKit)
import StoreKit
#endif

private struct BackendErrorEnvelope: Decodable {
    let error: String?
    let message: String?
    let requestId: String?

    private enum CodingKeys: String, CodingKey {
        case error
        case message
        case requestId = "request_id"
    }
}

private struct SessionIdentityEnvelope: Decodable {
    let sessionId: String
    let region: StoryTimeRegion?
    let entitlements: EntitlementBootstrapEnvelope?

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case region
        case entitlements
    }
}

private struct BackendHealthEnvelope: Decodable {
    let defaultRegion: StoryTimeRegion?
    let allowedRegions: [StoryTimeRegion]?
    let telemetry: BackendAnalyticsReport?

    private enum CodingKeys: String, CodingKey {
        case defaultRegion = "default_region"
        case allowedRegions = "allowed_regions"
        case telemetry
    }
}

struct BackendAnalyticsStageSummary: Codable, Equatable {
    let callCount: Int
    let durationMs: Int
    let successCount: Int
    let failureCount: Int

    private enum CodingKeys: String, CodingKey {
        case callCount = "call_count"
        case durationMs = "duration_ms"
        case successCount = "success_count"
        case failureCount = "failure_count"
    }
}

struct BackendAnalyticsSessionSummary: Codable, Equatable {
    let requestCount: Int
    let requestDurationMs: Int
    let openAICallCount: Int
    let openAIDurationMs: Int
    let openAISuccessCount: Int
    let openAIFailureCount: Int
    let routes: [String: Int]
    let runtimeStageGroups: [String: BackendAnalyticsStageSummary]
    let launchEvents: [String: Int]
    let lastEntitlementTier: String?
    let remainingStoryStarts: Int?
    let remainingContinuations: Int?

    private enum CodingKeys: String, CodingKey {
        case requestCount = "request_count"
        case requestDurationMs = "request_duration_ms"
        case openAICallCount = "openai_call_count"
        case openAIDurationMs = "openai_duration_ms"
        case openAISuccessCount = "openai_success_count"
        case openAIFailureCount = "openai_failure_count"
        case routes
        case runtimeStageGroups = "runtime_stage_groups"
        case launchEvents = "launch_events"
        case lastEntitlementTier = "last_entitlement_tier"
        case remainingStoryStarts = "remaining_story_starts"
        case remainingContinuations = "remaining_continuations"
    }
}

struct BackendAnalyticsReport: Codable, Equatable {
    let counters: [String: Int]
    let sessions: [String: BackendAnalyticsSessionSummary]
}

struct LaunchTelemetryJoinedReport: Codable, Equatable {
    let defaultRegion: StoryTimeRegion?
    let allowedRegions: [StoryTimeRegion]?
    let backend: BackendAnalyticsReport?
    let client: ClientLaunchTelemetryReport
}

struct EntitlementBootstrapEnvelope: Codable, Equatable {
    let snapshot: EntitlementSnapshot
    let token: String
    let expiresAt: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case snapshot
        case token
        case expiresAt = "expires_at"
    }
}

enum EntitlementTier: String, Codable, Equatable, CaseIterable {
    case starter
    case plus
}

enum EntitlementSource: String, Codable, Equatable {
    case none
    case storekitVerified = "storekit_verified"
    case debugSeed = "debug_seed"
}

enum EntitlementUsageWindowKind: String, Codable, Equatable {
    case rollingPeriod = "rolling_period"
}

struct EntitlementUsageWindow: Codable, Equatable {
    let kind: EntitlementUsageWindowKind
    let durationSeconds: Int?
    let resetsAt: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case kind
        case durationSeconds = "duration_seconds"
        case resetsAt = "resets_at"
    }
}

struct EntitlementSnapshot: Codable, Equatable {
    let tier: EntitlementTier
    let source: EntitlementSource
    let maxChildProfiles: Int
    let maxStoryStartsPerPeriod: Int?
    let maxContinuationsPerPeriod: Int?
    let maxStoryLengthMinutes: Int?
    let canReplaySavedStories: Bool
    let canStartNewStories: Bool
    let canContinueSavedSeries: Bool
    let effectiveAt: TimeInterval
    let expiresAt: TimeInterval
    let usageWindow: EntitlementUsageWindow
    let remainingStoryStarts: Int?
    let remainingContinuations: Int?

    private enum CodingKeys: String, CodingKey {
        case tier
        case source
        case maxChildProfiles = "max_child_profiles"
        case maxStoryStartsPerPeriod = "max_story_starts_per_period"
        case maxContinuationsPerPeriod = "max_continuations_per_period"
        case maxStoryLengthMinutes = "max_story_length_minutes"
        case canReplaySavedStories = "can_replay_saved_stories"
        case canStartNewStories = "can_start_new_stories"
        case canContinueSavedSeries = "can_continue_saved_series"
        case effectiveAt = "effective_at"
        case expiresAt = "expires_at"
        case usageWindow = "usage_window"
        case remainingStoryStarts = "remaining_story_starts"
        case remainingContinuations = "remaining_continuations"
    }
}

enum EntitlementRefreshReason: String, Codable, Equatable {
    case appLaunch = "app_launch"
    case foreground
    case purchase
    case restore
}

enum EntitlementPurchaseEnvironment: String, Codable, Equatable {
    case xcode
    case sandbox
    case production
    case unknown
}

enum EntitlementOwnershipType: String, Codable, Equatable {
    case purchased
    case familyShared = "family_shared"
}

enum EntitlementVerificationState: String, Codable, Equatable {
    case verified
    case unverified
}

struct EntitlementSyncTransaction: Codable, Equatable {
    let productID: String
    let originalTransactionID: String
    let latestTransactionID: String
    let purchasedAt: Int
    let expiresAt: Int?
    let revokedAt: Int?
    let ownershipType: EntitlementOwnershipType
    let environment: EntitlementPurchaseEnvironment
    let verificationState: EntitlementVerificationState
    let isActive: Bool

    private enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case originalTransactionID = "original_transaction_id"
        case latestTransactionID = "latest_transaction_id"
        case purchasedAt = "purchased_at"
        case expiresAt = "expires_at"
        case revokedAt = "revoked_at"
        case ownershipType = "ownership_type"
        case environment
        case verificationState = "verification_state"
        case isActive = "is_active"
    }
}

struct EntitlementSyncRequest: Codable, Equatable {
    let refreshReason: EntitlementRefreshReason
    let storefront: String?
    let activeProductIDs: [String]
    let transactions: [EntitlementSyncTransaction]

    init(
        refreshReason: EntitlementRefreshReason,
        storefront: String? = nil,
        transactions: [EntitlementSyncTransaction]
    ) {
        self.refreshReason = refreshReason
        self.storefront = storefront?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transactions = transactions
        self.activeProductIDs = Array(
            Set(
                transactions.compactMap { transaction in
                    guard transaction.verificationState == .verified, transaction.isActive else {
                        return nil
                    }
                    return transaction.productID
                }
            )
        ).sorted()
    }

    private enum CodingKeys: String, CodingKey {
        case refreshReason = "refresh_reason"
        case storefront
        case activeProductIDs = "active_product_ids"
        case transactions
    }
}

enum EntitlementPreflightAction: String, Codable, Equatable {
    case newStory = "new_story"
    case continueStory = "continue_story"
}

enum EntitlementPreflightBlockReason: String, Codable, Equatable {
    case childProfileLimit = "child_profile_limit"
    case newStoryNotAllowed = "new_story_not_allowed"
    case continuationNotAllowed = "continuation_not_allowed"
    case storyLengthExceeded = "story_length_exceeded"
    case storyStartsExhausted = "story_starts_exhausted"
    case continuationsExhausted = "continuations_exhausted"
}

enum EntitlementUpgradeSurface: String, Codable, Equatable {
    case newStoryJourney = "new_story_journey"
    case storySeriesDetail = "story_series_detail"
    case parentTrustCenter = "parent_trust_center"
}

struct EntitlementPreflightRequest: Codable, Equatable {
    let action: EntitlementPreflightAction
    let childProfileID: String
    let childProfileCount: Int
    let requestedLengthMinutes: Int
    let selectedSeriesID: String?

    init(
        action: EntitlementPreflightAction,
        childProfileID: String,
        childProfileCount: Int,
        requestedLengthMinutes: Int,
        selectedSeriesID: String? = nil
    ) {
        self.action = action
        self.childProfileID = childProfileID
        self.childProfileCount = childProfileCount
        self.requestedLengthMinutes = requestedLengthMinutes
        self.selectedSeriesID = selectedSeriesID
    }

    init?(plan: StoryLaunchPlan, childProfileCount: Int) {
        switch plan.mode {
        case .new:
            self.init(
                action: .newStory,
                childProfileID: plan.childProfileId.uuidString,
                childProfileCount: childProfileCount,
                requestedLengthMinutes: plan.lengthMinutes
            )
        case .extend(let seriesID):
            self.init(
                action: .continueStory,
                childProfileID: plan.childProfileId.uuidString,
                childProfileCount: childProfileCount,
                requestedLengthMinutes: plan.lengthMinutes,
                selectedSeriesID: seriesID.uuidString
            )
        case .repeatEpisode:
            return nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case action
        case childProfileID = "child_profile_id"
        case childProfileCount = "child_profile_count"
        case requestedLengthMinutes = "requested_length_minutes"
        case selectedSeriesID = "selected_series_id"
    }
}

struct EntitlementPreflightResponse: Codable, Equatable {
    let action: EntitlementPreflightAction
    let allowed: Bool
    let blockReason: EntitlementPreflightBlockReason?
    let recommendedUpgradeSurface: EntitlementUpgradeSurface?
    let snapshot: EntitlementSnapshot
    let entitlements: EntitlementBootstrapEnvelope?

    init(
        action: EntitlementPreflightAction,
        allowed: Bool,
        blockReason: EntitlementPreflightBlockReason?,
        recommendedUpgradeSurface: EntitlementUpgradeSurface?,
        snapshot: EntitlementSnapshot,
        entitlements: EntitlementBootstrapEnvelope? = nil
    ) {
        self.action = action
        self.allowed = allowed
        self.blockReason = blockReason
        self.recommendedUpgradeSurface = recommendedUpgradeSurface
        self.snapshot = snapshot
        self.entitlements = entitlements
    }

    private enum CodingKeys: String, CodingKey {
        case action
        case allowed
        case blockReason = "block_reason"
        case recommendedUpgradeSurface = "recommended_upgrade_surface"
        case snapshot
        case entitlements
    }
}

private struct EntitlementSyncEnvelope: Codable {
    let entitlements: EntitlementBootstrapEnvelope
}

protocol EntitlementPurchaseStateProviding {
    func currentSyncRequest(refreshReason: EntitlementRefreshReason) async throws -> EntitlementSyncRequest
}

struct ParentManagedPurchaseOption: Equatable, Identifiable {
    let productID: String
    let displayName: String
    let displayPrice: String

    var id: String { productID }
}

enum ParentManagedPurchaseOutcome: Equatable {
    case purchased(syncRequest: EntitlementSyncRequest?)
    case pending
    case cancelled
}

enum ParentManagedPurchaseError: Error, Equatable {
    case unavailable
    case verificationFailed
}

protocol ParentManagedPurchaseProviding {
    func availableOptions() async throws -> [ParentManagedPurchaseOption]
    func purchase(productID: String) async throws -> ParentManagedPurchaseOutcome
}

private enum EntitlementProductCatalog {
    static let plusProductIDs = [
        "storytime.plus.monthly",
        "storytime.plus.yearly"
    ]
}

#if canImport(StoreKit)
@available(iOS 17.0, *)
final class StoreKitEntitlementStateProvider: EntitlementPurchaseStateProviding {
    func currentSyncRequest(refreshReason: EntitlementRefreshReason) async throws -> EntitlementSyncRequest {
        var transactions: [EntitlementSyncTransaction] = []

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                transactions.append(Self.syncTransaction(from: transaction, verificationState: .verified))
            case .unverified(let transaction, _):
                transactions.append(Self.syncTransaction(from: transaction, verificationState: .unverified))
            }
        }

        return EntitlementSyncRequest(refreshReason: refreshReason, transactions: transactions)
    }

    private static func syncTransaction(
        from transaction: Transaction,
        verificationState: EntitlementVerificationState
    ) -> EntitlementSyncTransaction {
        let expiresAt = transaction.expirationDate.map { Int($0.timeIntervalSince1970) }
        let revokedAt = transaction.revocationDate.map { Int($0.timeIntervalSince1970) }
        let now = Int(Date().timeIntervalSince1970)
        let isActive = revokedAt == nil && (expiresAt.map { $0 > now } ?? true)

        return EntitlementSyncTransaction(
            productID: transaction.productID,
            originalTransactionID: String(transaction.originalID),
            latestTransactionID: String(transaction.id),
            purchasedAt: Int(transaction.purchaseDate.timeIntervalSince1970),
            expiresAt: expiresAt,
            revokedAt: revokedAt,
            ownershipType: entitlementOwnershipType(from: transaction.ownershipType),
            environment: entitlementEnvironment(from: transaction.environment),
            verificationState: verificationState,
            isActive: isActive
        )
    }

    private static func entitlementOwnershipType(from ownershipType: Transaction.OwnershipType) -> EntitlementOwnershipType {
        if ownershipType == .familyShared {
            return .familyShared
        }

        return .purchased
    }

    private static func entitlementEnvironment(from environment: AppStore.Environment) -> EntitlementPurchaseEnvironment {
        if environment == .production {
            return .production
        }

        if environment == .sandbox {
            return .sandbox
        }

        if environment == .xcode {
            return .xcode
        }

        return .unknown
    }
}

@available(iOS 17.0, *)
final class StoreKitParentManagedPurchaseProvider: ParentManagedPurchaseProviding {
    func availableOptions() async throws -> [ParentManagedPurchaseOption] {
        let products = try await Product.products(for: EntitlementProductCatalog.plusProductIDs)
        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        return EntitlementProductCatalog.plusProductIDs.compactMap { productID in
            guard let product = productsByID[productID] else { return nil }
            return ParentManagedPurchaseOption(
                productID: productID,
                displayName: product.displayName,
                displayPrice: product.displayPrice
            )
        }
    }

    func purchase(productID: String) async throws -> ParentManagedPurchaseOutcome {
        guard let product = try await Product.products(for: [productID]).first else {
            throw ParentManagedPurchaseError.unavailable
        }

        let result = try await product.purchase()
        switch result {
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                let syncRequest = try await StoreKitEntitlementStateProvider().currentSyncRequest(refreshReason: .purchase)
                return .purchased(syncRequest: syncRequest)
            case .unverified:
                throw ParentManagedPurchaseError.verificationFailed
            }
        @unknown default:
            return .cancelled
        }
    }
}
#endif

struct UnsupportedParentManagedPurchaseProvider: ParentManagedPurchaseProviding {
    func availableOptions() async throws -> [ParentManagedPurchaseOption] {
        []
    }

    func purchase(productID: String) async throws -> ParentManagedPurchaseOutcome {
        throw ParentManagedPurchaseError.unavailable
    }
}

enum APIClientTraceOperation: String, Equatable, Hashable {
    case healthCheck
    case sessionBootstrap
    case entitlementSync = "entitlement_sync"
    case entitlementPreflight = "entitlement_preflight"
    case voices
    case realtimeSession
    case storyDiscovery
    case storyGeneration
    case storyRevision
    case embeddings
}

enum RuntimeTelemetryStage: String, Equatable, Hashable {
    case discovery
    case storyGeneration = "story_generation"
    case answerOnlyInteraction = "answer_only_interaction"
    case reviseFutureScenes = "revise_future_scenes"
    case ttsGeneration = "tts_generation"
    case ttsPlaybackStarted = "tts_playback_started"
    case ttsPlaybackCompleted = "tts_playback_completed"
    case ttsPlaybackCancelled = "tts_playback_cancelled"
    case continuityRetrieval = "continuity_retrieval"
}

enum RuntimeTelemetryStageGroup: String, Equatable, Hashable {
    case interaction
    case generation
    case narration
    case revision
}

extension RuntimeTelemetryStage {
    var stageGroup: RuntimeTelemetryStageGroup? {
        switch self {
        case .discovery, .answerOnlyInteraction:
            return .interaction
        case .storyGeneration:
            return .generation
        case .ttsGeneration, .ttsPlaybackStarted, .ttsPlaybackCompleted, .ttsPlaybackCancelled:
            return .narration
        case .reviseFutureScenes:
            return .revision
        case .continuityRetrieval:
            return nil
        }
    }
}

enum RuntimeTelemetryCostDriver: String, Equatable, Hashable {
    case remoteModel = "remote_model"
    case realtimeInteraction = "realtime_interaction"
    case localSpeech = "local_speech"
    case localData = "local_data"
}

extension APIClientTraceOperation {
    var runtimeStage: RuntimeTelemetryStage? {
        switch self {
        case .storyDiscovery:
            return .discovery
        case .storyGeneration:
            return .storyGeneration
        case .storyRevision:
            return .reviseFutureScenes
        case .embeddings:
            return .continuityRetrieval
        case .healthCheck, .sessionBootstrap, .entitlementSync, .entitlementPreflight, .voices, .realtimeSession:
            return nil
        }
    }

    var runtimeCostDriver: RuntimeTelemetryCostDriver? {
        switch self {
        case .storyDiscovery, .storyGeneration, .storyRevision, .embeddings:
            return .remoteModel
        case .healthCheck, .sessionBootstrap, .entitlementSync, .entitlementPreflight, .voices, .realtimeSession:
            return nil
        }
    }
}

enum ClientLaunchTelemetryEventName: String, Codable, Equatable {
    case entitlementSync = "entitlement_sync"
    case entitlementPreflight = "entitlement_preflight"
    case blockedReviewPresented = "blocked_review_presented"
    case parentPlanPresented = "parent_plan_presented"
    case parentPlanRefresh = "parent_plan_refresh"
    case restorePurchases = "restore_purchases"
}

enum ClientLaunchTelemetryOutcome: String, Codable, Equatable {
    case started
    case completed
    case failed
    case allowed
    case blocked
    case presented
}

struct ClientLaunchTelemetryEvent: Codable, Equatable {
    let name: ClientLaunchTelemetryEventName
    let outcome: ClientLaunchTelemetryOutcome
    let sessionId: String?
    let requestId: String?
    let refreshReason: EntitlementRefreshReason?
    let action: EntitlementPreflightAction?
    let blockReason: EntitlementPreflightBlockReason?
    let surface: EntitlementUpgradeSurface?
    let entitlementTier: EntitlementTier?
    let remainingStoryStarts: Int?
    let remainingContinuations: Int?
}

struct ClientLaunchTelemetrySessionSummary: Codable, Equatable {
    let launchEvents: [String: Int]
    let lastEntitlementTier: EntitlementTier?
    let remainingStoryStarts: Int?
    let remainingContinuations: Int?
}

struct ClientLaunchTelemetryReport: Codable, Equatable {
    let counters: [String: Int]
    let sessions: [String: ClientLaunchTelemetrySessionSummary]
    let events: [ClientLaunchTelemetryEvent]
}

final class ClientLaunchTelemetry {
    static let shared = ClientLaunchTelemetry()

    private let lock = NSLock()
    private let storageKey = "com.storytime.client-launch-telemetry.v1"
    private var counters: [String: Int] = [:]
    private var events: [ClientLaunchTelemetryEvent] = []
    private var sessionSummaries: [String: MutableSessionSummary] = [:]
    private var userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadPersistedStateLocked()
    }

    static func reset() {
        shared.resetLocked()
    }

    static func report() -> ClientLaunchTelemetryReport {
        shared.reportLocked()
    }

    static func replacePersistentStoreForTesting(userDefaults: UserDefaults) {
        shared.replacePersistentStoreLocked(userDefaults)
    }

    static func reloadPersistedStateForTesting() {
        shared.reloadPersistedStateLocked()
    }

    static func recordEntitlementSync(
        refreshReason: EntitlementRefreshReason,
        snapshot: EntitlementSnapshot,
        requestId: String?
    ) {
        shared.record(
            ClientLaunchTelemetryEvent(
                name: .entitlementSync,
                outcome: .completed,
                sessionId: AppSession.currentSessionId,
                requestId: requestId,
                refreshReason: refreshReason,
                action: nil,
                blockReason: nil,
                surface: nil,
                entitlementTier: snapshot.tier,
                remainingStoryStarts: snapshot.remainingStoryStarts,
                remainingContinuations: snapshot.remainingContinuations
            )
        )
    }

    static func recordEntitlementSyncFailure(
        refreshReason: EntitlementRefreshReason,
        requestId: String?
    ) {
        shared.record(
            ClientLaunchTelemetryEvent(
                name: .entitlementSync,
                outcome: .failed,
                sessionId: AppSession.currentSessionId,
                requestId: requestId,
                refreshReason: refreshReason,
                action: nil,
                blockReason: nil,
                surface: nil,
                entitlementTier: nil,
                remainingStoryStarts: nil,
                remainingContinuations: nil
            )
        )
    }

    static func recordEntitlementPreflight(
        response: EntitlementPreflightResponse,
        requestId: String?
    ) {
        shared.record(
            ClientLaunchTelemetryEvent(
                name: .entitlementPreflight,
                outcome: response.allowed ? .allowed : .blocked,
                sessionId: AppSession.currentSessionId,
                requestId: requestId,
                refreshReason: nil,
                action: response.action,
                blockReason: response.blockReason,
                surface: response.recommendedUpgradeSurface,
                entitlementTier: response.snapshot.tier,
                remainingStoryStarts: response.snapshot.remainingStoryStarts,
                remainingContinuations: response.snapshot.remainingContinuations
            )
        )
    }

    static func recordEntitlementPreflightFailure(
        action: EntitlementPreflightAction,
        requestId: String?
    ) {
        shared.record(
            ClientLaunchTelemetryEvent(
                name: .entitlementPreflight,
                outcome: .failed,
                sessionId: AppSession.currentSessionId,
                requestId: requestId,
                refreshReason: nil,
                action: action,
                blockReason: nil,
                surface: nil,
                entitlementTier: nil,
                remainingStoryStarts: nil,
                remainingContinuations: nil
            )
        )
    }

    static func recordBlockedReviewPresented(
        surface: EntitlementUpgradeSurface,
        response: EntitlementPreflightResponse
    ) {
        shared.record(
            ClientLaunchTelemetryEvent(
                name: .blockedReviewPresented,
                outcome: .presented,
                sessionId: AppSession.currentSessionId,
                requestId: nil,
                refreshReason: nil,
                action: response.action,
                blockReason: response.blockReason,
                surface: surface,
                entitlementTier: response.snapshot.tier,
                remainingStoryStarts: response.snapshot.remainingStoryStarts,
                remainingContinuations: response.snapshot.remainingContinuations
            )
        )
    }

    static func recordParentPlanPresented(snapshot: EntitlementSnapshot?) {
        shared.record(
            event(
                name: .parentPlanPresented,
                outcome: .presented,
                surface: .parentTrustCenter,
                snapshot: snapshot
            )
        )
    }

    static func recordParentPlanRefresh(
        outcome: ClientLaunchTelemetryOutcome,
        snapshot: EntitlementSnapshot?
    ) {
        shared.record(
            event(
                name: .parentPlanRefresh,
                outcome: outcome,
                surface: .parentTrustCenter,
                snapshot: snapshot
            )
        )
    }

    static func recordRestorePurchases(
        outcome: ClientLaunchTelemetryOutcome,
        snapshot: EntitlementSnapshot?
    ) {
        shared.record(
            event(
                name: .restorePurchases,
                outcome: outcome,
                refreshReason: .restore,
                surface: .parentTrustCenter,
                snapshot: snapshot
            )
        )
    }

    private static func event(
        name: ClientLaunchTelemetryEventName,
        outcome: ClientLaunchTelemetryOutcome,
        refreshReason: EntitlementRefreshReason? = nil,
        surface: EntitlementUpgradeSurface? = nil,
        snapshot: EntitlementSnapshot?
    ) -> ClientLaunchTelemetryEvent {
        ClientLaunchTelemetryEvent(
            name: name,
            outcome: outcome,
            sessionId: AppSession.currentSessionId,
            requestId: nil,
            refreshReason: refreshReason,
            action: nil,
            blockReason: nil,
            surface: surface,
            entitlementTier: snapshot?.tier,
            remainingStoryStarts: snapshot?.remainingStoryStarts,
            remainingContinuations: snapshot?.remainingContinuations
        )
    }

    private func record(_ event: ClientLaunchTelemetryEvent) {
        lock.lock()
        defer { lock.unlock() }

        events.append(event)
        incrementCounter(&counters, key: "launch:\(event.name.rawValue):\(event.outcome.rawValue)")
        if let action = event.action {
            incrementCounter(&counters, key: "launch_action:\(action.rawValue):\(event.outcome.rawValue)")
        }
        if let blockReason = event.blockReason {
            incrementCounter(&counters, key: "launch_block:\(blockReason.rawValue)")
        }
        if let refreshReason = event.refreshReason {
            incrementCounter(&counters, key: "launch_refresh:\(refreshReason.rawValue):\(event.outcome.rawValue)")
        }
        if let surface = event.surface {
            incrementCounter(&counters, key: "launch_surface:\(surface.rawValue):\(event.outcome.rawValue)")
        }

        guard let sessionId = event.sessionId else {
            persistLocked()
            return
        }
        var summary = sessionSummaries[sessionId] ?? MutableSessionSummary()
        summary.increment("launch:\(event.name.rawValue):\(event.outcome.rawValue)")
        if let action = event.action {
            summary.increment("action:\(action.rawValue):\(event.outcome.rawValue)")
        }
        if let blockReason = event.blockReason {
            summary.increment("block:\(blockReason.rawValue)")
        }
        if let refreshReason = event.refreshReason {
            summary.increment("refresh:\(refreshReason.rawValue):\(event.outcome.rawValue)")
        }
        if let surface = event.surface {
            summary.increment("surface:\(surface.rawValue):\(event.outcome.rawValue)")
        }
        if let entitlementTier = event.entitlementTier {
            summary.lastEntitlementTier = entitlementTier
        }
        summary.remainingStoryStarts = event.remainingStoryStarts
        summary.remainingContinuations = event.remainingContinuations
        sessionSummaries[sessionId] = summary
        persistLocked()
    }

    private func reportLocked() -> ClientLaunchTelemetryReport {
        lock.lock()
        defer { lock.unlock() }

        return reportUnlocked()
    }

    private func reportUnlocked() -> ClientLaunchTelemetryReport {
        ClientLaunchTelemetryReport(
            counters: counters,
            sessions: Dictionary(
                uniqueKeysWithValues: sessionSummaries.map { key, value in
                    (
                        key,
                        ClientLaunchTelemetrySessionSummary(
                            launchEvents: value.launchEvents,
                            lastEntitlementTier: value.lastEntitlementTier,
                            remainingStoryStarts: value.remainingStoryStarts,
                            remainingContinuations: value.remainingContinuations
                        )
                    )
                }
            ),
            events: events
        )
    }

    private func replacePersistentStoreLocked(_ userDefaults: UserDefaults) {
        lock.lock()
        defer { lock.unlock() }
        self.userDefaults = userDefaults
        loadPersistedStateLocked()
    }

    private func reloadPersistedStateLocked() {
        lock.lock()
        defer { lock.unlock() }
        loadPersistedStateLocked()
    }

    private func loadPersistedStateLocked() {
        counters.removeAll()
        events.removeAll()
        sessionSummaries.removeAll()

        guard let data = userDefaults.data(forKey: storageKey),
              let report = try? JSONDecoder().decode(ClientLaunchTelemetryReport.self, from: data) else {
            return
        }

        counters = report.counters
        events = report.events
        sessionSummaries = Dictionary(
            uniqueKeysWithValues: report.sessions.map { key, value in
                (
                    key,
                    MutableSessionSummary(
                        launchEvents: value.launchEvents,
                        lastEntitlementTier: value.lastEntitlementTier,
                        remainingStoryStarts: value.remainingStoryStarts,
                        remainingContinuations: value.remainingContinuations
                    )
                )
            }
        )
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(reportUnlocked()) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func resetLocked() {
        lock.lock()
        defer { lock.unlock() }
        counters.removeAll()
        events.removeAll()
        sessionSummaries.removeAll()
        userDefaults.removeObject(forKey: storageKey)
    }

    private struct MutableSessionSummary {
        var launchEvents: [String: Int] = [:]
        var lastEntitlementTier: EntitlementTier?
        var remainingStoryStarts: Int?
        var remainingContinuations: Int?

        mutating func increment(_ key: String) {
            launchEvents[key] = (launchEvents[key] ?? 0) + 1
        }
    }
}

private func incrementCounter(_ counters: inout [String: Int], key: String) {
    counters[key] = (counters[key] ?? 0) + 1
}

enum APIClientTracePhase: String, Equatable {
    case started
    case completed
    case transportFailed
}

struct APIClientTraceEvent: Equatable {
    let operation: APIClientTraceOperation
    let phase: APIClientTracePhase
    let route: String
    let requestId: String
    let sessionId: String?
    let statusCode: Int?
    let runtimeStage: RuntimeTelemetryStage?
    let costDriver: RuntimeTelemetryCostDriver?
    let durationMs: Int?

    var runtimeStageGroup: RuntimeTelemetryStageGroup? {
        runtimeStage?.stageGroup
    }

    init(
        operation: APIClientTraceOperation,
        phase: APIClientTracePhase,
        route: String,
        requestId: String,
        sessionId: String?,
        statusCode: Int?,
        runtimeStage: RuntimeTelemetryStage? = nil,
        costDriver: RuntimeTelemetryCostDriver? = nil,
        durationMs: Int? = nil
    ) {
        self.operation = operation
        self.phase = phase
        self.route = route
        self.requestId = requestId
        self.sessionId = sessionId
        self.statusCode = statusCode
        self.runtimeStage = runtimeStage
        self.costDriver = costDriver
        self.durationMs = durationMs
    }
}

protocol APIClienting: AnyObject {
    var traceHandler: ((APIClientTraceEvent) -> Void)? { get set }
    var resolvedRegion: StoryTimeRegion? { get }
    func prepareConnection() async throws -> URL
    func bootstrapSessionIdentity(baseURL: URL) async throws
    func fetchLaunchTelemetryReport() async throws -> LaunchTelemetryJoinedReport
    func syncEntitlements(request body: EntitlementSyncRequest) async throws -> EntitlementBootstrapEnvelope
    func preflightEntitlements(request body: EntitlementPreflightRequest) async throws -> EntitlementPreflightResponse
    func fetchVoices() async throws -> [String]
    func createRealtimeSession(request body: RealtimeSessionRequest) async throws -> RealtimeSessionEnvelope
    func discoverStoryTurn(request body: DiscoveryRequest) async throws -> DiscoveryEnvelope
    func generateStory(request body: GenerateStoryRequest) async throws -> GenerateStoryEnvelope
    func reviseStory(request body: ReviseStoryRequest) async throws -> ReviseStoryEnvelope
    func createEmbeddings(inputs: [String]) async throws -> [[Double]]
}

final class APIClient: APIClienting {
    var traceHandler: ((APIClientTraceEvent) -> Void)?
    var resolvedRegion: StoryTimeRegion? { AppSession.currentRegion }

    private let session: URLSession
    private let candidateBaseURLs: [URL]
    private let installId: String
    private var activeBaseURL: URL?

    init(
        baseURLs: [URL] = AppConfig.candidateAPIBaseURLs,
        session: URLSession = .shared,
        installId: String = AppInstall.identity
    ) {
        self.candidateBaseURLs = baseURLs
        self.session = session
        self.installId = installId
    }

    func prepareConnection() async throws -> URL {
        if let activeBaseURL, await isHealthy(baseURL: activeBaseURL) {
            return activeBaseURL
        }

        return try await withAvailableBaseURL { [self] baseURL in
            try await self.assertHealthy(baseURL: baseURL)
            return baseURL
        }
    }

    func bootstrapSessionIdentity(baseURL: URL) async throws {
        try await ensureSessionIdentity(baseURL: baseURL)
    }

    func fetchLaunchTelemetryReport() async throws -> LaunchTelemetryJoinedReport {
        try await withAvailableBaseURL { [self] baseURL in
            let endpoint = baseURL.appending(path: "health")
            var request = URLRequest(url: endpoint)
            request.timeoutInterval = 8
            request.httpMethod = "GET"
            self.applyInstallHeaders(to: &request)

            let (data, response) = try await self.perform(request, operation: .healthCheck)
            try self.validate(response: response, data: data)
            let envelope = try JSONDecoder().decode(BackendHealthEnvelope.self, from: data)
            self.storeResolvedRegion(from: envelope)

            return LaunchTelemetryJoinedReport(
                defaultRegion: envelope.defaultRegion,
                allowedRegions: envelope.allowedRegions,
                backend: envelope.telemetry,
                client: ClientLaunchTelemetry.report()
            )
        }
    }

    func syncEntitlements(request body: EntitlementSyncRequest) async throws -> EntitlementBootstrapEnvelope {
        try await withAvailableBaseURL { [self] baseURL in
            try await withAuthenticatedSession(baseURL: baseURL) {
                let endpoint = baseURL.appending(path: "v1").appending(path: "entitlements").appending(path: "sync")
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
                request.timeoutInterval = 20
                self.applyInstallHeaders(to: &request)

                do {
                    let (data, response) = try await self.perform(request, operation: .entitlementSync)
                    try self.validate(response: response, data: data)
                    let envelope = try JSONDecoder().decode(EntitlementSyncEnvelope.self, from: data).entitlements
                    AppEntitlements.store(envelope: envelope)
                    ClientLaunchTelemetry.recordEntitlementSync(
                        refreshReason: body.refreshReason,
                        snapshot: envelope.snapshot,
                        requestId: self.launchTelemetryRequestID(from: response, request: request)
                    )
                    return envelope
                } catch {
                    ClientLaunchTelemetry.recordEntitlementSyncFailure(
                        refreshReason: body.refreshReason,
                        requestId: self.launchTelemetryRequestID(from: nil, request: request, error: error)
                    )
                    throw error
                }
            }
        }
    }

    func preflightEntitlements(request body: EntitlementPreflightRequest) async throws -> EntitlementPreflightResponse {
        try await withAvailableBaseURL { [self] baseURL in
            try await withAuthenticatedSession(baseURL: baseURL) {
                let endpoint = baseURL.appending(path: "v1").appending(path: "entitlements").appending(path: "preflight")
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
                request.timeoutInterval = 20
                self.applyInstallHeaders(to: &request)
                self.applyEntitlementHeader(to: &request)

                do {
                    let (data, response) = try await self.perform(request, operation: .entitlementPreflight)
                    try self.validate(response: response, data: data)
                    let decoded = try JSONDecoder().decode(EntitlementPreflightResponse.self, from: data)
                    if let envelope = decoded.entitlements {
                        AppEntitlements.store(envelope: envelope)
                    }
                    ClientLaunchTelemetry.recordEntitlementPreflight(
                        response: decoded,
                        requestId: self.launchTelemetryRequestID(from: response, request: request)
                    )
                    return decoded
                } catch {
                    ClientLaunchTelemetry.recordEntitlementPreflightFailure(
                        action: body.action,
                        requestId: self.launchTelemetryRequestID(from: nil, request: request, error: error)
                    )
                    throw error
                }
            }
        }
    }

    func fetchVoices() async throws -> [String] {
        try await withAvailableBaseURL { [self] baseURL in
            let endpoint = baseURL.appending(path: "v1").appending(path: "voices")
            var request = URLRequest(url: endpoint)
            request.timeoutInterval = 12
            applyInstallHeaders(to: &request)

            let (data, response) = try await self.perform(request, operation: .voices)
            try self.validate(response: response, data: data)
            let decoded = try JSONDecoder().decode(VoicesResponse.self, from: data)
            self.reconcileResolvedRegion(with: decoded.regions)
            return decoded.voices
        }
    }

    func createRealtimeSession(request body: RealtimeSessionRequest) async throws -> RealtimeSessionEnvelope {
        try await withAvailableBaseURL { [self] baseURL in
            try await withAuthenticatedSession(baseURL: baseURL) {
                let alignedRegion = self.resolvedRegion ?? body.region
                let alignedRequest = RealtimeSessionRequest(
                    childProfileId: body.childProfileId,
                    voice: body.voice,
                    region: alignedRegion
                )
                let endpoint = baseURL.appending(path: "v1").appending(path: "realtime").appending(path: "session")
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(alignedRequest)
                request.timeoutInterval = 20
                self.applyInstallHeaders(to: &request, region: alignedRegion)

                let (data, response) = try await self.perform(request, operation: .realtimeSession)
                try self.validate(response: response, data: data)
                return try JSONDecoder().decode(RealtimeSessionEnvelope.self, from: data)
            }
        }
    }

    func discoverStoryTurn(request body: DiscoveryRequest) async throws -> DiscoveryEnvelope {
        try await withAvailableBaseURL { [self] baseURL in
            try await withAuthenticatedSession(baseURL: baseURL) {
                let endpoint = baseURL.appending(path: "v1").appending(path: "story").appending(path: "discovery")
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
                request.timeoutInterval = 20
                self.applyInstallHeaders(to: &request)

                let (data, response) = try await self.perform(request, operation: .storyDiscovery)
                let statusCode = response.statusCode
                if statusCode == 422 {
                    return try JSONDecoder().decode(DiscoveryEnvelope.self, from: data)
                }
                try self.validate(response: response, data: data)
                return try JSONDecoder().decode(DiscoveryEnvelope.self, from: data)
            }
        }
    }

    func generateStory(request body: GenerateStoryRequest) async throws -> GenerateStoryEnvelope {
        try await withAvailableBaseURL { [self] baseURL in
            try await withAuthenticatedSession(baseURL: baseURL) {
                let endpoint = baseURL.appending(path: "v1").appending(path: "story").appending(path: "generate")
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
                request.timeoutInterval = 20
                self.applyInstallHeaders(to: &request)

                let (data, response) = try await self.perform(request, operation: .storyGeneration)
                let statusCode = response.statusCode
                if statusCode == 422 {
                    return try JSONDecoder().decode(GenerateStoryEnvelope.self, from: data)
                }
                try self.validate(response: response, data: data)
                return try JSONDecoder().decode(GenerateStoryEnvelope.self, from: data)
            }
        }
    }

    func reviseStory(request body: ReviseStoryRequest) async throws -> ReviseStoryEnvelope {
        try await withAvailableBaseURL { [self] baseURL in
            try await withAuthenticatedSession(baseURL: baseURL) {
                let endpoint = baseURL.appending(path: "v1").appending(path: "story").appending(path: "revise")
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
                request.timeoutInterval = 20
                self.applyInstallHeaders(to: &request)

                let (data, response) = try await self.perform(request, operation: .storyRevision)
                let statusCode = response.statusCode
                if statusCode == 422 {
                    return try JSONDecoder().decode(ReviseStoryEnvelope.self, from: data)
                }
                try self.validate(response: response, data: data)
                return try JSONDecoder().decode(ReviseStoryEnvelope.self, from: data)
            }
        }
    }

    func createEmbeddings(inputs: [String]) async throws -> [[Double]] {
        try await withAvailableBaseURL { [self] baseURL in
            try await withAuthenticatedSession(baseURL: baseURL) {
                let endpoint = baseURL.appending(path: "v1").appending(path: "embeddings").appending(path: "create")
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(EmbeddingsCreateRequest(inputs: inputs))
                request.timeoutInterval = 20
                self.applyInstallHeaders(to: &request)

                let (data, response) = try await self.perform(request, operation: .embeddings)
                try self.validate(response: response, data: data)
                return try JSONDecoder().decode(EmbeddingsCreateResponse.self, from: data).embeddings
            }
        }
    }

    private func withAvailableBaseURL<T>(_ operation: @escaping (URL) async throws -> T) async throws -> T {
        var lastError: Error?
        for baseURL in orderedBaseURLs {
            do {
                let result = try await operation(baseURL)
                activeBaseURL = baseURL
                return result
            } catch {
                if shouldTryNextBaseURL(for: error) {
                    lastError = error
                    continue
                }

                throw error
            }
        }

        if let lastError {
            throw lastError
        }

        throw APIError.connectionFailed(candidateBaseURLs)
    }

    private var orderedBaseURLs: [URL] {
        if let activeBaseURL {
            return [activeBaseURL] + candidateBaseURLs.filter { $0 != activeBaseURL }
        }
        return candidateBaseURLs
    }

    private func perform(_ request: URLRequest, operation: APIClientTraceOperation) async throws -> (Data, HTTPURLResponse) {
        let route = request.url?.path ?? "/"
        let requestId = request.value(forHTTPHeaderField: "x-request-id") ?? nextRequestId()
        let startedAt = DispatchTime.now().uptimeNanoseconds
        var didEmitTransportFailure = false
        emitTrace(
            APIClientTraceEvent(
                operation: operation,
                phase: .started,
                route: route,
                requestId: requestId,
                sessionId: AppSession.currentSessionId,
                statusCode: nil,
                runtimeStage: operation.runtimeStage,
                costDriver: operation.runtimeCostDriver
            )
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                emitTrace(
                    APIClientTraceEvent(
                        operation: operation,
                        phase: .transportFailed,
                        route: route,
                        requestId: requestId,
                        sessionId: AppSession.currentSessionId,
                        statusCode: nil,
                        runtimeStage: operation.runtimeStage,
                        costDriver: operation.runtimeCostDriver,
                        durationMs: Self.durationMs(since: startedAt)
                    )
                )
                didEmitTransportFailure = true
                throw APIError.connectionFailed(candidateBaseURLs)
            }

            AppSession.store(from: http)
            emitTrace(
                APIClientTraceEvent(
                    operation: operation,
                    phase: .completed,
                    route: route,
                    requestId: http.value(forHTTPHeaderField: "x-request-id") ?? requestId,
                    sessionId: AppSession.currentSessionId,
                    statusCode: http.statusCode,
                    runtimeStage: operation.runtimeStage,
                    costDriver: operation.runtimeCostDriver,
                    durationMs: Self.durationMs(since: startedAt)
                )
            )
            return (data, http)
        } catch {
            if !didEmitTransportFailure {
                emitTrace(
                    APIClientTraceEvent(
                        operation: operation,
                        phase: .transportFailed,
                        route: route,
                        requestId: requestId,
                        sessionId: AppSession.currentSessionId,
                        statusCode: nil,
                        runtimeStage: operation.runtimeStage,
                        costDriver: operation.runtimeCostDriver,
                        durationMs: Self.durationMs(since: startedAt)
                    )
                )
            }
            throw error
        }
    }

    private func ensureSessionIdentity(baseURL: URL) async throws {
        if AppSession.currentToken != nil {
            return
        }

        let endpoint = baseURL.appending(path: "v1").appending(path: "session").appending(path: "identity")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        applyInstallHeaders(to: &request)

        do {
            let (data, response) = try await perform(request, operation: .sessionBootstrap)
            try validate(response: response, data: data)
            if let envelope = try? JSONDecoder().decode(SessionIdentityEnvelope.self, from: data) {
                AppSession.store(sessionId: envelope.sessionId)
                if let region = envelope.region {
                    AppSession.store(region: region)
                }
                if let entitlements = envelope.entitlements {
                    AppEntitlements.store(envelope: entitlements)
                } else {
                    AppEntitlements.clear()
                }
            }
        } catch let error as APIError {
            switch error {
            case .invalidResponse(let statusCode, _, _, _, _) where [404, 405, 501].contains(statusCode):
                // Legacy backends may not expose session bootstrap yet. Continue without a session token
                // when the route is absent so the app can still use provisional install-based auth.
                AppSession.clear()
                AppEntitlements.clear()
                return
            default:
                throw error
            }
        }
    }

    private func withAuthenticatedSession<T>(
        baseURL: URL,
        attempt: @escaping () async throws -> T
    ) async throws -> T {
        try await ensureSessionIdentity(baseURL: baseURL)

        do {
            return try await attempt()
        } catch let error as APIError where shouldRefreshSession(for: error) {
            AppSession.clear()
            try await ensureSessionIdentity(baseURL: baseURL)
            return try await attempt()
        }
    }

    private func shouldRefreshSession(for error: APIError) -> Bool {
        guard case .invalidResponse(let statusCode, let code, _, _, _) = error else {
            return false
        }

        guard statusCode == 401 else {
            return false
        }

        return ["missing_session_token", "invalid_session_token", "invalid_session_token_expired"].contains(code)
    }

    private func validate(response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let envelope = try? JSONDecoder().decode(BackendErrorEnvelope.self, from: data)
            throw APIError.invalidResponse(
                statusCode: response.statusCode,
                code: envelope?.error,
                message: envelope?.message,
                requestId: envelope?.requestId ?? response.value(forHTTPHeaderField: "x-request-id"),
                body: body
            )
        }
    }

    private func assertHealthy(baseURL: URL) async throws {
        let endpoint = baseURL.appending(path: "health")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 8
        request.httpMethod = "GET"
        applyInstallHeaders(to: &request)

        let (data, response) = try await perform(request, operation: .healthCheck)
        try validate(response: response, data: data)
        if let envelope = try? JSONDecoder().decode(BackendHealthEnvelope.self, from: data) {
            storeResolvedRegion(from: envelope)
        }
    }

    private func shouldTryNextBaseURL(for error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .networkConnectionLost, .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff, .secureConnectionFailed, .cannotLoadFromNetwork:
                return true
            default:
                return false
            }
        }

        if let apiError = error as? APIError {
            switch apiError {
            case .invalidResponse(let statusCode, _, _, _, _):
                return statusCode == 404 || statusCode == 405 || statusCode == 501
            case .connectionFailed:
                return true
            }
        }

        if error is DecodingError {
            return true
        }

        return false
    }

    private func isHealthy(baseURL: URL) async -> Bool {
        let endpoint = baseURL.appending(path: "health")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 8
        request.httpMethod = "GET"
        applyInstallHeaders(to: &request)

        do {
            let (data, response) = try await perform(request, operation: .healthCheck)
            if (200..<300).contains(response.statusCode),
               let envelope = try? JSONDecoder().decode(BackendHealthEnvelope.self, from: data) {
                storeResolvedRegion(from: envelope)
            }
            return (200..<300).contains(response.statusCode)
        } catch {
            return false
        }
    }

    private func applyInstallHeaders(to request: inout URLRequest, region: StoryTimeRegion? = AppSession.currentRegion) {
        request.setValue(installId, forHTTPHeaderField: "x-storytime-install-id")
        request.setValue("StoryTime-iOS/1.0", forHTTPHeaderField: "x-storytime-client")
        if request.value(forHTTPHeaderField: "x-request-id") == nil {
            request.setValue(nextRequestId(), forHTTPHeaderField: "x-request-id")
        }
        if let region {
            request.setValue(region.rawValue, forHTTPHeaderField: "x-storytime-region")
        }
        if let sessionToken = AppSession.currentToken {
            request.setValue(sessionToken, forHTTPHeaderField: "x-storytime-session")
        }
    }

    private func applyEntitlementHeader(to request: inout URLRequest) {
        if let entitlementToken = AppEntitlements.currentToken {
            request.setValue(entitlementToken, forHTTPHeaderField: "x-storytime-entitlement")
        }
    }

    private func storeResolvedRegion(from envelope: BackendHealthEnvelope) {
        if let defaultRegion = envelope.defaultRegion {
            AppSession.store(region: defaultRegion)
            return
        }

        if let allowedRegions = envelope.allowedRegions, allowedRegions.count == 1 {
            AppSession.store(region: allowedRegions[0])
        }
    }

    private func reconcileResolvedRegion(with availableRegions: [StoryTimeRegion]?) {
        guard let availableRegions, !availableRegions.isEmpty else { return }

        if let resolvedRegion, availableRegions.contains(resolvedRegion) {
            return
        }

        if availableRegions.count == 1 {
            AppSession.store(region: availableRegions[0])
        }
    }

    private func nextRequestId() -> String {
        "ios-\(UUID().uuidString.lowercased())"
    }

    private static func durationMs(since startedAt: UInt64) -> Int {
        Int((DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000)
    }

    private func emitTrace(_ event: APIClientTraceEvent) {
        traceHandler?(event)
    }

    private func launchTelemetryRequestID(
        from response: HTTPURLResponse?,
        request: URLRequest,
        error: Error? = nil
    ) -> String? {
        if let apiError = error as? APIError, let requestId = apiError.requestId, !requestId.isEmpty {
            return requestId
        }

        if let responseRequestID = response?.value(forHTTPHeaderField: "x-request-id"), !responseRequestID.isEmpty {
            return responseRequestID
        }

        if let requestRequestID = request.value(forHTTPHeaderField: "x-request-id"), !requestRequestID.isEmpty {
            return requestRequestID
        }

        return nil
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse(statusCode: Int, code: String?, message: String?, requestId: String?, body: String)
    case connectionFailed([URL])

    var statusCode: Int? {
        guard case .invalidResponse(let statusCode, _, _, _, _) = self else {
            return nil
        }
        return statusCode
    }

    var serverCode: String? {
        guard case .invalidResponse(_, let code, _, _, _) = self else {
            return nil
        }
        return code
    }

    var serverMessage: String? {
        guard case .invalidResponse(_, _, let message, _, _) = self else {
            return nil
        }
        return message
    }

    var requestId: String? {
        guard case .invalidResponse(_, _, _, let requestId, _) = self else {
            return nil
        }
        return requestId
    }

    var rawBody: String? {
        guard case .invalidResponse(_, _, _, _, let body) = self else {
            return nil
        }
        return body
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode, _, let message, _, _):
            if let message, !message.isEmpty {
                return "Server returned an error (\(statusCode)). \(message)"
            }
            return "Server returned an error (\(statusCode))."
        case .connectionFailed(let candidates):
            let joined = candidates.map(\.absoluteString).joined(separator: ", ")
            return "Could not connect to backend. Tried: \(joined)"
        }
    }
}

enum AppInstall {
    private static let key = "com.storytime.install-id"

    static var identity: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }

        let created = UUID().uuidString
        defaults.set(created, forKey: key)
        return created
    }
}

enum AppSession {
    private static let tokenKey = "com.storytime.session-token"
    private static let expiryKey = "com.storytime.session-expiry"
    private static let sessionIdKey = "com.storytime.session-id"
    private static let regionKey = "com.storytime.session-region"

    static var currentToken: String? {
        let defaults = UserDefaults.standard
        guard let token = defaults.string(forKey: tokenKey), !token.isEmpty else {
            return nil
        }

        let expiry = defaults.double(forKey: expiryKey)
        if expiry > 0, expiry < Date().timeIntervalSince1970 {
            clear()
            return nil
        }

        return token
    }

    static var currentSessionId: String? {
        guard currentToken != nil else { return nil }
        let defaults = UserDefaults.standard
        guard let sessionId = defaults.string(forKey: sessionIdKey), !sessionId.isEmpty else {
            return nil
        }
        return sessionId
    }

    static var currentRegion: StoryTimeRegion? {
        let defaults = UserDefaults.standard
        guard let rawValue = defaults.string(forKey: regionKey), !rawValue.isEmpty else {
            return nil
        }
        guard let region = StoryTimeRegion(rawValue: rawValue) else {
            defaults.removeObject(forKey: regionKey)
            return nil
        }
        return region
    }

    static func store(from response: HTTPURLResponse) {
        if let rawRegion = response.value(forHTTPHeaderField: "x-storytime-region"),
           let region = StoryTimeRegion(rawValue: rawRegion.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) {
            store(region: region)
        }

        guard let token = response.value(forHTTPHeaderField: "x-storytime-session"), !token.isEmpty else {
            return
        }

        let defaults = UserDefaults.standard
        defaults.set(token, forKey: tokenKey)

        if let expiryValue = response.value(forHTTPHeaderField: "x-storytime-session-expires-at"),
           let expiry = TimeInterval(expiryValue) {
            defaults.set(expiry, forKey: expiryKey)
        }
    }

    static func store(sessionId: String) {
        guard !sessionId.isEmpty else { return }
        UserDefaults.standard.set(sessionId, forKey: sessionIdKey)
    }

    static func store(region: StoryTimeRegion) {
        UserDefaults.standard.set(region.rawValue, forKey: regionKey)
    }

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: expiryKey)
        defaults.removeObject(forKey: sessionIdKey)
        defaults.removeObject(forKey: regionKey)
    }
}

enum AppEntitlements {
    private static let envelopeKey = "com.storytime.entitlements.bootstrap.v1"

    static var currentEnvelope: EntitlementBootstrapEnvelope? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: envelopeKey) else {
            return nil
        }

        guard let envelope = try? JSONDecoder().decode(EntitlementBootstrapEnvelope.self, from: data) else {
            defaults.removeObject(forKey: envelopeKey)
            return nil
        }

        if envelope.expiresAt < Date().timeIntervalSince1970 {
            clear()
            return nil
        }

        return envelope
    }

    static var currentSnapshot: EntitlementSnapshot? {
        currentEnvelope?.snapshot
    }

    static var currentToken: String? {
        currentEnvelope?.token
    }

    static func store(envelope: EntitlementBootstrapEnvelope) {
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        UserDefaults.standard.set(data, forKey: envelopeKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: envelopeKey)
    }
}

@MainActor
final class EntitlementManager: ObservableObject {
    @Published private(set) var snapshot: EntitlementSnapshot?

    init(snapshot: EntitlementSnapshot? = AppEntitlements.currentSnapshot) {
        self.snapshot = snapshot
    }

    func reloadFromCache() {
        snapshot = AppEntitlements.currentSnapshot
    }

    func refreshFromBootstrap(using client: APIClienting) async throws {
        let baseURL = try await client.prepareConnection()
        try await client.bootstrapSessionIdentity(baseURL: baseURL)
        snapshot = AppEntitlements.currentSnapshot
    }

    func refreshFromPurchaseState(
        using client: APIClienting,
        purchaseStateProvider: EntitlementPurchaseStateProviding,
        reason: EntitlementRefreshReason
    ) async throws {
        let request = try await purchaseStateProvider.currentSyncRequest(refreshReason: reason)
        _ = try await client.syncEntitlements(request: request)
        snapshot = AppEntitlements.currentSnapshot
    }

    func purchaseProduct(
        using client: APIClienting,
        purchaseProvider: any ParentManagedPurchaseProviding,
        productID: String
    ) async throws -> ParentManagedPurchaseOutcome {
        let outcome = try await purchaseProvider.purchase(productID: productID)
        switch outcome {
        case .purchased(let syncRequest):
            if let syncRequest {
                _ = try await client.syncEntitlements(request: syncRequest)
            }
            snapshot = AppEntitlements.currentSnapshot
        case .pending, .cancelled:
            break
        }
        return outcome
    }

    func invalidate() {
        AppEntitlements.clear()
        snapshot = nil
    }
}
