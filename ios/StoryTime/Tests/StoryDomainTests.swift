import XCTest
@testable import StoryTime

final class StoryDomainTests: XCTestCase {
    func testSensitivityModesAndRetentionPoliciesExposeUserFacingContent() {
        XCTAssertEqual(ContentSensitivity.standard.title, "Standard")
        XCTAssertTrue(ContentSensitivity.extraGentle.generationDirective.contains("extra gentle"))
        XCTAssertTrue(ContentSensitivity.mostGentle.generationDirective.contains("deeply calming"))

        XCTAssertEqual(StoryExperienceMode.classic.summaryLine, "Playful voice-led storytelling")
        XCTAssertEqual(StoryExperienceMode.bedtime.toneDirective, "sleepy, cozy, and reassuring")
        XCTAssertEqual(StoryExperienceMode.calm.lessonDirective, "patience, breathing, and gentle problem-solving")
        XCTAssertEqual(StoryExperienceMode.educational.title, "Educational")

        XCTAssertEqual(StoryRetentionPolicy.sevenDays.dayCount, 7)
        XCTAssertEqual(StoryRetentionPolicy.thirtyDays.title, "30 days")
        XCTAssertEqual(StoryRetentionPolicy.ninetyDays.dayCount, 90)
        XCTAssertNil(StoryRetentionPolicy.forever.dayCount)
    }
}
