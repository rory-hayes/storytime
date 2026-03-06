import Foundation

enum AppConfig {
    private static let localDefault = URL(string: "http://127.0.0.1:8787")!
    private static let cloudDefault = URL(string: "https://backend-brown-ten-94.vercel.app")!

    static var candidateAPIBaseURLs: [URL] {
        var candidates: [URL] = []

        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           let parsed = URL(string: override) {
            candidates.append(parsed)
        }

        #if DEBUG
        // Prefer the deployed backend in debug so simulator runs work without a local server.
        candidates.append(contentsOf: [cloudDefault, localDefault])
        #else
        candidates.append(cloudDefault)
        #endif

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.absoluteString).inserted }
    }
}
