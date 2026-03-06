import XCTest
@testable import StoryTime

final class SmokeTests: XCTestCase {
    func testAppConfigHasURL() {
        XCTAssertFalse(AppConfig.candidateAPIBaseURLs.isEmpty)
        XCTAssertTrue(AppConfig.candidateAPIBaseURLs.first?.absoluteString.hasPrefix("http") ?? false)
    }
}
