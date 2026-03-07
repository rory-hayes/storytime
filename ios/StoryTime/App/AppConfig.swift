import Foundation

enum AppConfig {
    private static let localDefault = URL(string: "http://127.0.0.1:8787")!
    private static let bundledDefault = URL(string: "https://backend-brown-ten-94.vercel.app")!
    private static let bundleAPIBaseURLKey = "StoryTimeAPIBaseURL"

    static var candidateAPIBaseURLs: [URL] {
        candidateAPIBaseURLs(
            environment: ProcessInfo.processInfo.environment,
            infoDictionary: Bundle.main.infoDictionary ?? [:],
            includeLocalDebugFallback: shouldIncludeLocalDebugFallback
        )
    }

    static func candidateAPIBaseURLs(
        environment: [String: String],
        infoDictionary: [String: Any],
        includeLocalDebugFallback: Bool
    ) -> [URL] {
        var candidates: [URL] = []

        if let override = normalizedBaseURL(from: environment["API_BASE_URL"]) {
            candidates.append(override)
        }

        if let configured = normalizedBaseURL(from: infoDictionary[bundleAPIBaseURLKey] as? String) {
            candidates.append(configured)
        } else {
            candidates.append(bundledDefault)
        }

        if includeLocalDebugFallback {
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

    private static var shouldIncludeLocalDebugFallback: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
