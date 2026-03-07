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

        openParentControls(in: app)

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

    func testParentControlsRequireDeliberateGateBeforeOpening() {
        let app = launchApp()

        let parentControlsButton = app.buttons["parentControlsButton"]
        XCTAssertTrue(parentControlsButton.waitForExistence(timeout: 10))
        parentControlsButton.tap()

        let gateTitle = app.staticTexts["parentAccessGateTitle"]
        XCTAssertTrue(gateTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(gateTitle.label, "Parents only")
        XCTAssertFalse(app.staticTexts["parentRawAudioStatusLabel"].exists)

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        XCTAssertFalse(unlockButton.isEnabled)
        unlockButton.tap()
        XCTAssertTrue(gateTitle.exists)

        let cancelButton = app.buttons["cancelParentAccessGateButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10))
        cancelButton.tap()
        XCTAssertFalse(gateTitle.exists)

        openParentControls(in: app)
        XCTAssertTrue(app.staticTexts["parentRawAudioStatusLabel"].waitForExistence(timeout: 10))
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

    func testSavedStoriesAndPastStoryPickerStayScopedToActiveChild() {
        let app = launchApp()

        let noraChip = app.buttons["profileChip-Nora"]
        XCTAssertTrue(noraChip.waitForExistence(timeout: 10))
        noraChip.tap()

        let emptyStateTitle = app.staticTexts["storiesEmptyStateTitle"]
        XCTAssertTrue(emptyStateTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(emptyStateTitle.label, "No stories yet for Nora.")
        XCTAssertFalse(app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"].exists)

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let usePastStoryToggle = app.switches["usePastStoryToggle"]
        XCTAssertTrue(usePastStoryToggle.waitForExistence(timeout: 10))
        usePastStoryToggle.tap()

        let noPastStoriesMessage = app.staticTexts["noPastStoriesMessage"]
        XCTAssertTrue(noPastStoriesMessage.waitForExistence(timeout: 10))
        XCTAssertEqual(
            noPastStoriesMessage.label,
            "No past stories for this child yet. We will start a fresh story."
        )
        XCTAssertFalse(app.buttons["pastStoryPicker"].exists)
    }

    func testPrivacyCopyReflectsLiveProcessingAndLocalRetention() {
        let app = launchApp()

        let homePrivacySummary = app.staticTexts["homePrivacySummary"]
        XCTAssertTrue(homePrivacySummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            homePrivacySummary.label,
            "Parents manage profiles, sensitivity, retention, and deletion. Raw audio is not saved. Story prompts and generated stories are sent for live processing, and saved history stays on this device after each session."
        )

        openParentControls(in: app)

        let parentRawAudioStatusLabel = app.staticTexts["parentRawAudioStatusLabel"]
        XCTAssertTrue(parentRawAudioStatusLabel.waitForExistence(timeout: 10))
        XCTAssertEqual(parentRawAudioStatusLabel.label, "Raw audio is not saved")

        let parentPrivacySummary = app.staticTexts["parentPrivacySummary"]
        XCTAssertTrue(parentPrivacySummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            parentPrivacySummary.label,
            "Saved stories and continuity stay on this device after the session ends. Raw audio is not saved. Live microphone audio, spoken prompts, story generation, and revisions are sent for live processing."
        )

        app.buttons["Done"].tap()

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let journeyPrivacySummary = app.staticTexts["journeyPrivacySummary"]
        XCTAssertTrue(journeyPrivacySummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            journeyPrivacySummary.label,
            "Raw audio is not saved. Story prompts and generated stories are sent for live processing. History retained for 30 days."
        )

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        if !startVoiceButton.waitForExistence(timeout: 3) {
            for _ in 0..<3 where !startVoiceButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(startVoiceButton.waitForExistence(timeout: 10))
        startVoiceButton.tap()

        let voicePrivacySummary = app.staticTexts["voicePrivacySummaryLabel"]
        XCTAssertTrue(voicePrivacySummary.waitForExistence(timeout: 20))
        XCTAssertEqual(
            voicePrivacySummary.label,
            "Live conversation is on. Raw audio is not saved. Spoken prompts are sent for live processing, and the on-screen transcript clears when the session ends."
        )

        let voiceProcessingHint = app.staticTexts["voiceProcessingHintLabel"]
        XCTAssertTrue(voiceProcessingHint.waitForExistence(timeout: 20))
        XCTAssertEqual(
            voiceProcessingHint.label,
            "Speak anytime to answer or interrupt. Raw audio is not saved, and your words are sent for live processing."
        )
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["STORYTIME_UI_TEST_MODE"] = "1"
        app.launchEnvironment["STORYTIME_UI_TEST_SEED"] = "1"
        app.launch()
        return app
    }

    private func openParentControls(in app: XCUIApplication) {
        let parentControlsButton = app.buttons["parentControlsButton"]
        XCTAssertTrue(parentControlsButton.waitForExistence(timeout: 10))
        parentControlsButton.tap()

        let gateTitle = app.staticTexts["parentAccessGateTitle"]
        XCTAssertTrue(gateTitle.waitForExistence(timeout: 10))

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        XCTAssertTrue(unlockButton.isEnabled)
        unlockButton.tap()
    }
}
