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
            "com.storytime.session-expiry",
            "com.storytime.session-id",
            "com.storytime.session-region"
        ].forEach { defaults.removeObject(forKey: $0) }
        StoryLibraryV2Storage(storageURL: StoryLibraryV2Storage.defaultStorageURL()).clear()
        StartupURLProtocolStub.reset()
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
        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertEqual(voice.spokenTexts.count, 1)
        XCTAssertTrue(voice.spokenTexts[0].contains("Tell me what kind"))
        XCTAssertEqual(viewModel.statusMessage, "Listening...")
        XCTAssertEqual(
            viewModel.sessionCue,
            PracticeSessionViewModel.SessionCue(
                title: "Listening",
                detail: "Answer live question 1 of 3 so StoryTime can build the story.",
                actionHint: "Speak your answer now.",
                tone: .listening
            )
        )
    }

    func testStartSessionWithRealAPIClientExecutesFullStartupContractSequence() async throws {
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let session = makeStartupSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var requestPaths: [String] = []

        StartupURLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            requestPaths.append(url.path)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-install-id"), "install-startup")

            switch url.path {
            case "/health":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-session"))
                return try Self.startupHTTPResponse(url: url, statusCode: 200, json: ["ok": true])

            case "/v1/session/identity":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-session"))
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-startup-1"],
                    headers: [
                        "x-storytime-session": "startup-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )

            case "/v1/voices":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "startup-session-token")
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: ["language": "en", "voices": ["alloy", "verse"]]
                )

            case "/v1/realtime/session":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "startup-session-token")
                let body = try Self.startupRequestBody(from: request)
                let payload = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: body) as? [String: Any]
                )
                XCTAssertEqual(payload["child_profile_id"] as? String, plan.childProfileId.uuidString)
                XCTAssertEqual(payload["voice"] as? String, "alloy")
                XCTAssertEqual(payload["region"] as? String, "US")
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-startup",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )

            default:
                XCTFail("Unexpected startup request: \(url.absoluteString)")
                return try Self.startupHTTPResponse(url: url, statusCode: 500, json: ["error": "unexpected"])
            }
        }

        let api = APIClient(baseURLs: [baseURL], session: session, installId: "install-startup")
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()

        XCTAssertEqual(
            requestPaths,
            ["/health", "/v1/session/identity", "/v1/voices", "/v1/realtime/session"]
        )
        XCTAssertEqual(voice.connectCallCount, 1)
        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertEqual(viewModel.statusMessage, "Listening...")
        XCTAssertEqual(viewModel.voices, ["alloy", "verse"])
        XCTAssertEqual(viewModel.selectedVoice, "alloy")
        XCTAssertEqual(voice.spokenTexts.count, 1)
        XCTAssertTrue(try XCTUnwrap(voice.spokenTexts.first).contains("Tell me what kind"))
    }

    func testStartSessionUsesResolvedBackendRegionDuringRealtimeStartup() async throws {
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let session = makeStartupSession()
        let baseURL = URL(string: "https://backend.example.com/")!

        StartupURLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)

            switch url.path {
            case "/health":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-region"))
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "ok": true,
                        "default_region": "EU",
                        "allowed_regions": ["US", "EU"]
                    ]
                )

            case "/v1/session/identity":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-region"), "EU")
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-session"))
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "session-region-1", "region": "EU"],
                    headers: [
                        "x-storytime-region": "EU",
                        "x-storytime-session": "region-session-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )

            case "/v1/voices":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-region"), "EU")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "region-session-token")
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: ["language": "en", "voices": ["alloy", "verse"], "regions": ["US", "EU"]]
                )

            case "/v1/realtime/session":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-region"), "EU")
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "region-session-token")
                let body = try Self.startupRequestBody(from: request)
                let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(payload["region"] as? String, "EU")
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-region",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )

            default:
                XCTFail("Unexpected startup request: \(url.absoluteString)")
                return try Self.startupHTTPResponse(url: url, statusCode: 500, json: ["error": "unexpected"])
            }
        }

        let api = APIClient(baseURLs: [baseURL], session: session, installId: "install-startup")
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()

        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertEqual(api.resolvedRegion, .eu)
        XCTAssertEqual(AppSession.currentRegion, .eu)
        XCTAssertEqual(voice.connectCallCount, 1)
    }

    func testStartSessionRefreshesStaleSessionTokenBeforeRealtimeStartupFails() async throws {
        let defaults = UserDefaults.standard
        defaults.set("stale-startup-token", forKey: "com.storytime.session-token")
        defaults.set(Date().addingTimeInterval(300).timeIntervalSince1970, forKey: "com.storytime.session-expiry")
        defaults.set("stale-startup-session", forKey: "com.storytime.session-id")

        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let session = makeStartupSession()
        let baseURL = URL(string: "https://backend.example.com/")!
        var requestPaths: [String] = []
        var realtimeAttempts = 0

        StartupURLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            requestPaths.append(url.path)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-install-id"), "install-startup")

            switch url.path {
            case "/health":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "stale-startup-token")
                return try Self.startupHTTPResponse(url: url, statusCode: 200, json: ["ok": true])

            case "/v1/voices":
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "stale-startup-token")
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: ["language": "en", "voices": ["alloy", "verse"]]
                )

            case "/v1/realtime/session":
                realtimeAttempts += 1
                if realtimeAttempts == 1 {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "stale-startup-token")
                    return try Self.startupHTTPResponse(
                        url: url,
                        statusCode: 401,
                        json: [
                            "error": "invalid_session_token",
                            "message": "Invalid signed token",
                            "request_id": "req-startup-stale"
                        ]
                    )
                }

                XCTAssertEqual(request.value(forHTTPHeaderField: "x-storytime-session"), "fresh-startup-token")
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: [
                        "session": [
                            "ticket": "ticket-startup-refresh",
                            "expires_at": 120,
                            "model": "gpt-realtime",
                            "voice": "alloy",
                            "input_audio_transcription_model": "gpt-4o-mini-transcribe"
                        ],
                        "transport": "webrtc",
                        "endpoint": "/v1/realtime/call"
                    ]
                )

            case "/v1/session/identity":
                XCTAssertNil(request.value(forHTTPHeaderField: "x-storytime-session"))
                return try Self.startupHTTPResponse(
                    url: url,
                    statusCode: 200,
                    json: ["session_id": "fresh-startup-session"],
                    headers: [
                        "x-storytime-session": "fresh-startup-token",
                        "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970)
                    ]
                )

            default:
                XCTFail("Unexpected startup request: \(url.absoluteString)")
                return try Self.startupHTTPResponse(url: url, statusCode: 500, json: ["error": "unexpected"])
            }
        }

        let api = APIClient(baseURLs: [baseURL], session: session, installId: "install-startup")
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()

        XCTAssertEqual(
            requestPaths,
            ["/health", "/v1/voices", "/v1/realtime/session", "/v1/session/identity", "/v1/realtime/session"]
        )
        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertEqual(viewModel.statusMessage, "Listening...")
        XCTAssertEqual(voice.connectCallCount, 1)
        XCTAssertEqual(AppSession.currentToken, "fresh-startup-token")
        XCTAssertEqual(AppSession.currentSessionId, "fresh-startup-session")
    }

    func testTraceEventsCaptureSessionLifecycleWithRequestAndSessionCorrelation() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a lantern parade",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit meadow",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a lantern parade story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Lantern Parade", sceneCount: 3)
        api.reviseStoryResult = makeRevisedEnvelope(
            scenes: [
                StoryScene(
                    sceneId: "2",
                    text: "Bunny and Fox added a rainbow lantern to the middle of the parade.",
                    durationSec: 1
                ),
                StoryScene(
                    sceneId: "3",
                    text: "The rainbow lantern glowed as the parade reached the moonlit gate.",
                    durationSec: 1
                )
            ],
            revisedFromSceneIndex: 2
        )

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true, true], playDelayNanoseconds: 250_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a lantern parade story")
        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 1 && api.generateRequests.count == 1 }

        voice.emitUserSpeechChanged(true)
        voice.emitTranscriptFinal("Please add a rainbow lantern")
        await waitUntil {
            viewModel.phase == .completed &&
            api.reviseRequests.count == 1 &&
            viewModel.traceEvents.contains { $0.kind == .revision }
        }

        XCTAssertEqual(viewModel.traceEvents.map(\.kind), [.startup, .discovery, .generation, .revision, .completion])
        XCTAssertEqual(viewModel.traceEvents.map(\.source), ["connected", "readyToGenerate", "resolved", "resolved", "completed"])
        XCTAssertEqual(viewModel.traceEvents.map(\.apiOperation), [.realtimeSession, .storyDiscovery, .storyGeneration, .storyRevision, nil])
        XCTAssertTrue(viewModel.traceEvents.dropLast().allSatisfy { $0.requestId?.hasPrefix("mock-") == true })
        XCTAssertTrue(viewModel.traceEvents.allSatisfy { $0.sessionId == "mock-session-123" })
        XCTAssertTrue(viewModel.traceEvents.allSatisfy { !$0.source.contains("lantern parade") })
        XCTAssertTrue(viewModel.traceEvents.allSatisfy { !$0.source.contains("rainbow lantern") })
        XCTAssertTrue(
            viewModel.runtimeTelemetryEvents.contains {
                $0.stage == .discovery &&
                $0.stageGroup == .interaction &&
                $0.apiOperation == .storyDiscovery &&
                $0.costDriver == .remoteModel
            }
        )
        XCTAssertTrue(
            viewModel.runtimeTelemetryEvents.contains {
                $0.stage == .storyGeneration &&
                $0.stageGroup == .generation &&
                $0.apiOperation == .storyGeneration &&
                $0.costDriver == .remoteModel
            }
        )
        XCTAssertTrue(
            viewModel.runtimeTelemetryEvents.contains {
                $0.stage == .reviseFutureScenes &&
                $0.stageGroup == .revision &&
                $0.apiOperation == .storyRevision &&
                $0.costDriver == .remoteModel
            }
        )
        XCTAssertTrue(viewModel.runtimeTelemetryEvents.allSatisfy { !$0.source.contains("lantern parade") })
        XCTAssertTrue(viewModel.runtimeTelemetryEvents.allSatisfy { !$0.source.contains("rainbow lantern") })
        XCTAssertFalse(
            viewModel.invalidTransitionMessages.contains {
                $0.contains("Revision index mismatch.")
            }
        )
    }

    func testCriticalPathAcceptanceHappyPathExercisesFullCoordinatorLifecycle() async throws {
        let result = try await runCriticalPathHappyPathAcceptance()

        XCTAssertEqual(result.api.prepareConnectionCallCount, 1)
        XCTAssertEqual(result.api.fetchVoicesCallCount, 1)
        XCTAssertEqual(result.api.createRealtimeSessionCallCount, 1)
        XCTAssertEqual(result.api.discoveryRequests.count, 1)
        XCTAssertEqual(result.api.generateRequests.count, 1)
        XCTAssertEqual(result.api.reviseRequests.count, 1)
        XCTAssertEqual(result.voice.connectCallCount, 1)
        XCTAssertEqual(result.voice.cancelCallCount, 1)
        XCTAssertEqual(result.viewModel.phase, .completed)
        XCTAssertNil(result.viewModel.lastAppError)
        XCTAssertEqual(result.viewModel.errorMessage, "")
        XCTAssertEqual(
            result.viewModel.traceEvents.map(\.kind),
            [.startup, .discovery, .generation, .revision, .completion]
        )
        XCTAssertTrue(result.voice.spokenTexts.contains(result.revisedScenes[0].text))
        XCTAssertTrue(result.voice.spokenTexts.contains(result.revisedScenes[1].text))

        let reviseRequest = try XCTUnwrap(result.api.reviseRequests.first)
        XCTAssertEqual(reviseRequest.completedScenes.count, 1)
        XCTAssertEqual(reviseRequest.remainingScenes.count, 2)
        XCTAssertEqual(reviseRequest.userUpdate, result.revisionText)
    }

    func testCriticalPathAcceptanceHappyPathPersistsRevisedStoryAcrossReload() async throws {
        let result = try await runCriticalPathHappyPathAcceptance()

        XCTAssertEqual(result.store.series.count, 1)
        XCTAssertEqual(result.savedSeries.childProfileId, result.plan.childProfileId)
        XCTAssertEqual(result.savedSeries.episodes.count, 1)
        XCTAssertEqual(result.savedSeries.latestEpisode?.title, "Picnic Clues")
        XCTAssertEqual(result.savedSeries.latestEpisode?.scenes.map(\.text), result.expectedSceneTexts)

        let reloadedStore = StoryLibraryStore()
        reloadedStore.selectActiveProfile(result.plan.childProfileId)
        let reloadedSeries = try XCTUnwrap(reloadedStore.seriesById(result.savedSeries.id))

        XCTAssertEqual(reloadedStore.visibleSeries.map(\.id), [result.savedSeries.id])
        XCTAssertEqual(reloadedSeries.childProfileId, result.plan.childProfileId)
        XCTAssertEqual(reloadedSeries.latestEpisode?.title, "Picnic Clues")
        XCTAssertEqual(reloadedSeries.latestEpisode?.scenes.map(\.text), result.expectedSceneTexts)
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

    func testCanonicalSessionStateProgressionStaysAlignedWithDerivedPhase() async throws {
        let api = MockAPIClient()
        api.discoveryDelayNanoseconds = 120_000_000
        api.generateStoryDelayNanoseconds = 120_000_000
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a lantern race",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a lantern race story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Lantern Race", sceneCount: 2)

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
        XCTAssertEqual(viewModel.sessionState, .ready(VoiceSessionReadyState(mode: .discovery(stepNumber: 1))))
        XCTAssertEqual(viewModel.phase, .ready)

        voice.emitTranscriptFinal("Tell a lantern race story")

        await waitUntil {
            if case .discovering = viewModel.sessionState {
                return true
            }
            return false
        }
        XCTAssertEqual(viewModel.phase, .discovering)

        await waitUntil {
            if case .generating = viewModel.sessionState {
                return true
            }
            return false
        }
        XCTAssertEqual(viewModel.phase, .generating)

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return true
            }
            return false
        }
        XCTAssertEqual(viewModel.phase, .narrating)
        XCTAssertEqual(viewModel.currentSceneIndex, 0)
    }

    func testGenerationDoesNotStartUntilDiscoveryResolves() async throws {
        let api = MockAPIClient()
        api.discoveryDelayNanoseconds = 250_000_000
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a lantern race",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a lantern race story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Lantern Race", sceneCount: 2)

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
        voice.emitTranscriptFinal("Tell a lantern race story")

        await waitUntil {
            if case .discovering = viewModel.sessionState {
                return true
            }
            return false
        }

        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(api.discoveryRequests.count, 1)
        XCTAssertEqual(api.generateRequests.count, 0)
        XCTAssertEqual(viewModel.phase, .discovering)

        await waitUntil { api.generateRequests.count == 1 && viewModel.generatedStory != nil }

        XCTAssertEqual(viewModel.phase, .narrating)
        XCTAssertEqual(viewModel.generatedStory?.title, "Lantern Race")
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
        api.reviseStoryResult = makeRevisedEnvelope(
            scenes: [
                StoryScene(sceneId: "3", text: "The rainbow clue led Bunny and Dragon home laughing.", durationSec: 35)
            ],
            revisedFromSceneIndex: 2
        )

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
        XCTAssertEqual(reviseRequest.currentSceneIndex, 2)
        XCTAssertEqual(reviseRequest.completedScenes.count, 2)
        XCTAssertEqual(reviseRequest.completedScenes.map(\.sceneId), ["1", "2"])
        XCTAssertEqual(reviseRequest.remainingScenes.count, 1)
        XCTAssertEqual(reviseRequest.remainingScenes.map(\.sceneId), ["3"])
        XCTAssertEqual(reviseRequest.userUpdate, "Please make the ending funnier and add a rainbow clue")
        XCTAssertEqual(viewModel.interruptionRouteDecision?.intent, .reviseFutureScenes)
        XCTAssertEqual(voice.cancelCallCount, 1)
        XCTAssertEqual(viewModel.generatedStory?.scenes.map(\.sceneId), ["1", "2", "3"])
        XCTAssertEqual(viewModel.generatedStory?.scenes[1].text, "Scene 2 ends with a happy smile.")
        XCTAssertEqual(viewModel.generatedStory?.scenes[2].text, "The rainbow clue led Bunny and Dragon home laughing.")
        XCTAssertEqual(viewModel.generatedStory?.scenes.count, 3)
    }

    func testInterruptionQuestionDoesNotBlindlyStartRevision() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a lantern picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a lantern picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Lantern Picnic", sceneCount: 3)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1, 2])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true, true], playDelayNanoseconds: 250_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a lantern picnic story")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        voice.emitUserSpeechChanged(true)
        await waitUntil { viewModel.sessionState == .interrupting(sceneIndex: 0) }

        voice.emitTranscriptFinal("Why is Bunny carrying the lantern?")

        await waitUntil {
            viewModel.interruptionRouteDecision?.intent == .answerOnly
                && viewModel.phase == .narrating
                && viewModel.currentSceneIndex == 0
                && narrationTransport.playedUtteranceIDs.count == 2
        }

        XCTAssertEqual(api.reviseRequests.count, 0)
        XCTAssertEqual(viewModel.interruptionRouteDecision?.canApplyImmediately, true)
        XCTAssertEqual(viewModel.statusMessage, "Narrating scene 1 of 3")
        XCTAssertEqual(viewModel.currentSceneIndex, 0)
        XCTAssertEqual(viewModel.generatedStory?.scenes.map(\.sceneId), ["1", "2", "3"])
        XCTAssertEqual(voice.spokenTexts.count, 2)
        XCTAssertTrue(try XCTUnwrap(voice.spokenTexts.last).contains("Right now in Lantern Picnic"))
        XCTAssertTrue(
            viewModel.runtimeTelemetryEvents.contains {
                $0.stage == .answerOnlyInteraction &&
                $0.stageGroup == .interaction &&
                $0.costDriver == .realtimeInteraction &&
                $0.durationMs >= 0
            }
        )
        XCTAssertTrue(viewModel.runtimeTelemetryEvents.allSatisfy { !$0.source.contains("Why is Bunny carrying the lantern?") })
    }

    func testNarrationPreloadsUpcomingSceneAndUsesPreparedCacheOnBoundaryAdvance() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moonlight picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moonlight picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 2)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true], playDelayNanoseconds: 150_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a moonlight picnic story")

        await waitUntil { viewModel.phase == .completed }

        let generatedStory = try XCTUnwrap(viewModel.generatedStory)
        let firstSceneKey = PreparedNarrationScene(
            sceneId: generatedStory.scenes[0].sceneId,
            text: generatedStory.scenes[0].text,
            estimatedDurationSec: generatedStory.scenes[0].durationSec
        ).cacheKey
        let secondSceneKey = PreparedNarrationScene(
            sceneId: generatedStory.scenes[1].sceneId,
            text: generatedStory.scenes[1].text,
            estimatedDurationSec: generatedStory.scenes[1].durationSec
        ).cacheKey

        XCTAssertTrue(narrationTransport.playedCacheMissKeys.contains(firstSceneKey))
        XCTAssertTrue(narrationTransport.prepareCallKeys.contains(secondSceneKey))
        XCTAssertTrue(narrationTransport.playedCacheHitKeys.contains(secondSceneKey))
        XCTAssertTrue(
            viewModel.runtimeTelemetryEvents.contains {
                $0.stage == .ttsGeneration &&
                $0.stageGroup == .narration &&
                $0.source == "preload" &&
                $0.costDriver == .localSpeech
            }
        )
    }

    func testRepeatOrClarifyReplaysCurrentSceneBoundaryWithoutRevision() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a lantern picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a lantern picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Lantern Picnic", sceneCount: 2)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true, true], playDelayNanoseconds: 250_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a lantern picnic story")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        let firstSceneText = narrationTransport.playedTexts.first

        voice.emitUserSpeechChanged(true)
        await waitUntil { viewModel.sessionState == .interrupting(sceneIndex: 0) }
        voice.emitTranscriptFinal("Can you repeat that?")

        await waitUntil {
            viewModel.interruptionRouteDecision?.intent == .repeatOrClarify
                && viewModel.phase == .narrating
                && viewModel.currentSceneIndex == 0
                && narrationTransport.playedUtteranceIDs.count == 2
        }

        XCTAssertEqual(api.reviseRequests.count, 0)
        XCTAssertEqual(viewModel.statusMessage, "Narrating scene 1 of 2")
        XCTAssertEqual(narrationTransport.playedTexts, [firstSceneText, firstSceneText].compactMap { $0 })
    }

    func testInterruptionRevisionWithoutFutureScenesStaysWaiting() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moon beam ride",
                        characters: ["Bunny"],
                        setting: "the sleepy sky",
                        tone: "gentle",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moon beam ride story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moon Beam Ride", sceneCount: 1)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true], playDelayNanoseconds: 250_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a moon beam ride story")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        voice.emitUserSpeechChanged(true)
        await waitUntil { viewModel.sessionState == .interrupting(sceneIndex: 0) }

        voice.emitTranscriptFinal("Change what happens next so Bunny rides a comet home.")

        await waitUntil {
            viewModel.interruptionRouteDecision?.intent == .reviseFutureScenes
                && viewModel.interruptionRouteDecision?.canApplyImmediately == false
        }

        XCTAssertEqual(api.reviseRequests.count, 0)
        XCTAssertEqual(viewModel.sessionState, .interrupting(sceneIndex: 0))
        XCTAssertEqual(viewModel.statusMessage, "No future scenes left to change")
    }

    func testPausedNarrationHandsOffToInteractionWithoutReconnect() async throws {
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
        api.reviseStoryResult = makeRevisedEnvelope(
            scenes: [
                StoryScene(sceneId: "3", text: "The rainbow clue made Dragon laugh at the final gate.", durationSec: 35)
            ],
            revisedFromSceneIndex: 2
        )

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true, true], playDelayNanoseconds: 250_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Bunny and Dragon should have a picnic adventure")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        viewModel.pauseNarration()
        XCTAssertEqual(viewModel.sessionState, .paused(sceneIndex: 0))

        voice.emitUserSpeechChanged(true)

        await waitUntil { viewModel.sessionState == .interrupting(sceneIndex: 0) }

        XCTAssertEqual(voice.connectCallCount, 1)
        XCTAssertGreaterThanOrEqual(narrationTransport.stopCallCount, 1)
        XCTAssertEqual(viewModel.currentSceneIndex, 0)
        XCTAssertEqual(viewModel.statusMessage, "Listening for a story update")

        voice.emitTranscriptFinal("Please make the ending funnier and add a rainbow clue")

        await waitUntil { api.reviseRequests.count == 1 && viewModel.phase == .narrating }

        XCTAssertEqual(voice.connectCallCount, 1)
    }

    func testPausedNarrationTranscriptFinalStartsInteractionHandoffDirectly() async throws {
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

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true, true], playDelayNanoseconds: 250_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Bunny and Dragon should have a picnic adventure")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        viewModel.pauseNarration()
        XCTAssertEqual(viewModel.sessionState, .paused(sceneIndex: 0))

        voice.emitTranscriptFinal("Please make the ending sillier")

        await waitUntil { api.reviseRequests.count == 1 && viewModel.phase == .narrating }

        XCTAssertEqual(voice.connectCallCount, 1)
        XCTAssertGreaterThanOrEqual(narrationTransport.stopCallCount, 1)
        XCTAssertEqual(api.reviseRequests.first?.userUpdate, "Please make the ending sillier")
    }

    func testPauseAndResumeNarrationPreservesSceneOwnership() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moonlight picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moonlight picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 2)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true], playDelayNanoseconds: 200_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a moonlight picnic story")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        viewModel.pauseNarration()

        XCTAssertEqual(viewModel.sessionState, .paused(sceneIndex: 0))
        XCTAssertEqual(viewModel.currentSceneIndex, 0)
        XCTAssertEqual(viewModel.statusMessage, "Narration paused")
        XCTAssertEqual(
            viewModel.sessionCue,
            PracticeSessionViewModel.SessionCue(
                title: "Paused",
                detail: "The story is paused on scene 1 of 2.",
                actionHint: "Speak to ask for a change, or wait to keep going.",
                tone: .paused
            )
        )
        XCTAssertEqual(narrationTransport.pauseCallCount, 1)

        try? await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertEqual(viewModel.sessionState, .paused(sceneIndex: 0))
        XCTAssertEqual(narrationTransport.playedUtteranceIDs.count, 1)

        viewModel.resumeNarration()

        XCTAssertEqual(narrationTransport.resumeCallCount, 1)

        await waitUntil {
            if case .narrating(sceneIndex: 1) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 2
            }
            return false
        }

        XCTAssertEqual(
            viewModel.sessionCue,
            PracticeSessionViewModel.SessionCue(
                title: "Storytelling",
                detail: "StoryTime is telling scene 2 of 2.",
                actionHint: "Speak anytime to ask a question or change what happens next.",
                tone: .storytelling
            )
        )

        await waitUntil { viewModel.phase == .completed }

        XCTAssertEqual(store.series.count, 1)
    }

    func testPauseAndResumeSingleSceneNarrationDoesNotDuplicateCompletionSideEffects() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moonlight picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moonlight picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 1)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true], playDelayNanoseconds: 200_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a moonlight picnic story")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        viewModel.pauseNarration()
        XCTAssertEqual(viewModel.sessionState, .paused(sceneIndex: 0))

        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(viewModel.sessionState, .paused(sceneIndex: 0))

        viewModel.resumeNarration()
        await waitUntil { viewModel.phase == .completed }

        XCTAssertEqual(narrationTransport.playedUtteranceIDs, ["scene-0-2"])
        XCTAssertEqual(store.series.count, 1)
        XCTAssertEqual(store.series.first?.episodes.count, 1)
        XCTAssertEqual(viewModel.statusMessage, "Story complete")
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
                    StoryScene(sceneId: "3", text: "They hugged at home with a happy picnic.", durationSec: 35)
                ],
                revisedFromSceneIndex: 2
            ),
            makeRevisedEnvelope(
                scenes: [
                    StoryScene(sceneId: "3", text: "They ended with a cozy song by the fountain after a moonbeam slide.", durationSec: 35)
                ],
                revisedFromSceneIndex: 2
            )
        ]

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(
            scriptedResults: [true, true, true],
            playDelayNanoseconds: 250_000_000
        )
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Bunny and Dragon should have a picnic adventure")

        await waitUntil {
            viewModel.phase == .narrating &&
            viewModel.currentSceneIndex == 1 &&
            narrationTransport.playedUtteranceIDs.count == 2
        }

        let firstUpdate = "Please add a rainbow clue"
        let secondUpdate = "Make the ending extra cozy"

        voice.emitUserSpeechChanged(true)
        voice.emitTranscriptFinal(firstUpdate)
        await waitUntil { viewModel.phase == .revising }
        XCTAssertEqual(
            viewModel.sessionCue,
            PracticeSessionViewModel.SessionCue(
                title: "Updating what happens next",
                detail: "StoryTime is changing only the scenes after scene 2 of 3.",
                actionHint: "Hold on while the next part is rewritten.",
                tone: .update
            )
        )
        try? await Task.sleep(nanoseconds: 60_000_000)
        voice.emitUserSpeechChanged(true)
        voice.emitTranscriptFinal(secondUpdate)

        await waitUntil { api.reviseRequests.count == 2 && viewModel.phase == .narrating }

        XCTAssertEqual(api.maxConcurrentRevises, 1)
        XCTAssertEqual(api.reviseRequests.map(\.userUpdate), [firstUpdate, secondUpdate])
        XCTAssertEqual(viewModel.generatedStory?.scenes[1].sceneId, "2")
        XCTAssertEqual(viewModel.generatedStory?.scenes[1].text, "Scene 2 ends with a happy smile.")
        XCTAssertTrue(viewModel.generatedStory?.scenes[2].text.contains("moonbeam slide") == true)
    }

    func testStartSessionWhileNarratingIsRejectedWithStateContext() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moon parade",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moon parade story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moon Parade", sceneCount: 2)

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
        voice.emitTranscriptFinal("Tell a moon parade story")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return true
            }
            return false
        }

        let invalidCount = viewModel.invalidTransitionMessages.count
        await viewModel.startSession()

        XCTAssertEqual(viewModel.sessionState, .narrating(sceneIndex: 0))
        XCTAssertEqual(api.prepareConnectionCallCount, 1)
        XCTAssertEqual(viewModel.invalidTransitionMessages.count, invalidCount + 1)
        XCTAssertEqual(
            viewModel.invalidTransitionMessages.last,
            "Rejected startRequested while in narrating(sceneIndex: 0)"
        )
    }

    func testStaleDiscoveryResultAfterFailureIsIgnored() async throws {
        let api = MockAPIClient()
        api.discoveryDelayNanoseconds = 250_000_000
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a lantern race",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a lantern race story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Lantern Race", sceneCount: 2)

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
        voice.emitTranscriptFinal("Tell a lantern race story")

        await waitUntil {
            if case .discovering = viewModel.sessionState {
                return true
            }
            return false
        }

        voice.emitDisconnected()
        await waitUntil { viewModel.phase == .failed }
        await waitUntil {
            viewModel.invalidTransitionMessages.contains {
                $0.contains("Ignored stale discovery result")
            }
        }

        XCTAssertEqual(api.generateRequests.count, 0)
        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertNil(viewModel.generatedStory)
    }

    func testNormalSessionProgressionCompletesAndSavesOnce() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moonlight picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moonlight picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 1)

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
        XCTAssertEqual(store.series.count, 0)

        voice.emitTranscriptFinal("Tell a moonlight picnic story")

        await waitUntil { viewModel.phase == .completed }

        XCTAssertEqual(store.series.count, 1)
        XCTAssertEqual(store.series.first?.episodes.count, 1)
        XCTAssertEqual(viewModel.statusMessage, "Story complete")
    }

    func testInterruptionDuringGenerationIsRejectedDeterministically() async throws {
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
        api.generateStoryDelayNanoseconds = 250_000_000
        api.generateStoryResult = makeGeneratedEnvelope(title: "Picnic Clues", sceneCount: 3)

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
        voice.emitTranscriptFinal("Bunny and Dragon should have a picnic adventure")
        await waitUntil { viewModel.phase == .generating }

        let invalidCount = viewModel.invalidTransitionMessages.count
        voice.emitTranscriptFinal("Actually make it sillier")

        await waitUntil { viewModel.invalidTransitionMessages.count > invalidCount }

        XCTAssertEqual(api.reviseRequests.count, 0)
        XCTAssertEqual(api.generateRequests.count, 1)
        XCTAssertTrue(viewModel.invalidTransitionMessages.last?.contains("transcriptFinal") == true)
    }

    func testTranscriptStartedDuringGenerationIsRejectedAfterNarrationBegins() async throws {
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
        api.generateStoryDelayNanoseconds = 250_000_000
        api.generateStoryResult = makeGeneratedEnvelope(title: "Picnic Clues", sceneCount: 3)

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
        voice.emitTranscriptFinal("Bunny and Dragon should have a picnic adventure")
        await waitUntil { viewModel.phase == .generating }

        voice.emitUserSpeechChanged(true)
        await waitUntil { viewModel.phase == .narrating }
        let invalidCount = viewModel.invalidTransitionMessages.count

        voice.emitTranscriptFinal("Actually make it sillier")

        await waitUntil { viewModel.invalidTransitionMessages.count > invalidCount }

        XCTAssertEqual(api.reviseRequests.count, 0)
        XCTAssertEqual(viewModel.sessionState, .narrating(sceneIndex: 0))
        XCTAssertEqual(
            viewModel.invalidTransitionMessages.last,
            "Rejected transcriptFinalDeferredFromGenerating while in narrating(sceneIndex: 0)"
        )
    }

    func testLateGenerationResultAfterFailureIsIgnoredAndDoesNotStartNarration() async throws {
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
        api.generateStoryDelayNanoseconds = 250_000_000
        api.generateStoryResult = makeGeneratedEnvelope(title: "Picnic Clues", sceneCount: 3)

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
        voice.emitTranscriptFinal("Bunny and Dragon should have a picnic adventure")
        await waitUntil { viewModel.phase == .generating }

        voice.emitDisconnected()
        await waitUntil { viewModel.phase == .failed }
        await waitUntil {
            viewModel.invalidTransitionMessages.contains {
                $0.contains("Ignored stale generation result")
            }
        }

        XCTAssertNil(viewModel.generatedStory)
        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(voice.spokenTexts.count, 1)
    }

    func testLateTranscriptAfterFailureDoesNotOverwriteLatestTranscript() async throws {
        let initialTranscript = "Bunny and Dragon should have a picnic adventure"
        let lateTranscript = "Actually make it sillier"

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
                    transcript: initialTranscript
                )
            )
        ]
        api.generateStoryDelayNanoseconds = 250_000_000
        api.generateStoryResult = makeGeneratedEnvelope(title: "Picnic Clues", sceneCount: 3)

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
        voice.emitTranscriptFinal(initialTranscript)
        await waitUntil { viewModel.phase == .generating }

        voice.emitDisconnected()
        await waitUntil { viewModel.phase == .failed }

        let preservedTranscript = viewModel.latestUserTranscript
        let invalidCount = viewModel.invalidTransitionMessages.count

        voice.emitTranscriptFinal(lateTranscript)
        await waitUntil { viewModel.invalidTransitionMessages.count > invalidCount }

        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.latestUserTranscript, preservedTranscript)
        XCTAssertNotEqual(viewModel.latestUserTranscript, lateTranscript)
        XCTAssertEqual(api.reviseRequests.count, 0)
        XCTAssertTrue(viewModel.invalidTransitionMessages.last?.contains("transcriptFinal") == true)
    }

    func testTranscriptStartedDuringRevisionIsRejectedAfterNarrationResumes() async throws {
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
        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 1 }

        voice.emitTranscriptFinal("Please make the ending funnier and add a rainbow clue")
        await waitUntil { viewModel.phase == .revising }

        voice.emitUserSpeechChanged(true)
        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 1 }
        let invalidCount = viewModel.invalidTransitionMessages.count

        voice.emitTranscriptFinal("Also add a moonbeam slide")

        await waitUntil { viewModel.invalidTransitionMessages.count > invalidCount }

        XCTAssertEqual(api.reviseRequests.count, 1)
        XCTAssertEqual(viewModel.sessionState, .narrating(sceneIndex: 1))
        XCTAssertEqual(
            viewModel.invalidTransitionMessages.last,
            "Rejected transcriptFinalDeferredFromRevising while in narrating(sceneIndex: 1)"
        )
    }

    func testRevisionQueueRejectsAdditionalUpdateBeyondOneQueuedRequest() async throws {
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

        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 1 }

        voice.emitTranscriptFinal("Add a rainbow clue")
        await waitUntil { viewModel.phase == .revising }
        voice.emitTranscriptFinal("Also make it extra cozy")
        try? await Task.sleep(nanoseconds: 60_000_000)
        let invalidCount = viewModel.invalidTransitionMessages.count
        voice.emitTranscriptFinal("And add a moonbeam slide too")

        await waitUntil { viewModel.invalidTransitionMessages.count > invalidCount }
        await waitUntil { api.reviseRequests.count == 2 && viewModel.phase == .narrating }

        XCTAssertEqual(api.maxConcurrentRevises, 1)
        XCTAssertEqual(api.reviseRequests.map(\.userUpdate), ["Add a rainbow clue", "Also make it extra cozy"])
        XCTAssertEqual(
            viewModel.invalidTransitionMessages.last,
            "Rejected revision update while queue full for scene 1"
        )
        XCTAssertTrue(viewModel.generatedStory?.scenes[1].text.contains("moonbeam slide") == true)
    }

    func testResumeNarrationFromCorrectSceneAfterRevision() async throws {
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

        voice.emitTranscriptFinal("Please make the ending funnier and add a rainbow clue")

        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 1 }

        XCTAssertEqual(viewModel.sessionState, .narrating(sceneIndex: 1))
        XCTAssertEqual(api.reviseRequests.first?.currentSceneIndex, 2)
        XCTAssertEqual(viewModel.generatedStory?.scenes.map(\.sceneId), ["1", "2", "3"])
        XCTAssertEqual(viewModel.generatedStory?.scenes[1].text, "Scene 2 ends with a happy smile.")
        XCTAssertEqual(viewModel.generatedStory?.scenes[2].text, "The rainbow clue made Dragon laugh at the final gate.")
    }

    func testDuplicateCompletionAndSavePrevention() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moonlight picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moonlight picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 1)

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
        voice.emitTranscriptFinal("Tell a moonlight picnic story")
        await waitUntil { viewModel.phase == .completed }

        let initialSeriesCount = store.series.count
        XCTAssertEqual(viewModel.latestUserTranscript, "")
        let lastUtteranceID = try XCTUnwrap(voice.spokenUtteranceIDs.last ?? nil)
        voice.emitAssistantResponseCompleted(lastUtteranceID)
        voice.emitDisconnected()
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(store.series.count, initialSeriesCount)
        XCTAssertEqual(store.series.first?.episodes.count, 1)
        XCTAssertEqual(viewModel.phase, .completed)
    }

    func testDisconnectDuringNarrationFailsSessionAndDoesNotSaveStory() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moonlight picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moonlight picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 2)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(
            scriptedResults: [true, true],
            playDelayNanoseconds: 300_000_000
        )
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a moonlight picnic story")

        await waitUntil {
            viewModel.phase == .narrating &&
            viewModel.currentSceneIndex == 0 &&
            narrationTransport.playedUtteranceIDs.count == 1
        }

        voice.emitDisconnected()
        await waitUntil { viewModel.phase == .failed }

        try? await Task.sleep(nanoseconds: 400_000_000)
        voice.emitDisconnected()
        await Task.yield()

        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.lastAppError?.category, .networkFailure)
        XCTAssertEqual(viewModel.statusMessage, "Voice session disconnected")
        XCTAssertEqual(viewModel.errorMessage, "The live storyteller disconnected. Please try again.")
        XCTAssertEqual(viewModel.activeSpeaker, .idle)
        XCTAssertEqual(store.series.count, 0)
        XCTAssertEqual(api.reviseRequests.count, 0)
        XCTAssertGreaterThanOrEqual(narrationTransport.stopCallCount, 1)
        XCTAssertGreaterThanOrEqual(narrationTransport.playedUtteranceIDs.count, 1)
    }

    func testRevisionInvalidatesStalePreloadedFutureSceneAudio() async throws {
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
        api.reviseStoryResult = makeRevisedEnvelope(
            scenes: [
                StoryScene(sceneId: "3", text: "The rainbow clue led Bunny and Dragon home laughing.", durationSec: 35)
            ],
            revisedFromSceneIndex: 2
        )

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true, true], playDelayNanoseconds: 250_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Bunny and Dragon should have a picnic adventure")

        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 1 }

        let originalStory = try XCTUnwrap(viewModel.generatedStory)
        let currentBoundaryKey = PreparedNarrationScene(
            sceneId: originalStory.scenes[1].sceneId,
            text: originalStory.scenes[1].text,
            estimatedDurationSec: originalStory.scenes[1].durationSec
        ).cacheKey
        let staleFutureKey = PreparedNarrationScene(
            sceneId: originalStory.scenes[2].sceneId,
            text: originalStory.scenes[2].text,
            estimatedDurationSec: originalStory.scenes[2].durationSec
        ).cacheKey

        await waitUntil { narrationTransport.prepareCallKeys.contains(staleFutureKey) }

        voice.emitUserSpeechChanged(true)
        voice.emitTranscriptFinal("Please make the ending funnier and add a rainbow clue")

        await waitUntil {
            viewModel.phase == .narrating
                && viewModel.currentSceneIndex == 1
                && viewModel.generatedStory?.scenes[2].text == "The rainbow clue led Bunny and Dragon home laughing."
        }

        let revisedStory = try XCTUnwrap(viewModel.generatedStory)
        let revisedFutureKey = PreparedNarrationScene(
            sceneId: revisedStory.scenes[2].sceneId,
            text: revisedStory.scenes[2].text,
            estimatedDurationSec: revisedStory.scenes[2].durationSec
        ).cacheKey

        XCTAssertTrue(narrationTransport.prepareCallKeys.contains(staleFutureKey))
        XCTAssertTrue(narrationTransport.prepareCallKeys.contains(revisedFutureKey))
        XCTAssertFalse(narrationTransport.invalidatedKeepKeySnapshots.last?.contains(staleFutureKey) ?? true)
        XCTAssertTrue(narrationTransport.invalidatedKeepKeySnapshots.last?.contains(currentBoundaryKey) ?? false)

        await waitUntil { viewModel.phase == .completed }

        XCTAssertTrue(narrationTransport.playedCacheHitKeys.contains(revisedFutureKey))
        XCTAssertFalse(narrationTransport.playedCacheHitKeys.contains(staleFutureKey))
    }

    func testAnswerOnlyResumeCompletesAndSavesOnce() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moonlight picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moonlight picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 1)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1, 2, 3])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true], playDelayNanoseconds: 250_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a moonlight picnic story")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        voice.emitUserSpeechChanged(true)
        await waitUntil { viewModel.sessionState == .interrupting(sceneIndex: 0) }
        voice.emitTranscriptFinal("Why are Bunny and Fox having a picnic?")

        await waitUntil {
            viewModel.interruptionRouteDecision?.intent == .answerOnly
                && viewModel.phase == .narrating
                && narrationTransport.playedUtteranceIDs.count == 2
        }

        await waitUntil { viewModel.phase == .completed }

        let initialSeriesCount = store.series.count
        XCTAssertEqual(store.series.first?.episodes.count, 1)

        let lastUtteranceID = try XCTUnwrap(voice.spokenUtteranceIDs.last)
        voice.emitAssistantResponseCompleted(lastUtteranceID)
        voice.emitDisconnected()
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(store.series.count, initialSeriesCount)
        XCTAssertEqual(store.series.first?.episodes.count, 1)
        XCTAssertEqual(viewModel.phase, .completed)
    }

    func testSessionCueExplainsAnswerOnlyInterruptionState() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moonlight picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moonlight picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 1)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true], playDelayNanoseconds: 250_000_000)
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a moonlight picnic story")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        voice.emitUserSpeechChanged(true)
        await waitUntil { viewModel.sessionState == .interrupting(sceneIndex: 0) }
        voice.emitTranscriptFinal("Why are Bunny and Fox having a picnic?")

        await waitUntil {
            viewModel.statusMessage == "Answering your question" && viewModel.activeSpeaker == .ai
        }

        XCTAssertEqual(
            viewModel.sessionCue,
            PracticeSessionViewModel.SessionCue(
                title: "Answering",
                detail: "StoryTime is answering your question before it returns to scene 1 of 1.",
                actionHint: "Listen now. The story will continue after the answer.",
                tone: .storytelling
            )
        )
    }

    func testStartSessionRestartsCleanlyFromCompletedTerminalState() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a moonlight picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the lantern park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a moonlight picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Moonlight Picnic", sceneCount: 1)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1, 2, 3])
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
        voice.emitTranscriptFinal("Tell a moonlight picnic story")
        await waitUntil { viewModel.phase == .completed }

        XCTAssertEqual(store.series.count, 1)
        XCTAssertEqual(viewModel.sessionState, .completed)

        await viewModel.startSession()

        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertEqual(viewModel.sessionState, .ready(VoiceSessionReadyState(mode: .discovery(stepNumber: 1))))
        XCTAssertNil(viewModel.generatedStory)
        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertEqual(viewModel.invalidTransitionMessages, [])
        XCTAssertEqual(api.prepareConnectionCallCount, 2)
        XCTAssertEqual(voice.connectCallCount, 2)
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
        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertTrue(viewModel.aiPrompt.contains("gentle and friendly"))
        XCTAssertEqual(viewModel.lastAppError?.category, .moderationBlock)
        XCTAssertEqual(
            viewModel.lastAppError?.userMessage,
            "Let's make it gentle and friendly. What kind of kind adventure should we tell?"
        )
    }

    func testBlockedGenerationUsesModerationCategoryAndSafeMessage() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a dragon parade",
                        characters: ["Dragon", "Bunny"],
                        setting: "the sunny hill",
                        tone: "playful",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a dragon parade story"
                )
            )
        ]
        let blockedStory = makeGeneratedEnvelope(title: "Dragon Parade", sceneCount: 2).data
        api.generateStoryResult = GenerateStoryEnvelope(
            blocked: true,
            safeMessage: "We kept this story extra gentle while it was being created.",
            data: blockedStory
        )

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
        voice.emitTranscriptFinal("Tell a dragon parade story")

        await waitUntil { viewModel.phase == .narrating }

        XCTAssertEqual(viewModel.lastAppError?.category, .moderationBlock)
        XCTAssertEqual(
            viewModel.lastAppError?.userMessage,
            "We kept this story extra gentle while it was being created."
        )
        XCTAssertEqual(viewModel.errorMessage, "")
    }

    func testBlockedRevisionUsesModerationCategoryAndSafeMessage() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a rainbow picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the sunny meadow",
                        tone: "gentle",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a rainbow picnic story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Rainbow Picnic", sceneCount: 2)
        api.reviseStoryResult = ReviseStoryEnvelope(
            blocked: true,
            safeMessage: "We softened the update to keep the story kind and calm.",
            data: RevisedStoryData(
                storyId: UUID().uuidString,
                revisedFromSceneIndex: 0,
                scenes: [
                    StoryScene(sceneId: "1", text: "Bunny spread a rainbow picnic blanket.", durationSec: 40),
                    StoryScene(sceneId: "2", text: "Fox added soft music and everyone smiled.", durationSec: 40)
                ],
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: nil
            )
        )

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
        voice.emitTranscriptFinal("Tell a rainbow picnic story")
        await waitUntil { viewModel.phase == .narrating }

        voice.emitTranscriptFinal("Make the ending much softer")
        await waitUntil { viewModel.phase == .narrating && viewModel.generatedStory?.scenes.last?.text.contains("soft music") == true }

        XCTAssertEqual(viewModel.lastAppError?.category, .moderationBlock)
        XCTAssertEqual(
            viewModel.lastAppError?.userMessage,
            "We softened the update to keep the story kind and calm."
        )
        XCTAssertEqual(viewModel.errorMessage, "")
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
        XCTAssertEqual(viewModel.phase, .ready)
    }

    func testStartupHealthCheckFailureUsesSafeMessageAndCategory() async throws {
        let api = MockAPIClient()
        api.prepareConnectionError = APIError.invalidResponse(
            statusCode: 503,
            code: "internal_error",
            message: "Unexpected server error",
            requestId: "req-startup-health",
            body: "{\"error\":\"db password leaked\"}"
        )
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
        XCTAssertEqual(viewModel.lastStartupFailure, .healthCheck)
        XCTAssertEqual(viewModel.lastAppError?.category, .startup)
        XCTAssertEqual(viewModel.errorMessage, "I couldn't reach StoryTime right now. Please try again in a moment.")
        XCTAssertFalse(viewModel.errorMessage.contains("db password"))
        XCTAssertEqual(voice.connectCallCount, 0)
        XCTAssertEqual(
            viewModel.sessionCue,
            PracticeSessionViewModel.SessionCue(
                title: "Need help",
                detail: "I couldn't reach StoryTime right now. Please try again in a moment.",
                actionHint: "Ask a grown-up to try again.",
                tone: .error
            )
        )
    }

    func testStartupSessionBootstrapFailureUsesSafeMessageAndCategory() async throws {
        let api = MockAPIClient()
        api.bootstrapSessionIdentityError = APIError.invalidResponse(
            statusCode: 401,
            code: "invalid_session_token",
            message: "Invalid signed token",
            requestId: "req-startup-bootstrap",
            body: "{\"message\":\"signed token invalid\"}"
        )
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

        XCTAssertEqual(api.bootstrapSessionIdentityCallCount, 1)
        XCTAssertEqual(api.createRealtimeSessionCallCount, 0)
        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.lastStartupFailure, .sessionBootstrap)
        XCTAssertEqual(viewModel.statusMessage, "Session unavailable")
        XCTAssertEqual(viewModel.errorMessage, "I couldn't start the live story session right now. Please try again.")
        XCTAssertFalse(viewModel.errorMessage.contains("signed token invalid"))
    }

    func testStartupRealtimeSessionFailureUsesSafeMessageAndCategory() async throws {
        let api = MockAPIClient()
        api.createRealtimeSessionError = APIError.invalidResponse(
            statusCode: 500,
            code: "internal_error",
            message: "Unexpected server error",
            requestId: "req-startup-realtime",
            body: "{\"error\":\"internal upstream response\"}"
        )
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

        XCTAssertEqual(api.createRealtimeSessionCallCount, 1)
        XCTAssertEqual(voice.connectCallCount, 0)
        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.lastStartupFailure, .realtimeSession)
        XCTAssertEqual(viewModel.statusMessage, "Session unavailable")
        XCTAssertEqual(viewModel.errorMessage, "I couldn't prepare the live story session right now. Please try again.")
        XCTAssertFalse(viewModel.errorMessage.contains("internal upstream response"))
    }

    func testStartupUnsupportedRegionFailureUsesSafeMessage() async throws {
        let api = MockAPIClient()
        api.createRealtimeSessionError = APIError.invalidResponse(
            statusCode: 403,
            code: "unsupported_region",
            message: "Unsupported processing region",
            requestId: "req-startup-region",
            body: "{\"allowed_regions\":[\"EU\"]}"
        )
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

        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.lastStartupFailure, .realtimeSession)
        XCTAssertEqual(viewModel.statusMessage, "Session unavailable")
        XCTAssertEqual(viewModel.errorMessage, "StoryTime isn't available in this region right now.")
        XCTAssertFalse(viewModel.errorMessage.contains("allowed_regions"))
    }

    func testStartupBridgeReadinessFailureUsesSafeMessageAndCategory() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        voice.connectError = RealtimeVoiceClient.RealtimeError.bridgeReadyTimedOut
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

        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.lastStartupFailure, .bridgeReadiness)
        XCTAssertEqual(viewModel.statusMessage, "Voice unavailable")
        XCTAssertEqual(viewModel.errorMessage, "The live storyteller isn't ready yet. Please try again.")
    }

    func testStartupCallConnectFailureUsesSafeMessageAndCategory() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        voice.connectError = RealtimeVoiceClient.RealtimeError.connectFailed("Socket failed: raw token")
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

        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.lastStartupFailure, .callConnect)
        XCTAssertEqual(viewModel.statusMessage, "Connection failed")
        XCTAssertEqual(viewModel.errorMessage, "I couldn't connect the live storyteller right now. Please try again.")
        XCTAssertFalse(viewModel.errorMessage.contains("raw token"))
    }

    func testStartupDisconnectBeforeReadyFailsOnceAndLateConnectedDoesNotReviveSession() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        voice.emitsConnectedOnConnect = false
        voice.onConnectAction = { mock in
            mock.emitDisconnected()
        }
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
        voice.emitConnected()
        await Task.yield()

        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.lastStartupFailure, .disconnectBeforeReady)
        XCTAssertEqual(viewModel.statusMessage, "Voice session disconnected")
        XCTAssertEqual(viewModel.errorMessage, "The live storyteller disconnected before it was ready. Please try again.")
        XCTAssertEqual(viewModel.aiPrompt, "Starting story conversation...")
    }

    func testStartupBridgeErrorEventFailsOnceAndDoesNotReviveSession() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        voice.emitsConnectedOnConnect = false
        voice.onConnectAction = { mock in
            mock.emitError("Socket failed: raw body")
        }
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
        voice.emitConnected()
        await Task.yield()

        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.lastStartupFailure, .callConnect)
        XCTAssertEqual(viewModel.statusMessage, "Connection failed")
        XCTAssertEqual(viewModel.errorMessage, "I couldn't connect the live storyteller right now. Please try again.")
        XCTAssertFalse(viewModel.errorMessage.contains("raw body"))
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
        XCTAssertTrue(viewModel.statusMessage.contains("Narrating scene"))
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
        XCTAssertEqual(viewModel.currentSceneIndex, 0)
    }

    func testRepeatEpisodeCompletionDoesNotCreateNewHistory() async throws {
        let api = MockAPIClient()
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let store = StoryLibraryStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let basePlan = makePlan(childProfileId: profileId)
        let story = StoryData(
            storyId: "repeat-story-1",
            title: "Moonlight Picnic",
            estimatedDurationSec: 10,
            scenes: [StoryScene(sceneId: "1", text: "Bunny shared a lantern picnic.", durationSec: 1)],
            safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
            engine: nil
        )
        let seriesId = try XCTUnwrap(store.addStory(story, characters: ["Bunny"], plan: basePlan))
        let originalSeries = try XCTUnwrap(store.seriesById(seriesId))
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
            sourceSeries: originalSeries,
            store: store,
            api: api,
            voiceCore: voice,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        await waitUntil { viewModel.phase == .completed }

        let replayedSeries = try XCTUnwrap(store.seriesById(seriesId))
        XCTAssertEqual(store.series.count, 1)
        XCTAssertEqual(replayedSeries, originalSeries)
        XCTAssertEqual(replayedSeries.episodes.count, 1)
        XCTAssertEqual(replayedSeries.episodes.first?.storyId, story.storyId)
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

    func testRepeatEpisodeRevisionReplacesExistingHistoryWithoutAddingEpisodes() async throws {
        let api = MockAPIClient()
        api.reviseStoryResult = ReviseStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: RevisedStoryData(
                storyId: "ignored-by-client",
                revisedFromSceneIndex: 0,
                scenes: [StoryScene(sceneId: "1", text: "Bunny added a rainbow clue to the replay.", durationSec: 1)],
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: nil
            )
        )
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        let store = StoryLibraryStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let basePlan = makePlan(childProfileId: profileId)
        let originalStory = StoryData(
            storyId: "repeat-story-2",
            title: "Moonlight Picnic",
            estimatedDurationSec: 10,
            scenes: [StoryScene(sceneId: "1", text: "Bunny shared a lantern picnic.", durationSec: 1)],
            safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
            engine: nil
        )
        let seriesId = try XCTUnwrap(store.addStory(originalStory, characters: ["Bunny"], plan: basePlan))
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
        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 0 }

        await viewModel.childDidSpeak()
        await waitUntil { viewModel.phase == .completed }

        let updatedSeries = try XCTUnwrap(store.seriesById(seriesId))
        XCTAssertEqual(store.series.count, 1)
        XCTAssertEqual(updatedSeries.episodes.count, 1)
        XCTAssertEqual(updatedSeries.episodes.first?.storyId, originalStory.storyId)
        XCTAssertEqual(updatedSeries.episodes.first?.scenes.first?.text, "Bunny added a rainbow clue to the replay.")
    }

    func testRepeatEpisodeRevisionReplacesContinuityFactsAndClearsClosedOpenLoops() async throws {
        let api = MockAPIClient()
        api.reviseStoryResult = ReviseStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: RevisedStoryData(
                storyId: "ignored-by-client",
                revisedFromSceneIndex: 0,
                scenes: [StoryScene(sceneId: "1", text: "Bunny followed the rainbow brook with Fox.", durationSec: 1)],
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: try makeEngineData(
                    episodeRecap: "Bunny followed the rainbow brook with Fox.",
                    recurringCharacters: ["Bunny", "Fox"],
                    priorEpisodeRecap: "Bunny followed the lantern clue.",
                    worldFacts: ["Rainbow Brook sparkles after the rain."],
                    openLoops: [],
                    favoritePlaces: ["Rainbow Brook"],
                    relationshipFacts: ["Bunny and Fox share clues."],
                    arcSummary: "Bunny and Fox are following rainbow clues together.",
                    nextEpisodeHook: "A silver bell rings beside the brook.",
                    continuityFacts: ["Rainbow Brook sparkles after the rain."],
                    characterBible: [
                        ["name": "Bunny", "role": "main story friend", "traits": ["kind", "curious"]],
                        ["name": "Fox", "role": "returning friend", "traits": ["warm", "helpful"]]
                    ]
                )
            )
        )
        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [])
        let store = StoryLibraryStore()
        let profileId = try XCTUnwrap(store.activeProfile?.id)
        let basePlan = makePlan(childProfileId: profileId)
        let originalStory = StoryData(
            storyId: "repeat-story-continuity",
            title: "Moonlight Picnic",
            estimatedDurationSec: 10,
            scenes: [StoryScene(sceneId: "1", text: "Bunny followed a lantern clue through the park.", durationSec: 1)],
            safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
            engine: try makeEngineData(
                episodeRecap: "Bunny followed a lantern clue through the park.",
                recurringCharacters: ["Bunny", "Fox"],
                priorEpisodeRecap: "Bunny followed a lantern clue through the park.",
                worldFacts: ["Moonlit Park glows after sunset."],
                openLoops: ["Find the hidden gate"],
                favoritePlaces: ["Moonlit Park"],
                relationshipFacts: ["Bunny trusts Fox"],
                arcSummary: "Bunny is following lantern clues through the park.",
                nextEpisodeHook: "The hidden gate starts to glow.",
                continuityFacts: ["Moonlit Park glows after sunset."],
                characterBible: [
                    ["name": "Bunny", "role": "main story friend", "traits": ["kind", "curious"]],
                    ["name": "Fox", "role": "returning friend", "traits": ["warm", "helpful"]]
                ]
            )
        )
        let seriesId = try XCTUnwrap(store.addStory(originalStory, characters: ["Bunny"], plan: basePlan))
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

        await ContinuityMemoryStore.shared.replaceFacts(
            seriesId: seriesId,
            storyId: originalStory.storyId,
            texts: ["Open loop: Find the hidden gate", "Place: Moonlit Park"],
            embeddings: [[1.0, 0.0], [0.9, 0.1]]
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
        await waitUntil { viewModel.phase == .narrating && viewModel.currentSceneIndex == 0 }

        await viewModel.childDidSpeak()
        await waitUntil { viewModel.phase == .completed }
        await waitUntilAsync {
            let records = await ContinuityMemoryStore.shared.factRecords(seriesId: seriesId, storyId: originalStory.storyId)
            return records.contains { $0.text == "Place: Rainbow Brook" }
        }

        let updatedSeries = try XCTUnwrap(store.seriesById(seriesId))
        XCTAssertEqual(updatedSeries.episodes.count, 1)
        XCTAssertEqual(updatedSeries.episodes.first?.storyId, originalStory.storyId)
        XCTAssertEqual(updatedSeries.favoritePlaces, ["Rainbow Brook"])
        XCTAssertEqual(updatedSeries.relationshipFacts, ["Bunny and Fox share clues."])
        XCTAssertNil(updatedSeries.unresolvedThreads)

        let revisedRecords = await ContinuityMemoryStore.shared.factRecords(
            seriesId: seriesId,
            storyId: originalStory.storyId
        )
        let revisedTexts = revisedRecords.map(\.text)
        XCTAssertTrue(revisedTexts.contains("Place: Rainbow Brook"))
        XCTAssertTrue(revisedTexts.contains("Relationship: Bunny and Fox share clues."))
        XCTAssertFalse(revisedTexts.contains("Place: Moonlit Park"))
        XCTAssertFalse(revisedTexts.contains("Open loop: Find the hidden gate"))
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
            api.embeddingInputs.count >= 1
        }

        XCTAssertTrue(api.generateRequests[0].continuityFacts.contains { $0.contains("Open loop:") })
        XCTAssertTrue(api.embeddingInputs[0].first?.contains("moonlit hill") == true)
        XCTAssertTrue(
            viewModel.runtimeTelemetryEvents.contains {
                $0.stage == .continuityRetrieval &&
                $0.stageGroup == nil &&
                $0.costDriver == .localData
            }
        )
        XCTAssertTrue(
            viewModel.runtimeTelemetryEvents.contains {
                $0.stage == .continuityRetrieval &&
                $0.stageGroup == nil &&
                $0.costDriver == .remoteModel &&
                $0.apiOperation == .embeddings
            }
        )
        XCTAssertTrue(viewModel.runtimeTelemetryEvents.allSatisfy { !$0.source.contains("moonlit hill") })
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

        XCTAssertEqual(viewModel.phase, .ready)
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
        XCTAssertEqual(
            viewModel.privacySummary,
            "Live conversation is on. Raw audio is not saved. Your words are sent for live processing during this session."
        )
    }

    func testPrivacySummaryMentionsLocalTranscriptClearingWhenEnabled() throws {
        let store = StoryLibraryStore()
        let plan = makePlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: MockAPIClient(),
            voiceCore: MockRealtimeVoiceCore(autoCompleteSpeakIndices: []),
            forceMockVoiceCore: true
        )

        XCTAssertEqual(
            viewModel.privacySummary,
            "Live conversation is on. Raw audio is not saved. Your words are sent for live processing during this session, and the on-screen transcript clears when the session ends."
        )
    }

    func testRealtimeCallbacksUpdateSpeakerLevelsAndUseSafeRuntimeVoiceFailures() async throws {
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
        XCTAssertEqual(viewModel.phase, .failed)
        XCTAssertEqual(viewModel.lastAppError?.category, .backendFailure)
        XCTAssertEqual(viewModel.statusMessage, "Voice session error")
        XCTAssertEqual(viewModel.errorMessage, "The live storyteller had a problem. Please try again.")
        XCTAssertFalse(viewModel.errorMessage.contains("Mic unavailable"))

        voice.emitDisconnected()
        await Task.yield()
        XCTAssertEqual(viewModel.statusMessage, "Voice session error")
        XCTAssertEqual(viewModel.activeSpeaker, .idle)
    }

    func testFailureTraceCapturesBackendRequestCorrelationWithoutTranscriptContent() async throws {
        let api = MockAPIClient()
        api.discoveryError = APIError.invalidResponse(
            statusCode: 500,
            code: "internal_error",
            message: "Unexpected server error",
            requestId: "req-discovery-failure",
            body: "{\"error\":\"internal_error\",\"details\":\"secret\"}"
        )
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
        voice.emitTranscriptFinal("Tell a stormy story")
        await waitUntil { viewModel.phase == .failed }

        let failureTrace = try XCTUnwrap(viewModel.traceEvents.last { $0.kind == .failure })
        XCTAssertEqual(failureTrace.requestId, "req-discovery-failure")
        XCTAssertEqual(failureTrace.sessionId, "mock-session-123")
        XCTAssertEqual(failureTrace.apiOperation, .storyDiscovery)
        XCTAssertEqual(failureTrace.statusCode, 500)
        XCTAssertEqual(failureTrace.state, viewModel.sessionState.logDescription)
        XCTAssertEqual(failureTrace.source, "discovery failed")
        XCTAssertFalse(failureTrace.source.contains("stormy"))
        XCTAssertEqual(viewModel.errorMessage, "I couldn't finish the story right now. Please try again.")
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
            await waitUntil { viewModel.phase == .failed }
            XCTAssertEqual(viewModel.lastAppError?.category, .backendFailure)
            XCTAssertEqual(viewModel.statusMessage, "Session failed")
            XCTAssertEqual(viewModel.errorMessage, "I couldn't finish the story right now. Please try again.")
            XCTAssertEqual(viewModel.latestUserTranscript, "")
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
            await waitUntil { viewModel.phase == .failed }
            XCTAssertEqual(viewModel.activeSpeaker, .idle)
            XCTAssertEqual(viewModel.lastAppError?.category, .networkFailure)
            XCTAssertEqual(viewModel.statusMessage, "Connection failed")
            XCTAssertEqual(viewModel.errorMessage, "I couldn't reach StoryTime right now. Please try again.")
            XCTAssertEqual(viewModel.latestUserTranscript, "")
        }
    }

    func testGenerationDecodeFailureUsesSafeAppErrorModel() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a river walk",
                        characters: ["Bunny"],
                        setting: "the riverbank",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a river walk story"
                )
            )
        ]
        api.generateStoryError = DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "bad payload")
        )
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
        voice.emitTranscriptFinal("Tell a river walk story")
        await waitUntil { viewModel.phase == .failed }

        XCTAssertEqual(viewModel.lastAppError?.category, .decodeFailure)
        XCTAssertEqual(viewModel.statusMessage, "Story unavailable")
        XCTAssertEqual(viewModel.errorMessage, "I couldn't understand StoryTime's reply right now. Please try again.")
    }

    func testRevisionConflictUsesBackendPublicMessageAndSafeCategory() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a kite day",
                        characters: ["Bunny", "Fox"],
                        setting: "the breezy hill",
                        tone: "playful",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a kite day story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Kite Day", sceneCount: 2)
        api.reviseStoryError = APIError.invalidResponse(
            statusCode: 409,
            code: "revision_conflict",
            message: "Use a current scene before revising.",
            requestId: "req-revision-conflict",
            body: "{\"error\":\"revision_conflict\"}"
        )

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
        voice.emitTranscriptFinal("Tell a kite day story")
        await waitUntil { viewModel.phase == .narrating }

        voice.emitTranscriptFinal("Please add more kites")
        await waitUntil { viewModel.phase == .failed }

        XCTAssertEqual(viewModel.lastAppError?.category, .backendFailure)
        XCTAssertEqual(viewModel.statusMessage, "Update unavailable")
        XCTAssertEqual(viewModel.errorMessage, "Use a current scene before revising.")
    }

    func testSessionAuthBackendErrorUsesSafeMappedMessage() async throws {
        let api = MockAPIClient()
        api.discoveryError = APIError.invalidResponse(
            statusCode: 401,
            code: "invalid_session_token",
            message: "Invalid signed token",
            requestId: "req-invalid-session",
            body: "{\"error\":\"invalid_session_token\"}"
        )
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
        voice.emitTranscriptFinal("Tell a bunny story")
        await waitUntil { viewModel.phase == .failed }

        XCTAssertEqual(viewModel.lastAppError?.category, .backendFailure)
        XCTAssertEqual(viewModel.statusMessage, "Session unavailable")
        XCTAssertEqual(viewModel.errorMessage, "StoryTime needs a fresh session before it can continue. Please try again.")
        XCTAssertFalse(viewModel.errorMessage.contains("Invalid signed token"))
    }

    func testDiscoveryCancellationDoesNotFailSession() async throws {
        let api = MockAPIClient()
        api.discoveryError = CancellationError()
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
        voice.emitTranscriptFinal("Tell a bunny story")
        await waitUntil { api.discoveryRequests.count == 1 }
        await waitUntil {
            viewModel.phase == .ready && viewModel.lastAppError?.category == .cancellation
        }

        XCTAssertEqual(viewModel.lastAppError?.category, .cancellation)
        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertEqual(viewModel.statusMessage, "Listening...")
        XCTAssertNotEqual(viewModel.phase, .failed)
    }

    func testRevisionCancellationDoesNotFailSession() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a kite day",
                        characters: ["Bunny", "Fox"],
                        setting: "the breezy hill",
                        tone: "playful",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a kite day story"
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Kite Day", sceneCount: 2)
        api.reviseStoryError = CancellationError()

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
        voice.emitTranscriptFinal("Tell a kite day story")
        await waitUntil { viewModel.phase == .narrating }

        voice.emitTranscriptFinal("Please add more kites")
        await waitUntil {
            if case .interrupting = viewModel.sessionState,
               viewModel.lastAppError?.category == .cancellation {
                return true
            }
            return false
        }

        XCTAssertEqual(viewModel.lastAppError?.category, .cancellation)
        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertEqual(viewModel.statusMessage, "Listening for a story update")
        if case .interrupting(let sceneIndex) = viewModel.sessionState {
            XCTAssertEqual(sceneIndex, 0)
        } else {
            XCTFail("Expected interrupting state after cancelled revision")
        }
    }

    private struct CriticalPathAcceptanceResult {
        let api: MockAPIClient
        let voice: MockRealtimeVoiceCore
        let store: StoryLibraryStore
        let viewModel: PracticeSessionViewModel
        let plan: StoryLaunchPlan
        let savedSeries: StorySeries
        let revisionText: String
        let revisedScenes: [StoryScene]

        var expectedSceneTexts: [String] {
            [
                "Scene 1 ends with a happy smile.",
                revisedScenes[0].text,
                revisedScenes[1].text
            ]
        }
    }

    private func runCriticalPathHappyPathAcceptance() async throws -> CriticalPathAcceptanceResult {
        let initialTranscript = "Bunny and Dragon should have a picnic adventure"
        let revisionText = "Please add a rainbow clue and a happy parade ending"
        let revisedScenes = [
            StoryScene(sceneId: "2", text: "The rainbow clue made Dragon laugh.", durationSec: 25),
            StoryScene(sceneId: "3", text: "They ended with a happy parade by the fountain.", durationSec: 35)
        ]

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
                    transcript: initialTranscript
                )
            )
        ]
        api.generateStoryResult = makeGeneratedEnvelope(title: "Picnic Clues", sceneCount: 3)
        api.reviseStoryResult = makeRevisedEnvelope(scenes: revisedScenes)

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1, 2, 4, 5])
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
        XCTAssertEqual(viewModel.phase, .ready)

        voice.emitTranscriptFinal(initialTranscript)
        await waitUntil {
            viewModel.phase == .narrating &&
            viewModel.currentSceneIndex == 1 &&
            voice.spokenTexts.count >= 3
        }

        voice.emitUserSpeechChanged(true)
        voice.emitTranscriptFinal(revisionText)

        await waitUntil {
            api.reviseRequests.count == 1 &&
            viewModel.traceEvents.contains { $0.kind == .revision }
        }
        await waitUntil { viewModel.phase == .completed }

        let savedSeries = try XCTUnwrap(store.series.first)
        return CriticalPathAcceptanceResult(
            api: api,
            voice: voice,
            store: store,
            viewModel: viewModel,
            plan: plan,
            savedSeries: savedSeries,
            revisionText: revisionText,
            revisedScenes: revisedScenes
        )
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

    private func waitUntilAsync(
        timeout: TimeInterval = 2.0,
        pollIntervalNanoseconds: UInt64 = 20_000_000,
        condition: @escaping () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() {
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
            ],
            revisedFromSceneIndex: 1
        )
    }

    private func makeRevisedEnvelope(
        scenes: [StoryScene],
        revisedFromSceneIndex: Int = 1
    ) -> ReviseStoryEnvelope {
        ReviseStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: RevisedStoryData(
                storyId: UUID().uuidString,
                revisedFromSceneIndex: revisedFromSceneIndex,
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

    private func makeStartupSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StartupURLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private static func startupHTTPResponse(
        url: URL,
        statusCode: Int,
        json: Any,
        headers: [String: String] = [:]
    ) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
        return (response, data)
    }

    private static func startupRequestBody(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            throw URLError(.badServerResponse)
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            if readCount < 0 {
                throw stream.streamError ?? URLError(.badServerResponse)
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }

        return data
    }
}

final class MockAPIClient: APIClienting {
    var traceHandler: ((APIClientTraceEvent) -> Void)?
    var resolvedRegion: StoryTimeRegion?
    var prepareConnectionCallCount = 0
    var bootstrapSessionIdentityCallCount = 0
    var fetchVoicesCallCount = 0
    var createRealtimeSessionCallCount = 0
    var discoveryRequests: [DiscoveryRequest] = []
    var generateRequests: [GenerateStoryRequest] = []
    var reviseRequests: [ReviseStoryRequest] = []
    var embeddingInputs: [[String]] = []

    var prepareConnectionError: Error?
    var bootstrapSessionIdentityError: Error?
    var createRealtimeSessionError: Error?
    var discoveryError: Error?
    var generateStoryError: Error?
    var reviseStoryError: Error?
    var embeddingsError: Error?
    var discoveryDelayNanoseconds: UInt64 = 0
    var generateStoryDelayNanoseconds: UInt64 = 0
    var reviseStoryDelayNanoseconds: UInt64 = 0
    var maxConcurrentRevises = 0
    private var inFlightRevises = 0
    private var traceRequestCounter = 0
    var voices = ["alloy"]
    var bootstrapSessionId = "mock-session-123"
    var bootstrapSessionToken = "mock-session-token"
    var bootstrapSessionRegion: StoryTimeRegion = .us
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
        let requestId = emitStartedTrace(for: .healthCheck)
        prepareConnectionCallCount += 1
        if let prepareConnectionError {
            emitFailureTrace(for: .healthCheck, requestId: requestId, error: prepareConnectionError)
            throw prepareConnectionError
        }
        emitCompletedTrace(for: .healthCheck, requestId: requestId, statusCode: 200)
        return URL(string: "https://backend.example.com")!
    }

    func bootstrapSessionIdentity(baseURL: URL) async throws {
        let requestId = emitStartedTrace(for: .sessionBootstrap)
        bootstrapSessionIdentityCallCount += 1
        if let bootstrapSessionIdentityError {
            emitFailureTrace(for: .sessionBootstrap, requestId: requestId, error: bootstrapSessionIdentityError)
            throw bootstrapSessionIdentityError
        }
        let response = HTTPURLResponse(
            url: baseURL.appending(path: "v1").appending(path: "session").appending(path: "identity"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "x-storytime-session": bootstrapSessionToken,
                "x-storytime-session-expires-at": String(Date().addingTimeInterval(300).timeIntervalSince1970),
                "x-storytime-region": bootstrapSessionRegion.rawValue
            ]
        )!
        AppSession.store(from: response)
        AppSession.store(sessionId: bootstrapSessionId)
        resolvedRegion = bootstrapSessionRegion
        emitCompletedTrace(for: .sessionBootstrap, requestId: requestId, statusCode: 200)
    }

    func fetchVoices() async throws -> [String] {
        let requestId = emitStartedTrace(for: .voices)
        fetchVoicesCallCount += 1
        emitCompletedTrace(for: .voices, requestId: requestId, statusCode: 200)
        return voices
    }

    func createRealtimeSession(request body: RealtimeSessionRequest) async throws -> RealtimeSessionEnvelope {
        let requestId = emitStartedTrace(for: .realtimeSession)
        createRealtimeSessionCallCount += 1
        if let createRealtimeSessionError {
            emitFailureTrace(for: .realtimeSession, requestId: requestId, error: createRealtimeSessionError)
            throw createRealtimeSessionError
        }
        emitCompletedTrace(for: .realtimeSession, requestId: requestId, statusCode: 200)
        return realtimeSessionResult
    }

    func discoverStoryTurn(request body: DiscoveryRequest) async throws -> DiscoveryEnvelope {
        let requestId = emitStartedTrace(for: .storyDiscovery)
        discoveryRequests.append(body)
        if let discoveryError {
            emitFailureTrace(for: .storyDiscovery, requestId: requestId, error: discoveryError)
            throw discoveryError
        }
        if discoveryDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: discoveryDelayNanoseconds)
        }
        if !discoveryResponses.isEmpty {
            let response = discoveryResponses.removeFirst()
            emitCompletedTrace(for: .storyDiscovery, requestId: requestId, statusCode: response.blocked ? 422 : 200)
            return response
        }
        let response = DiscoveryEnvelope(
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
        emitCompletedTrace(for: .storyDiscovery, requestId: requestId, statusCode: 200)
        return response
    }

    func generateStory(request body: GenerateStoryRequest) async throws -> GenerateStoryEnvelope {
        let requestId = emitStartedTrace(for: .storyGeneration)
        generateRequests.append(body)
        if let generateStoryError {
            emitFailureTrace(for: .storyGeneration, requestId: requestId, error: generateStoryError)
            throw generateStoryError
        }
        if generateStoryDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: generateStoryDelayNanoseconds)
        }
        emitCompletedTrace(for: .storyGeneration, requestId: requestId, statusCode: generateStoryResult.blocked ? 422 : 200)
        return generateStoryResult
    }

    func reviseStory(request body: ReviseStoryRequest) async throws -> ReviseStoryEnvelope {
        let requestId = emitStartedTrace(for: .storyRevision)
        reviseRequests.append(body)
        inFlightRevises += 1
        maxConcurrentRevises = max(maxConcurrentRevises, inFlightRevises)
        defer { inFlightRevises -= 1 }
        if let reviseStoryError {
            emitFailureTrace(for: .storyRevision, requestId: requestId, error: reviseStoryError)
            throw reviseStoryError
        }
        if reviseStoryDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: reviseStoryDelayNanoseconds)
        }
        if !reviseStoryResponses.isEmpty {
            let response = reviseStoryResponses.removeFirst()
            emitCompletedTrace(for: .storyRevision, requestId: requestId, statusCode: response.blocked ? 422 : 200)
            return response
        }
        emitCompletedTrace(for: .storyRevision, requestId: requestId, statusCode: reviseStoryResult.blocked ? 422 : 200)
        return reviseStoryResult
    }

    func createEmbeddings(inputs: [String]) async throws -> [[Double]] {
        let requestId = emitStartedTrace(for: .embeddings)
        embeddingInputs.append(inputs)
        if let embeddingsError {
            emitFailureTrace(for: .embeddings, requestId: requestId, error: embeddingsError)
            throw embeddingsError
        }
        emitCompletedTrace(for: .embeddings, requestId: requestId, statusCode: 200)
        return Array(repeating: embeddingsResult.first ?? [0.1, 0.2, 0.3], count: inputs.count)
    }

    private func emitStartedTrace(for operation: APIClientTraceOperation) -> String {
        let requestId = nextTraceRequestId(for: operation)
        traceHandler?(
            APIClientTraceEvent(
                operation: operation,
                phase: .started,
                route: route(for: operation),
                requestId: requestId,
                sessionId: AppSession.currentSessionId,
                statusCode: nil,
                runtimeStage: operation.runtimeStage,
                costDriver: operation.runtimeCostDriver
            )
        )
        return requestId
    }

    private func emitCompletedTrace(
        for operation: APIClientTraceOperation,
        requestId: String,
        statusCode: Int
    ) {
        traceHandler?(
            APIClientTraceEvent(
                operation: operation,
                phase: .completed,
                route: route(for: operation),
                requestId: requestId,
                sessionId: AppSession.currentSessionId,
                statusCode: statusCode,
                runtimeStage: operation.runtimeStage,
                costDriver: operation.runtimeCostDriver,
                durationMs: nextTraceDurationMs()
            )
        )
    }

    private func emitFailureTrace(
        for operation: APIClientTraceOperation,
        requestId: String,
        error: Error
    ) {
        if let apiError = error as? APIError,
           case .invalidResponse(let statusCode, _, _, let responseRequestId, _) = apiError {
            emitCompletedTrace(
                for: operation,
                requestId: responseRequestId ?? requestId,
                statusCode: statusCode
            )
            return
        }

        traceHandler?(
            APIClientTraceEvent(
                operation: operation,
                phase: .transportFailed,
                route: route(for: operation),
                requestId: requestId,
                sessionId: AppSession.currentSessionId,
                statusCode: nil,
                runtimeStage: operation.runtimeStage,
                costDriver: operation.runtimeCostDriver,
                durationMs: nextTraceDurationMs()
            )
        )
    }

    private func nextTraceRequestId(for operation: APIClientTraceOperation) -> String {
        traceRequestCounter += 1
        return "mock-\(operation.rawValue)-\(traceRequestCounter)"
    }

    private func nextTraceDurationMs() -> Int {
        traceRequestCounter += 1
        return traceRequestCounter * 7
    }

    private func route(for operation: APIClientTraceOperation) -> String {
        switch operation {
        case .healthCheck:
            return "/health"
        case .sessionBootstrap:
            return "/v1/session/identity"
        case .voices:
            return "/v1/voices"
        case .realtimeSession:
            return "/v1/realtime/session"
        case .storyDiscovery:
            return "/v1/story/discovery"
        case .storyGeneration:
            return "/v1/story/generate"
        case .storyRevision:
            return "/v1/story/revise"
        case .embeddings:
            return "/v1/embeddings/create"
        }
    }
}

@MainActor
final class MockRealtimeVoiceCore: RealtimeVoiceControlling, StoryNarrationTransporting {
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onTranscriptPartial: ((String) -> Void)?
    var onTranscriptFinal: ((String) -> Void)?
    var onLevels: ((CGFloat, CGFloat) -> Void)?
    var onUserSpeechChanged: ((Bool) -> Void)?
    var onAssistantResponseCompleted: ((String?) -> Void)?
    var onError: ((String) -> Void)?

    private let autoCompleteSpeakIndices: Set<Int>
    var connectError: Error?
    var emitsConnectedOnConnect = true
    var onConnectAction: ((MockRealtimeVoiceCore) -> Void)?
    var narrationPlayDelayNanoseconds: UInt64 = 0

    private(set) var connectCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var disconnectCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0
    private(set) var spokenTexts: [String] = []
    private(set) var spokenUtteranceIDs: [String?] = []
    private var completedPlaybackUtteranceIDs = Set<String>()

    init(autoCompleteSpeakIndices: Set<Int>) {
        self.autoCompleteSpeakIndices = autoCompleteSpeakIndices
    }

    func connect(baseURL: URL, endpointPath: String, session: RealtimeSessionData, installId: String) async throws {
        connectCallCount += 1
        onConnectAction?(self)
        if let connectError {
            throw connectError
        }
        if emitsConnectedOnConnect {
            onConnected?()
        }
    }

    func speak(text: String, utteranceId: String?) async {
        spokenTexts.append(text)
        spokenUtteranceIDs.append(utteranceId)
        if autoCompleteSpeakIndices.contains(spokenTexts.count) {
            if let utteranceId {
                completedPlaybackUtteranceIDs.insert(utteranceId)
            }
            onAssistantResponseCompleted?(utteranceId)
        }
    }

    func prepareScene(_ scene: PreparedNarrationScene) async {}

    func playScene(_ scene: PreparedNarrationScene, utteranceID: String) async -> Bool {
        completedPlaybackUtteranceIDs.remove(utteranceID)
        await speak(text: scene.text, utteranceId: utteranceID)

        let deadline = Date().addingTimeInterval(Double(scene.estimatedDurationSec) + 4)
        while Date() < deadline {
            if completedPlaybackUtteranceIDs.remove(utteranceID) != nil {
                return true
            }
            if Task.isCancelled {
                return false
            }
            try? await Task.sleep(nanoseconds: narrationPlayDelayNanoseconds > 0 ? narrationPlayDelayNanoseconds : 20_000_000)
        }

        return false
    }

    func cancelAssistantSpeech() async {
        cancelCallCount += 1
    }

    func pause() -> Bool {
        pauseCallCount += 1
        return true
    }

    func resume() -> Bool {
        resumeCallCount += 1
        return true
    }

    func invalidatePreparedScenes(keeping cacheKeys: Set<String>) {}

    func stop() {}

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

    func emitAssistantResponseCompleted(_ utteranceId: String?) {
        if let utteranceId {
            completedPlaybackUtteranceIDs.insert(utteranceId)
        }
        onAssistantResponseCompleted?(utteranceId)
    }

    func emitConnected() {
        onConnected?()
    }
}

@MainActor
private final class MockNarrationTransport: StoryNarrationTransporting {
    private var scriptedResults: [Bool]
    let playDelayNanoseconds: UInt64
    private let pollIntervalNanoseconds: UInt64 = 10_000_000
    private var isPaused = false
    private var stopRequested = false
    private var hasActivePlayback = false

    private(set) var playedTexts: [String] = []
    private(set) var playedUtteranceIDs: [String] = []
    private(set) var preparedSceneCacheKeys: Set<String> = []
    private(set) var prepareCallKeys: [String] = []
    private(set) var playedCacheHitKeys: [String] = []
    private(set) var playedCacheMissKeys: [String] = []
    private(set) var invalidatedKeepKeySnapshots: [[String]] = []
    private(set) var stopCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0

    init(scriptedResults: [Bool], playDelayNanoseconds: UInt64 = 0) {
        self.scriptedResults = scriptedResults
        self.playDelayNanoseconds = playDelayNanoseconds
    }

    func prepareScene(_ scene: PreparedNarrationScene) async {
        prepareCallKeys.append(scene.cacheKey)
        preparedSceneCacheKeys.insert(scene.cacheKey)
    }

    func playScene(_ scene: PreparedNarrationScene, utteranceID: String) async -> Bool {
        if preparedSceneCacheKeys.contains(scene.cacheKey) {
            playedCacheHitKeys.append(scene.cacheKey)
        } else {
            playedCacheMissKeys.append(scene.cacheKey)
            preparedSceneCacheKeys.insert(scene.cacheKey)
        }

        playedTexts.append(scene.text)
        playedUtteranceIDs.append(utteranceID)
        isPaused = false
        stopRequested = false
        hasActivePlayback = true

        var elapsedNanoseconds: UInt64 = 0
        while elapsedNanoseconds < playDelayNanoseconds {
            if stopRequested || Task.isCancelled {
                hasActivePlayback = false
                stopRequested = false
                isPaused = false
                return false
            }

            if isPaused {
                try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                continue
            }

            let step = min(pollIntervalNanoseconds, playDelayNanoseconds - elapsedNanoseconds)
            try? await Task.sleep(nanoseconds: step)
            elapsedNanoseconds += step
        }

        if stopRequested || Task.isCancelled {
            hasActivePlayback = false
            stopRequested = false
            isPaused = false
            return false
        }

        hasActivePlayback = false
        if scriptedResults.isEmpty {
            return true
        }
        return scriptedResults.removeFirst()
    }

    func pause() -> Bool {
        guard hasActivePlayback, !isPaused else { return false }
        pauseCallCount += 1
        isPaused = true
        return true
    }

    func resume() -> Bool {
        guard hasActivePlayback, isPaused else { return false }
        resumeCallCount += 1
        isPaused = false
        return true
    }

    func invalidatePreparedScenes(keeping cacheKeys: Set<String>) {
        invalidatedKeepKeySnapshots.append(cacheKeys.sorted())
        preparedSceneCacheKeys = preparedSceneCacheKeys.intersection(cacheKeys)
    }

    func stop() {
        stopCallCount += 1
        stopRequested = true
        isPaused = false
    }
}

private final class StartupURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (URLResponse, Data))?

    static func reset() {
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class HybridRuntimeContractTests: XCTestCase {
    func testHybridRuntimeModeSeparatesInteractionFromNarrationTransportExpectations() {
        let interactionMode = HybridRuntimeMode.interaction(.setupFollowUp(stepNumber: 1))
        let narrationMode = HybridRuntimeMode.narration(sceneIndex: 2)

        XCTAssertTrue(interactionMode.usesRealtimeInteraction)
        XCTAssertFalse(interactionMode.usesLongFormTTS)

        XCTAssertFalse(narrationMode.usesRealtimeInteraction)
        XCTAssertTrue(narrationMode.usesLongFormTTS)
    }

    func testInterruptionIntentOnlyMutatesFutureScenesForRevision() {
        XCTAssertFalse(InterruptionIntent.answerOnly.mutatesFutureScenes)
        XCTAssertTrue(InterruptionIntent.reviseFutureScenes.mutatesFutureScenes)
        XCTAssertFalse(InterruptionIntent.repeatOrClarify.mutatesFutureScenes)
    }

    func testNarrationResumeDecisionPinsSceneBoundaryContract() {
        let answerResume = NarrationResumeDecision.replayCurrentScene(sceneIndex: 3)
        let reviseResume = NarrationResumeDecision.replayCurrentSceneWithRevisedFuture(
            sceneIndex: 3,
            revisedFutureStartIndex: 4
        )
        let continueResume = NarrationResumeDecision.continueToNextScene(sceneIndex: 4)

        XCTAssertEqual(answerResume.sceneIndex, 3)
        XCTAssertEqual(reviseResume.sceneIndex, 3)
        XCTAssertEqual(continueResume.sceneIndex, 4)
        XCTAssertEqual(reviseResume.revisedFutureStartIndex, 4)
        XCTAssertEqual(VoiceSessionState.paused(sceneIndex: 3).phase, .narrating)

        XCTAssertTrue(answerResume.reusesExistingFutureScenes)
        XCTAssertFalse(reviseResume.reusesExistingFutureScenes)
        XCTAssertTrue(continueResume.reusesExistingFutureScenes)
    }

    func testHybridRuntimeStateNodeMapsCurrentCoordinatorStates() {
        XCTAssertEqual(
            VoiceSessionState.ready(VoiceSessionReadyState(mode: .discovery(stepNumber: 2))).hybridRuntimeStateNode,
            .setupInteraction(stepNumber: 2)
        )
        XCTAssertEqual(
            VoiceSessionState.narrating(sceneIndex: 1).hybridRuntimeStateNode,
            .narration(sceneIndex: 1)
        )
        XCTAssertEqual(
            VoiceSessionState.paused(sceneIndex: 1).hybridRuntimeStateNode,
            .narration(sceneIndex: 1)
        )
        XCTAssertEqual(
            VoiceSessionState.interrupting(sceneIndex: 1).hybridRuntimeStateNode,
            .interruptionIntake(sceneIndex: 1)
        )
        XCTAssertEqual(
            VoiceSessionState.revising(sceneIndex: 1, queuedUpdates: 0).hybridRuntimeStateNode,
            .reviseFutureScenes(sceneIndex: 1)
        )
        XCTAssertEqual(VoiceSessionState.completed.hybridRuntimeStateNode, .completed)
        XCTAssertNil(VoiceSessionState.generating.hybridRuntimeStateNode)
    }

    func testHybridRuntimeStateNodeAllowsMainHybridFlow() {
        let setup = HybridRuntimeStateNode.setupInteraction(stepNumber: 1)
        let narration = setup.transition(using: .beginNarration(sceneIndex: 0))
        let interruption = narration?.transition(using: .interruptNarration(sceneIndex: 0))
        let answerOnly = interruption?.transition(using: .routeInterruption(.answerOnly))
        let resumed = answerOnly?.transition(using: .resumeNarration(.replayCurrentScene(sceneIndex: 0)))
        let completion = resumed?.transition(using: .finishNarrationScene(nextSceneIndex: nil))

        XCTAssertEqual(narration, .narration(sceneIndex: 0))
        XCTAssertEqual(interruption, .interruptionIntake(sceneIndex: 0))
        XCTAssertEqual(answerOnly, .answerOnly(sceneIndex: 0))
        XCTAssertEqual(resumed, .narration(sceneIndex: 0))
        XCTAssertEqual(completion, .completed)
    }

    func testHybridRuntimeStateNodeRejectsInvalidHandoffs() {
        let narration = HybridRuntimeStateNode.narration(sceneIndex: 2)
        let interruption = HybridRuntimeStateNode.interruptionIntake(sceneIndex: 2)
        let answerOnly = HybridRuntimeStateNode.answerOnly(sceneIndex: 2)
        let reviseFutureScenes = HybridRuntimeStateNode.reviseFutureScenes(sceneIndex: 2)

        XCTAssertNil(narration.transition(using: .routeInterruption(.answerOnly)))
        XCTAssertNil(interruption.transition(using: .resumeNarration(.replayCurrentScene(sceneIndex: 2))))
        XCTAssertNil(
            answerOnly.transition(
                using: .resumeNarration(
                    .replayCurrentSceneWithRevisedFuture(sceneIndex: 2, revisedFutureStartIndex: 3)
                )
            )
        )
        XCTAssertNil(reviseFutureScenes.transition(using: .resumeNarration(.replayCurrentScene(sceneIndex: 2))))
        XCTAssertNil(HybridRuntimeStateNode.completed.transition(using: .beginNarration(sceneIndex: 0)))
    }

    func testAuthoritativeStorySceneStatePinsCompletedCurrentRemainingAndFutureSlices() throws {
        let story = makeContractStory()
        let sceneState = try XCTUnwrap(story.authoritativeSceneState(at: 1))

        XCTAssertEqual(sceneState.completedScenes.map(\.sceneId), ["scene-1"])
        XCTAssertEqual(sceneState.currentScene.sceneId, "scene-2")
        XCTAssertEqual(sceneState.remainingScenes.map(\.sceneId), ["scene-2", "scene-3"])
        XCTAssertEqual(sceneState.futureScenes.map(\.sceneId), ["scene-3"])
        XCTAssertEqual(sceneState.currentBoundary, StorySceneBoundary(sceneIndex: 1, sceneId: "scene-2"))
    }

    func testAnswerContextIsReadOnlyProjectionOfAuthoritativeSceneState() throws {
        let story = makeContractStory()
        let sceneState = try XCTUnwrap(story.authoritativeSceneState(at: 1))
        let answerContext = sceneState.answerContext

        XCTAssertEqual(answerContext.storyId, story.storyId)
        XCTAssertEqual(answerContext.storyTitle, story.title)
        XCTAssertEqual(answerContext.currentBoundary, StorySceneBoundary(sceneIndex: 1, sceneId: "scene-2"))
        XCTAssertEqual(answerContext.completedScenes.map(\.sceneId), ["scene-1"])
        XCTAssertEqual(answerContext.remainingScenes.map(\.sceneId), ["scene-2", "scene-3"])
        XCTAssertEqual(answerContext.futureScenes.map(\.sceneId), ["scene-3"])
        XCTAssertEqual(answerContext.mutationScope, .none)
    }

    func testRevisionBoundaryPreservesCurrentSceneAndMutatesFutureScenesOnly() throws {
        let story = makeContractStory()
        let sceneState = try XCTUnwrap(story.authoritativeSceneState(at: 1))
        let revisionBoundary = try XCTUnwrap(sceneState.revisionBoundary)
        let request = revisionBoundary.makeRequest(userUpdate: "Make the ending sillier")

        XCTAssertEqual(revisionBoundary.resumeBoundary, StorySceneBoundary(sceneIndex: 1, sceneId: "scene-2"))
        XCTAssertEqual(revisionBoundary.preservedScenes.map(\.sceneId), ["scene-1", "scene-2"])
        XCTAssertEqual(revisionBoundary.futureScenes.map(\.sceneId), ["scene-3"])
        XCTAssertEqual(revisionBoundary.mutationScope, .futureScenes(startingAt: 2))
        XCTAssertEqual(
            revisionBoundary.narrationResumeDecision,
            .replayCurrentSceneWithRevisedFuture(sceneIndex: 1, revisedFutureStartIndex: 2)
        )

        XCTAssertEqual(request.currentSceneIndex, 2)
        XCTAssertEqual(request.completedScenes.map(\.sceneId), ["scene-1", "scene-2"])
        XCTAssertEqual(request.remainingScenes.map(\.sceneId), ["scene-3"])
        XCTAssertEqual(request.userUpdate, "Make the ending sillier")
    }

    func testRevisionBoundaryIsUnavailableAtFinalSceneBecauseNoFutureScenesRemain() throws {
        let story = makeContractStory()
        let sceneState = try XCTUnwrap(story.authoritativeSceneState(at: 2))

        XCTAssertNil(sceneState.revisionBoundary)
    }

    func testInterruptionIntentRouterClassifiesAnswerOnlyQuestion() throws {
        let story = makeContractStory()
        let sceneState = try XCTUnwrap(story.authoritativeSceneState(at: 1))
        let decision = try XCTUnwrap(
            InterruptionIntentRouter.classify(
                transcript: "Why is Bunny carrying the lantern?",
                sceneState: sceneState
            )
        )

        XCTAssertEqual(decision.transcript, "Why is Bunny carrying the lantern?")
        XCTAssertEqual(decision.intent, .answerOnly)
        XCTAssertTrue(decision.canApplyImmediately)
        XCTAssertNil(decision.revisionBoundary)
        XCTAssertEqual(decision.answerContext.currentBoundary, StorySceneBoundary(sceneIndex: 1, sceneId: "scene-2"))
    }

    func testInterruptionIntentRouterClassifiesRepeatOrClarifyCue() throws {
        let story = makeContractStory()
        let sceneState = try XCTUnwrap(story.authoritativeSceneState(at: 1))
        let decision = try XCTUnwrap(
            InterruptionIntentRouter.classify(
                transcript: "Can you repeat that again please?",
                sceneState: sceneState
            )
        )

        XCTAssertEqual(decision.intent, .repeatOrClarify)
        XCTAssertTrue(decision.canApplyImmediately)
        XCTAssertNil(decision.revisionBoundary)
        XCTAssertEqual(decision.answerContext.futureScenes.map(\.sceneId), ["scene-3"])
    }

    func testInterruptionIntentRouterClassifiesReviseFutureScenesMutationRequest() throws {
        let story = makeContractStory()
        let sceneState = try XCTUnwrap(story.authoritativeSceneState(at: 1))
        let decision = try XCTUnwrap(
            InterruptionIntentRouter.classify(
                transcript: "Instead, can they visit the stars next?",
                sceneState: sceneState
            )
        )

        XCTAssertEqual(decision.intent, .reviseFutureScenes)
        XCTAssertTrue(decision.canApplyImmediately)
        XCTAssertEqual(decision.revisionBoundary?.resumeBoundary, StorySceneBoundary(sceneIndex: 1, sceneId: "scene-2"))
        XCTAssertEqual(decision.revisionBoundary?.futureScenes.map(\.sceneId), ["scene-3"])
    }

    func testInterruptionIntentRouterMarksRevisionUnavailableWhenNoFutureScenesRemain() throws {
        let story = makeContractStory()
        let sceneState = try XCTUnwrap(story.authoritativeSceneState(at: 2))
        let decision = try XCTUnwrap(
            InterruptionIntentRouter.classify(
                transcript: "Change what happens next so they fly home.",
                sceneState: sceneState
            )
        )

        XCTAssertEqual(decision.intent, .reviseFutureScenes)
        XCTAssertFalse(decision.canApplyImmediately)
        XCTAssertNil(decision.revisionBoundary)
        XCTAssertEqual(decision.answerContext.currentBoundary, StorySceneBoundary(sceneIndex: 2, sceneId: "scene-3"))
    }

    func testNarrationUsesDedicatedTransportInsteadOfRealtimeVoiceOutput() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a lantern picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a lantern picnic story"
                )
            )
        ]
        api.generateStoryResult = makeNarrationEnvelope()

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true])
        let store = StoryLibraryStore()
        let plan = makeNarrationPlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a lantern picnic story")

        await waitUntil { viewModel.phase == ConversationPhase.completed }

        let spokenTexts = voice.spokenTexts
        let playedTexts = narrationTransport.playedTexts

        XCTAssertEqual(spokenTexts.count, 1)
        XCTAssertTrue(try XCTUnwrap(spokenTexts.first).contains("Tell me what kind"))
        XCTAssertEqual(playedTexts, [
            "Bunny and Fox padded into the glowing grove with a picnic basket full of treats.",
            "They shared lantern light, laughed softly, and headed home with cozy hearts."
        ])
    }

    func testNarrationTransportAdvancesScenesUnderCoordinatorControl() async throws {
        let api = MockAPIClient()
        api.discoveryResponses = [
            DiscoveryEnvelope(
                blocked: false,
                safeMessage: nil,
                data: DiscoveryData(
                    slotState: DiscoverySlotState(
                        theme: "a lantern picnic",
                        characters: ["Bunny", "Fox"],
                        setting: "the moonlit park",
                        tone: "cozy",
                        episodeIntent: "a happy standalone adventure"
                    ),
                    questionCount: 1,
                    readyToGenerate: true,
                    assistantMessage: "I have enough details now.",
                    transcript: "Tell a lantern picnic story"
                )
            )
        ]
        api.generateStoryResult = makeNarrationEnvelope()

        let voice = MockRealtimeVoiceCore(autoCompleteSpeakIndices: [1])
        let narrationTransport = MockNarrationTransport(scriptedResults: [true, true], playDelayNanoseconds: 80_000_000)
        let store = StoryLibraryStore()
        let plan = makeNarrationPlan(childProfileId: try XCTUnwrap(store.activeProfile?.id))
        let viewModel = PracticeSessionViewModel(
            plan: plan,
            sourceSeries: nil,
            store: store,
            api: api,
            voiceCore: voice,
            narrationTransport: narrationTransport,
            forceMockVoiceCore: false
        )

        await viewModel.startSession()
        voice.emitTranscriptFinal("Tell a lantern picnic story")

        await waitUntil {
            if case .narrating(sceneIndex: 0) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 1
            }
            return false
        }

        await waitUntil {
            if case .narrating(sceneIndex: 1) = viewModel.sessionState {
                return narrationTransport.playedUtteranceIDs.count == 2
            }
            return false
        }

        await waitUntil { viewModel.phase == ConversationPhase.completed }

        let playedUtteranceIDs = narrationTransport.playedUtteranceIDs
        XCTAssertEqual(playedUtteranceIDs, ["scene-0-2", "scene-1-3"])
        XCTAssertEqual(viewModel.currentSceneIndex, 1)
    }

    private func makeContractStory() -> StoryData {
        StoryData(
            storyId: "2D289B18-89EA-4C2B-8A22-BB87D25A3790",
            title: "Moonlight Picnic",
            estimatedDurationSec: 180,
            scenes: [
                StoryScene(sceneId: "scene-1", text: "Scene one", durationSec: 30),
                StoryScene(sceneId: "scene-2", text: "Scene two", durationSec: 30),
                StoryScene(sceneId: "scene-3", text: "Scene three", durationSec: 30)
            ],
            safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
            engine: nil
        )
    }

    private func makeNarrationPlan(childProfileId: UUID) -> StoryLaunchPlan {
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

    private func makeNarrationEnvelope() -> GenerateStoryEnvelope {
        GenerateStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: StoryData(
                storyId: "2D289B18-89EA-4C2B-8A22-BB87D25A3790",
                title: "Lantern Picnic",
                estimatedDurationSec: 180,
                scenes: [
                    StoryScene(
                        sceneId: "1",
                        text: "Bunny and Fox padded into the glowing grove with a picnic basket full of treats.",
                        durationSec: 30
                    ),
                    StoryScene(
                        sceneId: "2",
                        text: "They shared lantern light, laughed softly, and headed home with cozy hearts.",
                        durationSec: 30
                    )
                ],
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: nil
            )
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        pollIntervalNanoseconds: UInt64 = 20_000_000,
        _ predicate: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() {
                return
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        XCTFail("Timed out waiting for condition")
    }
}
