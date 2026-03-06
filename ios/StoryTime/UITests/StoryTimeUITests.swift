import XCTest

final class StoryTimeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testVoiceFirstStoryJourney() {
        let app = launchApp()

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let usePastStoryToggle = app.switches["usePastStoryToggle"]
        if usePastStoryToggle.waitForExistence(timeout: 3) {
            usePastStoryToggle.tap()
        }

        let useOldCharactersToggle = app.switches["useOldCharactersToggle"]
        if useOldCharactersToggle.waitForExistence(timeout: 3) {
            useOldCharactersToggle.tap()
        }

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        if !startVoiceButton.waitForExistence(timeout: 3) {
            for _ in 0..<3 where !startVoiceButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(startVoiceButton.waitForExistence(timeout: 10))
        startVoiceButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
    }

    func testParentControlsCanRenderAndAddAChildProfile() {
        let app = launchApp()

        let parentControlsButton = app.buttons["parentControlsButton"]
        XCTAssertTrue(parentControlsButton.waitForExistence(timeout: 10))
        parentControlsButton.tap()

        let addChildButton = app.buttons["addChildProfileButton"]
        XCTAssertTrue(addChildButton.waitForExistence(timeout: 10))

        let saveStoryHistoryToggle = app.switches["saveStoryHistoryToggle"]
        if saveStoryHistoryToggle.waitForExistence(timeout: 2) {
            saveStoryHistoryToggle.tap()
            saveStoryHistoryToggle.tap()
        }

        addChildButton.tap()

        let nameField = app.textFields["childNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText("Maeve")

        let saveProfileButton = app.buttons["saveChildProfileButton"]
        XCTAssertTrue(saveProfileButton.waitForExistence(timeout: 5))
        saveProfileButton.tap()

        XCTAssertTrue(app.staticTexts["Maeve"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
    }

    func testSeriesDetailShowsContinuityAndActionButtons() {
        let app = launchApp()

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let detailTitle = app.staticTexts["seriesDetailTitle"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(detailTitle.label, "Bunny and the Lantern Trail")
        XCTAssertTrue(app.buttons["repeatEpisodeButton"].exists)
        XCTAssertTrue(app.buttons["newEpisodeButton"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "hidden garden")).firstMatch.exists)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["STORYTIME_UI_TEST_MODE"] = "1"
        app.launchEnvironment["STORYTIME_UI_TEST_SEED"] = "1"
        app.launch()
        return app
    }
}
