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

    func testVoiceSessionShowsListeningCueBeforeNarrationStarts() {
        let app = launchApp()

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        if !startVoiceButton.waitForExistence(timeout: 3) {
            for _ in 0..<3 where !startVoiceButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(startVoiceButton.waitForExistence(timeout: 10))
        startVoiceButton.tap()

        let sessionCueCard = app.otherElements["sessionCueCard"]
        XCTAssertTrue(sessionCueCard.waitForExistence(timeout: 20))
        XCTAssertTrue(waitForLabel(of: sessionCueCard, toEqual: "Listening"))
        XCTAssertEqual(
            sessionCueCard.value as? String,
            "Answer live question 1 of 3 so StoryTime can build the story.\nSpeak your answer now."
        )
    }

    func testVoiceSessionShowsStorytellingCueAfterNarrationStarts() {
        let app = launchApp()

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

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

        let sessionCueCard = app.otherElements["sessionCueCard"]
        XCTAssertTrue(sessionCueCard.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForLabel(of: sessionCueCard, toEqual: "Storytelling"))

        let cueValue = sessionCueCard.value as? String ?? ""
        XCTAssertTrue(cueValue.hasPrefix("StoryTime is telling scene "))
        XCTAssertTrue(cueValue.contains("Speak anytime to ask a question or change what happens next."))
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
        XCTAssertEqual(
            app.staticTexts["parentAccessGateMessage"].label,
            "Type PARENT for a lightweight parent check before opening profile, privacy, and saved-story controls."
        )
        XCTAssertEqual(
            app.staticTexts["parentAccessGateFootnote"].label,
            "This keeps quick taps out on this device. It is not a password or purchase login."
        )
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

    func testHomeViewFramesQuickStartLibraryAndParentControls() {
        let app = launchApp()

        let heroTitle = app.staticTexts["homeHeroTitle"]
        XCTAssertTrue(heroTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(heroTitle.label, "Kids shape the story while it is happening.")

        let heroSummary = app.staticTexts["homeHeroSummary"]
        XCTAssertTrue(heroSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            heroSummary.label,
            "Start with a few live questions, then StoryTime narrates the adventure scene by scene."
        )

        let activeProfileSummary = app.staticTexts["homeActiveProfileSummary"]
        XCTAssertTrue(activeProfileSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            activeProfileSummary.label,
            "Milo will answer a few live questions first, then StoryTime tells the story scene by scene."
        )

        let librarySummary = app.staticTexts["homeLibrarySummary"]
        XCTAssertTrue(librarySummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            librarySummary.label,
            "Replay favorites or start a new episode for Milo without losing the saved story world."
        )

        let parentEntryButton = app.buttons["homeParentControlsEntryButton"]
        XCTAssertTrue(parentEntryButton.waitForExistence(timeout: 10))
        XCTAssertEqual(
            app.staticTexts["homeParentControlsFootnote"].label,
            "PARENT is a lightweight check on this device. It is not account authentication."
        )
        parentEntryButton.tap()

        let gateTitle = app.staticTexts["parentAccessGateTitle"]
        XCTAssertTrue(gateTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(gateTitle.label, "Parents only")
    }

    func testSavedStoryCardShowsReplayAndContinueAffordanceOnHome() {
        let app = launchApp()

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))

        let episodeSummary = app.staticTexts["seriesCardEpisodeSummary-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(episodeSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(episodeSummary.label, "2 episodes saved")

        let actionHint = app.staticTexts["seriesCardActionHint-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(actionHint.waitForExistence(timeout: 10))
        XCTAssertEqual(actionHint.label, "Repeat or continue")
    }

    func testSeriesDetailPrioritizesContinuationActionsOverContinuityDetails() {
        let app = launchApp()

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let detailTitle = app.staticTexts["seriesDetailTitle"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(detailTitle.label, "Bunny and the Lantern Trail")
        XCTAssertTrue(app.staticTexts["seriesDetailContinueTitle"].exists)
        XCTAssertEqual(
            app.staticTexts["seriesDetailContinueSummary"].label,
            "Replay the latest adventure or start a new episode that keeps this world, these characters, and this child's saved continuity together."
        )
        XCTAssertTrue(app.buttons["repeatEpisodeButton"].exists)
        XCTAssertTrue(app.buttons["newEpisodeButton"].exists)
        XCTAssertEqual(
            app.staticTexts["seriesDetailContinueScopeHint"].label,
            "New episodes stay linked to this saved series for the selected child."
        )
        XCTAssertEqual(
            app.staticTexts["seriesDetailContinuityTitle"].label,
            "Story memory for the next episode"
        )
        XCTAssertEqual(
            app.staticTexts["seriesDetailContinuitySummary"].label,
            "StoryTime uses these saved details to keep future episodes familiar without changing earlier ones."
        )
        XCTAssertEqual(
            app.staticTexts["seriesDetailManagementTitle"].label,
            "Saved-story management"
        )
        XCTAssertEqual(
            app.staticTexts["seriesDetailParentControlsHint"].label,
            "Parents can remove saved stories or clear all saved story history from Parent Controls."
        )
        XCTAssertFalse(app.buttons["deleteSeriesToolbarButton"].exists)
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

    func testSavedStoriesAndPastStoryPickerReturnWhenSwitchingBackToSeededChild() {
        let app = launchApp()

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))

        let noraChip = app.buttons["profileChip-Nora"]
        XCTAssertTrue(noraChip.waitForExistence(timeout: 10))
        noraChip.tap()

        let emptyStateTitle = app.staticTexts["storiesEmptyStateTitle"]
        XCTAssertTrue(emptyStateTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(emptyStateTitle.label, "No stories yet for Nora.")
        XCTAssertFalse(seededSeriesCard.exists)

        let miloChip = app.buttons["profileChip-Milo"]
        XCTAssertTrue(miloChip.waitForExistence(timeout: 10))
        miloChip.tap()

        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let usePastStoryToggle = app.switches["usePastStoryToggle"]
        XCTAssertTrue(usePastStoryToggle.waitForExistence(timeout: 10))
        if usePastStoryToggle.value as? String != "1" {
            usePastStoryToggle.tap()
        }

        let pastStoryPicker = app.buttons["pastStoryPicker"]
        XCTAssertTrue(pastStoryPicker.waitForExistence(timeout: 10))
        XCTAssertTrue(pastStoryPicker.label.contains("Bunny and the Lantern Trail"))
    }

    func testFreshInstallShowsParentLedOnboardingFlow() {
        let app = launchFreshApp()

        let onboardingHeader = app.staticTexts["onboardingHeaderTitle"]
        XCTAssertTrue(onboardingHeader.waitForExistence(timeout: 10))
        XCTAssertEqual(onboardingHeader.label, "Welcome to StoryTime")
        XCTAssertFalse(app.buttons["newStoryInlineButton"].exists)

        let stepCounter = app.staticTexts["onboardingStepCounter"]
        XCTAssertEqual(stepCounter.label, "Step 1 of 5")
        XCTAssertEqual(
            app.staticTexts["onboardingStepTitle"].label,
            "Kids shape the story while it is happening."
        )

        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        continueButton.tap()

        XCTAssertEqual(app.staticTexts["onboardingStepCounter"].label, "Step 2 of 5")
        XCTAssertEqual(
            app.staticTexts["onboardingStepTitle"].label,
            "Start with trust and privacy"
        )
        XCTAssertTrue(app.buttons["onboardingReviewParentControlsButton"].exists)
    }

    func testOnboardingCanEditFallbackChildProfile() {
        let app = launchFreshApp()

        advanceOnboarding(in: app, toStep: 3)

        let childName = app.staticTexts["Story Explorer"]
        XCTAssertTrue(childName.waitForExistence(timeout: 10))
        XCTAssertEqual(childName.label, "Story Explorer")

        let childSummary = app.staticTexts[
            "Story Explorer is the fallback child profile. You can keep it for now or edit it before the first story starts."
        ]
        XCTAssertTrue(childSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            childSummary.label,
            "Story Explorer is the fallback child profile. You can keep it for now or edit it before the first story starts."
        )

        let editButton = app.buttons["onboardingEditChildButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10))
        editButton.tap()

        let nameField = app.textFields["childNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        clearAndTypeText("Maeve", into: nameField)

        let saveProfileButton = app.buttons["saveChildProfileButton"]
        XCTAssertTrue(saveProfileButton.waitForExistence(timeout: 10))
        saveProfileButton.tap()

        let updatedChildName = app.staticTexts["Maeve"]
        XCTAssertTrue(updatedChildName.waitForExistence(timeout: 10))
        XCTAssertEqual(updatedChildName.label, "Maeve")

        let updatedSummary = app.staticTexts[
            "Maeve is ready for the first story. You can still update name, age, sensitivity, or default mode before launch."
        ]
        XCTAssertTrue(updatedSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            updatedSummary.label,
            "Maeve is ready for the first story. You can still update name, age, sensitivity, or default mode before launch."
        )
    }

    func testOnboardingHandsOffToFirstStorySetupAndStaysDismissedAfterRelaunch() {
        let app = launchFreshApp()

        advanceOnboarding(in: app, toStep: 5)

        let startFirstStoryButton = app.buttons["onboardingStartFirstStoryButton"]
        XCTAssertTrue(startFirstStoryButton.waitForExistence(timeout: 10))
        startFirstStoryButton.tap()

        let preflightSummary = app.staticTexts["journeyPreflightSummary"]
        XCTAssertTrue(preflightSummary.waitForExistence(timeout: 10))

        app.terminate()

        let relaunched = launchFreshApp(reset: false)
        XCTAssertFalse(relaunched.staticTexts["onboardingHeaderTitle"].waitForExistence(timeout: 2))
        XCTAssertTrue(relaunched.buttons["newStoryInlineButton"].waitForExistence(timeout: 10))
    }

    func testJourneyBlocksNewStoryStartAndRoutesToParentManagedReview() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_new_story"
        ])

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        if !startVoiceButton.waitForExistence(timeout: 3) {
            for _ in 0..<3 where !startVoiceButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(startVoiceButton.waitForExistence(timeout: 10))
        startVoiceButton.tap()
        XCTAssertTrue(waitForLabel(of: startVoiceButton, toEqual: "Ask a Parent to Review Plans"))
        XCTAssertFalse(app.staticTexts["storyTitleLabel"].waitForExistence(timeout: 2))

        startVoiceButton.tap()

        let gateTitle = app.staticTexts["parentAccessGateTitle"]
        XCTAssertTrue(gateTitle.waitForExistence(timeout: 10))

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let reviewTitle = app.staticTexts["journeyUpgradeReviewTitle"]
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(reviewTitle.label, "Parent plan review")
        XCTAssertEqual(
            app.staticTexts["journeyUpgradeReviewBlockTitle"].label,
            "This plan can't start another new story right now."
        )
        XCTAssertEqual(app.staticTexts["journeyUpgradeReviewPlanTitle"].label, "Starter")
        XCTAssertEqual(
            app.staticTexts["journeyUpgradeReviewFootnote"].label,
            "Saved stories already on this device can still be replayed."
        )
        XCTAssertTrue(app.buttons["journeyUpgradeReviewParentControlsButton"].exists)
    }

    func testJourneyBlocksContinuationStartAndKeepsReplayCopyTruthful() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_continue_story"
        ])

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let usePastStoryToggle = app.switches["usePastStoryToggle"]
        XCTAssertTrue(usePastStoryToggle.waitForExistence(timeout: 10))
        usePastStoryToggle.tap()

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        if !startVoiceButton.waitForExistence(timeout: 3) {
            for _ in 0..<3 where !startVoiceButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(startVoiceButton.waitForExistence(timeout: 10))
        startVoiceButton.tap()

        let selectedPastStorySummary = app.staticTexts["selectedPastStorySummary"]
        XCTAssertTrue(selectedPastStorySummary.waitForExistence(timeout: 10))
        XCTAssertTrue(selectedPastStorySummary.label.contains("Bunny and the Lantern Trail"))

        XCTAssertTrue(waitForLabel(of: startVoiceButton, toEqual: "Ask a Parent to Review Plans"))
        XCTAssertFalse(app.staticTexts["storyTitleLabel"].waitForExistence(timeout: 2))
    }

    func testJourneyExplainsFreshStartAndLiveFollowUpBeforeSessionStarts() {
        let app = launchApp()

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let liveFollowUpSummary = app.staticTexts["journeyLiveFollowUpSummary"]
        XCTAssertTrue(liveFollowUpSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            liveFollowUpSummary.label,
            "Before narration, StoryTime asks up to 3 live questions and then builds the story scene by scene."
        )

        let pastStorySummary = app.staticTexts["pastStoryOptionSummary"]
        XCTAssertTrue(pastStorySummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            pastStorySummary.label,
            "Turn on Use past story to continue one saved series for this child. StoryTime will recap the latest episode during the live questions."
        )

        let useOldCharactersToggle = app.switches["useOldCharactersToggle"]
        XCTAssertTrue(useOldCharactersToggle.waitForExistence(timeout: 10))
        XCTAssertFalse(useOldCharactersToggle.isEnabled)

        let pastCharactersSummary = app.staticTexts["pastCharactersOptionSummary"]
        XCTAssertTrue(pastCharactersSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            pastCharactersSummary.label,
            "Turn on Use past story to reuse familiar characters from one saved series."
        )

        let continuitySummary = app.staticTexts["journeyContinuitySummary"]
        XCTAssertTrue(scrollToElement(continuitySummary, in: app))
        XCTAssertEqual(
            continuitySummary.label,
            "Story path: Start a brand-new story after the live questions."
        )

        let characterPlanSummary = app.staticTexts["journeyCharacterPlanSummary"]
        XCTAssertTrue(scrollToElement(characterPlanSummary, in: app))
        XCTAssertEqual(
            characterPlanSummary.label,
            "Character plan: The live questions will decide the characters for this new story."
        )
    }

    func testJourneyFramesPreflightParentHandoffAndLengthGuidance() {
        let app = launchApp()

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let preflightSummary = app.staticTexts["journeyPreflightSummary"]
        XCTAssertTrue(preflightSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            preflightSummary.label,
            "Set up Milo's child profile, story path, and session length before the live questions begin."
        )

        let parentHandoffSummary = app.staticTexts["journeyParentHandoffSummary"]
        XCTAssertTrue(parentHandoffSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            parentHandoffSummary.label,
            "This screen is the preflight step. It keeps setup and continuity choices clear before the child starts speaking."
        )

        let storyPathIntro = app.staticTexts["journeyStoryPathIntro"]
        XCTAssertTrue(scrollToElement(storyPathIntro, in: app))
        XCTAssertEqual(
            storyPathIntro.label,
            "Choose whether this starts fresh or continues one saved series for this child."
        )

        let lengthSummary = app.staticTexts["journeyLengthSummary"]
        XCTAssertTrue(scrollToElement(lengthSummary, in: app))
        XCTAssertEqual(
            lengthSummary.label,
            "Shorter stories move faster. Longer stories add more narrated scenes after the live questions."
        )

        let footerSummary = app.staticTexts["journeyStartFooterSummary"]
        XCTAssertTrue(scrollToElement(footerSummary, in: app))
        XCTAssertEqual(
            footerSummary.label,
            "Parents finish setup here, then hand the device to the child for the live questions. Parent controls stay outside the live story."
        )
    }

    func testJourneyExplainsContinueModeAndCharacterReuseChoices() {
        let app = launchApp()

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let usePastStoryToggle = app.switches["usePastStoryToggle"]
        XCTAssertTrue(usePastStoryToggle.waitForExistence(timeout: 10))
        usePastStoryToggle.tap()

        let selectedPastStorySummary = app.staticTexts["selectedPastStorySummary"]
        XCTAssertTrue(selectedPastStorySummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            selectedPastStorySummary.label,
            "Selected series: Bunny and the Lantern Trail. StoryTime will recap the latest episode during the live questions before it creates the next episode."
        )

        let pastCharactersSummary = app.staticTexts["pastCharactersOptionSummary"]
        XCTAssertTrue(pastCharactersSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            pastCharactersSummary.label,
            "If you turn on Use old characters, StoryTime will reuse Bunny and Fox from Bunny and the Lantern Trail."
        )

        let continuitySummary = app.staticTexts["journeyContinuitySummary"]
        XCTAssertTrue(scrollToElement(continuitySummary, in: app))
        XCTAssertEqual(
            continuitySummary.label,
            "Story path: Continue Bunny and the Lantern Trail as a new episode after the live questions."
        )

        let useOldCharactersToggle = app.switches["useOldCharactersToggle"]
        XCTAssertTrue(scrollToElement(useOldCharactersToggle, in: app))
        XCTAssertTrue(useOldCharactersToggle.isEnabled)

        let characterPlanSummary = app.staticTexts["journeyCharacterPlanSummary"]
        XCTAssertTrue(scrollToElement(characterPlanSummary, in: app))
        XCTAssertEqual(
            characterPlanSummary.label,
            "Character plan: The live questions can keep familiar characters or add new ones for this next episode."
        )
    }

    func testJourneyExplainsLiveNarrationAndInterruptionExpectations() {
        let app = launchApp()

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        XCTAssertTrue(scrollToElement(app.staticTexts["Live follow-up first"], in: app))
        XCTAssertTrue(
            app.staticTexts["StoryTime asks up to 3 live questions before it builds the story."].exists
        )

        XCTAssertTrue(scrollToElement(app.staticTexts["Scene-by-scene narration"], in: app))
        XCTAssertTrue(
            app.staticTexts["After the live questions, StoryTime narrates the adventure one scene at a time."].exists
        )

        XCTAssertTrue(scrollToElement(app.staticTexts["Interruptions stay live"], in: app))
        XCTAssertTrue(
            app.staticTexts["During narration, the child can still ask a question, ask for repetition, or change what happens next."].exists
        )
    }

    func testPrivacyCopyReflectsLiveProcessingAndLocalRetention() {
        let app = launchApp()

        let homePrivacySummary = app.staticTexts["homePrivacySummary"]
        XCTAssertTrue(homePrivacySummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            homePrivacySummary.label,
            "Parent Controls cover child setup, safety defaults, retention, and deletion. Raw audio is not saved. Live questions and story generation are processed during each session. Saved history and continuity stay on this device afterward."
        )

        openParentControls(in: app)

        let parentRawAudioStatusLabel = app.staticTexts["parentRawAudioStatusLabel"]
        XCTAssertTrue(parentRawAudioStatusLabel.waitForExistence(timeout: 10))
        XCTAssertEqual(parentRawAudioStatusLabel.label, "Raw audio is not saved")

        let parentPrivacySummary = app.staticTexts["parentPrivacySummary"]
        XCTAssertTrue(parentPrivacySummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            parentPrivacySummary.label,
            "Use Parent Controls for child setup, privacy, retention, and deletion on this device."
        )

        let parentPrivacyLocalSummary = app.staticTexts["parentPrivacyLocalSummary"]
        XCTAssertTrue(parentPrivacyLocalSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            parentPrivacyLocalSummary.label,
            "What stays on this device: saved stories and continuity after the session ends."
        )

        let parentPrivacyLiveSummary = app.staticTexts["parentPrivacyLiveSummary"]
        XCTAssertTrue(parentPrivacyLiveSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            parentPrivacyLiveSummary.label,
            "What goes live during a session: microphone audio, spoken prompts, story generation, and revisions. Raw audio is not saved."
        )

        app.buttons["Done"].tap()

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let journeyPrivacySummary = app.staticTexts["journeyPrivacySummary"]
        XCTAssertTrue(journeyPrivacySummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            journeyPrivacySummary.label,
            "Raw audio is not saved. Live questions, story prompts, and generated scenes are sent for live processing. History retained for 30 days on this device."
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
            "Live conversation is on. Raw audio is not saved. Your words are sent for live processing during this session, and the on-screen transcript clears when the session ends."
        )

        let voiceProcessingHint = app.staticTexts["voiceProcessingHintLabel"]
        XCTAssertTrue(voiceProcessingHint.waitForExistence(timeout: 20))
        XCTAssertEqual(
            voiceProcessingHint.label,
            "Speak anytime to answer or interrupt. Ask a grown-up to leave the live story if you need parent controls."
        )
    }

    func testDeleteAllSavedStoryHistoryClearsSeededSeriesFromHome() {
        let app = launchApp()

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))

        openParentControls(in: app)

        let storyHistoryScopeLabel = app.staticTexts["storyHistoryScopeLabel"]
        XCTAssertTrue(scrollToElement(storyHistoryScopeLabel, in: app))
        XCTAssertEqual(storyHistoryScopeLabel.label, "1 saved series across all children on this device")

        let deleteHistoryHint = app.staticTexts["deleteAllStoryHistoryHint"]
        XCTAssertTrue(scrollToElement(deleteHistoryHint, in: app))
        XCTAssertEqual(
            deleteHistoryHint.label,
            "Deletes saved stories and local continuity for every child profile on this device."
        )

        let deleteHistoryButton = app.buttons["deleteAllStoryHistoryButton"]
        XCTAssertTrue(scrollToElement(deleteHistoryButton, in: app))
        deleteHistoryButton.tap()

        let confirmDeleteButton = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 10))
        confirmDeleteButton.tap()

        app.buttons["Done"].tap()

        let emptyStateTitle = app.staticTexts["storiesEmptyStateTitle"]
        XCTAssertTrue(emptyStateTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(emptyStateTitle.label, "No stories yet for Milo.")
        XCTAssertFalse(seededSeriesCard.exists)
    }

    func testParentControlsDeleteSingleSeriesAndRemoveItFromHome() {
        let app = launchApp()

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))

        openParentControls(in: app)

        let deleteSeriesButton = app.buttons["Delete Series"].firstMatch
        XCTAssertTrue(scrollToElement(deleteSeriesButton, in: app))
        deleteSeriesButton.tap()

        let confirmDeleteButton = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 10))
        confirmDeleteButton.tap()

        XCTAssertFalse(deleteSeriesButton.exists)

        app.buttons["Done"].tap()

        let emptyStateTitle = app.staticTexts["storiesEmptyStateTitle"]
        XCTAssertTrue(emptyStateTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(emptyStateTitle.label, "No stories yet for Milo.")
        XCTAssertFalse(seededSeriesCard.exists)
    }

    private func launchApp(extraEnvironment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["STORYTIME_UI_TEST_MODE"] = "1"
        app.launchEnvironment["STORYTIME_UI_TEST_SEED"] = "1"
        extraEnvironment.forEach { app.launchEnvironment[$0.key] = $0.value }
        app.launch()
        return app
    }

    private func launchFreshApp(reset: Bool = true, extraEnvironment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["STORYTIME_UI_TEST_MODE"] = "1"
        if reset {
            app.launchEnvironment["STORYTIME_UI_TEST_RESET"] = "1"
        }
        extraEnvironment.forEach { app.launchEnvironment[$0.key] = $0.value }
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

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) -> Bool {
        if element.waitForExistence(timeout: 2) {
            return true
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return element.exists
    }

    private func waitForLabel(
        of element: XCUIElement,
        toEqual expected: String,
        timeout: TimeInterval = 10
    ) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func advanceOnboarding(in app: XCUIApplication, toStep targetStep: Int) {
        let continueButton = app.buttons["onboardingContinueButton"]
        let stepCounter = app.staticTexts["onboardingStepCounter"]

        for expectedStep in 2...targetStep {
            XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
            continueButton.tap()
            XCTAssertTrue(waitForLabel(of: stepCounter, toEqual: "Step \(expectedStep) of 5"))
        }
    }

    private func clearAndTypeText(_ text: String, into element: XCUIElement) {
        element.tap()

        if let currentValue = element.value as? String, currentValue.isEmpty == false, currentValue != "Name" {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            element.typeText(deleteString)
        }

        element.typeText(text)
    }
}
