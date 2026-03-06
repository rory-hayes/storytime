import Foundation

protocol APIClienting {
    func prepareConnection() async throws -> URL
    func fetchVoices() async throws -> [String]
    func createRealtimeSession(request body: RealtimeSessionRequest) async throws -> RealtimeSessionEnvelope
    func discoverStoryTurn(request body: DiscoveryRequest) async throws -> DiscoveryEnvelope
    func generateStory(request body: GenerateStoryRequest) async throws -> GenerateStoryEnvelope
    func reviseStory(request body: ReviseStoryRequest) async throws -> ReviseStoryEnvelope
    func createEmbeddings(inputs: [String]) async throws -> [[Double]]
}

final class APIClient: APIClienting {
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

    func fetchVoices() async throws -> [String] {
        try await withAvailableBaseURL { [self] baseURL in
            let endpoint = baseURL.appending(path: "v1").appending(path: "voices")
            var request = URLRequest(url: endpoint)
            request.timeoutInterval = 12
            applyInstallHeaders(to: &request)

            let (data, response) = try await self.perform(request)
            try self.validate(response: response, data: data)
            let decoded = try JSONDecoder().decode(VoicesResponse.self, from: data)
            return decoded.voices
        }
    }

    func createRealtimeSession(request body: RealtimeSessionRequest) async throws -> RealtimeSessionEnvelope {
        try await withAvailableBaseURL { [self] baseURL in
            try await ensureSessionIdentity(baseURL: baseURL)
            let endpoint = baseURL.appending(path: "v1").appending(path: "realtime").appending(path: "session")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
            request.timeoutInterval = 20
            applyInstallHeaders(to: &request)

            let (data, response) = try await self.perform(request)
            try self.validate(response: response, data: data)
            return try JSONDecoder().decode(RealtimeSessionEnvelope.self, from: data)
        }
    }

    func discoverStoryTurn(request body: DiscoveryRequest) async throws -> DiscoveryEnvelope {
        try await withAvailableBaseURL { [self] baseURL in
            try await ensureSessionIdentity(baseURL: baseURL)
            let endpoint = baseURL.appending(path: "v1").appending(path: "story").appending(path: "discovery")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
            request.timeoutInterval = 20
            applyInstallHeaders(to: &request)

            let (data, response) = try await self.perform(request)
            let statusCode = response.statusCode
            if statusCode == 422 {
                return try JSONDecoder().decode(DiscoveryEnvelope.self, from: data)
            }
            try self.validate(response: response, data: data)
            return try JSONDecoder().decode(DiscoveryEnvelope.self, from: data)
        }
    }

    func generateStory(request body: GenerateStoryRequest) async throws -> GenerateStoryEnvelope {
        try await withAvailableBaseURL { [self] baseURL in
            try await ensureSessionIdentity(baseURL: baseURL)
            let endpoint = baseURL.appending(path: "v1").appending(path: "story").appending(path: "generate")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
            request.timeoutInterval = 20
            applyInstallHeaders(to: &request)

            let (data, response) = try await self.perform(request)
            let statusCode = response.statusCode
            if statusCode == 422 {
                return try JSONDecoder().decode(GenerateStoryEnvelope.self, from: data)
            }
            try self.validate(response: response, data: data)
            return try JSONDecoder().decode(GenerateStoryEnvelope.self, from: data)
        }
    }

    func reviseStory(request body: ReviseStoryRequest) async throws -> ReviseStoryEnvelope {
        try await withAvailableBaseURL { [self] baseURL in
            try await ensureSessionIdentity(baseURL: baseURL)
            let endpoint = baseURL.appending(path: "v1").appending(path: "story").appending(path: "revise")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
            request.timeoutInterval = 20
            applyInstallHeaders(to: &request)

            let (data, response) = try await self.perform(request)
            let statusCode = response.statusCode
            if statusCode == 422 {
                return try JSONDecoder().decode(ReviseStoryEnvelope.self, from: data)
            }
            try self.validate(response: response, data: data)
            return try JSONDecoder().decode(ReviseStoryEnvelope.self, from: data)
        }
    }

    func createEmbeddings(inputs: [String]) async throws -> [[Double]] {
        try await withAvailableBaseURL { [self] baseURL in
            try await ensureSessionIdentity(baseURL: baseURL)
            let endpoint = baseURL.appending(path: "v1").appending(path: "embeddings").appending(path: "create")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(EmbeddingsCreateRequest(inputs: inputs))
            request.timeoutInterval = 20
            applyInstallHeaders(to: &request)

            let (data, response) = try await self.perform(request)
            try self.validate(response: response, data: data)
            return try JSONDecoder().decode(EmbeddingsCreateResponse.self, from: data).embeddings
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

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.connectionFailed(candidateBaseURLs)
        }

        AppSession.store(from: http)
        return (data, http)
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
            let (data, response) = try await perform(request)
            try validate(response: response, data: data)
        } catch let error as APIError {
            switch error {
            case .invalidResponse(let statusCode, _) where [404, 405, 501].contains(statusCode):
                // Legacy backends may not expose session bootstrap yet. Continue without a session token
                // when the route is absent so the app can still use provisional install-based auth.
                AppSession.clear()
                return
            default:
                throw error
            }
        }
    }

    private func validate(response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.invalidResponse(statusCode: response.statusCode, body: body)
        }
    }

    private func assertHealthy(baseURL: URL) async throws {
        let endpoint = baseURL.appending(path: "health")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 8
        request.httpMethod = "GET"
        applyInstallHeaders(to: &request)

        let (data, response) = try await perform(request)
        try validate(response: response, data: data)
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
            case .invalidResponse(let statusCode, _):
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
            let (_, response) = try await perform(request)
            return (200..<300).contains(response.statusCode)
        } catch {
            return false
        }
    }

    private func applyInstallHeaders(to request: inout URLRequest) {
        request.setValue(installId, forHTTPHeaderField: "x-storytime-install-id")
        request.setValue("StoryTime-iOS/1.0", forHTTPHeaderField: "x-storytime-client")
        if let sessionToken = AppSession.currentToken {
            request.setValue(sessionToken, forHTTPHeaderField: "x-storytime-session")
        }
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse(statusCode: Int, body: String)
    case connectionFailed([URL])

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode, let body):
            return "Server returned an error (\(statusCode)). \(body)"
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

    static func store(from response: HTTPURLResponse) {
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

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: expiryKey)
    }
}
