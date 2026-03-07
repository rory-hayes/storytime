import XCTest
@testable import StoryTime

@MainActor
final class StoryLibraryStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var storageURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "StoryLibraryStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
            .appendingPathComponent("storytime-v2.sqlite")
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: storageURL)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        if let storageURL {
            StoryLibraryV2Storage(storageURL: storageURL).clear()
        }
        await clearStandardPersistenceKeys()
        defaults = nil
        try await super.tearDown()
    }

    private func makeStore() -> StoryLibraryStore {
        StoryLibraryStore(userDefaults: defaults, storageURL: storageURL)
    }

    private func makeStandardStore() -> StoryLibraryStore {
        StoryLibraryStore(userDefaults: .standard, storageURL: StoryLibraryV2Storage.defaultStorageURL())
    }

    func testProfileLifecycleAndLimits() throws {
        let store = makeStore()

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
        let store = makeStore()
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
        XCTAssertTrue(store.visibleSeries.isEmpty, "The active child should only see their own saved stories.")

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

    func testVisibleSeriesForRequestedChildDoesNotDependOnActiveProfileOrFallback() throws {
        let store = makeStore()
        let primaryId = try XCTUnwrap(store.activeProfile?.id)
        store.addChildProfile(name: "Nora", age: 7, sensitivity: .standard, preferredMode: .educational)
        let secondaryId = try XCTUnwrap(store.childProfiles.first(where: { $0.id != primaryId })?.id)

        let primaryPlan = StoryLaunchPlan(
            mode: .new,
            childProfileId: primaryId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let primarySeriesId = try XCTUnwrap(store.addStory(
            makeStoryData(
                storyId: "primary-story",
                title: "Lantern Trail",
                characters: ["Bunny"],
                places: ["Moonlit Park"],
                relationships: ["Bunny trusts Fox"],
                loops: []
            ),
            characters: ["Bunny"],
            plan: primaryPlan
        ))

        XCTAssertEqual(store.visibleSeries(for: primaryId).map(\.id), [primarySeriesId])
        XCTAssertTrue(store.visibleSeries(for: secondaryId).isEmpty)

        store.selectActiveProfile(secondaryId)

        XCTAssertTrue(store.visibleSeries.isEmpty)
        XCTAssertEqual(store.visibleSeries(for: primaryId).map(\.id), [primarySeriesId])
    }

    func testAddStoryPersistsNewSeriesAcrossReload() throws {
        let store = makeStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let story = makeStoryData(
            storyId: "persist-new-series",
            title: "Lantern Path",
            characters: ["Bunny"],
            places: ["Moonlit Park"],
            relationships: ["Bunny trusts Fox"],
            loops: ["Where does the lantern lead?"]
        )
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )

        let seriesId = try XCTUnwrap(store.addStory(story, characters: ["Bunny"], plan: plan))

        let reloaded = makeStore()
        let persistedSeries = try XCTUnwrap(reloaded.seriesById(seriesId))
        XCTAssertEqual(persistedSeries.title, "Lantern Path")
        XCTAssertEqual(persistedSeries.episodes.map(\.storyId), ["persist-new-series"])
        XCTAssertEqual(reloaded.series.first?.id, seriesId)
    }

    func testAppendEpisodePersistsAcrossReloadAndMovesSeriesToFront() throws {
        let store = makeStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let firstPlan = StoryLaunchPlan(
            mode: .new,
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let firstSeriesId = try XCTUnwrap(store.addStory(
            makeStoryData(
                storyId: "append-base-story",
                title: "Lantern One",
                characters: ["Bunny"],
                places: ["Park"],
                relationships: ["Bunny listens"],
                loops: []
            ),
            characters: ["Bunny"],
            plan: firstPlan
        ))
        _ = try XCTUnwrap(store.addStory(
            makeStoryData(
                storyId: "front-runner-story",
                title: "Garden Gate",
                characters: ["Fox"],
                places: ["Garden"],
                relationships: ["Fox explores"],
                loops: []
            ),
            characters: ["Fox"],
            plan: firstPlan
        ))

        let extendPlan = StoryLaunchPlan(
            mode: .extend(seriesId: firstSeriesId),
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: true,
            selectedSeriesId: firstSeriesId,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        _ = store.addStory(
            makeStoryData(
                storyId: "append-follow-up-story",
                title: "Lantern Two",
                characters: ["Bunny", "Fox"],
                places: ["Park", "Pond"],
                relationships: ["Bunny trusts Fox"],
                loops: ["What glows by the pond?"]
            ),
            characters: [],
            plan: extendPlan
        )

        let reloaded = makeStore()
        let persistedSeries = try XCTUnwrap(reloaded.seriesById(firstSeriesId))
        XCTAssertEqual(persistedSeries.episodes.map(\.storyId), ["append-base-story", "append-follow-up-story"])
        XCTAssertEqual(reloaded.series.first?.id, firstSeriesId)
        XCTAssertTrue(persistedSeries.characterHints.contains("Fox"))
    }

    func testReplaceStoryPersistsAcrossReload() throws {
        let store = makeStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let seriesId = try XCTUnwrap(store.addStory(
            makeStoryData(
                storyId: "replace-me",
                title: "Lantern Draft",
                characters: ["Bunny"],
                places: ["Park"],
                relationships: ["Bunny learns"],
                loops: []
            ),
            characters: ["Bunny"],
            plan: plan
        ))

        _ = store.replaceStory(
            makeStoryData(
                storyId: "replace-me",
                title: "Lantern Finale",
                characters: ["Bunny", "Fox"],
                places: ["Park", "Garden"],
                relationships: ["Bunny trusts Fox"],
                loops: ["The garden gate opens."]
            )
        )

        let reloaded = makeStore()
        let persistedSeries = try XCTUnwrap(reloaded.seriesById(seriesId))
        XCTAssertEqual(persistedSeries.episodes.count, 1)
        XCTAssertEqual(persistedSeries.episodes.first?.title, "Lantern Finale")
        XCTAssertEqual(persistedSeries.episodes.first?.storyId, "replace-me")
        XCTAssertTrue(persistedSeries.favoritePlaces?.contains("Garden") == true)
    }

    func testReplaceStoryRebuildsContinuityMetadataAcrossReload() throws {
        let store = makeStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let seriesId = try XCTUnwrap(store.addStory(
            makeStoryData(
                storyId: "replace-continuity",
                title: "Lantern Draft",
                characters: ["Bunny", "Fox"],
                places: ["Moonlit Park"],
                relationships: ["Bunny trusts Fox"],
                loops: ["Find the hidden gate"]
            ),
            characters: ["Bunny"],
            plan: plan
        ))

        _ = store.replaceStory(
            makeStoryData(
                storyId: "replace-continuity",
                title: "Lantern Finale",
                characters: ["Bunny", "Owl"],
                places: ["Rainbow Brook"],
                relationships: ["Bunny follows Owl"],
                loops: []
            )
        )

        let inMemorySeries = try XCTUnwrap(store.seriesById(seriesId))
        XCTAssertEqual(inMemorySeries.favoritePlaces, ["Rainbow Brook"])
        XCTAssertEqual(inMemorySeries.relationshipFacts, ["Bunny follows Owl"])
        XCTAssertNil(inMemorySeries.unresolvedThreads)

        let reloaded = makeStore()
        let persistedSeries = try XCTUnwrap(reloaded.seriesById(seriesId))
        XCTAssertEqual(persistedSeries.favoritePlaces, ["Rainbow Brook"])
        XCTAssertEqual(persistedSeries.relationshipFacts, ["Bunny follows Owl"])
        XCTAssertNil(persistedSeries.unresolvedThreads)
    }

    func testDeleteSeriesPersistsAcrossReload() throws {
        let store = makeStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let deletedSeriesId = try XCTUnwrap(store.addStory(
            makeStoryData(
                storyId: "delete-target",
                title: "Delete Me",
                characters: ["Bunny"],
                places: ["Park"],
                relationships: [],
                loops: []
            ),
            characters: ["Bunny"],
            plan: plan
        ))
        let retainedSeriesId = try XCTUnwrap(store.addStory(
            makeStoryData(
                storyId: "keep-target",
                title: "Keep Me",
                characters: ["Fox"],
                places: ["Garden"],
                relationships: [],
                loops: []
            ),
            characters: ["Fox"],
            plan: plan
        ))

        store.deleteSeries(deletedSeriesId)

        let reloaded = makeStore()
        XCTAssertNil(reloaded.seriesById(deletedSeriesId))
        XCTAssertNotNil(reloaded.seriesById(retainedSeriesId))
        XCTAssertEqual(reloaded.series.count, 1)
        XCTAssertEqual(reloaded.series.first?.id, retainedSeriesId)
    }

    func testClearStoryHistoryPersistsAcrossReload() throws {
        let store = makeStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        _ = try XCTUnwrap(store.addStory(
            makeStoryData(
                storyId: "clear-history-story",
                title: "Clear Me",
                characters: ["Bunny"],
                places: ["Park"],
                relationships: [],
                loops: []
            ),
            characters: ["Bunny"],
            plan: plan
        ))

        store.clearStoryHistory()

        let reloaded = makeStore()
        XCTAssertTrue(reloaded.series.isEmpty)
    }

    func testRepeatEpisodeDoesNotPersistNewHistoryAcrossReload() throws {
        let store = makeStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let seriesId = try XCTUnwrap(store.addStory(
            makeStoryData(
                storyId: "repeat-source-story",
                title: "Replay Me",
                characters: ["Bunny"],
                places: ["Park"],
                relationships: [],
                loops: []
            ),
            characters: ["Bunny"],
            plan: plan
        ))

        let repeatPlan = StoryLaunchPlan(
            mode: .repeatEpisode(seriesId: seriesId),
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: true,
            selectedSeriesId: seriesId,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        XCTAssertNil(store.addStory(
            makeStoryData(
                storyId: "repeat-ignored-story",
                title: "Should Not Save",
                characters: ["Bunny"],
                places: ["Park"],
                relationships: [],
                loops: []
            ),
            characters: [],
            plan: repeatPlan
        ))

        let reloaded = makeStore()
        let persistedSeries = try XCTUnwrap(reloaded.seriesById(seriesId))
        XCTAssertEqual(reloaded.series.count, 1)
        XCTAssertEqual(persistedSeries.episodes.map(\.storyId), ["repeat-source-story"])
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

        let store = makeStore()
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

    func testRetentionPolicyPrunesPersistedStoreAcrossReload() throws {
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
        let oldEpisodeDate = Calendar.current.date(byAdding: .day, value: -100, to: Date()) ?? .distantPast
        let recentEpisodeDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let seriesID = UUID()
        let oldStoryID = "retention-old-story"
        let recentStoryID = "retention-recent-story"
        let series = StorySeries(
            id: seriesID,
            childProfileId: profile.id,
            title: "Lantern Trail",
            characterHints: ["Bunny"],
            arcSummary: nil,
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Old Episode",
                    storyId: oldStoryID,
                    scenes: [StoryScene(sceneId: "1", text: "Old trail", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: oldEpisodeDate
                ),
                StoryEpisode(
                    id: UUID(),
                    title: "Recent Episode",
                    storyId: recentStoryID,
                    scenes: [StoryScene(sceneId: "2", text: "Recent trail", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: recentEpisodeDate
                )
            ],
            createdAt: oldEpisodeDate,
            updatedAt: recentEpisodeDate
        )

        defaults.set(try JSONEncoder().encode([profile]), forKey: "storytime.child.profiles.v1")
        defaults.set(profile.id.uuidString, forKey: "storytime.active.child.profile.v1")
        defaults.set(try JSONEncoder().encode(privacy), forKey: "storytime.parent.privacy.v1")
        defaults.set(try JSONEncoder().encode([series]), forKey: "storytime.series.library.v1")

        let store = makeStore()
        XCTAssertEqual(store.seriesById(seriesID)?.episodes.map(\.storyId), [oldStoryID, recentStoryID])

        store.setRetentionPolicy(.sevenDays)

        let reloaded = makeStore()
        let persistedSeries = try XCTUnwrap(reloaded.seriesById(seriesID))
        XCTAssertEqual(reloaded.privacySettings.retentionPolicy, .sevenDays)
        XCTAssertEqual(persistedSeries.episodes.map(\.storyId), [recentStoryID])
        XCTAssertEqual(persistedSeries.updatedAt, recentEpisodeDate)
    }

    func testReusePastStoryBranchMissingSeriesFallbackAndFinalProfileDeletion() throws {
        let store = makeStore()
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

        let store = makeStore()
        XCTAssertEqual(store.series.count, 1)
        XCTAssertEqual(store.series.first?.title, "Very Old Story")
    }

    func testCorruptPersistenceFallsBackToDefaults() {
        defaults.set(Data("not-json".utf8), forKey: "storytime.series.library.v1")
        defaults.set(Data("bad-profiles".utf8), forKey: "storytime.child.profiles.v1")
        defaults.set(Data("bad-privacy".utf8), forKey: "storytime.parent.privacy.v1")
        defaults.set("not-a-uuid", forKey: "storytime.active.child.profile.v1")

        let store = makeStore()

        XCTAssertEqual(store.series.count, 0)
        XCTAssertEqual(store.childProfiles.count, 1)
        XCTAssertEqual(store.activeProfile?.displayName, "Story Explorer")
        XCTAssertEqual(store.privacySettings, .default)
    }

    func testLegacyMigrationLoadsFromUserDefaults() {
        let profile = ChildProfile(
            id: UUID(),
            displayName: "Migrated Explorer",
            age: 7,
            contentSensitivity: .standard,
            preferredMode: .educational
        )
        let privacy = ParentPrivacySettings(
            saveStoryHistory: true,
            retentionPolicy: .sevenDays,
            saveRawAudio: false,
            clearTranscriptsAfterSession: false
        )
        let series = StorySeries(
            id: UUID(),
            childProfileId: profile.id,
            title: "Legacy Series",
            characterHints: ["Bunny"],
            arcSummary: "Found a lantern",
            relationshipFacts: ["Bunny trusts Fox"],
            favoritePlaces: ["Moonlit Park"],
            unresolvedThreads: ["Find the hidden gate"],
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Legacy Episode",
                    storyId: "legacy-story",
                    scenes: [StoryScene(sceneId: "1", text: "Legacy text", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: Date()
                )
            ],
            createdAt: Date(),
            updatedAt: Date()
        )

        defaults.set(try! JSONEncoder().encode([profile]), forKey: "storytime.child.profiles.v1")
        defaults.set(profile.id.uuidString, forKey: "storytime.active.child.profile.v1")
        defaults.set(try! JSONEncoder().encode(privacy), forKey: "storytime.parent.privacy.v1")
        defaults.set(try! JSONEncoder().encode([series]), forKey: "storytime.series.library.v1")

        let store = makeStore()

        XCTAssertEqual(store.childProfiles, [profile])
        XCTAssertEqual(store.activeProfile?.id, profile.id)
        let migratedSeries = try! XCTUnwrap(store.series.first)
        XCTAssertEqual(migratedSeries.id, series.id)
        XCTAssertEqual(migratedSeries.childProfileId, series.childProfileId)
        XCTAssertEqual(migratedSeries.title, series.title)
        XCTAssertEqual(migratedSeries.characterHints, series.characterHints)
        XCTAssertEqual(migratedSeries.arcSummary, series.arcSummary)
        XCTAssertEqual(migratedSeries.relationshipFacts, series.relationshipFacts)
        XCTAssertEqual(migratedSeries.favoritePlaces, series.favoritePlaces)
        XCTAssertEqual(migratedSeries.unresolvedThreads, series.unresolvedThreads)
        XCTAssertEqual(migratedSeries.episodes.map(\.storyId), series.episodes.map(\.storyId))
        XCTAssertEqual(store.privacySettings, privacy)
    }

    func testLegacyMigrationIsIdempotentAfterRelaunch() {
        let profile = ChildProfile(
            id: UUID(),
            displayName: "Persistent Explorer",
            age: 8,
            contentSensitivity: .extraGentle,
            preferredMode: .calm
        )
        defaults.set(try! JSONEncoder().encode([profile]), forKey: "storytime.child.profiles.v1")
        defaults.set(profile.id.uuidString, forKey: "storytime.active.child.profile.v1")

        _ = makeStore()

        defaults.set(Data("bad".utf8), forKey: "storytime.child.profiles.v1")
        defaults.removeObject(forKey: "storytime.active.child.profile.v1")

        let relaunchedStore = makeStore()
        XCTAssertEqual(relaunchedStore.childProfiles, [profile])
        XCTAssertEqual(relaunchedStore.activeProfile?.id, profile.id)
    }

    func testMigrationFallsBackWhenCorruptLegacySeriesIsPresent() {
        defaults.set(Data("bad".utf8), forKey: "storytime.series.library.v1")
        defaults.set(Data("bad".utf8), forKey: "storytime.child.profiles.v1")
        defaults.set(Data("bad".utf8), forKey: "storytime.parent.privacy.v1")

        let store = makeStore()

        XCTAssertEqual(store.series, [])
        XCTAssertEqual(store.childProfiles.count, 1)
        XCTAssertEqual(store.privacySettings, .default)
    }

    func testV2StoragePersistsSnapshotAcrossReload() {
        let snapshot = StoryLibraryV2Snapshot(
            migrationVersion: StoryLibraryV2Snapshot.currentMigrationVersion,
            series: [
                StorySeries(
                    id: UUID(),
                    childProfileId: nil,
                    title: "Migrated Series",
                    characterHints: ["Bunny", "Fox"],
                    arcSummary: "A lantern leads the way.",
                    relationshipFacts: ["Bunny trusts Fox"],
                    favoritePlaces: ["Moonlit Park"],
                    unresolvedThreads: ["Who lit the lantern?"],
                    episodes: [
                        StoryEpisode(
                            id: UUID(),
                            title: "Episode One",
                            storyId: "story-1",
                            scenes: [
                                StoryScene(sceneId: "1", text: "Scene one", durationSec: 30),
                                StoryScene(sceneId: "2", text: "Scene two", durationSec: 45)
                            ],
                            estimatedDurationSec: 75,
                            engine: nil,
                            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
                        )
                    ],
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_200)
                )
            ],
            childProfiles: [
                ChildProfile(
                    id: UUID(),
                    displayName: "Milo",
                    age: 5,
                    contentSensitivity: .extraGentle,
                    preferredMode: .bedtime
                )
            ],
            activeChildProfileId: nil,
            privacySettings: ParentPrivacySettings(
                saveStoryHistory: true,
                retentionPolicy: .thirtyDays,
                saveRawAudio: false,
                clearTranscriptsAfterSession: true
            )
        )

        let storage = StoryLibraryV2Storage(storageURL: storageURL)
        storage.saveSnapshot(snapshot)

        let reloaded = StoryLibraryV2Storage(storageURL: storageURL).loadSnapshot()
        XCTAssertEqual(reloaded, snapshot)
    }

    func testExistingV1StoreUpgradesToCurrentVersionWithoutReimportingLegacyLibraryDefaults() throws {
        let now = Date()
        let persistedProfile = ChildProfile(
            id: UUID(),
            displayName: "Persisted Explorer",
            age: 6,
            contentSensitivity: .extraGentle,
            preferredMode: .classic
        )
        let persistedSeries = StorySeries(
            id: UUID(),
            childProfileId: persistedProfile.id,
            title: "Persisted Series",
            characterHints: ["Bunny"],
            arcSummary: "Persisted arc",
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Persisted Episode",
                    storyId: "persisted-story",
                    scenes: [StoryScene(sceneId: "1", text: "Persisted scene", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: now
                )
            ],
            createdAt: now,
            updatedAt: now.addingTimeInterval(60)
        )
        let persistedSnapshot = StoryLibraryV2Snapshot(
            migrationVersion: 1,
            series: [persistedSeries],
            childProfiles: [persistedProfile],
            activeChildProfileId: persistedProfile.id,
            privacySettings: .default
        )
        StoryLibraryV2Storage(storageURL: storageURL).saveSnapshot(persistedSnapshot)

        let legacyProfile = ChildProfile(
            id: UUID(),
            displayName: "Legacy Explorer",
            age: 8,
            contentSensitivity: .standard,
            preferredMode: .educational
        )
        defaults.set(try JSONEncoder().encode([legacyProfile]), forKey: "storytime.child.profiles.v1")
        defaults.set(legacyProfile.id.uuidString, forKey: "storytime.active.child.profile.v1")
        defaults.set(Data("bad".utf8), forKey: "storytime.series.library.v1")

        let store = makeStore()

        XCTAssertEqual(store.childProfiles, [persistedProfile])
        XCTAssertEqual(store.activeProfile?.id, persistedProfile.id)
        let reloadedSeries = try XCTUnwrap(store.series.first)
        XCTAssertEqual(reloadedSeries.id, persistedSeries.id)
        XCTAssertEqual(reloadedSeries.childProfileId, persistedSeries.childProfileId)
        XCTAssertEqual(reloadedSeries.title, persistedSeries.title)
        XCTAssertEqual(reloadedSeries.episodes.map(\.storyId), persistedSeries.episodes.map(\.storyId))
        XCTAssertEqual(
            StoryLibraryV2Storage(storageURL: storageURL).loadSnapshot()?.migrationVersion,
            StoryLibraryV2Snapshot.currentMigrationVersion
        )
    }

    func testContinuityMigrationLoadsFromLegacyUserDefaults() async throws {
        let legacyFacts = [
            ContinuityFactRecord(
                id: UUID(),
                seriesId: UUID(),
                storyId: "legacy-story-1",
                text: "Bunny remembers the lantern path.",
                embedding: [0.9, 0.1],
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            ContinuityFactRecord(
                id: UUID(),
                seriesId: UUID(),
                storyId: "legacy-story-2",
                text: "Fox keeps watch at the pond.",
                embedding: [0.2, 0.8],
                updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        ]
        defaults.set(try JSONEncoder().encode(legacyFacts), forKey: "storytime.continuity.memory.v1")

        let memory = ContinuityMemoryStore(userDefaults: defaults, storageURL: storageURL)
        let ranked = await memory.topFactTexts(seriesId: legacyFacts[0].seriesId, queryEmbedding: [1.0, 0.0], limit: 3)

        XCTAssertEqual(ranked, ["Bunny remembers the lantern path."])
        XCTAssertEqual(StoryLibraryV2Storage(storageURL: storageURL).loadContinuityFacts(), legacyFacts)
        XCTAssertNil(defaults.data(forKey: "storytime.continuity.memory.v1"))
    }

    func testContinuityMigrationFallsBackWhenLegacyBlobIsCorrupt() async {
        defaults.set(Data("bad".utf8), forKey: "storytime.continuity.memory.v1")

        let memory = ContinuityMemoryStore(userDefaults: defaults, storageURL: storageURL)
        let ranked = await memory.topFactTexts(seriesId: UUID(), queryEmbedding: [1.0, 0.0], limit: 3)

        XCTAssertEqual(ranked, [])
        XCTAssertEqual(StoryLibraryV2Storage(storageURL: storageURL).loadContinuityFacts(), [])
        XCTAssertNil(defaults.data(forKey: "storytime.continuity.memory.v1"))
    }

    func testContinuityMigrationIsIdempotentAfterRelaunch() async throws {
        let seriesId = UUID()
        let migratedFacts = [
            ContinuityFactRecord(
                id: UUID(),
                seriesId: seriesId,
                storyId: "legacy-story",
                text: "Bunny follows the moonlight map.",
                embedding: [0.9, 0.1],
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ]
        defaults.set(try JSONEncoder().encode(migratedFacts), forKey: "storytime.continuity.memory.v1")

        let firstLaunch = ContinuityMemoryStore(userDefaults: defaults, storageURL: storageURL)
        let firstRanked = await firstLaunch.topFactTexts(seriesId: seriesId, queryEmbedding: [1.0, 0.0], limit: 3)
        XCTAssertEqual(firstRanked, ["Bunny follows the moonlight map."])

        let staleLegacyFacts = [
            ContinuityFactRecord(
                id: UUID(),
                seriesId: seriesId,
                storyId: "stale-legacy-story",
                text: "This stale legacy blob should be ignored.",
                embedding: [1.0, 0.0],
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        ]
        defaults.set(try JSONEncoder().encode(staleLegacyFacts), forKey: "storytime.continuity.memory.v1")

        let relaunched = ContinuityMemoryStore(userDefaults: defaults, storageURL: storageURL)
        let ranked = await relaunched.topFactTexts(seriesId: seriesId, queryEmbedding: [1.0, 0.0], limit: 3)

        XCTAssertEqual(ranked, ["Bunny follows the moonlight map."])
        XCTAssertEqual(StoryLibraryV2Storage(storageURL: storageURL).loadContinuityFacts(), migratedFacts)
        XCTAssertNil(defaults.data(forKey: "storytime.continuity.memory.v1"))
    }

    func testContinuityMemoryStoreRanksPrunesAndClearsFacts() async {
        let memoryDefaults = try! XCTUnwrap(UserDefaults(suiteName: "ContinuityMemoryStoreTests.\(UUID().uuidString)"))
        let memory = ContinuityMemoryStore(userDefaults: memoryDefaults, storageURL: storageURL)
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

        await memory.prune(
            toStoryReferences: Set([
                ContinuityStoryReference(seriesId: seriesId, storyId: "story-2")
            ])
        )
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

    func testContinuityMemoryStorePrunesBySeriesAndStoryProvenance() async {
        let memoryDefaults = try! XCTUnwrap(UserDefaults(suiteName: "ContinuityMemoryStoreProvenance.\(UUID().uuidString)"))
        let memory = ContinuityMemoryStore(userDefaults: memoryDefaults, storageURL: storageURL)
        let firstSeriesId = UUID()
        let secondSeriesId = UUID()
        let sharedStoryId = "shared-story-id"

        await memory.replaceFacts(
            seriesId: firstSeriesId,
            storyId: sharedStoryId,
            texts: ["First series clue"],
            embeddings: [[1.0, 0.0]]
        )
        await memory.replaceFacts(
            seriesId: secondSeriesId,
            storyId: sharedStoryId,
            texts: ["Second series clue"],
            embeddings: [[1.0, 0.0]]
        )

        await memory.prune(
            toStoryReferences: Set([
                ContinuityStoryReference(seriesId: secondSeriesId, storyId: sharedStoryId)
            ])
        )

        let firstSeriesFacts = await memory.factRecords(seriesId: firstSeriesId, storyId: sharedStoryId)
        let secondSeriesFacts = await memory.factRecords(seriesId: secondSeriesId, storyId: sharedStoryId)
        XCTAssertTrue(firstSeriesFacts.isEmpty)
        XCTAssertEqual(secondSeriesFacts.map(\.text), ["Second series clue"])
    }

    func testClearStoryHistoryClearsSharedContinuityMemory() async throws {
        await clearStandardPersistenceKeys()

        let standard = UserDefaults.standard
        let profileId = UUID()
        let seriesId = UUID()
        let storyId = "shared-history-story"
        let seededSeries = StorySeries(
            id: seriesId,
            childProfileId: profileId,
            title: "Lantern Path",
            characterHints: ["Bunny"],
            arcSummary: nil,
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Lantern Path",
                    storyId: storyId,
                    scenes: [StoryScene(sceneId: "1", text: "Lantern glow", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: Date()
                )
            ],
            createdAt: Date(),
            updatedAt: Date()
        )
        standard.set(try JSONEncoder().encode([ChildProfile(
            id: profileId,
            displayName: "Story Explorer",
            age: 5,
            contentSensitivity: .extraGentle,
            preferredMode: .classic
        )]), forKey: "storytime.child.profiles.v1")
        standard.set(profileId.uuidString, forKey: "storytime.active.child.profile.v1")
        standard.set(try JSONEncoder().encode([seededSeries]), forKey: "storytime.series.library.v1")

        let store = makeStandardStore()

        await ContinuityMemoryStore.shared.replaceFacts(
            seriesId: seriesId,
            storyId: storyId,
            texts: ["Bunny keeps the lantern safe."],
            embeddings: [[1.0, 0.0]]
        )
        let initialFacts = await ContinuityMemoryStore.shared.topFactTexts(
            seriesId: seriesId,
            queryEmbedding: [1.0, 0.0],
            limit: 3
        )
        XCTAssertEqual(initialFacts, ["Bunny keeps the lantern safe."])

        store.clearStoryHistory()
        await waitForSharedContinuityCleanup {
            await ContinuityMemoryStore.shared.topFactTexts(seriesId: seriesId, queryEmbedding: [1.0, 0.0], limit: 3).isEmpty
        }

        XCTAssertTrue(store.series.isEmpty)
    }

    func testDeleteSeriesClearsSharedContinuityMemory() async throws {
        await clearStandardPersistenceKeys()

        let standard = UserDefaults.standard
        let profileId = UUID()
        let seriesId = UUID()
        let storyId = "shared-delete-story"
        let seededSeries = StorySeries(
            id: seriesId,
            childProfileId: profileId,
            title: "Garden Gate",
            characterHints: ["Bunny"],
            arcSummary: nil,
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Garden Gate",
                    storyId: storyId,
                    scenes: [StoryScene(sceneId: "1", text: "Garden gate", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: Date()
                )
            ],
            createdAt: Date(),
            updatedAt: Date()
        )
        standard.set(try JSONEncoder().encode([ChildProfile(
            id: profileId,
            displayName: "Story Explorer",
            age: 5,
            contentSensitivity: .extraGentle,
            preferredMode: .classic
        )]), forKey: "storytime.child.profiles.v1")
        standard.set(profileId.uuidString, forKey: "storytime.active.child.profile.v1")
        standard.set(try JSONEncoder().encode([seededSeries]), forKey: "storytime.series.library.v1")

        let store = makeStandardStore()

        await ContinuityMemoryStore.shared.replaceFacts(
            seriesId: seriesId,
            storyId: storyId,
            texts: ["The hidden gate glows at sunset."],
            embeddings: [[1.0, 0.0]]
        )
        let initialFacts = await ContinuityMemoryStore.shared.topFactTexts(
            seriesId: seriesId,
            queryEmbedding: [1.0, 0.0],
            limit: 3
        )
        XCTAssertEqual(initialFacts, ["The hidden gate glows at sunset."])

        store.deleteSeries(seriesId)
        await waitForSharedContinuityCleanup {
            await ContinuityMemoryStore.shared.topFactTexts(seriesId: seriesId, queryEmbedding: [1.0, 0.0], limit: 3).isEmpty
        }

        XCTAssertNil(store.seriesById(seriesId))
    }

    func testRetentionPolicyPrunesSharedContinuityFactsToLibraryStories() async throws {
        await clearStandardPersistenceKeys()

        let standard = UserDefaults.standard

        let profileId = UUID()
        let seriesId = UUID()
        let oldStoryId = "old-library-story"
        let recentStoryId = "recent-library-story"
        let oldEpisodeDate = Calendar.current.date(byAdding: .day, value: -100, to: Date()) ?? .distantPast
        let recentEpisodeDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        let series = StorySeries(
            id: seriesId,
            childProfileId: profileId,
            title: "Lantern Trail",
            characterHints: ["Bunny"],
            arcSummary: nil,
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Old Episode",
                    storyId: oldStoryId,
                    scenes: [StoryScene(sceneId: "1", text: "Old trail", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: oldEpisodeDate
                ),
                StoryEpisode(
                    id: UUID(),
                    title: "Recent Episode",
                    storyId: recentStoryId,
                    scenes: [StoryScene(sceneId: "2", text: "Recent trail", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: recentEpisodeDate
                )
            ],
            createdAt: oldEpisodeDate,
            updatedAt: recentEpisodeDate
        )

        standard.set(try JSONEncoder().encode([ChildProfile(
            id: profileId,
            displayName: "Story Explorer",
            age: 5,
            contentSensitivity: .extraGentle,
            preferredMode: .classic
        )]), forKey: "storytime.child.profiles.v1")
        standard.set(profileId.uuidString, forKey: "storytime.active.child.profile.v1")
        standard.set(try JSONEncoder().encode([series]), forKey: "storytime.series.library.v1")

        await ContinuityMemoryStore.shared.replaceFacts(
            seriesId: seriesId,
            storyId: oldStoryId,
            texts: ["Old lantern clue"],
            embeddings: [[1.0, 0.0]]
        )
        await ContinuityMemoryStore.shared.replaceFacts(
            seriesId: seriesId,
            storyId: recentStoryId,
            texts: ["Recent lantern clue"],
            embeddings: [[1.0, 0.0]]
        )

        let store = makeStandardStore()
        await waitForSharedContinuityCleanup {
            let facts = await ContinuityMemoryStore.shared.topFactTexts(
                seriesId: seriesId,
                queryEmbedding: [1.0, 0.0],
                limit: 5
            )
            return facts == ["Recent lantern clue"]
        }

        let persistedSeries = try XCTUnwrap(store.seriesById(seriesId))
        XCTAssertEqual(persistedSeries.episodes.map(\.storyId), [recentStoryId])

        let reloaded = makeStandardStore()
        let reloadedSeries = try XCTUnwrap(reloaded.seriesById(seriesId))
        XCTAssertEqual(reloadedSeries.episodes.map(\.storyId), [recentStoryId])
    }

    func testRetentionPolicyRebuildsSeriesContinuityMetadataAcrossReload() throws {
        let profileId = UUID()
        let oldEpisodeDate = Calendar.current.date(byAdding: .day, value: -40, to: Date()) ?? .distantPast
        let recentEpisodeDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let oldEngine = makeEngineData(
            characters: ["Bunny", "Fox"],
            places: ["Moonlit Park"],
            relationships: ["Bunny trusts Fox"],
            loops: ["Find the hidden gate"]
        )
        let recentEngine = makeEngineData(
            characters: ["Bunny", "Owl"],
            places: ["Rainbow Brook"],
            relationships: ["Bunny follows Owl"],
            loops: ["A silver bell rings at dusk"]
        )
        let seededSeries = StorySeries(
            id: UUID(),
            childProfileId: profileId,
            title: "Lantern Trail",
            characterHints: ["Bunny", "Fox", "Owl"],
            arcSummary: "Bunny keeps discovering new clues.",
            relationshipFacts: ["Bunny follows Owl", "Bunny trusts Fox"],
            favoritePlaces: ["Moonlit Park", "Rainbow Brook"],
            unresolvedThreads: ["A silver bell rings at dusk", "Find the hidden gate"],
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Old Clue",
                    storyId: "old-clue",
                    scenes: [StoryScene(sceneId: "1", text: "Old clue", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: oldEngine,
                    createdAt: oldEpisodeDate
                ),
                StoryEpisode(
                    id: UUID(),
                    title: "New Clue",
                    storyId: "new-clue",
                    scenes: [StoryScene(sceneId: "2", text: "New clue", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: recentEngine,
                    createdAt: recentEpisodeDate
                )
            ],
            createdAt: oldEpisodeDate,
            updatedAt: recentEpisodeDate
        )

        defaults.set(try JSONEncoder().encode([ChildProfile(
            id: profileId,
            displayName: "Story Explorer",
            age: 5,
            contentSensitivity: .extraGentle,
            preferredMode: .classic
        )]), forKey: "storytime.child.profiles.v1")
        defaults.set(profileId.uuidString, forKey: "storytime.active.child.profile.v1")
        defaults.set(try JSONEncoder().encode([seededSeries]), forKey: "storytime.series.library.v1")

        let store = makeStore()
        store.setRetentionPolicy(.sevenDays)

        let inMemorySeries = try XCTUnwrap(store.seriesById(seededSeries.id))
        XCTAssertEqual(inMemorySeries.episodes.map(\.storyId), ["new-clue"])
        XCTAssertEqual(inMemorySeries.favoritePlaces, ["Rainbow Brook"])
        XCTAssertEqual(inMemorySeries.relationshipFacts, ["Bunny follows Owl"])
        XCTAssertEqual(inMemorySeries.unresolvedThreads, ["A silver bell rings at dusk"])

        let reloaded = makeStore()
        let persistedSeries = try XCTUnwrap(reloaded.seriesById(seededSeries.id))
        XCTAssertEqual(persistedSeries.episodes.map(\.storyId), ["new-clue"])
        XCTAssertEqual(persistedSeries.favoritePlaces, ["Rainbow Brook"])
        XCTAssertEqual(persistedSeries.relationshipFacts, ["Bunny follows Owl"])
        XCTAssertEqual(persistedSeries.unresolvedThreads, ["A silver bell rings at dusk"])
    }

    func testSaveHistoryOffClearsPersistedStoreAndSharedContinuityAcrossReload() async throws {
        await clearStandardPersistenceKeys()

        let store = makeStandardStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let story = makeStoryData(
            storyId: "history-off-story",
            title: "History Off",
            characters: ["Bunny"],
            places: ["Moonlit Park"],
            relationships: ["Bunny follows the lantern"],
            loops: []
        )
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: false,
            lengthMinutes: 3
        )
        let seriesId = try XCTUnwrap(store.addStory(story, characters: ["Bunny"], plan: plan))

        await ContinuityMemoryStore.shared.replaceFacts(
            seriesId: seriesId,
            storyId: story.storyId,
            texts: ["Bunny keeps the lantern close."],
            embeddings: [[1.0, 0.0]]
        )

        store.setSaveStoryHistory(false)
        await waitForSharedContinuityCleanup {
            await ContinuityMemoryStore.shared.topFactTexts(
                seriesId: seriesId,
                queryEmbedding: [1.0, 0.0],
                limit: 3
            ).isEmpty
        }

        let reloaded = makeStandardStore()
        XCTAssertTrue(reloaded.series.isEmpty)
        XCTAssertFalse(reloaded.privacySettings.saveStoryHistory)
        XCTAssertEqual(reloaded.storyHistorySummary, "Story history is off")
        XCTAssertNil(reloaded.addStory(story, characters: ["Bunny"], plan: plan))
    }

    func testDeleteChildProfileClearsOnlyRemovedChildContinuityFacts() async throws {
        await clearStandardPersistenceKeys()

        let standard = UserDefaults.standard
        let primaryProfileId = UUID()
        let secondaryProfileId = UUID()
        let primarySeriesId = UUID()
        let secondarySeriesId = UUID()
        let primaryStoryId = "primary-child-story"
        let secondaryStoryId = "secondary-child-story"

        let primaryProfile = ChildProfile(
            id: primaryProfileId,
            displayName: "Story Explorer",
            age: 5,
            contentSensitivity: .extraGentle,
            preferredMode: .classic
        )
        let secondaryProfile = ChildProfile(
            id: secondaryProfileId,
            displayName: "Nora",
            age: 6,
            contentSensitivity: .standard,
            preferredMode: .classic
        )
        let primarySeries = StorySeries(
            id: primarySeriesId,
            childProfileId: primaryProfileId,
            title: "Pond Path",
            characterHints: ["Bunny"],
            arcSummary: nil,
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Pond Path",
                    storyId: primaryStoryId,
                    scenes: [StoryScene(sceneId: "1", text: "Pond path", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: Date()
                )
            ],
            createdAt: Date(),
            updatedAt: Date()
        )
        let secondarySeries = StorySeries(
            id: secondarySeriesId,
            childProfileId: secondaryProfileId,
            title: "Garden Gate",
            characterHints: ["Fox"],
            arcSummary: nil,
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [
                StoryEpisode(
                    id: UUID(),
                    title: "Garden Gate",
                    storyId: secondaryStoryId,
                    scenes: [StoryScene(sceneId: "1", text: "Garden gate", durationSec: 30)],
                    estimatedDurationSec: 30,
                    engine: nil,
                    createdAt: Date()
                )
            ],
            createdAt: Date(),
            updatedAt: Date()
        )
        standard.set(try JSONEncoder().encode([primaryProfile, secondaryProfile]), forKey: "storytime.child.profiles.v1")
        standard.set(primaryProfileId.uuidString, forKey: "storytime.active.child.profile.v1")
        standard.set(try JSONEncoder().encode([primarySeries, secondarySeries]), forKey: "storytime.series.library.v1")

        let store = makeStandardStore()

        await ContinuityMemoryStore.shared.replaceFacts(
            seriesId: primarySeriesId,
            storyId: primaryStoryId,
            texts: ["Primary child fact"],
            embeddings: [[1.0, 0.0]]
        )
        await ContinuityMemoryStore.shared.replaceFacts(
            seriesId: secondarySeriesId,
            storyId: secondaryStoryId,
            texts: ["Secondary child fact"],
            embeddings: [[1.0, 0.0]]
        )

        store.deleteChildProfile(secondaryProfileId)
        await waitForSharedContinuityCleanup {
            let removedFacts = await ContinuityMemoryStore.shared.topFactTexts(
                seriesId: secondarySeriesId,
                queryEmbedding: [1.0, 0.0],
                limit: 3
            )
            let retainedFacts = await ContinuityMemoryStore.shared.topFactTexts(
                seriesId: primarySeriesId,
                queryEmbedding: [1.0, 0.0],
                limit: 3
            )
            return removedFacts.isEmpty && retainedFacts == ["Primary child fact"]
        }

        XCTAssertNil(store.profileById(secondaryProfileId))
        XCTAssertNil(store.seriesById(secondarySeriesId))
        XCTAssertNotNil(store.seriesById(primarySeriesId))

        let reloaded = makeStandardStore()
        XCTAssertNil(reloaded.profileById(secondaryProfileId))
        XCTAssertNil(reloaded.seriesById(secondarySeriesId))
        XCTAssertNotNil(reloaded.seriesById(primarySeriesId))
        XCTAssertEqual(reloaded.activeProfile?.id, primaryProfileId)
    }

    func testDeletingActiveChildKeepsOtherChildStoriesAndPersistsFallbackSelectionAcrossReload() throws {
        let store = makeStore()
        let originalActiveId = try XCTUnwrap(store.activeProfile?.id)
        store.addChildProfile(name: "Nora", age: 7, sensitivity: .standard, preferredMode: .educational)
        let remainingChildId = try XCTUnwrap(store.childProfiles.first(where: { $0.id != originalActiveId })?.id)

        let originalStory = makeStoryData(
            storyId: "original-active-story",
            title: "Milo's Lantern",
            characters: ["Bunny"],
            places: ["Moonlit Park"],
            relationships: [],
            loops: []
        )
        let remainingStory = makeStoryData(
            storyId: "remaining-child-story",
            title: "Nora's Garden",
            characters: ["Fox"],
            places: ["Hidden Garden"],
            relationships: [],
            loops: []
        )
        let activePlan = StoryLaunchPlan(
            mode: .new,
            childProfileId: originalActiveId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let remainingPlan = StoryLaunchPlan(
            mode: .new,
            childProfileId: remainingChildId,
            experienceMode: .educational,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )

        let deletedSeriesId = try XCTUnwrap(store.addStory(originalStory, characters: ["Bunny"], plan: activePlan))
        let retainedSeriesId = try XCTUnwrap(store.addStory(remainingStory, characters: ["Fox"], plan: remainingPlan))

        store.selectActiveProfile(originalActiveId)
        store.deleteChildProfile(originalActiveId)

        XCTAssertEqual(store.activeProfile?.id, remainingChildId)
        XCTAssertNil(store.profileById(originalActiveId))
        XCTAssertNil(store.seriesById(deletedSeriesId))
        XCTAssertNotNil(store.seriesById(retainedSeriesId))
        XCTAssertEqual(store.visibleSeries.map(\.id), [retainedSeriesId])

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.activeProfile?.id, remainingChildId)
        XCTAssertNil(reloaded.profileById(originalActiveId))
        XCTAssertNil(reloaded.seriesById(deletedSeriesId))
        XCTAssertNotNil(reloaded.seriesById(retainedSeriesId))
        XCTAssertEqual(reloaded.visibleSeries.map(\.id), [retainedSeriesId])
    }

    func testDeletingFinalChildRecreatesFallbackProfileAndClearsStoriesAcrossReload() throws {
        let store = makeStore()
        let deletedProfileId = try XCTUnwrap(store.activeProfile?.id)
        let story = makeStoryData(
            storyId: "final-child-story",
            title: "Last Lantern",
            characters: ["Bunny"],
            places: ["Moonlit Park"],
            relationships: [],
            loops: []
        )
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: deletedProfileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let deletedSeriesId = try XCTUnwrap(store.addStory(story, characters: ["Bunny"], plan: plan))

        store.deleteChildProfile(deletedProfileId)

        let fallbackProfile = try XCTUnwrap(store.activeProfile)
        XCTAssertEqual(store.childProfiles.count, 1)
        XCTAssertEqual(fallbackProfile.displayName, "Story Explorer")
        XCTAssertEqual(store.activeChildProfileId, fallbackProfile.id)
        XCTAssertNil(store.profileById(deletedProfileId))
        XCTAssertNil(store.seriesById(deletedSeriesId))
        XCTAssertTrue(store.visibleSeries.isEmpty)

        let reloaded = makeStore()
        let reloadedFallback = try XCTUnwrap(reloaded.activeProfile)
        XCTAssertEqual(reloaded.childProfiles.count, 1)
        XCTAssertEqual(reloadedFallback.displayName, "Story Explorer")
        XCTAssertEqual(reloaded.activeChildProfileId, reloadedFallback.id)
        XCTAssertNil(reloaded.profileById(deletedProfileId))
        XCTAssertNil(reloaded.seriesById(deletedSeriesId))
        XCTAssertTrue(reloaded.visibleSeries.isEmpty)
    }

    func testAddStoryPreservesImmediateContinuityIndexingAfterSave() async throws {
        await clearStandardPersistenceKeys()

        let store = makeStandardStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let story = makeStoryData(
            storyId: "post-save-index-race-story",
            title: "Lantern Race",
            characters: ["Bunny"],
            places: ["Moonlit Park"],
            relationships: ["Bunny follows the lantern"],
            loops: ["The lantern keeps glowing."]
        )
        let plan = StoryLaunchPlan(
            mode: .new,
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: false,
            lengthMinutes: 3
        )
        let seriesId = try XCTUnwrap(store.addStory(story, characters: ["Bunny"], plan: plan))

        await ContinuityMemoryStore.shared.replaceFacts(
            seriesId: seriesId,
            storyId: story.storyId,
            texts: ["The lantern still glows after sunset."],
            embeddings: [[1.0, 0.0]]
        )
        try? await Task.sleep(nanoseconds: 100_000_000)

        let facts = await ContinuityMemoryStore.shared.topFactTexts(
            seriesId: seriesId,
            queryEmbedding: [1.0, 0.0],
            limit: 3
        )
        XCTAssertEqual(facts, ["The lantern still glows after sunset."])
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

    private func clearStandardPersistenceKeys() async {
        let standard = UserDefaults.standard
        [
            "storytime.series.library.v1",
            "storytime.child.profiles.v1",
            "storytime.active.child.profile.v1",
            "storytime.parent.privacy.v1",
            "storytime.continuity.memory.v1",
            "com.storytime.install-id",
            "com.storytime.session-token",
            "com.storytime.session-expiry",
            "com.storytime.session-region"
        ].forEach { standard.removeObject(forKey: $0) }
        StoryLibraryV2Storage(storageURL: StoryLibraryV2Storage.defaultStorageURL()).clear()
        await ContinuityMemoryStore.shared.clearAll()
    }

    private func waitForSharedContinuityCleanup(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping @Sendable () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(Double(timeoutNanoseconds) / 1_000_000_000)

        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTFail("Condition was not met before timeout", file: file, line: line)
    }
}
