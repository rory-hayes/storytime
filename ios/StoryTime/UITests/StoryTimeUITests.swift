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
        let cueValue = sessionCueCard.value as? String ?? ""
        XCTAssertTrue(cueValue.hasPrefix("Answer live question "))
        XCTAssertTrue(cueValue.contains(" of 3 so StoryTime can build the story."))
        XCTAssertTrue(cueValue.hasSuffix("Speak your answer now."))
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
        XCTAssertFalse(app.buttons["parentUpgradeToPlusButton"].exists)
    }

    func testVoiceSessionShowsCompletionLoopAfterStoryFinishes() {
        let app = launchApp()

        startSeededReplayAndWaitForCompletion(in: app)

        XCTAssertTrue(app.staticTexts["Story finished"].exists)
        XCTAssertTrue(
            app.staticTexts["“Bunny and the Moonlight Map” is ready for Milo. Replay it now, start a new episode later, or head back to saved stories."].exists
        )
        XCTAssertTrue(
            app.staticTexts["Saved-story controls stay outside this finished story. Raw audio was not saved."].exists
        )
        XCTAssertTrue(app.buttons["completionReplayButton"].exists)
        XCTAssertTrue(app.buttons["completionContinueButton"].exists)
        XCTAssertEqual(app.buttons["completionLibraryButton"].label, "Back to Saved Stories")
    }

    func testVoiceSessionCompletionReplayRestartsNarration() {
        let app = launchApp()

        startSeededReplayAndWaitForCompletion(in: app)

        let replayButton = app.buttons["completionReplayButton"]
        XCTAssertTrue(replayButton.waitForExistence(timeout: 10))
        replayButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(storyTitle.label, "Bunny and the Moonlight Map")
        XCTAssertTrue(app.otherElements["waveformModule"].exists)
        XCTAssertFalse(app.staticTexts["seriesDetailTitle"].exists)
        XCTAssertFalse(app.buttons["newStoryInlineButton"].exists)
    }

    func testVoiceSessionCompletionContinueActionReturnsToSeriesDetail() {
        let app = launchApp()

        startSeededReplayAndWaitForCompletion(in: app)

        let continueButton = app.buttons["completionContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        continueButton.tap()

        let detailTitle = app.staticTexts["seriesDetailTitle"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(detailTitle.label, "Bunny and the Lantern Trail")
        XCTAssertTrue(app.buttons["newEpisodeButton"].exists)
        XCTAssertTrue(app.buttons["repeatEpisodeButton"].exists)
    }

    func testVoiceSessionCompletionLibraryActionReturnsToSavedStoriesSurface() {
        let app = launchApp()

        startSeededReplayAndWaitForCompletion(in: app)

        let libraryButton = app.buttons["completionLibraryButton"]
        XCTAssertTrue(libraryButton.waitForExistence(timeout: 10))
        libraryButton.tap()

        let detailTitle = app.staticTexts["seriesDetailTitle"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(detailTitle.label, "Bunny and the Lantern Trail")
        XCTAssertTrue(app.buttons["repeatEpisodeButton"].exists)
    }

    func testParentControlsCanRenderAndAddAChildProfile() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_ENTITLEMENT_TIER": "plus"
        ])

        openParentControls(in: app)

        let addChildButton = app.buttons["addChildProfileButton"]
        XCTAssertTrue(scrollToElement(addChildButton, in: app))

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

    func testParentControlsShowCurrentPlanAndRestoreEntry() {
        let app = launchApp()

        openParentControls(in: app)

        let planTitle = app.staticTexts["parentPlanTitle"]
        XCTAssertTrue(planTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(planTitle.label, "Starter")
        XCTAssertEqual(
            app.staticTexts["parentPlanSummary"].label,
            "Starter currently allows up to 2 child profiles, 1 new story start, and 1 saved-series continuation. Replay and parent controls stay available on this device."
        )
        XCTAssertEqual(
            app.staticTexts["parentPlanProfilesSummary"].label,
            "Child profiles saved on this device: 2 of 2 allowed"
        )
        XCTAssertEqual(
            app.staticTexts["parentPlanStartsSummary"].label,
            "New story starts remaining in the current window: 1"
        )
        XCTAssertEqual(
            app.staticTexts["parentPlanContinuationsSummary"].label,
            "Saved-series continuations remaining in the current window: 1"
        )
        XCTAssertTrue(scrollToElement(app.buttons["parentRefreshPlanButton"], in: app))
        XCTAssertTrue(scrollToElement(app.buttons["parentRestorePurchasesButton"], in: app))
        XCTAssertTrue(scrollToElement(app.staticTexts["parentPlanFootnote"], in: app))
    }

    func testParentControlsShowSignedOutParentAccountStatus() {
        let app = launchApp()

        openParentControls(in: app)

        let accountStatusTitle = app.staticTexts["parentAccountStatusTitle"]
        XCTAssertTrue(accountStatusTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(accountStatusTitle.label, "Parent account not signed in")
        XCTAssertEqual(
            app.staticTexts["parentAccountStatusSummary"].label,
            "Firebase Auth is ready on this device, but no parent account is signed in yet. Child story screens stay sign-in-free."
        )
        XCTAssertTrue(app.buttons["parentAccountEntryButton"].exists)
        XCTAssertEqual(
            app.staticTexts["parentAccountEntrySummary"].label,
            "First-run activation now happens during onboarding. Use Parent Controls later to manage this device's parent account, purchases, restore, and promo access."
        )
        XCTAssertEqual(
            app.staticTexts["parentAccountStatusFootnote"].label,
            "The PARENT check opens this screen on the current device. Firebase Auth keeps parent account identity separate from child story flow."
        )
        XCTAssertTrue(scrollToElement(app.staticTexts["parentPurchaseAccountRequiredSummary"], in: app))
        XCTAssertEqual(
            app.staticTexts["parentPurchaseAccountRequiredSummary"].label,
            "A parent account is required before buying Plus so the purchase can belong to that parent instead of staying tied only to this device."
        )
        XCTAssertTrue(scrollToElement(app.staticTexts["parentRestoreAccountRequiredSummary"], in: app))
        XCTAssertEqual(
            app.staticTexts["parentRestoreAccountRequiredSummary"].label,
            "A parent account is required before restoring Plus so the refreshed entitlement belongs to that parent. StoryTime won't move a restored plan between different parent accounts on this device."
        )
        XCTAssertTrue(scrollToElement(app.staticTexts["parentRestoreOwnershipSummary"], in: app))
        XCTAssertEqual(
            app.staticTexts["parentRestoreOwnershipSummary"].label,
            "Restore stays linked to the parent account that restores Plus on this device. If another parent signs in later, StoryTime keeps that parent's current plan instead of transferring the restored access."
        )
        XCTAssertTrue(scrollToElement(app.staticTexts["parentPromoAccountRequiredSummary"], in: app))
        XCTAssertEqual(
            app.staticTexts["parentPromoAccountRequiredSummary"].label,
            "A parent account is required before redeeming a promo code so the premium grant belongs to that parent instead of staying tied only to this device."
        )
        XCTAssertTrue(scrollToElement(app.buttons["parentPurchaseAccountEntryButton"], in: app))
        XCTAssertFalse(app.buttons["parentUpgradeToPlusButton"].exists)
    }

    func testParentControlsCanCreateParentAccountAndPersistAcrossRelaunch() {
        let app = launchApp()

        openParentControls(in: app)
        createParentAccount(in: app, email: "parent@example.com", password: "secret1")

        XCTAssertTrue(app.staticTexts["parent@example.com"].waitForExistence(timeout: 10))
        XCTAssertEqual(
            app.staticTexts["parentAccountPersistenceSummary"].label,
            "This device will keep the parent signed in after relaunch until a parent signs out."
        )
        XCTAssertTrue(app.buttons["parentAccountManageButton"].exists)

        app.terminate()

        let relaunched = launchApp(reset: false, seed: false)
        openParentControls(in: relaunched)

        XCTAssertTrue(relaunched.staticTexts["parent@example.com"].waitForExistence(timeout: 10))
        XCTAssertTrue(relaunched.buttons["parentAccountManageButton"].exists)
    }

    func testParentControlsCanSignOutAndSignBackIn() {
        let app = launchApp()

        openParentControls(in: app)
        createParentAccount(in: app, email: "grownup@example.com", password: "secret1")

        app.terminate()

        let relaunched = launchApp(reset: false, seed: false)
        openParentControls(in: relaunched)

        let signOutButton = relaunched.buttons["parentAccountSignOutButton"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 10))
        signOutButton.tap()

        let signedOutTitle = relaunched.staticTexts["parentAccountStatusTitle"]
        XCTAssertTrue(signedOutTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(signedOutTitle.label, "Parent account not signed in")
        XCTAssertTrue(relaunched.buttons["parentAccountEntryButton"].exists)

        let entryButton = relaunched.buttons["parentAccountEntryButton"]
        entryButton.tap()
        XCTAssertTrue(relaunched.staticTexts["parentAccountSheetTitle"].waitForExistence(timeout: 10))

        let modePicker = relaunched.segmentedControls["parentAccountModePicker"].buttons["Sign In"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 10))
        modePicker.tap()

        let emailField = relaunched.textFields["parentAccountEmailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        emailField.tap()
        emailField.typeText("grownup@example.com")

        let passwordField = relaunched.secureTextFields["parentAccountPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10))
        passwordField.tap()
        passwordField.typeText("secret1")

        let primaryButton = relaunched.buttons["parentAccountPrimaryButton"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 10))
        primaryButton.tap()

        XCTAssertTrue(relaunched.staticTexts["grownup@example.com"].waitForExistence(timeout: 10))
        XCTAssertTrue(relaunched.buttons["parentAccountManageButton"].exists)
    }

    func testParentControlsCanSignInWithAppleAndPersistAcrossRelaunch() {
        let app = launchApp()

        openParentControls(in: app)
        signInWithApple(in: app)

        XCTAssertTrue(app.staticTexts["Parent account signed in with Apple"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["parentAccountManageButton"].exists)
        XCTAssertTrue(app.buttons["parentAccountSignOutButton"].exists)

        app.terminate()

        let relaunched = launchApp(reset: false, seed: false)
        openParentControls(in: relaunched)

        XCTAssertTrue(relaunched.staticTexts["Parent account signed in with Apple"].waitForExistence(timeout: 10))
        XCTAssertTrue(relaunched.buttons["parentAccountManageButton"].exists)
        XCTAssertTrue(relaunched.buttons["parentAccountSignOutButton"].exists)
    }

    func testParentControlsCanCompleteParentManagedPlusPurchase() {
        let app = launchApp()

        openParentControls(in: app)
        createParentAccount(in: app, email: "buyer@example.com", password: "secret1")

        let upgradeButton = app.buttons["parentUpgradeToPlusButton"]
        XCTAssertTrue(scrollToElement(upgradeButton, in: app))
        XCTAssertTrue(upgradeButton.label.hasPrefix("Upgrade to Plus"))
        upgradeButton.tap()

        let planTitle = app.staticTexts["parentPlanTitle"]
        XCTAssertTrue(waitForLabel(of: planTitle, toEqual: "Plus"))
        XCTAssertTrue(app.staticTexts["parentPlusActiveSummary"].waitForExistence(timeout: 10))
        XCTAssertEqual(
            app.staticTexts["parentPlanActionStatus"].label,
            "Plus is now ready for buyer@example.com on this device."
        )
        XCTAssertEqual(
            app.staticTexts["parentPlanOwnershipSummary"].label,
            "This entitlement snapshot is linked to buyer@example.com."
        )
        XCTAssertFalse(app.buttons["parentUpgradeToPlusButton"].exists)
    }

    func testParentControlsCanRestorePlusForSignedInParentAndClearItOnSignOut() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_RESTORE_ENTITLEMENT_TIER": "plus"
        ])

        openParentControls(in: app)
        createParentAccount(in: app, email: "restore@example.com", password: "secret1")
        restorePurchases(in: app)

        let restoredPlanTitle = app.staticTexts["parentPlanTitle"]
        XCTAssertTrue(waitForLabel(of: restoredPlanTitle, toEqual: "Plus"))
        XCTAssertEqual(
            app.staticTexts["parentPlanOwnershipSummary"].label,
            "This entitlement snapshot is linked to restore@example.com."
        )
        XCTAssertTrue(scrollToElement(app.staticTexts["parentRestoreOwnershipSummary"], in: app))
        XCTAssertEqual(
            app.staticTexts["parentRestoreOwnershipSummary"].label,
            "Restore stays linked to the parent account that restores Plus on this device. If another parent signs in later, StoryTime keeps that parent's current plan instead of transferring the restored access."
        )

        let signOutButton = app.buttons["parentAccountSignOutButton"]
        XCTAssertTrue(scrollToElement(signOutButton, in: app))
        signOutButton.tap()

        let signedOutPlanTitle = app.staticTexts["parentPlanTitle"]
        XCTAssertTrue(scrollToElement(signedOutPlanTitle, in: app))
        XCTAssertTrue(waitForLabel(of: signedOutPlanTitle, toEqual: "Starter"))
        let signedOutAccountTitle = app.staticTexts["parentAccountStatusTitle"]
        for _ in 0..<4 {
            app.swipeDown()
        }
        XCTAssertTrue(signedOutAccountTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(signedOutAccountTitle.label, "Parent account not signed in")
        XCTAssertFalse(app.staticTexts["parentPlanOwnershipSummary"].exists)
    }

    func testParentControlsShowRestoreMismatchForDifferentParentOnSameDevice() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_RESTORE_ENTITLEMENT_TIER": "plus",
            "STORYTIME_UI_TEST_RESTORE_CONFLICT_EMAIL": "restore-owner@example.com"
        ])

        openParentControls(in: app)
        createParentAccount(in: app, email: "different-parent@example.com", password: "secret1")

        let restoreButton = app.buttons["parentRestorePurchasesButton"]
        XCTAssertTrue(scrollToElement(restoreButton, in: app))
        restoreButton.tap()

        let errorLabel = app.staticTexts["parentPlanActionError"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 10))
        XCTAssertEqual(
            errorLabel.label,
            "This device already restored Plus for a different parent account. Sign back into that parent account to restore here again. StoryTime won't move restored access between parent accounts on the same device."
        )
        XCTAssertEqual(app.staticTexts["parentPlanTitle"].label, "Starter")
        XCTAssertFalse(app.staticTexts["parentPlanOwnershipSummary"].exists)
    }

    func testParentControlsCanRedeemPromoCodeForSignedInParent() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PROMO_CODE": "FRIENDS-PLUS-2026",
            "STORYTIME_UI_TEST_PROMO_ENTITLEMENT_TIER": "plus"
        ])

        openParentControls(in: app)
        createParentAccount(in: app, email: "promo@example.com", password: "secret1")
        redeemPromoCode(in: app, code: "FRIENDS-PLUS-2026")

        let planTitle = app.staticTexts["parentPlanTitle"]
        for _ in 0..<4 {
            app.swipeDown()
        }
        XCTAssertTrue(planTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForLabel(of: planTitle, toEqual: "Plus"))
        XCTAssertEqual(
            app.staticTexts["parentPlusActiveSummary"].label,
            "Plus is active for promo@example.com on this device through a parent promo code."
        )
        XCTAssertEqual(
            app.staticTexts["parentPlanOwnershipSummary"].label,
            "This entitlement snapshot is linked to promo@example.com through a promo grant."
        )
        XCTAssertEqual(
            app.staticTexts["parentPlanActionStatus"].label,
            "Promo code redeemed. Plus is now ready for promo@example.com on this device."
        )
    }

    func testParentControlsGateAddChildWhenPlanLimitIsReached() {
        let app = launchApp()

        openParentControls(in: app)

        let childProfileLimitMessage = app.staticTexts["parentChildProfileLimitMessage"]
        XCTAssertTrue(scrollToElement(childProfileLimitMessage, in: app))
        XCTAssertFalse(app.buttons["addChildProfileButton"].exists)
        XCTAssertEqual(
            childProfileLimitMessage.label,
            "This device already uses all 2 child profiles allowed on this plan."
        )
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
        XCTAssertTrue(scrollToElement(app.staticTexts["parentRawAudioStatusLabel"], in: app))
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
        XCTAssertEqual(stepCounter.label, "Step 1 of 7")
        XCTAssertEqual(
            app.staticTexts["onboardingStepTitle"].label,
            "StoryTime lets kids shape the story while it's happening."
        )

        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        continueButton.tap()

        XCTAssertEqual(app.staticTexts["onboardingStepCounter"].label, "Step 2 of 7")
        XCTAssertEqual(
            app.staticTexts["onboardingStepTitle"].label,
            "How StoryTime works"
        )
        XCTAssertTrue(app.staticTexts["onboardingHowItWorksParentCard"].exists)
    }

    func testOnboardingCanEditFallbackChildProfile() {
        let app = launchFreshApp()

        advanceOnboarding(in: app, toStep: 3)

        let childName = app.staticTexts["Story Explorer"]
        XCTAssertTrue(childName.waitForExistence(timeout: 10))
        XCTAssertEqual(childName.label, "Story Explorer")

        let childSummary = app.staticTexts[
            "Story Explorer is the fallback child profile. You can keep it for now or edit it before first-run activation finishes."
        ]
        XCTAssertTrue(childSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            childSummary.label,
            "Story Explorer is the fallback child profile. You can keep it for now or edit it before first-run activation finishes."
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
            "Maeve is ready for onboarding. You can still update name, age, sensitivity, or default mode before StoryTime opens the main app."
        ]
        XCTAssertTrue(updatedSummary.waitForExistence(timeout: 10))
        XCTAssertEqual(
            updatedSummary.label,
            "Maeve is ready for onboarding. You can still update name, age, sensitivity, or default mode before StoryTime opens the main app."
        )
    }

    func testOnboardingRequiresParentAccountBeforePlanStep() {
        let app = launchFreshApp()

        advanceOnboarding(in: app, toStep: 5)

        XCTAssertTrue(app.staticTexts["onboardingAccountRequiredSummary"].waitForExistence(timeout: 10))
        let createAccountButton = app.buttons["onboardingCreateAccountButton"]
        XCTAssertTrue(createAccountButton.exists)
        XCTAssertTrue(app.buttons["onboardingSignInButton"].exists)
        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.exists)
        XCTAssertFalse(continueButton.isEnabled)

        createAccountButton.tap()
        XCTAssertTrue(app.staticTexts["parentAccountSheetTitle"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["parentAccountAppleButton"].exists)
        XCTAssertTrue(app.staticTexts["parentAccountAppleSummary"].exists)
        XCTAssertTrue(app.buttons["parentAccountCancelButton"].exists)
        app.buttons["parentAccountCancelButton"].tap()
        XCTAssertTrue(app.staticTexts["onboardingAccountRequiredSummary"].waitForExistence(timeout: 10))
        XCTAssertFalse(continueButton.isEnabled)
    }

    func testOnboardingShowsPlanRestoreAndPromoEntryPoints() {
        let app = launchFreshApp()

        advanceOnboardingToPlanStepUsingAppleSignIn(in: app)

        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertFalse(continueButton.isEnabled)
        XCTAssertTrue(app.buttons["onboardingChooseStarterButton"].exists)
        XCTAssertTrue(app.buttons["onboardingUpgradeToPlusButton"].exists)
        XCTAssertTrue(app.buttons["onboardingRestorePurchasesButton"].exists)
        XCTAssertEqual(
            app.staticTexts["onboardingRestoreOwnershipSummary"].label,
            "Restore stays linked to the parent account that restores Plus on this device. If another parent signs in later, StoryTime keeps that parent's current plan instead of transferring the restored access."
        )
        XCTAssertTrue(app.textFields["onboardingPromoCodeField"].exists)
        XCTAssertTrue(app.buttons["onboardingRedeemPromoButton"].exists)
    }

    func testOnboardingCompletesIntoHomeAndStaysDismissedAfterRelaunch() {
        let app = launchFreshApp()

        advanceOnboardingToPlanStepUsingAppleSignIn(in: app)
        chooseStarterInOnboarding(in: app)
        finishOnboarding(in: app)

        XCTAssertTrue(app.buttons["newStoryInlineButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["onboardingHeaderTitle"].exists)

        app.terminate()

        let relaunched = launchFreshApp(reset: false)
        XCTAssertFalse(relaunched.staticTexts["onboardingHeaderTitle"].waitForExistence(timeout: 2))
        XCTAssertTrue(relaunched.buttons["newStoryInlineButton"].waitForExistence(timeout: 10))
    }

    func testOnboardingCanCompleteAfterParentManagedPlusPurchase() {
        let app = launchFreshApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PURCHASE_RESULT": "purchased"
        ])

        advanceOnboardingToPlanStepUsingAppleSignIn(in: app)

        let upgradeButton = app.buttons["onboardingUpgradeToPlusButton"]
        XCTAssertTrue(scrollToElement(upgradeButton, in: app))
        XCTAssertTrue(upgradeButton.label.hasPrefix("Upgrade to Plus"))
        upgradeButton.tap()

        let status = app.staticTexts["onboardingPlanActionStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(
            status.label,
            "Plus is now ready for this parent account on this device."
        )

        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertTrue(continueButton.isEnabled)
        finishOnboarding(in: app)
        XCTAssertTrue(app.buttons["newStoryInlineButton"].waitForExistence(timeout: 10))
    }

    func testOnboardingCanCompleteAfterRestoreRefresh() {
        let app = launchFreshApp(extraEnvironment: [
            "STORYTIME_UI_TEST_RESTORE_ENTITLEMENT_TIER": "plus"
        ])

        advanceOnboardingToPlanStepUsingAppleSignIn(in: app)

        let restoreButton = app.buttons["onboardingRestorePurchasesButton"]
        XCTAssertTrue(scrollToElement(restoreButton, in: app))
        restoreButton.tap()

        let status = app.staticTexts["onboardingPlanActionStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(
            status.label,
            "Restore check finished. StoryTime refreshed the plan for this parent account."
        )

        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertTrue(continueButton.isEnabled)
        finishOnboarding(in: app)
        XCTAssertTrue(app.buttons["newStoryInlineButton"].waitForExistence(timeout: 10))
    }

    func testOnboardingCanCompleteAfterPromoRedemption() {
        let app = launchFreshApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PROMO_CODE": "ONBOARDING-PLUS-2026",
            "STORYTIME_UI_TEST_PROMO_ENTITLEMENT_TIER": "plus"
        ])

        advanceOnboardingToPlanStepUsingAppleSignIn(in: app)

        let promoField = app.textFields["onboardingPromoCodeField"]
        XCTAssertTrue(scrollToElement(promoField, in: app))
        promoField.tap()
        promoField.typeText("ONBOARDING-PLUS-2026")

        let redeemButton = app.buttons["onboardingRedeemPromoButton"]
        XCTAssertTrue(scrollToElement(redeemButton, in: app))
        redeemButton.tap()

        let status = app.staticTexts["onboardingPlanActionStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(
            status.label,
            "Promo code redeemed. Plus is now ready for this parent account on this device."
        )

        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertTrue(continueButton.isEnabled)
        finishOnboarding(in: app)
        XCTAssertTrue(app.buttons["newStoryInlineButton"].waitForExistence(timeout: 10))
    }

    func testChildStorySurfacesRemainFreeOfAccountPrompts() {
        let app = launchApp()

        XCTAssertFalse(app.staticTexts["parentAccountStatusTitle"].exists)

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        XCTAssertFalse(app.staticTexts["parentAccountStatusTitle"].exists)

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
        XCTAssertFalse(app.staticTexts["parentAccountStatusTitle"].exists)
        XCTAssertFalse(app.buttons["parentUpgradeToPlusButton"].exists)
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

    func testJourneyReviewLinksToDurableParentPlanSurface() {
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
        startVoiceButton.tap()

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let parentPlanButton = app.buttons["journeyUpgradeReviewParentControlsButton"]
        XCTAssertTrue(parentPlanButton.waitForExistence(timeout: 10))
        parentPlanButton.tap()

        let parentPlanTitle = app.staticTexts["parentPlanTitle"]
        XCTAssertTrue(parentPlanTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(parentPlanTitle.label, "Starter")
        XCTAssertTrue(scrollToElement(app.buttons["parentRestorePurchasesButton"], in: app))
    }

    func testJourneyBlockedStartCanRecoverAfterParentManagedPurchase() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_new_story"
        ])

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        XCTAssertTrue(scrollToElement(startVoiceButton, in: app))
        startVoiceButton.tap()
        XCTAssertTrue(waitForLabel(of: startVoiceButton, toEqual: "Ask a Parent to Review Plans"))
        startVoiceButton.tap()

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let parentPlanButton = app.buttons["journeyUpgradeReviewParentControlsButton"]
        XCTAssertTrue(parentPlanButton.waitForExistence(timeout: 10))
        parentPlanButton.tap()

        createParentAccount(in: app, email: "journeybuyer@example.com", password: "secret1")

        let upgradeButton = app.buttons["parentUpgradeToPlusButton"]
        XCTAssertTrue(scrollToElement(upgradeButton, in: app))
        upgradeButton.tap()

        let parentPlanTitle = app.staticTexts["parentPlanTitle"]
        XCTAssertTrue(waitForLabel(of: parentPlanTitle, toEqual: "Plus"))

        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["journeyUpgradeReviewTitle"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        XCTAssertTrue(waitForLabel(of: startVoiceButton, toEqual: "Start Voice Session"))
        startVoiceButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
    }

    func testJourneyBlockedStartCanRecoverAfterAuthenticatedRestore() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_new_story",
            "STORYTIME_UI_TEST_RESTORE_ENTITLEMENT_TIER": "plus"
        ])

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        XCTAssertTrue(scrollToElement(startVoiceButton, in: app))
        startVoiceButton.tap()
        XCTAssertTrue(waitForLabel(of: startVoiceButton, toEqual: "Ask a Parent to Review Plans"))
        startVoiceButton.tap()

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let parentPlanButton = app.buttons["journeyUpgradeReviewParentControlsButton"]
        XCTAssertTrue(parentPlanButton.waitForExistence(timeout: 10))
        parentPlanButton.tap()

        createParentAccount(in: app, email: "restorejourney@example.com", password: "secret1")
        restorePurchases(in: app)

        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["journeyUpgradeReviewTitle"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        XCTAssertTrue(waitForLabel(of: startVoiceButton, toEqual: "Start Voice Session"))
        startVoiceButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
    }

    func testJourneyBlockedStartCanRecoverAfterPromoRedemption() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_new_story",
            "STORYTIME_UI_TEST_PROMO_CODE": "JOURNEY-PLUS-2026",
            "STORYTIME_UI_TEST_PROMO_ENTITLEMENT_TIER": "plus"
        ])

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        XCTAssertTrue(scrollToElement(startVoiceButton, in: app))
        startVoiceButton.tap()
        XCTAssertTrue(waitForLabel(of: startVoiceButton, toEqual: "Ask a Parent to Review Plans"))
        startVoiceButton.tap()

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let parentPlanButton = app.buttons["journeyUpgradeReviewParentControlsButton"]
        XCTAssertTrue(parentPlanButton.waitForExistence(timeout: 10))
        parentPlanButton.tap()

        createParentAccount(in: app, email: "journeypromo@example.com", password: "secret1")
        redeemPromoCode(in: app, code: "JOURNEY-PLUS-2026")

        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["journeyUpgradeReviewTitle"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        XCTAssertTrue(waitForLabel(of: startVoiceButton, toEqual: "Start Voice Session"))
        startVoiceButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
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

    func testSeriesDetailBlocksNewEpisodeAndKeepsReplayTruthful() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_continue_story"
        ])

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let newEpisodeButton = app.buttons["newEpisodeButton"]
        XCTAssertTrue(newEpisodeButton.waitForExistence(timeout: 10))
        newEpisodeButton.tap()

        XCTAssertTrue(waitForLabel(of: newEpisodeButton, toEqual: "Ask a Parent"))
        XCTAssertTrue(app.buttons["repeatEpisodeButton"].exists)
        XCTAssertFalse(app.staticTexts["storyTitleLabel"].waitForExistence(timeout: 2))
    }

    func testSeriesDetailBlockedContinuationRoutesToParentManagedReview() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_continue_story"
        ])

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let newEpisodeButton = app.buttons["newEpisodeButton"]
        XCTAssertTrue(newEpisodeButton.waitForExistence(timeout: 10))
        newEpisodeButton.tap()

        XCTAssertTrue(waitForLabel(of: newEpisodeButton, toEqual: "Ask a Parent"))
        newEpisodeButton.tap()

        let gateTitle = app.staticTexts["parentAccessGateTitle"]
        XCTAssertTrue(gateTitle.waitForExistence(timeout: 10))

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let reviewTitle = app.staticTexts["seriesDetailUpgradeReviewTitle"]
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(reviewTitle.label, "Parent plan review")
        XCTAssertEqual(
            app.staticTexts["seriesDetailUpgradeReviewBlockTitle"].label,
            "This plan can't start a new episode right now."
        )
        XCTAssertEqual(app.staticTexts["seriesDetailUpgradeReviewPlanTitle"].label, "Starter")
        XCTAssertEqual(
            app.staticTexts["seriesDetailUpgradeReviewFootnote"].label,
            "Replay of the latest saved episode stays available on this device."
        )
        XCTAssertEqual(
            app.staticTexts["seriesDetailUpgradeReviewPlanSummary"].label,
            "Starter currently allows up to 2 child profiles, 1 new story start, and 0 saved-series continuations in the current window."
        )
        XCTAssertTrue(app.buttons["seriesDetailUpgradeReviewParentControlsButton"].exists)
    }

    func testSeriesDetailBlockedContinuationCanRecoverAfterParentManagedPurchase() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_continue_story"
        ])

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let newEpisodeButton = app.buttons["newEpisodeButton"]
        XCTAssertTrue(newEpisodeButton.waitForExistence(timeout: 10))
        newEpisodeButton.tap()

        XCTAssertTrue(waitForLabel(of: newEpisodeButton, toEqual: "Ask a Parent"))
        newEpisodeButton.tap()

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let parentPlanButton = app.buttons["seriesDetailUpgradeReviewParentControlsButton"]
        XCTAssertTrue(parentPlanButton.waitForExistence(timeout: 10))
        parentPlanButton.tap()

        createParentAccount(in: app, email: "seriesbuyer@example.com", password: "secret1")

        let upgradeButton = app.buttons["parentUpgradeToPlusButton"]
        XCTAssertTrue(scrollToElement(upgradeButton, in: app))
        upgradeButton.tap()

        let parentPlanTitle = app.staticTexts["parentPlanTitle"]
        XCTAssertTrue(waitForLabel(of: parentPlanTitle, toEqual: "Plus"))

        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["seriesDetailUpgradeReviewTitle"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        XCTAssertTrue(waitForLabel(of: newEpisodeButton, toEqual: "New Episode"))
        newEpisodeButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
    }

    func testSeriesDetailBlockedContinuationCanRecoverAfterAuthenticatedPlanRefresh() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_continue_story",
            "STORYTIME_UI_TEST_REFRESH_ENTITLEMENT_TIER": "plus"
        ])

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let newEpisodeButton = app.buttons["newEpisodeButton"]
        XCTAssertTrue(newEpisodeButton.waitForExistence(timeout: 10))
        newEpisodeButton.tap()

        XCTAssertTrue(waitForLabel(of: newEpisodeButton, toEqual: "Ask a Parent"))
        newEpisodeButton.tap()

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let parentPlanButton = app.buttons["seriesDetailUpgradeReviewParentControlsButton"]
        XCTAssertTrue(parentPlanButton.waitForExistence(timeout: 10))
        parentPlanButton.tap()

        createParentAccount(in: app, email: "refreshseries@example.com", password: "secret1")
        refreshPlanStatus(in: app)

        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["seriesDetailUpgradeReviewTitle"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        XCTAssertTrue(waitForLabel(of: newEpisodeButton, toEqual: "New Episode"))
        newEpisodeButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
    }

    func testSeriesDetailBlockedContinuationCanRecoverAfterPromoRedemption() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_continue_story",
            "STORYTIME_UI_TEST_PROMO_CODE": "SERIES-PLUS-2026",
            "STORYTIME_UI_TEST_PROMO_ENTITLEMENT_TIER": "plus"
        ])

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let newEpisodeButton = app.buttons["newEpisodeButton"]
        XCTAssertTrue(newEpisodeButton.waitForExistence(timeout: 10))
        newEpisodeButton.tap()

        XCTAssertTrue(waitForLabel(of: newEpisodeButton, toEqual: "Ask a Parent"))
        newEpisodeButton.tap()

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let parentPlanButton = app.buttons["seriesDetailUpgradeReviewParentControlsButton"]
        XCTAssertTrue(parentPlanButton.waitForExistence(timeout: 10))
        parentPlanButton.tap()

        createParentAccount(in: app, email: "seriespromo@example.com", password: "secret1")
        redeemPromoCode(in: app, code: "SERIES-PLUS-2026")

        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["seriesDetailUpgradeReviewTitle"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()

        XCTAssertTrue(waitForLabel(of: newEpisodeButton, toEqual: "New Episode"))
        newEpisodeButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
    }

    func testSeriesDetailRepeatRemainsAvailableWhenContinuationIsBlocked() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_continue_story"
        ])

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let repeatButton = app.buttons["repeatEpisodeButton"]
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 10))
        repeatButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
    }

    func testJourneyReviewShowsCurrentPlanCountersForBlockedStart() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "block_new_story"
        ])

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        XCTAssertTrue(scrollToElement(startVoiceButton, in: app))
        startVoiceButton.tap()
        XCTAssertTrue(waitForLabel(of: startVoiceButton, toEqual: "Ask a Parent to Review Plans"))
        startVoiceButton.tap()

        let gateField = app.textFields["parentAccessGateField"]
        XCTAssertTrue(gateField.waitForExistence(timeout: 10))
        gateField.tap()
        gateField.typeText("PARENT")

        let unlockButton = app.buttons["unlockParentControlsButton"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 10))
        unlockButton.tap()

        let reviewTitle = app.staticTexts["journeyUpgradeReviewTitle"]
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(
            app.staticTexts["journeyUpgradeReviewPlanSummary"].label,
            "Starter currently allows up to 2 child profiles, 0 new story starts, and 1 saved-series continuation in the current window."
        )
    }

    func testJourneyAllowsNewStoryWhenPlanStillHasRoom() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "allow_new_story",
            "STORYTIME_UI_TEST_ENTITLEMENT_TIER": "plus"
        ])

        let newStoryButton = app.buttons["newStoryInlineButton"]
        XCTAssertTrue(newStoryButton.waitForExistence(timeout: 10))
        newStoryButton.tap()

        let startVoiceButton = app.buttons["startVoiceSessionButton"]
        XCTAssertTrue(scrollToElement(startVoiceButton, in: app))
        startVoiceButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
    }

    func testSeriesDetailAllowsNewEpisodeWhenPlanStillHasRoom() {
        let app = launchApp(extraEnvironment: [
            "STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE": "allow_continue_story",
            "STORYTIME_UI_TEST_ENTITLEMENT_TIER": "plus"
        ])

        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let newEpisodeButton = app.buttons["newEpisodeButton"]
        XCTAssertTrue(newEpisodeButton.waitForExistence(timeout: 10))
        newEpisodeButton.tap()

        let storyTitle = app.staticTexts["storyTitleLabel"]
        XCTAssertTrue(storyTitle.waitForExistence(timeout: 120))
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
        XCTAssertTrue(scrollToElement(parentRawAudioStatusLabel, in: app))
        XCTAssertEqual(parentRawAudioStatusLabel.label, "Raw audio is not saved")

        let parentPrivacySummary = app.staticTexts["parentPrivacySummary"]
        XCTAssertTrue(scrollToElement(parentPrivacySummary, in: app))
        XCTAssertEqual(
            parentPrivacySummary.label,
            "Use Parent Controls for child setup, privacy, retention, and deletion on this device."
        )

        let parentPrivacyLocalSummary = app.staticTexts["parentPrivacyLocalSummary"]
        XCTAssertTrue(scrollToElement(parentPrivacyLocalSummary, in: app))
        XCTAssertEqual(
            parentPrivacyLocalSummary.label,
            "What stays on this device: saved stories and continuity after the session ends."
        )

        let parentPrivacyLiveSummary = app.staticTexts["parentPrivacyLiveSummary"]
        XCTAssertTrue(scrollToElement(parentPrivacyLiveSummary, in: app))
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

    private func launchApp(
        reset: Bool = true,
        seed: Bool = true,
        extraEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["STORYTIME_UI_TEST_MODE"] = "1"
        if seed {
            app.launchEnvironment["STORYTIME_UI_TEST_SEED"] = "1"
        }
        if reset && !seed {
            app.launchEnvironment["STORYTIME_UI_TEST_RESET"] = "1"
        }
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

    private func createParentAccount(in app: XCUIApplication, email: String, password: String) {
        let entryButton = app.buttons["parentAccountEntryButton"]
        XCTAssertTrue(entryButton.waitForExistence(timeout: 10))
        entryButton.tap()

        completeParentAccountSheet(in: app, email: email, password: password)
        XCTAssertTrue(app.buttons["parentAccountManageButton"].waitForExistence(timeout: 10))
    }

    private func createParentAccountFromOnboarding(in app: XCUIApplication, email: String, password: String) {
        let entryButton = app.buttons["onboardingCreateAccountButton"]
        XCTAssertTrue(entryButton.waitForExistence(timeout: 10))
        entryButton.tap()

        completeParentAccountSheet(in: app, email: email, password: password)
        XCTAssertTrue(app.staticTexts["onboardingAccountSignedInSummary"].waitForExistence(timeout: 10))
    }

    private func completeParentAccountSheet(in app: XCUIApplication, email: String, password: String) {
        let sheetTitle = app.staticTexts["parentAccountSheetTitle"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10))

        let emailField = app.textFields["parentAccountEmailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["parentAccountPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10))
        passwordField.tap()
        passwordField.typeText(password)

        let primaryButton = app.buttons["parentAccountPrimaryButton"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 10))
        primaryButton.tap()

        let doneButton = app.buttons["parentAccountCancelButton"]
        let savePasswordButton = app.buttons["Not Now"]
        if savePasswordButton.waitForExistence(timeout: 2) {
            savePasswordButton.tap()
        }

        let signedInSummary = app.staticTexts["parentAccountSheetSignedInSummary"]
        if signedInSummary.waitForExistence(timeout: 2) && doneButton.exists {
            doneButton.tap()
        }

        XCTAssertTrue(waitForNonExistence(of: sheetTitle, timeout: 10) || !sheetTitle.exists)
    }

    private func advanceOnboardingToPlanStep(in app: XCUIApplication, email: String, password: String) {
        advanceOnboarding(in: app, toStep: 5)
        createParentAccountFromOnboarding(in: app, email: email, password: password)

        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        let stepCounter = app.staticTexts["onboardingStepCounter"]
        XCTAssertTrue(waitForLabel(of: stepCounter, toEqual: "Step 6 of 7"))
        XCTAssertTrue(app.staticTexts["onboardingPlanSelectionStatus"].waitForExistence(timeout: 10))
    }

    private func advanceOnboardingToPlanStepUsingAppleSignIn(in app: XCUIApplication) {
        advanceOnboarding(in: app, toStep: 5)
        signInWithAppleFromOnboarding(in: app)

        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        let stepCounter = app.staticTexts["onboardingStepCounter"]
        XCTAssertTrue(waitForLabel(of: stepCounter, toEqual: "Step 6 of 7"))
        XCTAssertTrue(app.staticTexts["onboardingPlanSelectionStatus"].waitForExistence(timeout: 10))
    }

    private func chooseStarterInOnboarding(in app: XCUIApplication) {
        let chooseStarterButton = app.buttons["onboardingChooseStarterButton"]
        XCTAssertTrue(scrollToElement(chooseStarterButton, in: app))
        chooseStarterButton.tap()

        let status = app.staticTexts["onboardingPlanActionStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.label, "Starter selected for this parent account.")
    }

    private func finishOnboarding(in app: XCUIApplication) {
        let continueButton = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        let stepCounter = app.staticTexts["onboardingStepCounter"]
        XCTAssertTrue(waitForLabel(of: stepCounter, toEqual: "Step 7 of 7"))

        let finishButton = app.buttons["onboardingFinishSetupButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 10))
        XCTAssertTrue(finishButton.isEnabled)
        finishButton.tap()
    }

    private func signInWithApple(in app: XCUIApplication) {
        let entryButton = app.buttons["parentAccountEntryButton"]
        XCTAssertTrue(entryButton.waitForExistence(timeout: 10))
        entryButton.tap()

        let sheetTitle = app.staticTexts["parentAccountSheetTitle"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10))

        let appleButton = app.buttons["parentAccountAppleButton"]
        XCTAssertTrue(appleButton.waitForExistence(timeout: 10))
        appleButton.tap()

        XCTAssertTrue(waitForNonExistence(of: sheetTitle, timeout: 10))
    }

    private func signInWithAppleFromOnboarding(in app: XCUIApplication) {
        let entryButton = app.buttons["onboardingCreateAccountButton"]
        XCTAssertTrue(entryButton.waitForExistence(timeout: 10))
        entryButton.tap()

        let sheetTitle = app.staticTexts["parentAccountSheetTitle"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10))

        let appleButton = app.buttons["parentAccountAppleButton"]
        XCTAssertTrue(appleButton.waitForExistence(timeout: 10))
        appleButton.tap()

        XCTAssertTrue(waitForNonExistence(of: sheetTitle, timeout: 10))
        XCTAssertTrue(app.staticTexts["onboardingAccountSignedInSummary"].waitForExistence(timeout: 10))
    }

    private func refreshPlanStatus(in app: XCUIApplication) {
        let refreshButton = app.buttons["parentRefreshPlanButton"]
        XCTAssertTrue(scrollToElement(refreshButton, in: app))
        refreshButton.tap()
        XCTAssertTrue(app.staticTexts["parentPlanActionStatus"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["parentPlanActionStatus"].label, "Plan status refreshed for this device.")
    }

    private func restorePurchases(in app: XCUIApplication) {
        let restoreButton = app.buttons["parentRestorePurchasesButton"]
        XCTAssertTrue(scrollToElement(restoreButton, in: app))
        restoreButton.tap()
        XCTAssertTrue(app.staticTexts["parentPlanActionStatus"].waitForExistence(timeout: 10))
        XCTAssertEqual(
            app.staticTexts["parentPlanActionStatus"].label,
            "Restore check finished. StoryTime refreshed the plan for this device."
        )
    }

    private func redeemPromoCode(in app: XCUIApplication, code: String) {
        let promoCodeField = app.textFields["parentPromoCodeField"]
        XCTAssertTrue(scrollToElement(promoCodeField, in: app))
        promoCodeField.tap()
        promoCodeField.typeText(code)

        let redeemButton = app.buttons["parentRedeemPromoButton"]
        XCTAssertTrue(scrollToElement(redeemButton, in: app))
        redeemButton.tap()
        XCTAssertTrue(app.staticTexts["parentPlanActionStatus"].waitForExistence(timeout: 10))
    }

    private func startSeededReplayAndWaitForCompletion(in app: XCUIApplication) {
        let seededSeriesCard = app.buttons["seriesCard-55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(seededSeriesCard.waitForExistence(timeout: 10))
        seededSeriesCard.tap()

        let repeatButton = app.buttons["repeatEpisodeButton"]
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 10))
        repeatButton.tap()

        let replayButton = app.buttons["completionReplayButton"]
        XCTAssertTrue(replayButton.waitForExistence(timeout: 30))
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

        for _ in 0..<maxSwipes {
            app.swipeDown()
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

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForNonExistence(of element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func advanceOnboarding(in app: XCUIApplication, toStep targetStep: Int) {
        let continueButton = app.buttons["onboardingContinueButton"]
        let stepCounter = app.staticTexts["onboardingStepCounter"]

        for expectedStep in 2...targetStep {
            XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
            continueButton.tap()
            XCTAssertTrue(waitForLabel(of: stepCounter, toEqual: "Step \(expectedStep) of 7"))
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
