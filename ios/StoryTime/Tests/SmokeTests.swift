import XCTest
@testable import StoryTime

final class SmokeTests: XCTestCase {
    func testAppConfigHasURL() {
        XCTAssertFalse(AppConfig.candidateAPIBaseURLs.isEmpty)
        XCTAssertTrue(AppConfig.candidateAPIBaseURLs.first?.absoluteString.hasPrefix("http") ?? false)
    }

    func testAppConfigPrefersEnvironmentThenBundleThenLocalFallback() {
        let candidates = AppConfig.candidateAPIBaseURLs(
            environment: ["API_BASE_URL": " https://override.example.com/api?debug=1#fragment "],
            infoDictionary: ["StoryTimeAPIBaseURL": "https://bundle.example.com"],
            includeLocalDebugFallback: true
        )

        XCTAssertEqual(
            candidates,
            [
                URL(string: "https://override.example.com/api")!,
                URL(string: "https://bundle.example.com/")!,
                URL(string: "http://127.0.0.1:8787")!
            ]
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
}
