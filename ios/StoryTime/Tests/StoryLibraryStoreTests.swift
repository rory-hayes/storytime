import XCTest
@testable import StoryTime

@MainActor
final class StoryLibraryStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "StoryLibraryStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        try await super.tearDown()
    }

    func testProfileLifecycleAndLimits() throws {
        let store = StoryLibraryStore(userDefaults: defaults)

        XCTAssertEqual(store.childProfiles.count, 1)
        XCTAssertEqual(store.activeProfile?.displayName, "Story Explorer")
        XCTAssertTrue(store.canAddMoreProfiles)

        store.addChildProfile(name: "  ", age: 9, sensitivity: .mostGentle, preferredMode: .calm)
        store.addChildProfile(name: "Nora", age: 4, sensitivity: .standard, preferredMode: .educational)
        store.addChildProfile(name: "Extra", age: 6, sensitivity: .extraGentle, preferredMode: .classic)

        XCTAssertEqual(store.childProfiles.count, 3)
        XCTAssertFalse(store.canAddMoreProfiles)
        XCTAssertTrue(store.childProfiles.contains(where: { $0.displayName == "Story Explorer" && $0.age == 8 }))

        var nora = try XCTUnwrap(store.childProfiles.first(where: { $0.displayName == "Nora" }))
        store.selectActiveProfile(nora.id)
        XCTAssertEqual(store.activeProfile?.id, nora.id)

        nora.displayName = "Nora Updated"
        nora.age = 7
        store.updateChildProfile(nora)
        XCTAssertEqual(store.profileById(nora.id)?.displayName, "Nora Updated")

        store.deleteChildProfile(nora.id)
        XCTAssertNil(store.profileById(nora.id))
        XCTAssertNotNil(store.activeProfile)
    }

    func testStoryLifecycleVisibilityAndReplacement() throws {
        let store = StoryLibraryStore(userDefaults: defaults)
        let primaryId = try XCTUnwrap(store.activeProfile?.id)
        store.addChildProfile(name: "Nora", age: 7, sensitivity: .standard, preferredMode: .educational)
        let secondaryId = try XCTUnwrap(store.childProfiles.first(where: { $0.id != primaryId })?.id)

        let newPlan = StoryLaunchPlan(
            mode: .new,
            childProfileId: primaryId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let story = makeStoryData(
            storyId: "story-1",
            title: "Lantern Trail",
            characters: ["Bunny", "Fox"],
            places: ["Moonlit Park"],
            relationships: ["Bunny trusts Fox"],
            loops: ["The lantern still glows at the pond."]
        )

        let seriesId = try XCTUnwrap(store.addStory(story, characters: ["Bunny"], plan: newPlan))
        XCTAssertEqual(store.visibleSeries.count, 1)
        XCTAssertEqual(store.seriesById(seriesId)?.characterHints.sorted(), ["Bunny"])

        let extendPlan = StoryLaunchPlan(
            mode: .extend(seriesId: seriesId),
            childProfileId: primaryId,
            experienceMode: .classic,
            usePastStory: true,
            selectedSeriesId: seriesId,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let secondStory = makeStoryData(
            storyId: "story-2",
            title: "Lantern Trail Returns",
            characters: ["Bunny", "Fox", "Owl"],
            places: ["Moonlit Park", "Hidden Garden"],
            relationships: ["Bunny trusts Fox", "Owl guides Bunny"],
            loops: ["What is inside the hidden garden gate?"]
        )
        XCTAssertEqual(store.addStory(secondStory, characters: [], plan: extendPlan), seriesId)
        XCTAssertEqual(store.seriesById(seriesId)?.episodeCount, 2)
        XCTAssertTrue(store.seriesById(seriesId)?.characterHints.contains("Fox") == true)
        XCTAssertTrue(store.seriesById(seriesId)?.favoritePlaces?.contains("Hidden Garden") == true)

        let replacement = makeStoryData(
            storyId: "story-2",
            title: "Lantern Trail Finale",
            characters: ["Bunny", "Fox"],
            places: ["Moonlit Park"],
            relationships: ["Bunny and Fox work as a team"],
            loops: []
        )
        XCTAssertEqual(store.replaceStory(replacement), seriesId)
        XCTAssertEqual(store.seriesById(seriesId)?.episodes.last?.title, "Lantern Trail Finale")

        store.selectActiveProfile(secondaryId)
        XCTAssertEqual(store.visibleSeries.count, 1, "When the active child has no stories yet, the store falls back to showing all series.")

        let repeatPlan = StoryLaunchPlan(
            mode: .repeatEpisode(seriesId: seriesId),
            childProfileId: secondaryId,
            experienceMode: .educational,
            usePastStory: true,
            selectedSeriesId: seriesId,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        XCTAssertNil(store.addStory(secondStory, characters: [], plan: repeatPlan))
    }

    func testPrivacyRetentionAndDeletionControls() throws {
        let series = StorySeries(
            id: UUID(),
            childProfileId: UUID(),
            title: "Old Series",
            characterHints: ["Bunny"],
            arcSummary: nil,
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Old Episode",
                    storyId: "old-story",
                    scenes: [StoryScene(sceneId: "1", text: "Old", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: Calendar.current.date(byAdding: .day, value: -100, to: Date()) ?? .distantPast
                )
            ],
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
        defaults.set(try JSONEncoder().encode([series]), forKey: "storytime.series.library.v1")

        let store = StoryLibraryStore(userDefaults: defaults)
        XCTAssertTrue(store.series.isEmpty, "Old stories should be pruned by the default retention policy.")

        store.setClearTranscriptsAfterSession(false)
        XCTAssertFalse(store.privacySettings.clearTranscriptsAfterSession)

        let primaryId = try XCTUnwrap(store.activeProfile?.id)
        let story = makeStoryData(
            storyId: "recent-story",
            title: "New Story",
            characters: ["Bunny"],
            places: ["Pond Path"],
            relationships: ["Bunny waves hello"],
            loops: []
        )
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: primaryId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: false,
            lengthMinutes: 3
        )
        let seriesId = try XCTUnwrap(store.addStory(story, characters: ["Bunny"], plan: plan))
        XCTAssertEqual(store.storyHistorySummary, "History retained for 90 days")

        store.setRetentionPolicy(.sevenDays)
        XCTAssertEqual(store.privacySettings.retentionPolicy, .sevenDays)

        store.deleteSeries(seriesId)
        XCTAssertTrue(store.series.isEmpty)

        _ = store.addStory(story, characters: ["Bunny"], plan: plan)
        XCTAssertFalse(store.series.isEmpty)
        store.clearStoryHistory()
        XCTAssertTrue(store.series.isEmpty)

        store.setSaveStoryHistory(false)
        XCTAssertEqual(store.storyHistorySummary, "Story history is off")
        XCTAssertNil(store.addStory(story, characters: ["Bunny"], plan: plan))
    }

    func testReusePastStoryBranchMissingSeriesFallbackAndFinalProfileDeletion() throws {
        let store = StoryLibraryStore(userDefaults: defaults)
        let childProfileId = try XCTUnwrap(store.activeProfile?.id)
        let firstStory = makeStoryData(
            storyId: "story-1",
            title: "First Story",
            characters: ["Bunny"],
            places: ["Pond Path"],
            relationships: ["Bunny trusts Fox"],
            loops: []
        )
        let initialPlan = StoryLaunchPlan(
            mode: .new,
            childProfileId: childProfileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: false,
            lengthMinutes: 4
        )
        let initialSeriesId = try XCTUnwrap(store.addStory(firstStory, characters: ["Bunny"], plan: initialPlan))

        let reusePlan = StoryLaunchPlan(
            mode: .new,
            childProfileId: childProfileId,
            experienceMode: .classic,
            usePastStory: true,
            selectedSeriesId: initialSeriesId,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let followUpStory = makeStoryData(
            storyId: "story-2",
            title: "Second Story",
            characters: ["Bunny", "Fox"],
            places: ["Moonlit Park"],
            relationships: ["Bunny trusts Fox"],
            loops: []
        )
        XCTAssertEqual(store.addStory(followUpStory, characters: [], plan: reusePlan), initialSeriesId)
        XCTAssertEqual(store.seriesById(initialSeriesId)?.episodeCount, 2)

        let missingSeriesId = UUID()
        let missingPlan = StoryLaunchPlan(
            mode: .extend(seriesId: missingSeriesId),
            childProfileId: childProfileId,
            experienceMode: .classic,
            usePastStory: true,
            selectedSeriesId: missingSeriesId,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let replacementSeriesId = try XCTUnwrap(store.addStory(followUpStory, characters: [], plan: missingPlan))
        XCTAssertNotEqual(replacementSeriesId, missingSeriesId)
        XCTAssertNil(store.replaceStory(makeStoryData(
            storyId: "missing-story",
            title: "Missing",
            characters: [],
            places: [],
            relationships: [],
            loops: []
        )))

        store.deleteChildProfile(childProfileId)
        XCTAssertEqual(store.childProfiles.count, 1)
        XCTAssertEqual(store.activeProfile?.displayName, "Story Explorer")
    }

    func testForeverRetentionKeepsOldStories() throws {
        let profile = ChildProfile(
            id: UUID(),
            displayName: "Milo",
            age: 5,
            contentSensitivity: .extraGentle,
            preferredMode: .classic
        )
        let privacy = ParentPrivacySettings(
            saveStoryHistory: true,
            retentionPolicy: .forever,
            saveRawAudio: false,
            clearTranscriptsAfterSession: true
        )
        let oldSeries = StorySeries(
            id: UUID(),
            childProfileId: profile.id,
            title: "Very Old Story",
            characterHints: ["Bunny"],
            arcSummary: nil,
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Old Episode",
                    storyId: "old-story",
                    scenes: [StoryScene(sceneId: "1", text: "Old", durationSec: 20)],
                    estimatedDurationSec: 20,
                    engine: nil,
                    createdAt: Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? .distantPast
                )
            ],
            createdAt: .distantPast,
            updatedAt: .distantPast
        )

        defaults.set(try JSONEncoder().encode([profile]), forKey: "storytime.child.profiles.v1")
        defaults.set(profile.id.uuidString, forKey: "storytime.active.child.profile.v1")
        defaults.set(try JSONEncoder().encode(privacy), forKey: "storytime.parent.privacy.v1")
        defaults.set(try JSONEncoder().encode([oldSeries]), forKey: "storytime.series.library.v1")

        let store = StoryLibraryStore(userDefaults: defaults)
        XCTAssertEqual(store.series.count, 1)
        XCTAssertEqual(store.series.first?.title, "Very Old Story")
    }

    func testCorruptPersistenceFallsBackToDefaults() {
        defaults.set(Data("not-json".utf8), forKey: "storytime.series.library.v1")
        defaults.set(Data("bad-profiles".utf8), forKey: "storytime.child.profiles.v1")
        defaults.set(Data("bad-privacy".utf8), forKey: "storytime.parent.privacy.v1")
        defaults.set("not-a-uuid", forKey: "storytime.active.child.profile.v1")

        let store = StoryLibraryStore(userDefaults: defaults)

        XCTAssertEqual(store.series.count, 0)
        XCTAssertEqual(store.childProfiles.count, 1)
        XCTAssertEqual(store.activeProfile?.displayName, "Story Explorer")
        XCTAssertEqual(store.privacySettings, .default)
    }

    func testContinuityMemoryStoreRanksPrunesAndClearsFacts() async {
        let memoryDefaults = try! XCTUnwrap(UserDefaults(suiteName: "ContinuityMemoryStoreTests.\(UUID().uuidString)"))
        let memory = ContinuityMemoryStore(userDefaults: memoryDefaults)
        let seriesId = UUID()

        await memory.replaceFacts(seriesId: seriesId, storyId: "story-1", texts: ["ignored"], embeddings: [])
        let initialResults = await memory.topFactTexts(seriesId: seriesId, queryEmbedding: [1, 0], limit: 3)
        XCTAssertEqual(initialResults, [])

        await memory.replaceFacts(
            seriesId: seriesId,
            storyId: "story-1",
            texts: ["Bunny loves Moonlit Park", "Fox keeps the lantern safe"],
            embeddings: [[0.9, 0.1], [0.2, 0.8]]
        )
        await memory.replaceFacts(
            seriesId: seriesId,
            storyId: "story-2",
            texts: ["Moonlit Park has a hidden garden gate"],
            embeddings: [[0.85, 0.15]]
        )

        let ranked = await memory.topFactTexts(seriesId: seriesId, queryEmbedding: [1, 0], limit: 2)
        XCTAssertEqual(ranked.first, "Bunny loves Moonlit Park")
        XCTAssertTrue(ranked.contains("Moonlit Park has a hidden garden gate"))

        await memory.prune(toSeriesIDs: Set([seriesId]), storyIDs: Set(["story-2"]))
        let afterPrune = await memory.topFactTexts(seriesId: seriesId, queryEmbedding: [1, 0], limit: 3)
        XCTAssertEqual(afterPrune, ["Moonlit Park has a hidden garden gate"])

        await memory.clearSeries(seriesId)
        let afterClearSeries = await memory.topFactTexts(seriesId: seriesId, queryEmbedding: [1, 0], limit: 3)
        XCTAssertEqual(afterClearSeries, [])

        await memory.replaceFacts(seriesId: seriesId, storyId: "story-3", texts: ["Bunny naps"], embeddings: [[0.4, 0.4]])
        await memory.clearAll()
        let afterClearAll = await memory.topFactTexts(seriesId: seriesId, queryEmbedding: [1, 0], limit: 3)
        XCTAssertEqual(afterClearAll, [])
    }

    private func makeStoryData(
        storyId: String,
        title: String,
        characters: [String],
        places: [String],
        relationships: [String],
        loops: [String]
    ) -> StoryData {
        let engine = makeEngineData(
            characters: characters,
            places: places,
            relationships: relationships,
            loops: loops
        )
        return StoryData(
            storyId: storyId,
            title: title,
            estimatedDurationSec: 120,
            scenes: [
                StoryScene(sceneId: "1", text: "A gentle beginning.", durationSec: 40),
                StoryScene(sceneId: "2", text: "A warm ending.", durationSec: 40)
            ],
            safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
            engine: engine
        )
    }

    private func makeEngineData(
        characters: [String],
        places: [String],
        relationships: [String],
        loops: [String]
    ) -> StoryEngineData {
        let characterBible = characters.map { name in
            [
                "name": name,
                "role": "friend",
                "traits": ["kind", "curious"]
            ] as [String: Any]
        }
        let payload: [String: Any] = [
            "episode_recap": "Bunny solved a gentle mystery.",
            "series_memory": [
                "title": "Lantern Trail",
                "recurring_characters": characters,
                "prior_episode_recap": "Earlier, Bunny followed a lantern through the park.",
                "world_facts": ["Moonlit Park glows after sunset."],
                "open_loops": loops,
                "favorite_places": places,
                "relationship_facts": relationships,
                "arc_summary": "Bunny keeps discovering new clues.",
                "next_episode_hook": "A garden gate begins to shine."
            ],
            "character_bible": characterBible,
            "beat_plan": [
                [
                    "beat_id": "beat-1",
                    "scene_index": 0,
                    "label": "Opening",
                    "purpose": "Set up the gentle mystery.",
                    "target_duration_sec": 40
                ]
            ],
            "continuity_facts": relationships + places + loops,
            "quality": [
                "passed": true,
                "issues": [],
                "total_duration_sec": 120,
                "target_duration_sec": 120,
                "repeated_phrase_count": 0
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! JSONDecoder().decode(StoryEngineData.self, from: data)
    }
}
