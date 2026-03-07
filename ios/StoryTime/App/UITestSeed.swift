import Foundation

enum UITestSeed {
    static func prepareIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["STORYTIME_UI_TEST_SEED"] == "1" else { return }

        let defaults = UserDefaults.standard
        let keys = [
            "storytime.series.library.v1",
            "storytime.child.profiles.v1",
            "storytime.active.child.profile.v1",
            "storytime.parent.privacy.v1",
            "storytime.continuity.memory.v1",
            "com.storytime.install-id",
            "com.storytime.session-token",
            "com.storytime.session-expiry",
            "com.storytime.session-id"
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
        StoryLibraryV2Storage(storageURL: StoryLibraryV2Storage.defaultStorageURL()).clear()

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
    }
}
