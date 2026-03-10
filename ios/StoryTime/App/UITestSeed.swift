import Foundation

enum UITestSeed {
    static func prepareIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        let shouldSeed = environment["STORYTIME_UI_TEST_SEED"] == "1"
        let shouldReset = shouldSeed || environment["STORYTIME_UI_TEST_RESET"] == "1"
        guard shouldReset else { return }

        let defaults = UserDefaults.standard
        let keys = [
            "storytime.series.library.v1",
            "storytime.child.profiles.v1",
            "storytime.active.child.profile.v1",
            "storytime.parent.privacy.v1",
            "storytime.continuity.memory.v1",
            FirstRunExperienceStore.onboardingCompletedKey,
            "com.storytime.install-id",
            "com.storytime.entitlements.bootstrap.v1",
            "com.storytime.session-token",
            "com.storytime.session-expiry",
            "com.storytime.session-id"
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
        StoryLibraryV2Storage(storageURL: StoryLibraryV2Storage.defaultStorageURL()).clear()

        guard shouldSeed else { return }

        let primaryProfile = ChildProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
            displayName: "Milo",
            age: 5,
            contentSensitivity: .extraGentle,
            preferredMode: .bedtime
        )
        let secondaryProfile = ChildProfile(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
            displayName: "Nora",
            age: 7,
            contentSensitivity: .standard,
            preferredMode: .educational
        )

        let now = Date()
        let firstEpisode = StoryEpisode(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
            title: "Bunny and the Lantern Trail",
            storyId: "seed-story-1",
            scenes: [
                StoryScene(sceneId: "1", text: "Bunny followed a glowing trail into the park.", durationSec: 45),
                StoryScene(sceneId: "2", text: "Fox helped Bunny find the missing lantern by the pond.", durationSec: 50)
            ],
            estimatedDurationSec: 95,
            engine: nil,
            createdAt: now.addingTimeInterval(-86_400)
        )
        let secondEpisode = StoryEpisode(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
            title: "Bunny and the Moonlight Map",
            storyId: "seed-story-2",
            scenes: [
                StoryScene(sceneId: "1", text: "Bunny found a moonlight map tucked inside the lantern.", durationSec: 48),
                StoryScene(sceneId: "2", text: "The map pointed toward a hidden garden behind the swings.", durationSec: 47)
            ],
            estimatedDurationSec: 95,
            engine: nil,
            createdAt: now
        )

        let seededSeries = StorySeries(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
            childProfileId: primaryProfile.id,
            title: "Bunny and the Lantern Trail",
            characterHints: ["Bunny", "Fox"],
            arcSummary: "Bunny keeps discovering clues that point toward a glowing hidden garden.",
            relationshipFacts: ["Bunny trusts Fox to solve quiet mysteries."],
            favoritePlaces: ["Moonlit Park", "Pond Path"],
            unresolvedThreads: ["What waits in the hidden garden?"],
            episodes: [firstEpisode, secondEpisode],
            createdAt: now.addingTimeInterval(-86_400),
            updatedAt: now
        )

        let privacy = ParentPrivacySettings(
            saveStoryHistory: true,
            retentionPolicy: .thirtyDays,
            saveRawAudio: false,
            clearTranscriptsAfterSession: true
        )

        defaults.set(try? JSONEncoder().encode([seededSeries]), forKey: "storytime.series.library.v1")
        defaults.set(try? JSONEncoder().encode([primaryProfile, secondaryProfile]), forKey: "storytime.child.profiles.v1")
        defaults.set(primaryProfile.id.uuidString, forKey: "storytime.active.child.profile.v1")
        defaults.set(try? JSONEncoder().encode(privacy), forKey: "storytime.parent.privacy.v1")
        defaults.set(true, forKey: FirstRunExperienceStore.onboardingCompletedKey)
    }

    static func entitlementPreflightOverride(for plan: StoryLaunchPlan, childProfileCount: Int) -> EntitlementPreflightResponse? {
        let environment = ProcessInfo.processInfo.environment
        guard environment["STORYTIME_UI_TEST_MODE"] == "1" else {
            return nil
        }

        let override = environment["STORYTIME_UI_TEST_PREFLIGHT_OVERRIDE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch override {
        case "block_new_story":
            guard case .new = plan.mode else { return nil }
            return EntitlementPreflightResponse(
                action: .newStory,
                allowed: false,
                blockReason: .storyStartsExhausted,
                recommendedUpgradeSurface: .newStoryJourney,
                snapshot: blockedStarterSnapshot(
                    childProfileCount: childProfileCount,
                    canStartNewStories: false,
                    canContinueSavedSeries: true,
                    remainingStoryStarts: 0,
                    remainingContinuations: 1
                )
            )
        case "block_continue_story":
            guard case .extend = plan.mode else { return nil }
            return EntitlementPreflightResponse(
                action: .continueStory,
                allowed: false,
                blockReason: .continuationsExhausted,
                recommendedUpgradeSurface: .newStoryJourney,
                snapshot: blockedStarterSnapshot(
                    childProfileCount: childProfileCount,
                    canStartNewStories: true,
                    canContinueSavedSeries: false,
                    remainingStoryStarts: 1,
                    remainingContinuations: 0
                )
            )
        default:
            return nil
        }
    }

    private static func blockedStarterSnapshot(
        childProfileCount: Int,
        canStartNewStories: Bool,
        canContinueSavedSeries: Bool,
        remainingStoryStarts: Int?,
        remainingContinuations: Int?
    ) -> EntitlementSnapshot {
        let now = Date()
        return EntitlementSnapshot(
            tier: .starter,
            source: .debugSeed,
            maxChildProfiles: max(1, childProfileCount),
            maxStoryStartsPerPeriod: 1,
            maxContinuationsPerPeriod: 1,
            maxStoryLengthMinutes: 10,
            canReplaySavedStories: true,
            canStartNewStories: canStartNewStories,
            canContinueSavedSeries: canContinueSavedSeries,
            effectiveAt: now.timeIntervalSince1970,
            expiresAt: now.addingTimeInterval(300).timeIntervalSince1970,
            usageWindow: EntitlementUsageWindow(
                kind: .rollingPeriod,
                durationSeconds: 86_400,
                resetsAt: now.addingTimeInterval(86_400).timeIntervalSince1970
            ),
            remainingStoryStarts: remainingStoryStarts,
            remainingContinuations: remainingContinuations
        )
    }
}
