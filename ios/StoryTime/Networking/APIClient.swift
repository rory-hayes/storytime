import Foundation

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

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case region
    }
}

private struct BackendHealthEnvelope: Decodable {
    let defaultRegion: StoryTimeRegion?
    let allowedRegions: [StoryTimeRegion]?

    private enum CodingKeys: String, CodingKey {
        case defaultRegion = "default_region"
        case allowedRegions = "allowed_regions"
    }
}

enum APIClientTraceOperation: String, Equatable, Hashable {
    case healthCheck
    case sessionBootstrap
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
        case .ttsGeneration:
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
        case .healthCheck, .sessionBootstrap, .voices, .realtimeSession:
            return nil
        }
    }

    var runtimeCostDriver: RuntimeTelemetryCostDriver? {
        switch self {
        case .storyDiscovery, .storyGeneration, .storyRevision, .embeddings:
            return .remoteModel
        case .healthCheck, .sessionBootstrap, .voices, .realtimeSession:
            return nil
        }
    }
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
            }
        } catch let error as APIError {
            switch error {
            case .invalidResponse(let statusCode, _, _, _, _) where [404, 405, 501].contains(statusCode):
                // Legacy backends may not expose session bootstrap yet. Continue without a session token
                // when the route is absent so the app can still use provisional install-based auth.
                AppSession.clear()
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
