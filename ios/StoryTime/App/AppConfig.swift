import Foundation

enum AppConfig {
    private static let localDefault = URL(string: "http://127.0.0.1:8787")!
    private static let bundledDefault = URL(string: "https://backend-brown-ten-94.vercel.app")!
    private static let bundleAPIBaseURLKey = "StoryTimeAPIBaseURL"

    static var candidateAPIBaseURLs: [URL] {
        candidateAPIBaseURLs(
            environment: ProcessInfo.processInfo.environment,
            infoDictionary: Bundle.main.infoDictionary ?? [:],
            includeLocalDebugFallback: shouldIncludeLocalDebugFallback(
                environment: ProcessInfo.processInfo.environment,
                isDebugBuild: isDebugBuild,
                isSimulatorBuild: isSimulatorBuild
            )
        )
    }

    static func candidateAPIBaseURLs(
        environment: [String: String],
        infoDictionary: [String: Any],
        includeLocalDebugFallback: Bool
    ) -> [URL] {
        var candidates: [URL] = []
        let explicitOverride = normalizedBaseURL(from: environment["API_BASE_URL"])

        if let override = explicitOverride {
            candidates.append(override)
        }

        if let configured = normalizedBaseURL(from: infoDictionary[bundleAPIBaseURLKey] as? String) {
            candidates.append(configured)
        } else {
            candidates.append(bundledDefault)
        }

        // Keep the localhost fallback for general debug convenience, but do not append it
        // when the caller explicitly chose a backend target for this run.
        if includeLocalDebugFallback, explicitOverride == nil {
            candidates.append(localDefault)
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.absoluteString).inserted }
    }

    static func normalizedBaseURL(from rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let parsed = URL(string: trimmed),
              let scheme = parsed.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              parsed.host != nil else {
            return nil
        }

        guard var components = URLComponents(url: parsed, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.fragment = nil
        components.query = nil
        if components.path.isEmpty {
            components.path = "/"
        }

        return components.url
    }

    static func shouldIncludeLocalDebugFallback(
        environment: [String: String],
        isDebugBuild: Bool,
        isSimulatorBuild: Bool
    ) -> Bool {
        guard isDebugBuild else { return false }
        if isSimulatorBuild {
            return true
        }

        // Localhost is only useful by default on the simulator. Physical devices should
        // target the bundled or explicitly selected backend unless a developer opts in.
        return environment["STORYTIME_ALLOW_DEVICE_LOCALHOST_FALLBACK"] == "1"
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private static var isSimulatorBuild: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static func debugCandidateBaseURLMessages(baseURLs: [URL] = candidateAPIBaseURLs) -> [String] {
        baseURLs.enumerated().map { index, baseURL in
            let label = index == 0 ? "Backend target" : "Fallback target \(index)"
            return "\(label): \(baseURL.absoluteString)"
        }
    }
}
