import XCTest
@testable import StoryTime

@MainActor
final class PracticeSessionViewModelTests: XCTestCase {
    override func setUp() async throws {
        let defaults = UserDefaults.standard
        [
            "storytime.series.library.v1",
            "storytime.child.profiles.v1",
            "storytime.active.child.profile.v1",
            "storytime.parent.privacy.v1",
            "storytime.continuity.memory.v1",
            "com.storytime.install-id",
            "com.storytime.session-token",
            "com.storytime.session-expiry"
        ].forEach { defaults.removeObject(forKey: $0) }
        await ContinuityMemoryStore.shared.clearAll()
    }

    func testStartSessionConnectsAndSpeaksOpeningQuestion() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))

        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()

        XCTAssertEqual(api.prepareConnectionCallCount, 1)
        XCTAssertEqual(api.fetchVoicesCallCount, 1)
        XCTAssertEqual(api.createRealtimeSessionCallCount, 1)
        XCTAssertEqual(voice.connectCallCount, 1)
        XCTAssertEqual(viewModel.phase, .gatheringInput)
        XCTAssertEqual(voice.spokenTexts.count, 1)
        XCTAssertTrue(voice.spokenTexts[0].contains("Tell me what kind"))
        XCTAssertEqual(viewModel.statusMessage, "Listening...")
    }

    func testDiscoveryUsesActualTranscriptAndGeneratesStory() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a lost lantern adventure",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "I want Bunny and Fox to find a lantern in the park"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Lantern Trail", sceneCount: 3)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("I want Bunny and Fox to find a lantern in the park")

        await waitUntil { api.generateRequests.count == 1 && viewModel.generatedStory != nil }

        XCTAssertEqual(api.discoveryRequests.first?.transcript, "I want Bunny and Fox to find a lantern in the park")
        XCTAssertEqual(api.generateRequests.first?.storyBrief.theme, "a lost lantern adventure")
        XCTAssertEqual(api.generateRequests.first?.storyBrief.characters, ["Bunny", "Fox"])
        XCTAssertEqual(api.generateRequests.first?.storyBrief.setting, "the moonlit park")
        XCTAssertEqual(api.generateRequests.first?.storyBrief.tone, "cozy, gentle and playful")
        XCTAssertEqual(viewModel.phase, .narrating)
        XCTAssertEqual(viewModel.generatedStory?.title, "Lantern Trail")
    }

    func testInterruptionCancelsAssistantAndRevisesOnlyFutureScenes() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a dragon picnic",
                        characters: ["Bunny", "Dragon"],
                        setting: "the fountain park",
                        tone: "funny",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Bunny and Dragon should have a picnic adventure"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Picnic Clues", sceneCount: 3)
        api.reviseStoryResult = makeRevisedEnvelope()

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1, 2])
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Bunny and Dragon should have a picnic adventure")

        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 1 && voice.spokenTexts.count >= 3 }

        voice.emitUserSpeechChanged(true)
        voice.emitTranscriptFinal("Please make the ending funnier and add a rainbow clue")

        await waitUntil { api.reviseRequests.count == 1 && viewModel.phase == .narrating }

        let reviseRequest = try XCTUnwrap(api.reviseRequests.first)
        XCTAssertEqual(reviseRequest.completedScenes.count, 1)
        XCTAssertEqual(reviseRequest.remainingScenes.count, 2)
        XCTAssertEqual(reviseRequest.userUpdate, "Please make the ending funnier and add a rainbow clue")
        XCTAssertGreaterThanOrEqual(voice.cancelCallCount, 1)
        XCTAssertEqual(viewModel.generatedStory?.scenes[0].sceneId, "1")
        XCTAssertEqual(viewModel.generatedStory?.scenes.count, 3)
    }

    func testOverlappingInterruptionsQueueInsteadOfStartingConcurrentRevisions() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a dragon picnic",
                        characters: ["Bunny", "Dragon"],
                        setting: "the fountain park",
                        tone: "funny",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Bunny and Dragon should have a picnic adventure"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Picnic Clues", sceneCount: 3)
        api.reviseStoryDelayNanoseconds = 250_000_000
        api.reviseStoryResponses = [
            makeRevisedEnvelope(
                scenes: [
                    StoryScene(sceneId: "2", text: "The rainbow clue made Dragon laugh.", durationSec: 25),
                    StoryScene(sceneId: "3", text: "They hugged at home with a happy picnic.", durationSec: 35)
                ]
            ),
            makeRevisedEnvelope(
                scenes: [
                    StoryScene(sceneId: "2", text: "The rainbow clue now led to a moonbeam slide.", durationSec: 25),
                    StoryScene(sceneId: "3", text: "They ended with a cozy song by the fountain.", durationSec: 35)
                ]
            )
        ]

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1, 2])
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Bunny and Dragon should have a picnic adventure")

        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 1 && voice.spokenTexts.count >= 3 }

        voice.emitTranscriptFinal("Add a rainbow clue")
        try? await Task.sleep(nanoseconds: 60_000_000)
        voice.emitTranscriptFinal("Also make it extra cozy")

        await waitUntil { api.reviseRequests.count == 2 && viewModel.phase == .narrating }

        XCTAssertEqual(api.maxConcurrentRevises, 1)
        XCTAssertEqual(api.reviseRequests.map(\.userUpdate), ["Add a rainbow clue", "Also make it extra cozy"])
        XCTAssertTrue(viewModel.generatedStory?.scenes[1].text.contains("moonbeam slide") == true)
    }

    func testBlockedDiscoveryTurnUsesSafeReplyWithoutGenerating() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: true,
                safeMessage: "Let's make it gentle and friendly. What kind of kind adventure should we tell?",
                data: DiscoveryData(
                    slotState: DiscoverySlotState(),
                    questionCount: 1,
                    readyToGenerate: false,
                    assistantMessage: "Ignored fallback",
                    transcript: "Make it scary"
                )
            )
        ]

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1, 2])
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Make it scary")

        await waitUntil { voice.spokenTexts.count >= 2 }

        XCTAssertEqual(api.generateRequests.count, 0)
        XCTAssertEqual(viewModel.phase, .gatheringInput)
        XCTAssertTrue(viewModel.aiPrompt.contains("gentle and friendly"))
    }

    func testPartialAndBlankTranscriptsDoNotTriggerNetworkCalls() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()

        voice.emitTranscriptPartial("Bunny wants")
        voice.emitTranscriptFinal("   ")
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(api.discoveryRequests.count, 0)
        XCTAssertEqual(api.generateRequests.count, 0)
        XCTAssertEqual(viewModel.latestUserTranscript, "Bunny wants")
        XCTAssertEqual(viewModel.phase, .gatheringInput)
    }

    func testConnectionFailureSurfacesError() async throws {
        let api = MockAPIClient()
        api.prepareConnectionError = URLError(.cannotConnectToHost)
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()

        XCTAssertEqual(viewModel.statusMessage, "Connection failed")
        XCTAssertFalse(viewModel.errorMessage.isEmpty)
        XCTAssertEqual(voice.connectCallCount, 0)
    }

    func testMockVoiceCoreJourneyCanProgressWithoutManualTextEntry() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: true
        )

        await viewModel.startSession()
        await viewModel.childDidSpeak()
        await viewModel.childDidSpeak()
        await viewModel.childDidSpeak()

        await waitUntil { viewModel.generatedStory != nil && viewModel.phase == .narrating }

        XCTAssertEqual(api.generateRequests.count, 0)
        XCTAssertEqual(viewModel.generatedStory?.scenes.count, 3)
        XCTAssertEqual(viewModel.statusMessage, "Story ready")
    }

    func testRepeatEpisodeModeReplaysLatestEpisode() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        let store = StoryLibraryStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let basePlan = makePlan(childProfileId: profileId)
        let story = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 2).data
        let seriesId = try XCTUnwrap(store.addStory(story, characters: ["Bunny"], plan: basePlan))
        let series = try XCTUnwrap(store.seriesById(seriesId))
        let repeatPlan = StoryLaunchPlan(
            mode: .repeatEpisode(seriesId: seriesId),
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: true,
            selectedSeriesId: seriesId,
            usePastCharacters: true,
            lengthMinutes: 3
        )

        let viewModel = PracticeSessionViewModel(
            plan: repeatPlan,
            sourceSeries: series,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: true
        )

        await viewModel.startSession()

        XCTAssertEqual(viewModel.phase, .narrating)
        XCTAssertEqual(viewModel.generatedStory?.title, "Moonlight Picnic")
        XCTAssertEqual(viewModel.aiPrompt, "Replaying the latest episode now.")
    }

    func testMockNarrationChildDidSpeakUsesScriptedUpdateRequest() async throws {
        let api = MockAPIClient()
        api.reviseStoryResult = makeRevisedEnvelope(
            scenes: [
                StoryScene(sceneId: "1", text: "Bunny found a glowing clue by the pond.", durationSec: 30),
                StoryScene(sceneId: "2", text: "Fox added a silly parade and everyone laughed.", durationSec: 30)
            ]
        )
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        let store = StoryLibraryStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let basePlan = makePlan(childProfileId: profileId)
        let story = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 2).data
        let seriesId = try XCTUnwrap(store.addStory(story, characters: ["Bunny"], plan: basePlan))
        let series = try XCTUnwrap(store.seriesById(seriesId))
        let repeatPlan = StoryLaunchPlan(
            mode: .repeatEpisode(seriesId: seriesId),
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: true,
            selectedSeriesId: seriesId,
            usePastCharacters: true,
            lengthMinutes: 3
        )

        let viewModel = PracticeSessionViewModel(
            plan: repeatPlan,
            sourceSeries: series,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: true
        )

        await viewModel.startSession()
        await viewModel.childDidSpeak()
        await waitUntil { api.reviseRequests.count == 1 && viewModel.phase == .narrating }

        XCTAssertEqual(api.reviseRequests.first?.userUpdate, "Please add a new clue and a happy rainbow ending to the remaining story.")
        XCTAssertTrue(viewModel.generatedStory?.scenes.last?.text.contains("silly parade") == true)
    }

    func testRepeatEpisodeWithoutSourceSeriesFallsBackCleanly() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        let store = StoryLibraryStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let repeatPlan = StoryLaunchPlan(
            mode: .repeatEpisode(seriesId: UUID()),
            childProfileId: profileId,
            experienceMode: .classic,
            usePastStory: true,
            selectedSeriesId: nil,
            usePastCharacters: true,
            lengthMinutes: 3
        )

        let viewModel = PracticeSessionViewModel(
            plan: repeatPlan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: true
        )

        await viewModel.startSession()

        XCTAssertEqual(viewModel.phase, .completed)
        XCTAssertTrue(viewModel.aiPrompt.contains("couldn't find an episode"))
        XCTAssertNil(viewModel.generatedStory)
    }

    func testExtendModeUsesPreviousRecapAndContinuityEmbeddings() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a star map adventure",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit hill",
                        tone: "calm",
                        episodeIntent: "continue the series with a new episode"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Let's go back to the moonlit hill"
                )
            )
        ]
        api.generateStoryResult = GenerateStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: StoryData(
                storyId: UUID().uuidString,
                title: "Star Map Trail",
                estimatedDurationSec: 120,
                scenes: [
                    StoryScene(sceneId: "1", text: "Bunny found the star map and smiled happily.", durationSec: 40),
                    StoryScene(sceneId: "2", text: "Fox followed the clue to the moonlit hill and cheered.", durationSec: 40),
                    StoryScene(sceneId: "3", text: "They solved the puzzle and walked home calm and happy.", durationSec: 40)
                ],
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: try makeEngineData(
                    episodeRecap: "Bunny and Fox found a glowing map near the lantern tree.",
                    recurringCharacters: ["Bunny", "Fox"],
                    priorEpisodeRecap: "They found a glowing map near the lantern tree.",
                    worldFacts: ["Lantern trees point toward hidden star paths."],
                    openLoops: ["A final star clue points to the hill."],
                    favoritePlaces: ["moonlit hill"],
                    relationshipFacts: ["Bunny and Fox solve clues together."],
                    arcSummary: "They are solving a star-and-lantern mystery.",
                    nextEpisodeHook: "A bright clue waits by the hill.",
                    continuityFacts: ["Lantern trees point toward hidden star paths."],
                    characterBible: [
                        ["name": "Bunny", "role": "main story friend", "traits": ["kind", "curious"]],
                        ["name": "Fox", "role": "returning friend", "traits": ["warm", "helpful"]]
                    ]
                )
            )
        )

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let store = StoryLibraryStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let previousStory = GenerateStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: StoryData(
                storyId: UUID().uuidString,
                title: "Lantern Club",
                estimatedDurationSec: 100,
                scenes: [StoryScene(sceneId: "1", text: "Bunny and Fox found a glowing map beside the lantern tree.", durationSec: 40)],
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: try makeEngineData(
                    episodeRecap: "Bunny and Fox found a glowing map beside the lantern tree.",
                    recurringCharacters: ["Bunny", "Fox"],
                    priorEpisodeRecap: "Bunny and Fox found a glowing map beside the lantern tree.",
                    worldFacts: ["Lantern trees point toward hidden star paths."],
                    openLoops: ["A final star clue points to the hill."],
                    favoritePlaces: ["moonlit hill"],
                    relationshipFacts: ["Bunny and Fox solve clues together."],
                    arcSummary: "They are solving a star-and-lantern mystery.",
                    nextEpisodeHook: "A bright clue waits by the hill.",
                    continuityFacts: ["Open loop: A final star clue points to the hill."],
                    characterBible: [
                        ["name": "Bunny", "role": "main story friend", "traits": ["kind", "curious"]]
                    ]
                )
            )
        ).data
        let basePlan = makePlan(childProfileId: profileId)
        let seriesId = try XCTUnwrap(store.addStory(previousStory, characters: ["Bunny", "Fox"], plan: basePlan))
        let extendPlan = StoryLaunchPlan(
            mode: .extend(seriesId: seriesId),
            childProfileId: profileId,
            experienceMode: .calm,
            usePastStory: true,
            selectedSeriesId: seriesId,
            usePastCharacters: true,
            lengthMinutes: 3
        )

        let viewModel = PracticeSessionViewModel(
            plan: extendPlan,
            sourceSeries: try XCTUnwrap(store.seriesById(seriesId)),
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()

        XCTAssertTrue(voice.spokenTexts.first?.contains("Last time:") == true)

        voice.emitTranscriptFinal("Let's go back to the moonlit hill")

        await waitUntil {
            viewModel.generatedStory != nil &&
            api.generateRequests.count == 1 &&
            api.embeddingInputs.count >= 2
        }

        XCTAssertTrue(api.generateRequests[0].continuityFacts.contains { $0.contains("Open loop:") })
        XCTAssertTrue(api.embeddingInputs[0].first?.contains("moonlit hill") == true)
    }

    func testExtendModeUsesHappyFallbackRecapWhenPreviousSceneIsBlank() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let store = StoryLibraryStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let basePlan = makePlan(childProfileId: profileId)
        let priorStory = GenerateStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: StoryData(
                storyId: UUID().uuidString,
                title: "Sleepy Lantern",
                estimatedDurationSec: 80,
                scenes: [StoryScene(sceneId: "1", text: "   ", durationSec: 40)],
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: nil
            )
        ).data
        let seriesId = try XCTUnwrap(store.addStory(priorStory, characters: ["Bunny"], plan: basePlan))
        let extendPlan = StoryLaunchPlan(
            mode: .extend(seriesId: seriesId),
            childProfileId: profileId,
            experienceMode: .bedtime,
            usePastStory: true,
            selectedSeriesId: seriesId,
            usePastCharacters: true,
            lengthMinutes: 4
        )
        let series = try XCTUnwrap(store.seriesById(seriesId))

        let viewModel = PracticeSessionViewModel(
            plan: extendPlan,
            sourceSeries: series,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: true
        )

        await viewModel.startSession()

        XCTAssertEqual(viewModel.phase, .gatheringInput)
        XCTAssertTrue(viewModel.aiPrompt.contains("ended with a happy moment"))
        XCTAssertTrue(viewModel.aiPrompt.contains("bedtime story"))
    }

    func testPrivacySummaryElseBranchAndMockChildSpeechIdleAreSafe() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        let store = StoryLibraryStore()
        store.setClearTranscriptsAfterSession(false)
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: true
        )

        let initialPrompt = viewModel.aiPrompt
        await viewModel.childDidSpeak()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.aiPrompt, initialPrompt)
        XCTAssertEqual(viewModel.privacySummary, "Live conversation is on. Raw audio is not saved.")
    }

    func testRealtimeCallbacksUpdateSpeakerLevelsAndErrors() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()

        voice.emitTranscriptPartial("Bunny wants")
        await Task.yield()
        XCTAssertEqual(viewModel.latestUserTranscript, "Bunny wants")
        XCTAssertEqual(viewModel.activeSpeaker, .child)

        voice.emitLevels(local: 0.0, remote: 0.09)
        await Task.yield()
        XCTAssertEqual(viewModel.activeSpeaker, .ai)

        voice.emitLevels(local: 0.08, remote: 0.0)
        await Task.yield()
        XCTAssertEqual(viewModel.activeSpeaker, .child)

        voice.emitError("Mic unavailable")
        await Task.yield()
        XCTAssertEqual(viewModel.statusMessage, "Voice session error")
        XCTAssertEqual(viewModel.errorMessage, "Mic unavailable")

        voice.emitDisconnected()
        await Task.yield()
        XCTAssertEqual(viewModel.statusMessage, "Voice session disconnected")
        XCTAssertEqual(viewModel.activeSpeaker, .idle)
    }

    func testDiscoveryAndGenerationFailuresEndSession() async throws {
        let store = StoryLibraryStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)

        do {
            let api = MockAPIClient()
            api.discoveryError = URLError(.badServerResponse)
            let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
            let viewModel = PracticeSessionViewModel(
                plan: makePlan(childProfileId: profileId),
                sourceSeries: nil,
                store: store,
                api: api,
                voiceCore: voice,
                forceMockVoiceCore: false
            )

            await viewModel.startSession()
            voice.emitTranscriptFinal("Tell a bunny story")
            await waitUntil { viewModel.phase == .completed }
            XCTAssertFalse(viewModel.errorMessage.isEmpty)
        }

        do {
            let api = MockAPIClient()
            api.discoveryResponses = [
                DiscoveryEnvelope(
                    blocked: false,
                    safeMessage: nil,
                    data: DiscoveryData(
                        slotState: DiscoverySlotState(
                            theme: "bunny adventure",
                            characters: ["Bunny"],
                            setting: "park",
                            tone: "cozy",
                            episodeIntent: "a happy standalone adventure"
                        ),
                        questionCount: 1,
                        readyToGenerate: true,
                        assistantMessage: "I have enough details now.",
                        transcript: "Tell a bunny story"
                    )
                )
            ]
            api.generateStoryError = URLError(.cannotLoadFromNetwork)
            let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
            let viewModel = PracticeSessionViewModel(
                plan: makePlan(childProfileId: profileId),
                sourceSeries: nil,
                store: store,
                api: api,
                voiceCore: voice,
                forceMockVoiceCore: false
            )

            await viewModel.startSession()
            voice.emitTranscriptFinal("Tell a bunny story")
            await waitUntil { viewModel.phase == .completed }
            XCTAssertEqual(viewModel.activeSpeaker, .idle)
            XCTAssertFalse(viewModel.errorMessage.isEmpty)
        }
    }

    private func makePlan(childProfileId: UUID) -> StoryLaunchPlan {
        StoryLaunchPlan(
            mode: .new,
            childProfileId: childProfileId,
            experienceMode: .classic,
            usePastStory: false,
            selectedSeriesId: nil,
            usePastCharacters: false,
            lengthMinutes: 3
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        pollIntervalNanoseconds: UInt64 = 20_000_000,
        condition: @escaping () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        XCTFail("Condition was not met before timeout", file: file, line: line)
    }

    private func makeGeneratedEnvelope(title: String, sceneCount: Int) -> GenerateStoryEnvelope {
        let scenes = (1...sceneCount).map { index in
            StoryScene(sceneId: "\(index)", text: "Scene \(index) ends with a happy smile.", durationSec: 40)
        }

        return GenerateStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: StoryData(
                storyId: UUID().uuidString,
                title: title,
                estimatedDurationSec: 120,
                scenes: scenes,
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: nil
            )
        )
    }

    private func makeRevisedEnvelope() -> ReviseStoryEnvelope {
        makeRevisedEnvelope(
            scenes: [
                StoryScene(sceneId: "2", text: "The rainbow clue made Dragon laugh.", durationSec: 25),
                StoryScene(sceneId: "3", text: "They hugged at home with a happy picnic.", durationSec: 35)
            ]
        )
    }

    private func makeRevisedEnvelope(scenes: [StoryScene]) -> ReviseStoryEnvelope {
        ReviseStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: RevisedStoryData(
                storyId: UUID().uuidString,
                revisedFromSceneIndex: 1,
                scenes: scenes,
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: nil
            )
        )
    }

    private func makeEngineData(
        episodeRecap: String,
        recurringCharacters: [String],
        priorEpisodeRecap: String,
        worldFacts: [String],
        openLoops: [String],
        favoritePlaces: [String],
        relationshipFacts: [String],
        arcSummary: String,
        nextEpisodeHook: String,
        continuityFacts: [String],
        characterBible: [[String: Any]]
    ) throws -> StoryEngineData {
        let payload: [String: Any] = [
            "episode_recap": episodeRecap,
            "series_memory": [
                "title": "Lantern Club",
                "recurring_characters": recurringCharacters,
                "prior_episode_recap": priorEpisodeRecap,
                "world_facts": worldFacts,
                "open_loops": openLoops,
                "favorite_places": favoritePlaces,
                "relationship_facts": relationshipFacts,
                "arc_summary": arcSummary,
                "next_episode_hook": nextEpisodeHook
            ],
            "character_bible": characterBible,
            "beat_plan": [],
            "continuity_facts": continuityFacts
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(StoryEngineData.self, from: data)
    }
}

final class MockAPIClient: APIClienting {
    var prepareConnectionCallCount = 0
    var fetchVoicesCallCount = 0
    var createRealtimeSessionCallCount = 0
    var discoveryRequests: [DiscoveryRequest] = []
    var generateRequests: [GenerateStoryRequest] = []
    var reviseRequests: [ReviseStoryRequest] = []
    var embeddingInputs: [[String]] = []

    var prepareConnectionError: Error?
    var discoveryError: Error?
    var generateStoryError: Error?
    var reviseStoryError: Error?
    var embeddingsError: Error?
    var reviseStoryDelayNanoseconds: UInt64 = 0
    var maxConcurrentRevises = 0
    private var inFlightRevises = 0
    var voices = ["alloy"]
    var realtimeSessionResult = RealtimeSessionEnvelope(
        session: RealtimeSessionData(
            ticket: "ticket",
            expiresAt: 123,
            model: "gpt-realtime",
            voice: "alloy",
            inputAudioTranscriptionModel: "gpt-4o-mini-transcribe"
        ),
        transport: "webrtc",
        endpoint: "/v1/realtime/call"
    )
    var discoveryResponses: [DiscoveryEnvelope] = []
    var generateStoryResult = GenerateStoryEnvelope(
        blocked: false,
        safeMessage: nil,
        data: StoryData(
            storyId: UUID().uuidString,
            title: "Default Story",
            estimatedDurationSec: 120,
            scenes: [StoryScene(sceneId: "1", text: "A happy scene.", durationSec: 40)],
            safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
            engine: nil
        )
    )
    var reviseStoryResult = ReviseStoryEnvelope(
        blocked: false,
        safeMessage: nil,
        data: RevisedStoryData(
            storyId: UUID().uuidString,
            revisedFromSceneIndex: 0,
            scenes: [StoryScene(sceneId: "1", text: "A revised happy scene.", durationSec: 40)],
            safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
            engine: nil
        )
    )
    var reviseStoryResponses: [ReviseStoryEnvelope] = []
    var embeddingsResult: [[Double]] = [[0.1, 0.2, 0.3]]

    func prepareConnection() async throws -> URL {
        prepareConnectionCallCount += 1
        if let prepareConnectionError {
            throw prepareConnectionError
        }
        return URL(string: "https://backend.example.com")!
    }

    func fetchVoices() async throws -> [String] {
        fetchVoicesCallCount += 1
        return voices
    }

    func createRealtimeSession(request body: RealtimeSessionRequest) async throws -> RealtimeSessionEnvelope {
        createRealtimeSessionCallCount += 1
        return realtimeSessionResult
    }

    func discoverStoryTurn(request body: DiscoveryRequest) async throws -> DiscoveryEnvelope {
        discoveryRequests.append(body)
        if let discoveryError {
            throw discoveryError
        }
        if !discoveryResponses.isEmpty {
            return discoveryResponses.removeFirst()
        }
        return DiscoveryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: DiscoveryData(
                slotState: body.slotState,
                questionCount: body.questionCount + 1,
                readyToGenerate: false,
                assistantMessage: "Who should be in the story?",
                transcript: body.transcript
            )
        )
    }

    func generateStory(request body: GenerateStoryRequest) async throws -> GenerateStoryEnvelope {
        generateRequests.append(body)
        if let generateStoryError {
            throw generateStoryError
        }
        return generateStoryResult
    }

    func reviseStory(request body: ReviseStoryRequest) async throws -> ReviseStoryEnvelope {
        reviseRequests.append(body)
        inFlightRevises += 1
        maxConcurrentRevises = max(maxConcurrentRevises, inFlightRevises)
        defer { inFlightRevises -= 1 }
        if let reviseStoryError {
            throw reviseStoryError
        }
        if reviseStoryDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: reviseStoryDelayNanoseconds)
        }
        if !reviseStoryResponses.isEmpty {
            return reviseStoryResponses.removeFirst()
        }
        return reviseStoryResult
    }

    func createEmbeddings(inputs: [String]) async throws -> [[Double]] {
        embeddingInputs.append(inputs)
        if let embeddingsError {
            throw embeddingsError
        }
        return Array(repeating: embeddingsResult.first ?? [0.1, 0.2, 0.3], count: inputs.count)
    }
}

@MainActor
final class MockRealtimeVoiceCore: RealtimeVoiceControlling {
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onTranscriptPartial: ((String) -> Void)?
    var onTranscriptFinal: ((String) -> Void)?
    var onLevels: ((CGFloat, CGFloat) -> Void)?
    var onUserSpeechChanged: ((Bool) -> Void)?
    var onAssistantResponseCompleted: (() -> Void)?
    var onError: ((String) -> Void)?

    private let autoCompleteSpeakIndices: Set<Int>

    private(set) var connectCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var disconnectCallCount = 0
    private(set) var spokenTexts: [String] = []

    init(autoCompleteSpeakIndices: Set<Int>) {
        self.autoCompleteSpeakIndices = autoCompleteSpeakIndices
    }

    func connect(baseURL: URL, endpointPath: String, session: RealtimeSessionData, installId: String) async throws {
        connectCallCount += 1
        onConnected?()
    }

    func speak(text: String) async {
        spokenTexts.append(text)
        if autoCompleteSpeakIndices.contains(spokenTexts.count) {
            onAssistantResponseCompleted?()
        }
    }

    func cancelAssistantSpeech() async {
        cancelCallCount += 1
    }

    func disconnect() async {
        disconnectCallCount += 1
        onDisconnected?()
    }

    func emitTranscriptFinal(_ text: String) {
        onTranscriptFinal?(text)
    }

    func emitTranscriptPartial(_ text: String) {
        onTranscriptPartial?(text)
    }

    func emitLevels(local: CGFloat, remote: CGFloat) {
        onLevels?(local, remote)
    }

    func emitUserSpeechChanged(_ speaking: Bool) {
        onUserSpeechChanged?(speaking)
    }

    func emitError(_ message: String) {
        onError?(message)
    }

    func emitDisconnected() {
        onDisconnected?()
    }
}
