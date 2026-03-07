import AVFoundation
import CoreGraphics
import Foundation
import OSLog

@MainActor
final class PracticeSessionViewModel: ObservableObject {
    private enum SessionEvent {
        case startRequested
        case transcriptPartial(String)
        case transcriptFinal(String)
        case userSpeechChanged(Bool)
        case assistantSpeechCompleted(String?)
        case discoveryResolved(requestID: Int, Result<DiscoveryEnvelope, Error>)
        case generationResolved(requestID: Int, Result<GenerateStoryEnvelope, Error>)
        case revisionResolved(requestID: Int, sceneIndex: Int, Result<ReviseStoryEnvelope, Error>)
        case narrationSceneFinished(utteranceID: String, sceneIndex: Int)
        case disconnected
        case voiceError(String)
    }

    private enum CompletionSaveStrategy {
        case none
        case add(characters: [String])
        case replaceExisting
    }

    enum StartupFailure: String, Equatable {
        case healthCheck
        case sessionBootstrap
        case realtimeSession
        case bridgeReadiness
        case callConnect
        case disconnectBeforeReady

        var statusMessage: String {
            switch self {
            case .healthCheck, .callConnect:
                return "Connection failed"
            case .sessionBootstrap, .realtimeSession:
                return "Session unavailable"
            case .bridgeReadiness:
                return "Voice unavailable"
            case .disconnectBeforeReady:
                return "Voice session disconnected"
            }
        }

        var userMessage: String {
            switch self {
            case .healthCheck:
                return "I couldn't reach StoryTime right now. Please try again in a moment."
            case .sessionBootstrap:
                return "I couldn't start the live story session right now. Please try again."
            case .realtimeSession:
                return "I couldn't prepare the live story session right now. Please try again."
            case .bridgeReadiness:
                return "The live storyteller isn't ready yet. Please try again."
            case .callConnect:
                return "I couldn't connect the live storyteller right now. Please try again."
            case .disconnectBeforeReady:
                return "The live storyteller disconnected before it was ready. Please try again."
            }
        }
    }

    private enum StartupStage {
        case healthCheck
        case sessionBootstrap
        case realtimeSession
        case callConnect
    }

    private enum SessionFailureContext {
        case discovery
        case generation
        case revision(sceneIndex: Int)
        case voiceRuntime
        case disconnected

        var failureReason: String {
            switch self {
            case .discovery:
                return "discovery failed"
            case .generation:
                return "generation failed"
            case .revision:
                return "revision failed"
            case .voiceRuntime:
                return "voice runtime error"
            case .disconnected:
                return "voice disconnected"
            }
        }
    }

    private struct StartupAttempt {
        let id: Int
        var stage: StartupStage
    }

    private enum GenerationStartSource {
        case discoveryResolved(requestID: Int)
        case mockDiscoveryCompleted(stepNumber: Int)

        var eventName: String {
            switch self {
            case .discoveryResolved:
                return "startGenerationFromDiscoveryResolved"
            case .mockDiscoveryCompleted:
                return "startGenerationFromMockDiscovery"
            }
        }
    }

    private enum NarrationStartSource {
        case replayFromBoot
        case generationResolved
        case revisionResolved(sceneIndex: Int)
        case continueAfterScene(sceneIndex: Int)

        var eventName: String {
            switch self {
            case .replayFromBoot:
                return "startNarrationFromReplayBoot"
            case .generationResolved:
                return "startNarrationFromGenerationResolved"
            case .revisionResolved:
                return "startNarrationFromRevisionResolved"
            case .continueAfterScene:
                return "startNarrationFromSceneCompletion"
            }
        }
    }

    private enum DeferredTranscriptPolicy {
        case rejectIfSessionLeaves(ConversationPhase)

        var eventName: String {
            switch self {
            case .rejectIfSessionLeaves(let phase):
                return "transcriptFinalDeferredFrom\(phase.rawValue.capitalized)"
            }
        }
    }

    enum SessionTraceKind: String, Equatable {
        case startup
        case discovery
        case generation
        case revision
        case completion
        case failure
    }

    struct SessionTraceEvent: Equatable {
        let kind: SessionTraceKind
        let source: String
        let state: String
        let requestId: String?
        let sessionId: String?
        let apiOperation: APIClientTraceOperation?
        let statusCode: Int?
    }

    @Published var voices: [String] = []
    @Published var selectedVoice: String = "alloy"
    @Published private(set) var sessionState: VoiceSessionState = .idle
    @Published var activeSpeaker: VoiceSpeaker = .idle
    @Published var waveformPhase: CGFloat = 0
    @Published var microphoneLevel: CGFloat = 0
    @Published var aiVoiceLevel: CGFloat = 0

    @Published var aiPrompt: String = "Starting story conversation..."
    @Published var statusMessage: String = ""
    @Published var followUpQuestionCount: Int = 0
    @Published var generatedStory: StoryData?
    @Published var nowNarratingText: String = ""
    @Published var currentSceneIndex: Int = 0
    @Published var errorMessage: String = ""
    @Published var latestUserTranscript: String = ""
    @Published private(set) var lastAppError: StoryTimeAppError?

    let launchPlan: StoryLaunchPlan
    let realtimeVoiceClient: RealtimeVoiceClient?

    private let sourceSeries: StorySeries?
    private let store: StoryLibraryStore
    private let continuityMemory: ContinuityMemoryStore
    private let api: APIClienting
    private let voiceCore: RealtimeVoiceControlling
    private let usesMockVoiceCore: Bool

    private var discoverySlots = DiscoverySlotState()
    private var scenePlaybackTask: Task<Void, Never>?
    private var waveTimer: Timer?
    private var discoveryFallbackTask: Task<Void, Never>?
    private var completionSaveStrategy: CompletionSaveStrategy = .none
    private var completionSaveDidRun = false
    private var queuedRevisionUpdates: [String] = []
    private var completedUtteranceIDs = Set<String>()
    private var activeDiscoveryRequestID: Int?
    private var activeGenerationRequestID: Int?
    private var activeRevisionRequestID: Int?
    private var activeNarrationUtteranceID: String?
    private var activePromptUtteranceID: String?
    private var deferredTranscriptPolicy: DeferredTranscriptPolicy?
    private var operationCounter = 0
    private var utteranceCounter = 0

    internal private(set) var invalidTransitionMessages: [String] = []
    internal private(set) var lastStartupFailure: StartupFailure?
    internal private(set) var traceEvents: [SessionTraceEvent] = []

    private static let logger = Logger(subsystem: "com.tuesday.storytime", category: "VoiceSession")
    private static let maxQueuedRevisionUpdates = 1
    private static let networkErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .networkConnectionLost,
        .notConnectedToInternet,
        .dataNotAllowed,
        .internationalRoamingOff,
        .secureConnectionFailed,
        .cannotLoadFromNetwork,
        .resourceUnavailable
    ]
    private var activeStartupAttempt: StartupAttempt?
    private var latestAPITraceByOperation: [APIClientTraceOperation: APIClientTraceEvent] = [:]

    init(
        plan: StoryLaunchPlan,
        sourceSeries: StorySeries?,
        store: StoryLibraryStore,
        continuityMemory: ContinuityMemoryStore = .shared,
        api: APIClienting = APIClient(),
        realtimeVoiceClient: RealtimeVoiceClient? = nil,
        voiceCore: RealtimeVoiceControlling? = nil,
        forceMockVoiceCore: Bool? = nil
    ) {
        self.launchPlan = plan
        self.sourceSeries = sourceSeries
        self.store = store
        self.continuityMemory = continuityMemory
        self.api = api
        let resolvedRealtimeClient = realtimeVoiceClient ?? (voiceCore as? RealtimeVoiceClient)
        let resolvedVoiceCore = voiceCore ?? resolvedRealtimeClient ?? RealtimeVoiceClient()
        self.realtimeVoiceClient = resolvedRealtimeClient ?? (resolvedVoiceCore as? RealtimeVoiceClient)
        self.voiceCore = resolvedVoiceCore
        self.usesMockVoiceCore = forceMockVoiceCore ?? (ProcessInfo.processInfo.environment["STORYTIME_UI_TEST_MODE"] == "1")

        bindAPITraceEvents()
        bindRealtimeEvents()
        startWaveTimer()
    }

    deinit {
        scenePlaybackTask?.cancel()
        discoveryFallbackTask?.cancel()
        waveTimer?.invalidate()
    }

    var childName: String {
        sessionProfile?.displayName ?? "Story Explorer"
    }

    var modeTitle: String {
        launchPlan.experienceMode.title
    }

    var phase: ConversationPhase {
        sessionState.phase
    }

    var privacySummary: String {
        if store.privacySettings.clearTranscriptsAfterSession {
            return "Live conversation is on. Raw audio is not saved. Spoken prompts are sent for live processing, and the on-screen transcript clears when the session ends."
        }
        return "Live conversation is on. Raw audio is not saved. Spoken prompts are sent for live processing."
    }

    func startSession() async {
        await process(.startRequested)
    }

    func childDidSpeak() async {
        guard usesMockVoiceCore else { return }

        switch sessionState {
        case .ready(let readyState):
            switch readyState.mode {
            case .discovery:
                await captureMockFollowUpAnswer()
            }
        case .narrating(let sceneIndex):
            await beginNarrationInterruption(at: sceneIndex, immediateUserUpdate: scriptedUpdateRequest())
        case .idle, .booting, .discovering, .generating, .interrupting, .revising, .completed, .failed:
            break
        }
    }

    private func process(_ event: SessionEvent) async {
        switch event {
        case .startRequested:
            await handleStartRequested()
        case .transcriptPartial(let text):
            handleTranscriptPartial(text)
        case .transcriptFinal(let text):
            await handleTranscriptFinal(text)
        case .userSpeechChanged(let speaking):
            guard speaking else { return }
            await handleUserSpeechStarted()
        case .assistantSpeechCompleted(let utteranceID):
            handleAssistantSpeechCompleted(utteranceID)
        case .discoveryResolved(let requestID, let result):
            await handleDiscoveryResolved(requestID: requestID, result: result)
        case .generationResolved(let requestID, let result):
            await handleGenerationResolved(requestID: requestID, result: result)
        case .revisionResolved(let requestID, let sceneIndex, let result):
            await handleRevisionResolved(requestID: requestID, sceneIndex: sceneIndex, result: result)
        case .narrationSceneFinished(let utteranceID, let sceneIndex):
            await handleNarrationSceneFinished(utteranceID: utteranceID, sceneIndex: sceneIndex)
        case .disconnected:
            await handleDisconnected()
        case .voiceError(let message):
            await handleVoiceError(message)
        }
    }

    private func handleStartRequested() async {
        guard sessionState.canStartSession else {
            logInvalidTransition(event: "startRequested", state: sessionState)
            return
        }

        resetForNewSession()
        setSessionState(.booting, reason: "session start")

        if usesMockVoiceCore {
            if voices.isEmpty {
                voices = ["alloy"]
                selectedVoice = "alloy"
            }
            statusMessage = "Demo voice session"
            recordTrace(.startup, source: "mockVoiceSession")
            await beginLaunchFlow()
            return
        }

        let startupAttemptID = nextOperationID()
        activeStartupAttempt = StartupAttempt(id: startupAttemptID, stage: .healthCheck)

        do {
            let connectedURL = try await api.prepareConnection()
            guard isStartupAttemptActive(startupAttemptID) else { return }

            updateStartupStage(.sessionBootstrap, attemptID: startupAttemptID)
            try await api.bootstrapSessionIdentity(baseURL: connectedURL)
            guard isStartupAttemptActive(startupAttemptID) else { return }

            updateStartupStage(.realtimeSession, attemptID: startupAttemptID)
            if voices.isEmpty {
                voices = try await api.fetchVoices()
                selectedVoice = voices.first ?? "alloy"
            }
            guard isStartupAttemptActive(startupAttemptID) else { return }

            let envelope = try await api.createRealtimeSession(
                request: RealtimeSessionRequest(
                    childProfileId: launchPlan.childProfileId.uuidString,
                    voice: selectedVoice,
                    region: api.resolvedRegion ?? .us
                )
            )
            guard isStartupAttemptActive(startupAttemptID) else { return }

            statusMessage = "Connecting live voice"
            updateStartupStage(.callConnect, attemptID: startupAttemptID)
            try await voiceCore.connect(
                baseURL: connectedURL,
                endpointPath: envelope.endpoint,
                session: envelope.session,
                installId: AppInstall.identity
            )
            guard isStartupAttemptActive(startupAttemptID) else { return }

            activeStartupAttempt = nil
            statusMessage = "Live conversation is on"
            recordTrace(.startup, source: "connected", operation: .realtimeSession)
            await beginLaunchFlow()
        } catch {
            failStartupAttemptIfNeeded(error, attemptID: startupAttemptID)
        }
    }

    private func handleTranscriptPartial(_ text: String) {
        latestUserTranscript = text

        switch sessionState {
        case .ready, .interrupting, .revising:
            activeSpeaker = .child
            statusMessage = "Listening..."
        case .narrating:
            activeSpeaker = .child
            statusMessage = "Listening for a story update"
        case .idle, .booting, .discovering, .generating, .completed, .failed:
            break
        }
    }

    private func handleTranscriptFinal(_ transcript: String) async {
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        latestUserTranscript = clean

        if let deferredTranscriptPolicy {
            self.deferredTranscriptPolicy = nil

            switch deferredTranscriptPolicy {
            case .rejectIfSessionLeaves(let expectedPhase):
                guard sessionState.phase == expectedPhase else {
                    logInvalidTransition(event: deferredTranscriptPolicy.eventName, state: sessionState)
                    return
                }
            }
        }

        switch sessionState {
        case .ready(let readyState):
            switch readyState.mode {
            case .discovery:
                startDiscoveryRequest(transcript: clean)
            }
        case .narrating(let sceneIndex):
            await beginNarrationInterruption(at: sceneIndex, immediateUserUpdate: clean)
        case .interrupting(let sceneIndex):
            startRevisionRequest(userUpdate: clean, sceneIndex: sceneIndex)
        case .revising(let sceneIndex, _):
            queueRevisionUpdate(clean, sceneIndex: sceneIndex)
        case .idle, .booting, .discovering, .generating, .completed, .failed:
            logInvalidTransition(event: "transcriptFinal", state: sessionState)
        }
    }

    private func handleUserSpeechStarted() async {
        switch sessionState {
        case .ready:
            if !usesMockVoiceCore {
                await voiceCore.cancelAssistantSpeech()
            }
            activeSpeaker = .child
            statusMessage = "Listening..."

        case .narrating(let sceneIndex):
            await beginNarrationInterruption(at: sceneIndex, immediateUserUpdate: nil)

        case .interrupting:
            activeSpeaker = .child

        case .revising:
            deferredTranscriptPolicy = .rejectIfSessionLeaves(.revising)
            activeSpeaker = .child
            statusMessage = "Finishing the current story update"

        case .generating:
            deferredTranscriptPolicy = .rejectIfSessionLeaves(.generating)
            activeSpeaker = .child
            statusMessage = "Finishing the story"

        case .idle, .booting, .discovering, .completed, .failed:
            break
        }
    }

    private func handleAssistantSpeechCompleted(_ utteranceID: String?) {
        if let utteranceID {
            completedUtteranceIDs.insert(utteranceID)
            return
        }

        if let activePromptUtteranceID {
            completedUtteranceIDs.insert(activePromptUtteranceID)
            return
        }

        if let activeNarrationUtteranceID {
            completedUtteranceIDs.insert(activeNarrationUtteranceID)
        }
    }

    private func handleDiscoveryResolved(requestID: Int, result: Result<DiscoveryEnvelope, Error>) async {
        guard activeDiscoveryRequestID == requestID else {
            logStaleResult(kind: "discovery", requestID: requestID)
            return
        }
        activeDiscoveryRequestID = nil

        guard case .discovering(let activeTurnID) = sessionState, activeTurnID == requestID else {
            logInvalidTransition(event: "discoveryResolved", state: sessionState)
            return
        }

        switch result {
        case .failure(let error):
            handleSessionFailure(error, context: .discovery)

        case .success(let envelope):
            mergeDiscoverySlots(from: envelope.data.slotState)
            followUpQuestionCount = min(3, envelope.data.questionCount)

            if envelope.blocked {
                noteModerationBlock(
                    userMessage: envelope.safeMessage ?? envelope.data.assistantMessage,
                    statusMessage: "Safety adjustment"
                )
                let stepNumber = max(1, followUpQuestionCount + 1)
                setSessionState(
                    .ready(VoiceSessionReadyState(mode: .discovery(stepNumber: stepNumber))),
                    reason: "blocked discovery fallback"
                )
                recordTrace(.discovery, source: "blocked", operation: .storyDiscovery)
                await deliverDiscoveryPrompt(
                    envelope.safeMessage ?? envelope.data.assistantMessage,
                    stepNumber: stepNumber
                )
                return
            }

            if envelope.data.readyToGenerate {
                recordTrace(.discovery, source: "readyToGenerate", operation: .storyDiscovery)
                startGenerationRequest(source: .discoveryResolved(requestID: requestID))
                return
            }

            let stepNumber = max(1, followUpQuestionCount + 1)
            setSessionState(
                .ready(VoiceSessionReadyState(mode: .discovery(stepNumber: stepNumber))),
                reason: "awaiting next discovery answer"
            )
            recordTrace(.discovery, source: "followUp", operation: .storyDiscovery)
            await deliverDiscoveryPrompt(envelope.data.assistantMessage, stepNumber: stepNumber)
        }
    }

    private func handleGenerationResolved(requestID: Int, result: Result<GenerateStoryEnvelope, Error>) async {
        guard activeGenerationRequestID == requestID else {
            logStaleResult(kind: "generation", requestID: requestID)
            return
        }
        activeGenerationRequestID = nil

        guard case .generating = sessionState else {
            logInvalidTransition(event: "generationResolved", state: sessionState)
            return
        }

        switch result {
        case .failure(let error):
            handleSessionFailure(error, context: .generation)

        case .success(let envelope):
            generatedStory = envelope.data
            nowNarratingText = ""

            if case .none = completionSaveStrategy {
                completionSaveStrategy = .add(characters: charactersSlot)
            }

            statusMessage = envelope.blocked
                ? (envelope.safeMessage ?? "Story generated with safety adjustments")
                : "Story ready"
            if envelope.blocked {
                noteModerationBlock(
                    userMessage: envelope.safeMessage ?? "Story generated with safety adjustments",
                    statusMessage: "Story adjusted for safety"
                )
            }

            recordTrace(.generation, source: envelope.blocked ? "blocked" : "resolved", operation: .storyGeneration)
            await startNarration(from: 0, source: .generationResolved)
        }
    }

    private func handleRevisionResolved(
        requestID: Int,
        sceneIndex: Int,
        result: Result<ReviseStoryEnvelope, Error>
    ) async {
        guard activeRevisionRequestID == requestID else {
            logStaleResult(kind: "revision", requestID: requestID)
            return
        }
        activeRevisionRequestID = nil

        guard case .revising(let activeSceneIndex, _) = sessionState, activeSceneIndex == sceneIndex else {
            logInvalidTransition(event: "revisionResolved", state: sessionState)
            return
        }

        switch result {
        case .failure(let error):
            queuedRevisionUpdates.removeAll()
            handleSessionFailure(error, context: .revision(sceneIndex: sceneIndex))

        case .success(let envelope):
            guard let currentStory = generatedStory else {
                failSession(
                    message: "Missing story during revision.",
                    status: "Session failed",
                    reason: "revision missing story"
                )
                return
            }

            let mergedScenes = Array(currentStory.scenes.prefix(sceneIndex)) + envelope.data.scenes
            let updated = StoryData(
                storyId: currentStory.storyId,
                title: currentStory.title,
                estimatedDurationSec: currentStory.estimatedDurationSec,
                scenes: mergedScenes,
                safety: envelope.data.safety,
                engine: envelope.data.engine ?? currentStory.engine
            )

            generatedStory = updated
            nowNarratingText = ""

            switch launchPlan.mode {
            case .repeatEpisode:
                completionSaveStrategy = .replaceExisting
            case .new, .extend:
                if case .none = completionSaveStrategy {
                    completionSaveStrategy = .add(characters: charactersSlot)
                }
            }

            if envelope.data.revisedFromSceneIndex != sceneIndex {
                logUnexpectedRevisionIndex(expected: sceneIndex, actual: envelope.data.revisedFromSceneIndex)
            }

            recordTrace(.revision, source: envelope.blocked ? "blocked" : "resolved", operation: .storyRevision)
            if !queuedRevisionUpdates.isEmpty {
                let nextUpdate = queuedRevisionUpdates.removeFirst()
                submitRevisionRequest(nextUpdate, sceneIndex: sceneIndex, story: updated)
                return
            }

            statusMessage = envelope.blocked
                ? (envelope.safeMessage ?? "Update was softened for safety.")
                : "Story updated. Continuing narration."
            if envelope.blocked {
                noteModerationBlock(
                    userMessage: envelope.safeMessage ?? "Update was softened for safety.",
                    statusMessage: "Update adjusted for safety"
                )
            }

            await startNarration(from: sceneIndex, source: .revisionResolved(sceneIndex: sceneIndex))
        }
    }

    private func handleNarrationSceneFinished(utteranceID: String, sceneIndex: Int) async {
        guard activeNarrationUtteranceID == utteranceID else {
            logStaleNarrationCompletion(utteranceID: utteranceID, sceneIndex: sceneIndex)
            return
        }
        activeNarrationUtteranceID = nil

        guard case .narrating(let currentSceneIndex) = sessionState, currentSceneIndex == sceneIndex else {
            logInvalidTransition(event: "narrationSceneFinished", state: sessionState)
            return
        }

        guard let story = generatedStory else {
            failSession(
                message: "Missing story during narration.",
                status: "Session failed",
                reason: "narration missing story"
            )
            return
        }

        let nextSceneIndex = sceneIndex + 1
        if nextSceneIndex < story.scenes.count {
            await startNarration(from: nextSceneIndex, source: .continueAfterScene(sceneIndex: sceneIndex))
        } else {
            completeSession()
        }
    }

    private func handleVoiceError(_ message: String) async {
        guard !sessionState.isTerminal else { return }

        if case .booting = sessionState {
            failStartupAttemptIfNeeded(.callConnect, reason: "voice startup error")
            return
        }

        presentAppFailure(voiceRuntimeAppError(for: message), reason: SessionFailureContext.voiceRuntime.failureReason)
    }

    private func handleDisconnected() async {
        guard !sessionState.isTerminal else {
            activeSpeaker = .idle
            return
        }

        if case .booting = sessionState {
            failStartupAttemptIfNeeded(.disconnectBeforeReady, reason: "voice disconnected before ready")
            return
        }

        presentAppFailure(disconnectedAppError(), reason: SessionFailureContext.disconnected.failureReason)
    }

    private func bindRealtimeEvents() {
        voiceCore.onConnected = { [weak self] in
            guard let self, !self.sessionState.isTerminal else { return }
            guard case .booting = self.sessionState else {
                self.statusMessage = "Live conversation is on"
                return
            }
        }

        voiceCore.onDisconnected = { [weak self] in
            guard let self else { return }
            if case .booting = self.sessionState {
                self.failStartupAttemptIfNeeded(.disconnectBeforeReady, reason: "voice disconnected before ready")
                return
            }
            Task { @MainActor in
                await self.process(.disconnected)
            }
        }

        voiceCore.onTranscriptPartial = { [weak self] text in
            Task { @MainActor in
                await self?.process(.transcriptPartial(text))
            }
        }

        voiceCore.onTranscriptFinal = { [weak self] text in
            Task { @MainActor in
                await self?.process(.transcriptFinal(text))
            }
        }

        voiceCore.onLevels = { [weak self] local, remote in
            Task { @MainActor in
                self?.handleAudioLevels(local: local, remote: remote)
            }
        }

        voiceCore.onUserSpeechChanged = { [weak self] speaking in
            Task { @MainActor in
                await self?.process(.userSpeechChanged(speaking))
            }
        }

        voiceCore.onAssistantResponseCompleted = { [weak self] utteranceID in
            Task { @MainActor in
                await self?.process(.assistantSpeechCompleted(utteranceID))
            }
        }

        voiceCore.onError = { [weak self] message in
            guard let self else { return }
            if case .booting = self.sessionState {
                self.failStartupAttemptIfNeeded(.callConnect, reason: "voice startup error")
                return
            }
            Task { @MainActor in
                await self.process(.voiceError(message))
            }
        }
    }

    private func beginLaunchFlow() async {
        switch launchPlan.mode {
        case .repeatEpisode:
            if let episode = sourceSeries?.latestEpisode {
                generatedStory = StoryData(
                    storyId: episode.storyId,
                    title: episode.title,
                    estimatedDurationSec: episode.estimatedDurationSec,
                    scenes: episode.scenes,
                    safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                    engine: episode.engine
                )
                completionSaveStrategy = .none
                aiPrompt = "Replaying the latest episode now."
                statusMessage = "Story ready"
                await startNarration(from: 0, source: .replayFromBoot)
            } else {
                completeSession(
                    status: "Story unavailable",
                    prompt: "I couldn't find an episode to replay. Start a new story instead."
                )
            }

        case .new, .extend:
            await beginDiscoveryConversation()
        }
    }

    private func beginDiscoveryConversation() async {
        followUpQuestionCount = 0
        latestUserTranscript = ""
        discoverySlots = DiscoverySlotState(
            theme: nil,
            characters: [],
            setting: nil,
            tone: nil,
            episodeIntent: seededEpisodeIntent()
        )

        setSessionState(
            .ready(VoiceSessionReadyState(mode: .discovery(stepNumber: 1))),
            reason: "discovery started"
        )
        await deliverDiscoveryPrompt(discoveryOpeningPrompt(), stepNumber: 1)
    }

    private func deliverDiscoveryPrompt(_ text: String, stepNumber: Int) async {
        aiPrompt = text
        activeSpeaker = .ai
        statusMessage = "Voice input step \(min(3, stepNumber)) of 3"
        discoveryFallbackTask?.cancel()

        let utteranceID = nextUtteranceID(prefix: "prompt-\(stepNumber)")
        activePromptUtteranceID = utteranceID

        if usesMockVoiceCore {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard activePromptUtteranceID == utteranceID else { return }
            completeDiscoveryPromptIfStillCurrent(stepNumber: stepNumber, utteranceID: utteranceID)
            scheduleMockDiscoveryFallback(forStep: stepNumber)
            return
        }

        _ = await speakAndAwaitCompletion(text: text, utteranceID: utteranceID, timeoutSeconds: 8)
        guard activePromptUtteranceID == utteranceID else { return }
        completeDiscoveryPromptIfStillCurrent(stepNumber: stepNumber, utteranceID: utteranceID)
    }

    private func completeDiscoveryPromptIfStillCurrent(stepNumber: Int, utteranceID: String) {
        guard case .ready(let readyState) = sessionState else { return }
        guard readyState.mode == .discovery(stepNumber: stepNumber) else { return }
        guard activePromptUtteranceID == utteranceID else { return }

        activePromptUtteranceID = nil
        activeSpeaker = .idle
        statusMessage = "Listening..."
    }

    private func startDiscoveryRequest(transcript: String) {
        guard case .ready(let readyState) = sessionState else {
            logInvalidTransition(event: "startDiscoveryRequest", state: sessionState)
            return
        }

        guard case .discovery = readyState.mode else {
            logInvalidTransition(event: "startDiscoveryRequest", state: sessionState)
            return
        }

        discoveryFallbackTask?.cancel()
        activePromptUtteranceID = nil
        clearAppError()
        let requestID = nextOperationID()
        activeDiscoveryRequestID = requestID
        setSessionState(.discovering(turnID: requestID), reason: "discovery request in flight")
        activeSpeaker = .child
        statusMessage = "Understanding story request"

        let request = DiscoveryRequest(
            childProfileId: launchPlan.childProfileId.uuidString,
            transcript: transcript,
            questionCount: followUpQuestionCount,
            slotState: DiscoverySlotState(
                theme: themeSlot,
                characters: charactersSlot,
                setting: settingSlot,
                tone: toneSlot,
                episodeIntent: episodeIntentSlot
            ),
            mode: discoveryModeValue,
            previousEpisodeRecap: previousEpisodeRecap()
        )

        Task { [weak self] in
            guard let self else { return }
            let result: Result<DiscoveryEnvelope, Error>
            do {
                result = .success(try await self.api.discoverStoryTurn(request: request))
            } catch {
                result = .failure(error)
            }
            await self.process(.discoveryResolved(requestID: requestID, result))
        }
    }

    private func startGenerationRequest(source: GenerationStartSource) {
        switch source {
        case .discoveryResolved(let requestID):
            guard case .discovering(let activeTurnID) = sessionState, activeTurnID == requestID else {
                logInvalidTransition(event: source.eventName, state: sessionState)
                return
            }
        case .mockDiscoveryCompleted(let stepNumber):
            guard case .ready(let readyState) = sessionState,
                  readyState.mode == .discovery(stepNumber: stepNumber),
                  shouldGenerateNow else {
                logInvalidTransition(event: source.eventName, state: sessionState)
                return
            }
        }

        guard activeGenerationRequestID == nil else {
            logInvalidTransition(event: source.eventName, state: sessionState)
            return
        }

        activePromptUtteranceID = nil
        clearAppError()
        setSessionState(.generating, reason: "story generation started")
        activeSpeaker = .ai
        statusMessage = "Generating story"
        aiPrompt = "Thanks. I have enough information. Creating your story now."

        let requestID = nextOperationID()
        activeGenerationRequestID = requestID

        let selectedSeries = seriesForContext()
        let defaultCharacters = selectedSeries?.characterHints ?? ["Bunny", "Fox"]
        if charactersSlot.isEmpty {
            charactersSlot = defaultCharacters
        }
        completionSaveStrategy = .add(characters: charactersSlot)

        let generationSlotState = discoverySlots
        let resolvedTheme = generationSlotState.theme ?? "A kind forest adventure"
        let resolvedCharacters = generationSlotState.characters.isEmpty ? defaultCharacters : generationSlotState.characters
        let resolvedSetting = generationSlotState.setting ?? "a friendly park"
        let resolvedTone = resolvedTone(for: generationSlotState.tone)
        let resolvedEpisodeIntent = generationSlotState.episodeIntent
        let questionCount = min(3, followUpQuestionCount)
        let lengthMinutes = launchPlan.lengthMinutes
        let childProfileId = launchPlan.childProfileId.uuidString
        let voiceName = self.selectedVoice
        let lessonDirective = launchPlan.experienceMode.lessonDirective

        if usesMockVoiceCore {
            let story = mockGeneratedStory(
                characters: resolvedCharacters,
                theme: resolvedTheme,
                setting: resolvedSetting,
                tone: resolvedTone
            )
            Task { [weak self] in
                await self?.process(
                    .generationResolved(
                        requestID: requestID,
                        .success(
                            GenerateStoryEnvelope(
                                blocked: false,
                                safeMessage: nil,
                                data: story
                            )
                        )
                    )
                )
            }
            return
        }

        let continuityFactsTask = Task { [weak self] () -> [String] in
            guard let self else { return [] }
            return await self.combinedContinuityFacts(
                from: selectedSeries,
                theme: resolvedTheme,
                characters: resolvedCharacters,
                setting: resolvedSetting,
                tone: resolvedTone,
                episodeIntent: resolvedEpisodeIntent
            )
        }

        Task { [weak self] in
            guard let self else { return }
            let continuityFacts = await continuityFactsTask.value
            let request = GenerateStoryRequest(
                childProfileId: childProfileId,
                ageBand: "3-8",
                language: "en",
                lengthMinutes: lengthMinutes,
                voice: voiceName,
                questionCount: questionCount,
                storyBrief: StoryBrief(
                    theme: resolvedTheme,
                    characters: resolvedCharacters,
                    setting: resolvedSetting,
                    tone: resolvedTone,
                    episodeIntent: resolvedEpisodeIntent,
                    lesson: lessonDirective
                ),
                continuityFacts: self.uniqueFacts(continuityFacts + self.profileContinuityFacts(characters: resolvedCharacters))
            )

            let result: Result<GenerateStoryEnvelope, Error>
            do {
                result = .success(try await self.api.generateStory(request: request))
            } catch {
                result = .failure(error)
            }
            await self.process(.generationResolved(requestID: requestID, result))
        }
    }

    private func startNarration(from startIndex: Int, source: NarrationStartSource) async {
        switch source {
        case .replayFromBoot:
            guard case .booting = sessionState, startIndex == 0 else {
                logInvalidTransition(event: source.eventName, state: sessionState)
                return
            }
        case .generationResolved:
            guard case .generating = sessionState, startIndex == 0 else {
                logInvalidTransition(event: source.eventName, state: sessionState)
                return
            }
        case .revisionResolved(let sceneIndex):
            guard case .revising(let activeSceneIndex, _) = sessionState,
                  activeSceneIndex == sceneIndex,
                  startIndex == sceneIndex else {
                logInvalidTransition(event: source.eventName, state: sessionState)
                return
            }
        case .continueAfterScene(let sceneIndex):
            guard case .narrating(let currentSceneIndex) = sessionState,
                  currentSceneIndex == sceneIndex,
                  startIndex == (sceneIndex + 1) else {
                logInvalidTransition(event: source.eventName, state: sessionState)
                return
            }
        }

        guard let story = generatedStory else {
            failSession(
                message: "Missing story before narration.",
                status: "Session failed",
                reason: "narration without story"
            )
            return
        }

        guard !story.scenes.isEmpty else {
            completeSession()
            return
        }

        guard startIndex < story.scenes.count else {
            completeSession()
            return
        }

        scenePlaybackTask?.cancel()
        setSessionState(.narrating(sceneIndex: startIndex), reason: "narrating scene \(startIndex)")
        currentSceneIndex = startIndex
        nowNarratingText = story.scenes[startIndex].text
        aiPrompt = "Narrating scene \(startIndex + 1) of \(story.scenes.count)"
        statusMessage = "Narrating scene \(startIndex + 1) of \(story.scenes.count)"
        activeSpeaker = .ai

        let utteranceID = nextUtteranceID(prefix: "scene-\(startIndex)")
        activeNarrationUtteranceID = utteranceID

        scenePlaybackTask = Task { [weak self] in
            guard let self else { return }

            if self.usesMockVoiceCore {
                let seconds = min(max(Double(story.scenes[startIndex].durationSec) / 14.0, 1.2), 4.0)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } else {
                _ = await self.speakAndAwaitCompletion(
                    text: story.scenes[startIndex].text,
                    utteranceID: utteranceID,
                    timeoutSeconds: Double(story.scenes[startIndex].durationSec) + 4
                )
            }

            guard !Task.isCancelled else { return }
            await self.process(.narrationSceneFinished(utteranceID: utteranceID, sceneIndex: startIndex))
        }
    }

    private func beginNarrationInterruption(at sceneIndex: Int, immediateUserUpdate: String?) async {
        guard case .narrating(let currentSceneIndex) = sessionState, currentSceneIndex == sceneIndex else {
            logInvalidTransition(event: "beginNarrationInterruption", state: sessionState)
            return
        }

        scenePlaybackTask?.cancel()
        activeNarrationUtteranceID = nil
        setSessionState(.interrupting(sceneIndex: sceneIndex), reason: "narration interrupted")
        activeSpeaker = .child
        statusMessage = "Listening for a story update"

        if !usesMockVoiceCore {
            await voiceCore.cancelAssistantSpeech()
        }

        if let immediateUserUpdate {
            startRevisionRequest(userUpdate: immediateUserUpdate, sceneIndex: sceneIndex)
        }
    }

    private func startRevisionRequest(userUpdate: String, sceneIndex: Int) {
        let cleanUpdate = userUpdate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUpdate.isEmpty else { return }

        if case .revising(let revisingSceneIndex, _) = sessionState {
            queueRevisionUpdate(cleanUpdate, sceneIndex: revisingSceneIndex)
            return
        }

        guard case .interrupting(let interruptingSceneIndex) = sessionState, interruptingSceneIndex == sceneIndex else {
            logInvalidTransition(event: "startRevisionRequest", state: sessionState)
            return
        }

        guard let currentStory = generatedStory else {
            failSession(
                message: "Missing story before revision.",
                status: "Session failed",
                reason: "revision without story"
            )
            return
        }

        submitRevisionRequest(cleanUpdate, sceneIndex: sceneIndex, story: currentStory)
    }

    private func queueRevisionUpdate(_ userUpdate: String, sceneIndex: Int) {
        guard queuedRevisionUpdates.count < Self.maxQueuedRevisionUpdates else {
            logRevisionQueueOverflow(sceneIndex: sceneIndex)
            return
        }

        queuedRevisionUpdates.append(userUpdate)
        setSessionState(
            .revising(sceneIndex: sceneIndex, queuedUpdates: queuedRevisionUpdates.count),
            reason: "queued revision update"
        )
        activeSpeaker = .child
        statusMessage = "Finishing the current story update"
    }

    private func submitRevisionRequest(_ userUpdate: String, sceneIndex: Int, story: StoryData) {
        clearAppError()
        let requestID = nextOperationID()
        activeRevisionRequestID = requestID
        setSessionState(.revising(sceneIndex: sceneIndex, queuedUpdates: queuedRevisionUpdates.count), reason: "revision in flight")
        activeSpeaker = .child
        statusMessage = "Updating story from current scene"
        aiPrompt = "Got it. I'll update the rest of the story with your new idea."

        let request = ReviseStoryRequest(
            storyId: story.storyId,
            currentSceneIndex: sceneIndex,
            storyTitle: story.title,
            userUpdate: userUpdate,
            completedScenes: Array(story.scenes.prefix(sceneIndex)),
            remainingScenes: Array(story.scenes.dropFirst(sceneIndex))
        )

        Task { [weak self] in
            guard let self else { return }
            let result: Result<ReviseStoryEnvelope, Error>
            do {
                result = .success(try await self.api.reviseStory(request: request))
            } catch {
                result = .failure(error)
            }
            await self.process(.revisionResolved(requestID: requestID, sceneIndex: sceneIndex, result))
        }
    }

    private func completeSession(
        status: String = "Story complete",
        prompt: String = "The story has ended. You can start another episode."
    ) {
        if case .completed = sessionState {
            logDuplicateCompletion()
            return
        }

        guard canCompleteSession(from: sessionState) else {
            logInvalidTransition(event: "completeSession", state: sessionState)
            return
        }

        cancelTimedWork()
        activeStartupAttempt = nil
        activeDiscoveryRequestID = nil
        activeGenerationRequestID = nil
        activeRevisionRequestID = nil
        activeNarrationUtteranceID = nil
        activePromptUtteranceID = nil
        deferredTranscriptPolicy = nil
        queuedRevisionUpdates.removeAll()
        setSessionState(.completed, reason: "session complete")
        statusMessage = status
        aiPrompt = prompt
        activeSpeaker = .idle
        clearAppError()
        applyTerminalTranscriptPolicy()
        recordTrace(.completion, source: "completed")
        persistCompletedStoryIfNeeded()
    }

    private func persistCompletedStoryIfNeeded() {
        guard !completionSaveDidRun else { return }
        completionSaveDidRun = true

        guard let story = generatedStory else { return }

        let seriesID: UUID?
        switch completionSaveStrategy {
        case .none:
            seriesID = nil
        case .add(let characters):
            seriesID = store.addStory(story, characters: characters, plan: launchPlan)
        case .replaceExisting:
            seriesID = store.replaceStory(story)
        }

        if let seriesID {
            Task { [weak self] in
                await self?.indexContinuityMemory(for: story, seriesId: seriesID)
            }
        }
    }

    private func isStartupAttemptActive(_ attemptID: Int) -> Bool {
        guard let activeStartupAttempt else { return false }
        guard case .booting = sessionState else { return false }
        return activeStartupAttempt.id == attemptID
    }

    private func updateStartupStage(_ stage: StartupStage, attemptID: Int) {
        guard activeStartupAttempt?.id == attemptID else { return }
        activeStartupAttempt?.stage = stage
    }

    private func failStartupAttemptIfNeeded(_ error: Error, attemptID: Int) {
        guard let startupAttempt = activeStartupAttempt, startupAttempt.id == attemptID else {
            return
        }
        guard case .booting = sessionState else { return }

        let failure = mapStartupFailure(for: error, stage: startupAttempt.stage)
        let appError = startupAppError(for: error, fallback: failure)
        failStartupAttemptIfNeeded(failure, appError: appError, reason: "startup \(failure.rawValue)")
    }

    private func failStartupAttemptIfNeeded(
        _ failure: StartupFailure,
        appError: StoryTimeAppError? = nil,
        reason: String
    ) {
        guard activeStartupAttempt != nil else { return }
        guard case .booting = sessionState else { return }

        let operation = activeStartupAttempt.map { traceOperation(for: $0.stage) }
        let resolvedAppError = appError ?? StoryTimeAppError(
            category: .startup,
            statusMessage: failure.statusMessage,
            userMessage: failure.userMessage
        )
        lastStartupFailure = failure
        lastAppError = resolvedAppError
        failSession(
            message: resolvedAppError.userMessage,
            status: resolvedAppError.statusMessage,
            reason: reason
        )
        recordTrace(.failure, source: "startup.\(failure.rawValue)", operation: operation)
    }

    private func mapStartupFailure(for error: Error, stage: StartupStage) -> StartupFailure {
        if let realtimeError = error as? RealtimeVoiceClient.RealtimeError {
            switch realtimeError {
            case .bridgeReadyTimedOut, .bridgeReadyFailed:
                return .bridgeReadiness
            case .disconnectedBeforeReady:
                return .disconnectBeforeReady
            case .connectFailed, .invalidBridgeResponse, .notReady:
                return .callConnect
            }
        }

        switch stage {
        case .healthCheck:
            return .healthCheck
        case .sessionBootstrap:
            return .sessionBootstrap
        case .realtimeSession:
            return .realtimeSession
        case .callConnect:
            return .callConnect
        }
    }

    private func startupAppError(for error: Error, fallback failure: StartupFailure) -> StoryTimeAppError {
        if let apiError = error as? APIError, apiError.serverCode == "unsupported_region" {
            return StoryTimeAppError(
                category: .startup,
                statusMessage: failure.statusMessage,
                userMessage: "StoryTime isn't available in this region right now."
            )
        }

        return StoryTimeAppError(
            category: .startup,
            statusMessage: failure.statusMessage,
            userMessage: failure.userMessage
        )
    }

    private func clearAppError() {
        lastAppError = nil
    }

    private func noteModerationBlock(userMessage: String, statusMessage: String) {
        lastAppError = StoryTimeAppError(
            category: .moderationBlock,
            statusMessage: statusMessage,
            userMessage: userMessage
        )
    }

    private func presentAppFailure(
        _ appError: StoryTimeAppError,
        reason: String,
        operation: APIClientTraceOperation? = nil
    ) {
        lastAppError = appError
        failSession(
            message: appError.userMessage,
            status: appError.statusMessage,
            reason: reason
        )
        recordTrace(.failure, source: reason, operation: operation)
    }

    private func handleSessionFailure(_ error: Error, context: SessionFailureContext) {
        if isCancellationError(error) {
            handleCancelledOperation(for: context)
            return
        }

        presentAppFailure(
            mapAppError(for: error, context: context),
            reason: context.failureReason,
            operation: traceOperation(for: context)
        )
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        return false
    }

    private func handleCancelledOperation(for context: SessionFailureContext) {
        switch context {
        case .discovery:
            setSessionState(
                .ready(VoiceSessionReadyState(mode: .discovery(stepNumber: max(1, followUpQuestionCount + 1)))),
                reason: "discovery cancelled"
            )
            activeSpeaker = .idle
            statusMessage = "Listening..."
            lastAppError = StoryTimeAppError(
                category: .cancellation,
                statusMessage: "Listening...",
                userMessage: ""
            )

        case .generation:
            setSessionState(
                .ready(VoiceSessionReadyState(mode: .discovery(stepNumber: max(1, followUpQuestionCount + 1)))),
                reason: "generation cancelled"
            )
            activeSpeaker = .idle
            statusMessage = "Listening..."
            lastAppError = StoryTimeAppError(
                category: .cancellation,
                statusMessage: "Listening...",
                userMessage: ""
            )

        case .revision(let sceneIndex):
            setSessionState(.interrupting(sceneIndex: sceneIndex), reason: "revision cancelled")
            activeSpeaker = .child
            statusMessage = "Listening for a story update"
            lastAppError = StoryTimeAppError(
                category: .cancellation,
                statusMessage: "Listening for a story update",
                userMessage: ""
            )

        case .voiceRuntime, .disconnected:
            lastAppError = StoryTimeAppError(
                category: .cancellation,
                statusMessage: "",
                userMessage: ""
            )
        }

        errorMessage = ""
    }

    private func mapAppError(for error: Error, context: SessionFailureContext) -> StoryTimeAppError {
        if error is DecodingError {
            return StoryTimeAppError(
                category: .decodeFailure,
                statusMessage: "Story unavailable",
                userMessage: "I couldn't understand StoryTime's reply right now. Please try again."
            )
        }

        if let apiError = error as? APIError {
            switch apiError {
            case .connectionFailed:
                return networkAppError(for: context)
            case .invalidResponse:
                return mappedBackendAppError(for: apiError, context: context)
            }
        }

        if let urlError = error as? URLError, Self.networkErrorCodes.contains(urlError.code) {
            return networkAppError(for: context)
        }

        return backendAppError(for: context)
    }

    private func mappedBackendAppError(for apiError: APIError, context: SessionFailureContext) -> StoryTimeAppError {
        let fallback = backendAppError(for: context)
        switch apiError.serverCode {
        case "rate_limited":
            return StoryTimeAppError(
                category: .backendFailure,
                statusMessage: "Please try again soon",
                userMessage: "StoryTime is a little busy right now. Please try again in a moment."
            )
        case "missing_install_id",
             "missing_session_token",
             "invalid_session_token",
             "invalid_session_token_signature",
             "invalid_session_token_audience",
             "invalid_session_token_expired",
             "invalid_session_token_install_id":
            return StoryTimeAppError(
                category: .backendFailure,
                statusMessage: "Session unavailable",
                userMessage: "StoryTime needs a fresh session before it can continue. Please try again."
            )
        case "unsupported_region":
            return StoryTimeAppError(
                category: .backendFailure,
                statusMessage: "Session unavailable",
                userMessage: "StoryTime isn't available in this region right now."
            )
        case "invalid_request":
            return StoryTimeAppError(
                category: .backendFailure,
                statusMessage: fallback.statusMessage,
                userMessage: "StoryTime couldn't use that request right now. Please try again."
            )
        case "revision_conflict":
            return StoryTimeAppError(
                category: .backendFailure,
                statusMessage: "Update unavailable",
                userMessage: safeBackendPublicMessage(for: apiError) ?? "I couldn't apply that story change right now. Please try again."
            )
        case "realtime_call_failed", "invalid_realtime_answer":
            return StoryTimeAppError(
                category: .backendFailure,
                statusMessage: fallback.statusMessage,
                userMessage: safeBackendPublicMessage(for: apiError) ?? fallback.userMessage
            )
        default:
            if let safeMessage = safeBackendPublicMessage(for: apiError) {
                return StoryTimeAppError(
                    category: fallback.category,
                    statusMessage: fallback.statusMessage,
                    userMessage: safeMessage
                )
            }
            return fallback
        }
    }

    private func safeBackendPublicMessage(for apiError: APIError) -> String? {
        guard let message = apiError.serverMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            return nil
        }

        switch apiError.serverCode {
        case "revision_conflict", "realtime_call_failed", "invalid_realtime_answer":
            return message
        default:
            return nil
        }
    }

    private func networkAppError(for context: SessionFailureContext) -> StoryTimeAppError {
        switch context {
        case .voiceRuntime:
            return StoryTimeAppError(
                category: .networkFailure,
                statusMessage: "Connection failed",
                userMessage: "The live storyteller lost its connection. Please try again."
            )
        case .disconnected:
            return disconnectedAppError()
        case .discovery, .generation, .revision:
            return StoryTimeAppError(
                category: .networkFailure,
                statusMessage: "Connection failed",
                userMessage: "I couldn't reach StoryTime right now. Please try again."
            )
        }
    }

    private func backendAppError(for context: SessionFailureContext) -> StoryTimeAppError {
        switch context {
        case .voiceRuntime, .disconnected:
            return StoryTimeAppError(
                category: .backendFailure,
                statusMessage: "Voice session error",
                userMessage: "The live storyteller had a problem. Please try again."
            )
        case .discovery, .generation, .revision:
            return StoryTimeAppError(
                category: .backendFailure,
                statusMessage: "Session failed",
                userMessage: "I couldn't finish the story right now. Please try again."
            )
        }
    }

    private func voiceRuntimeAppError(for message: String) -> StoryTimeAppError {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("disconnect") || normalized.contains("network") || normalized.contains("connection") {
            return networkAppError(for: .voiceRuntime)
        }

        return backendAppError(for: .voiceRuntime)
    }

    private func disconnectedAppError() -> StoryTimeAppError {
        StoryTimeAppError(
            category: .networkFailure,
            statusMessage: "Voice session disconnected",
            userMessage: "The live storyteller disconnected. Please try again."
        )
    }

    private func failSession(message: String, status: String, reason: String) {
        cancelTimedWork()
        activeStartupAttempt = nil
        activeDiscoveryRequestID = nil
        activeGenerationRequestID = nil
        activeRevisionRequestID = nil
        activeNarrationUtteranceID = nil
        activePromptUtteranceID = nil
        deferredTranscriptPolicy = nil
        queuedRevisionUpdates.removeAll()
        errorMessage = message
        statusMessage = status
        activeSpeaker = .idle
        applyTerminalTranscriptPolicy()
        setSessionState(.failed, reason: reason)
    }

    private func resetForNewSession() {
        cancelTimedWork()
        completionSaveStrategy = .none
        completionSaveDidRun = false
        queuedRevisionUpdates.removeAll()
        completedUtteranceIDs.removeAll()
        invalidTransitionMessages.removeAll()
        traceEvents.removeAll()
        latestAPITraceByOperation.removeAll()
        activeStartupAttempt = nil
        lastStartupFailure = nil
        lastAppError = nil
        activeDiscoveryRequestID = nil
        activeGenerationRequestID = nil
        activeRevisionRequestID = nil
        activeNarrationUtteranceID = nil
        activePromptUtteranceID = nil
        deferredTranscriptPolicy = nil
        generatedStory = nil
        followUpQuestionCount = 0
        currentSceneIndex = 0
        nowNarratingText = ""
        errorMessage = ""
        latestUserTranscript = ""
        aiPrompt = "Starting story conversation..."
        statusMessage = ""
        activeSpeaker = .idle
        discoverySlots = DiscoverySlotState()
    }

    private func cancelTimedWork() {
        scenePlaybackTask?.cancel()
        scenePlaybackTask = nil
        discoveryFallbackTask?.cancel()
        discoveryFallbackTask = nil
    }

    private func bindAPITraceEvents() {
        api.traceHandler = { [weak self] event in
            Task { @MainActor in
                self?.consumeAPITrace(event)
            }
        }
    }

    private func consumeAPITrace(_ event: APIClientTraceEvent) {
        latestAPITraceByOperation[event.operation] = event
        let sessionId = event.sessionId ?? "-"
        let statusCode = event.statusCode.map(String.init) ?? "-"
        Self.logger.debug(
            "Voice session API trace: operation=\(event.operation.rawValue, privacy: .public) phase=\(event.phase.rawValue, privacy: .public) requestId=\(event.requestId, privacy: .public) sessionId=\(sessionId, privacy: .public) statusCode=\(statusCode, privacy: .public) route=\(event.route, privacy: .public)"
        )
    }

    private func recordTrace(
        _ kind: SessionTraceKind,
        source: String,
        operation: APIClientTraceOperation? = nil
    ) {
        let apiTrace = operation.flatMap { latestAPITraceByOperation[$0] }
        let event = SessionTraceEvent(
            kind: kind,
            source: source,
            state: sessionState.logDescription,
            requestId: apiTrace?.requestId,
            sessionId: apiTrace?.sessionId ?? AppSession.currentSessionId,
            apiOperation: operation,
            statusCode: apiTrace?.statusCode
        )
        traceEvents.append(event)
        let operationName = operation?.rawValue ?? "-"
        let requestId = event.requestId ?? "-"
        let sessionId = event.sessionId ?? "-"
        let statusCode = event.statusCode.map(String.init) ?? "-"
        Self.logger.debug(
            "Voice session trace: kind=\(kind.rawValue, privacy: .public) source=\(source, privacy: .public) state=\(event.state, privacy: .public) operation=\(operationName, privacy: .public) requestId=\(requestId, privacy: .public) sessionId=\(sessionId, privacy: .public) statusCode=\(statusCode, privacy: .public)"
        )
    }

    private func setSessionState(_ newState: VoiceSessionState, reason: String) {
        let previousState = sessionState
        sessionState = newState
        if let sceneIndex = newState.sceneIndex {
            currentSceneIndex = sceneIndex
        }
        Self.logger.debug(
            "Voice session transition: \(previousState.logDescription, privacy: .public) -> \(newState.logDescription, privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    private func nextOperationID() -> Int {
        operationCounter += 1
        return operationCounter
    }

    private func nextUtteranceID(prefix: String) -> String {
        utteranceCounter += 1
        return "\(prefix)-\(utteranceCounter)"
    }

    private func canCompleteSession(from state: VoiceSessionState) -> Bool {
        switch state {
        case .booting, .generating, .narrating, .revising:
            return true
        case .idle, .ready, .discovering, .interrupting, .completed, .failed:
            return false
        }
    }

    private func applyTerminalTranscriptPolicy() {
        guard store.privacySettings.clearTranscriptsAfterSession else { return }
        latestUserTranscript = ""
    }

    private func traceOperation(for stage: StartupStage) -> APIClientTraceOperation {
        switch stage {
        case .healthCheck:
            return .healthCheck
        case .sessionBootstrap:
            return .sessionBootstrap
        case .realtimeSession, .callConnect:
            return .realtimeSession
        }
    }

    private func traceOperation(for context: SessionFailureContext) -> APIClientTraceOperation? {
        switch context {
        case .discovery:
            return .storyDiscovery
        case .generation:
            return .storyGeneration
        case .revision:
            return .storyRevision
        case .voiceRuntime, .disconnected:
            return nil
        }
    }

    private func speakAndAwaitCompletion(
        text: String,
        utteranceID: String,
        timeoutSeconds: Double
    ) async -> Bool {
        completedUtteranceIDs.remove(utteranceID)
        await voiceCore.speak(text: text, utteranceId: utteranceID)

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if completedUtteranceIDs.remove(utteranceID) != nil {
                return true
            }
            if Task.isCancelled {
                return false
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        return false
    }

    private func mergeDiscoverySlots(from slotState: DiscoverySlotState) {
        themeSlot = slotState.theme ?? themeSlot
        if !slotState.characters.isEmpty {
            charactersSlot = slotState.characters
        }
        settingSlot = slotState.setting ?? settingSlot
        toneSlot = slotState.tone ?? toneSlot
        episodeIntentSlot = slotState.episodeIntent ?? episodeIntentSlot
    }

    private func handleAudioLevels(local: CGFloat, remote: CGFloat) {
        microphoneLevel = local
        aiVoiceLevel = remote

        if remote > 0.035 {
            activeSpeaker = .ai
        } else if local > 0.055 {
            activeSpeaker = .child
        } else if case .generating = sessionState {
            activeSpeaker = .ai
        } else if case .revising = sessionState {
            activeSpeaker = .ai
        } else {
            activeSpeaker = .idle
        }
    }

    private func logInvalidTransition(event: String, state: VoiceSessionState) {
        let message = "Rejected \(event) while in \(state.logDescription)"
        invalidTransitionMessages.append(message)
        Self.logger.error("\(message, privacy: .public)")
    }

    private func logDuplicateCompletion() {
        let message = "Ignored duplicate completion while in completed"
        invalidTransitionMessages.append(message)
        Self.logger.debug("\(message, privacy: .public)")
    }

    private func logStaleResult(kind: String, requestID: Int) {
        let message = "Ignored stale \(kind) result for request \(requestID)"
        invalidTransitionMessages.append(message)
        Self.logger.debug("\(message, privacy: .public)")
    }

    private func logStaleNarrationCompletion(utteranceID: String, sceneIndex: Int) {
        let message = "Ignored stale narration completion \(utteranceID) for scene \(sceneIndex)"
        invalidTransitionMessages.append(message)
        Self.logger.debug("\(message, privacy: .public)")
    }

    private func logUnexpectedRevisionIndex(expected: Int, actual: Int) {
        let message = "Revision index mismatch. expected=\(expected) actual=\(actual)"
        invalidTransitionMessages.append(message)
        Self.logger.error("\(message, privacy: .public)")
    }

    private func logRevisionQueueOverflow(sceneIndex: Int) {
        let message = "Rejected revision update while queue full for scene \(sceneIndex)"
        invalidTransitionMessages.append(message)
        Self.logger.error("\(message, privacy: .public)")
    }

    private var themeSlot: String? {
        get { discoverySlots.theme }
        set { discoverySlots.theme = newValue }
    }

    private var charactersSlot: [String] {
        get { discoverySlots.characters }
        set { discoverySlots.characters = newValue }
    }

    private var settingSlot: String? {
        get { discoverySlots.setting }
        set { discoverySlots.setting = newValue }
    }

    private var toneSlot: String? {
        get { discoverySlots.tone }
        set { discoverySlots.tone = newValue }
    }

    private var episodeIntentSlot: String? {
        get { discoverySlots.episodeIntent }
        set { discoverySlots.episodeIntent = newValue }
    }

    private var shouldGenerateNow: Bool {
        if followUpQuestionCount >= 3 {
            return true
        }
        return themeSlot != nil && !charactersSlot.isEmpty && settingSlot != nil
    }

    private func captureMockFollowUpAnswer() async {
        guard case .ready(let readyState) = sessionState else { return }
        guard readyState.mode == .discovery(stepNumber: followUpQuestionCount + 1) else { return }

        let slotIndex = followUpQuestionCount
        let answer = scriptedChildAnswer(for: slotIndex)
        latestUserTranscript = answer
        statusMessage = "Captured child voice input"
        activeSpeaker = .child

        if slotIndex == 0 {
            themeSlot = answer
        } else if slotIndex == 1 {
            charactersSlot = answer
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else if slotIndex == 2 {
            settingSlot = answer
        }

        followUpQuestionCount += 1

        if shouldGenerateNow {
            startGenerationRequest(source: .mockDiscoveryCompleted(stepNumber: followUpQuestionCount))
            return
        }

        let nextStep = followUpQuestionCount + 1
        setSessionState(
            .ready(VoiceSessionReadyState(mode: .discovery(stepNumber: nextStep))),
            reason: "mock discovery follow-up"
        )
        await deliverDiscoveryPrompt(scriptedFollowUpPrompt(for: followUpQuestionCount), stepNumber: nextStep)
    }

    private func scheduleMockDiscoveryFallback(forStep stepNumber: Int) {
        discoveryFallbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self else { return }
            guard case .ready(let readyState) = self.sessionState else { return }
            guard readyState.mode == .discovery(stepNumber: stepNumber) else { return }
            guard self.followUpQuestionCount == (stepNumber - 1) else { return }
            await self.captureMockFollowUpAnswer()
        }
    }

    private func seriesForContext() -> StorySeries? {
        switch launchPlan.mode {
        case .extend(let id), .repeatEpisode(let id):
            return store.seriesById(id)
        case .new:
            if launchPlan.usePastStory {
                return store.seriesById(launchPlan.selectedSeriesId)
            }
            return nil
        }
    }

    private func continuityFacts(from series: StorySeries?) -> [String] {
        guard let series, let lastEpisode = series.latestEpisode else {
            return []
        }

        let firstScene = lastEpisode.scenes.first?.text ?? ""
        let summary = String(firstScene.prefix(180))
        var facts: [String] = []

        if !series.title.isEmpty {
            facts.append("Series title: \(series.title)")
        }

        if !series.characterHints.isEmpty {
            facts.append("Characters: \(series.characterHints.joined(separator: ", "))")
        }

        if let recap = lastEpisode.engine?.episodeRecap, !recap.isEmpty {
            facts.append("Last episode context: \(recap)")
        } else if !summary.isEmpty {
            facts.append("Last episode context: \(summary)")
        }

        if let memory = lastEpisode.engine?.seriesMemory {
            for fact in memory.worldFacts.prefix(4) where !fact.isEmpty {
                facts.append(fact)
            }
            for relation in memory.relationshipFacts.prefix(3) where !relation.isEmpty {
                facts.append("Relationship: \(relation)")
            }
            for place in memory.favoritePlaces.prefix(3) where !place.isEmpty {
                facts.append("Place: \(place)")
            }
            if let arcSummary = memory.arcSummary, !arcSummary.isEmpty {
                facts.append("Arc summary: \(arcSummary)")
            }
            if let nextHook = memory.nextEpisodeHook, !nextHook.isEmpty {
                facts.append("Next episode hook: \(nextHook)")
            }
            for loop in memory.openLoops.prefix(2) where !loop.isEmpty {
                facts.append("Open loop: \(loop)")
            }
        }

        if let engine = lastEpisode.engine, !engine.characterBible.isEmpty {
            for character in engine.characterBible.prefix(3) {
                let traits = character.traits.prefix(3).joined(separator: ", ")
                facts.append("Character note: \(character.name) is \(traits)")
            }
        }

        if let arcSummary = series.arcSummary, !arcSummary.isEmpty {
            facts.append("Arc summary: \(arcSummary)")
        }
        for relation in (series.relationshipFacts ?? []).prefix(3) where !relation.isEmpty {
            facts.append("Relationship: \(relation)")
        }
        for place in (series.favoritePlaces ?? []).prefix(3) where !place.isEmpty {
            facts.append("Place: \(place)")
        }
        for thread in (series.unresolvedThreads ?? []).prefix(3) where !thread.isEmpty {
            facts.append("Open loop: \(thread)")
        }

        return uniqueFacts(facts)
    }

    private func combinedContinuityFacts(
        from series: StorySeries?,
        theme: String,
        characters: [String],
        setting: String,
        tone: String,
        episodeIntent: String?
    ) async -> [String] {
        var facts = continuityFacts(from: series)

        guard let series else {
            return facts
        }

        let query = [
            theme,
            characters.joined(separator: ", "),
            setting,
            tone,
            episodeIntent ?? "",
            series.arcSummary ?? "",
            (series.unresolvedThreads ?? []).joined(separator: " | ")
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        do {
            let embeddings = try await api.createEmbeddings(inputs: [query])
            if let queryEmbedding = embeddings.first {
                let semanticFacts = await continuityMemory.topFactTexts(seriesId: series.id, queryEmbedding: queryEmbedding, limit: 8)
                facts.append(contentsOf: semanticFacts)
            }
        } catch {
            // Semantic retrieval is additive. If it fails, generation can still continue with structural memory.
        }

        return uniqueFacts(facts)
    }

    private func indexContinuityMemory(for story: StoryData, seriesId: UUID) async {
        let facts = continuityFactTexts(from: story)
        guard !facts.isEmpty else { return }

        do {
            let embeddings = try await api.createEmbeddings(inputs: facts)
            await continuityMemory.replaceFacts(seriesId: seriesId, storyId: story.storyId, texts: facts, embeddings: embeddings)
        } catch {
            // Indexing failure should not interrupt the live story session.
        }
    }

    private func continuityFactTexts(from story: StoryData) -> [String] {
        guard let engine = story.engine else { return [] }

        var facts: [String] = []

        if let recap = engine.episodeRecap, !recap.isEmpty {
            facts.append(recap)
        }

        facts.append(contentsOf: engine.continuityFacts)

        if let arcSummary = engine.seriesMemory.arcSummary, !arcSummary.isEmpty {
            facts.append("Arc summary: \(arcSummary)")
        }

        if let hook = engine.seriesMemory.nextEpisodeHook, !hook.isEmpty {
            facts.append("Next episode hook: \(hook)")
        }

        facts.append(contentsOf: engine.seriesMemory.worldFacts)
        facts.append(contentsOf: engine.seriesMemory.relationshipFacts.map { "Relationship: \($0)" })
        facts.append(contentsOf: engine.seriesMemory.favoritePlaces.map { "Place: \($0)" })
        facts.append(contentsOf: engine.seriesMemory.openLoops.map { "Open loop: \($0)" })
        facts.append(contentsOf: engine.characterBible.map { "Character note: \($0.name) is \($0.traits.joined(separator: ", "))" })

        return uniqueFacts(facts)
    }

    private func uniqueFacts(_ facts: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for fact in facts {
            let trimmed = fact.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }

        return result
    }

    private func mockGeneratedStory(characters: [String], theme: String, setting: String, tone: String) -> StoryData {
        let estimatedDurationSec = max(60, launchPlan.lengthMinutes * 60)
        let leadCharacter = characters.first ?? "Bunny"
        let supportingCharacter = characters.dropFirst().first ?? "Fox"
        let scenes = [
            StoryScene(
                sceneId: "1",
                text: "\(leadCharacter) began a \(tone) adventure in \(setting) to explore \(theme.lowercased()).",
                durationSec: max(20, estimatedDurationSec / 4)
            ),
            StoryScene(
                sceneId: "2",
                text: "\(supportingCharacter) joined in, and together they solved a gentle clue with teamwork and smiles.",
                durationSec: max(20, estimatedDurationSec / 3)
            ),
            StoryScene(
                sceneId: "3",
                text: "The friends celebrated their discovery, shared a hug, and went home happy under the soft sky.",
                durationSec: max(20, estimatedDurationSec / 3)
            )
        ]

        return StoryData(
            storyId: UUID().uuidString,
            title: "\(leadCharacter)'s StoryTime Adventure",
            estimatedDurationSec: estimatedDurationSec,
            scenes: scenes,
            safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
            engine: nil
        )
    }

    private func scriptedFollowUpPrompt(for index: Int) -> String {
        switch index {
        case 1:
            return "Great. Who should be in this story?"
        case 2:
            return "Nice. Where should the story happen?"
        default:
            return "I have enough details and will create the story now."
        }
    }

    private func scriptedChildAnswer(for index: Int) -> String {
        let seedCharacter = sourceSeries?.characterHints.first ?? "Bunny"

        switch index {
        case 0:
            if launchPlan.usePastStory, let title = sourceSeries?.title {
                return "A new episode after \(title) where \(seedCharacter) learns something kind"
            }
            return "A cozy adventure about \(seedCharacter) helping a friend"

        case 1:
            if launchPlan.usePastCharacters, let hints = sourceSeries?.characterHints, !hints.isEmpty {
                return hints.joined(separator: ", ")
            }
            return "Bunny, Fox, Little Owl"

        default:
            return "In a sunny park with sparkly trees"
        }
    }

    private func scriptedUpdateRequest() -> String {
        "Please add a new clue and a happy rainbow ending to the remaining story."
    }

    private func startWaveTimer() {
        waveTimer?.invalidate()
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.activeSpeaker == .ai || self.activeSpeaker == .child || self.microphoneLevel > 0.04 || self.aiVoiceLevel > 0.04 {
                    self.waveformPhase += 0.35
                }
            }
        }
    }

    private func discoveryOpeningPrompt() -> String {
        if case .extend = launchPlan.mode, let recap = previousEpisodeRecap() {
            return "Last time: \(recap) For \(childName)'s \(launchPlan.experienceMode.title.lowercased()) story, what should happen next, and what feeling should this episode have?"
        }
        return "Hi \(childName). Tell me what kind of \(launchPlan.experienceMode.title.lowercased()) story you want today. You can tell me who is in it, where it happens, and what feeling you want."
    }

    private func seededEpisodeIntent() -> String? {
        switch launchPlan.mode {
        case .extend:
            return "continue the series with a new episode"
        case .repeatEpisode:
            return "retell the same episode"
        case .new:
            if launchPlan.usePastStory {
                return "start a fresh story connected to an earlier adventure"
            }
            return nil
        }
    }

    private func previousEpisodeRecap() -> String? {
        guard let latest = sourceSeries?.latestEpisode else { return nil }
        let firstScene = latest.scenes.first?.text ?? ""
        let flattened = firstScene.replacingOccurrences(of: "\n", with: " ")
        let snippet = String(flattened.prefix(160))

        if snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(latest.title) ended with a happy moment."
        }
        return "\(latest.title). \(snippet)"
    }

    private var discoveryModeValue: String {
        switch launchPlan.mode {
        case .extend:
            return "extend"
        case .new, .repeatEpisode:
            return "new"
        }
    }

    private var sessionProfile: ChildProfile? {
        store.profileById(launchPlan.childProfileId) ?? store.activeProfile
    }

    private var resolvedTone: String {
        resolvedTone(for: toneSlot)
    }

    private func resolvedTone(for requestedTone: String?) -> String {
        let requestedTone = requestedTone?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let requestedTone, !requestedTone.isEmpty {
            return "\(requestedTone), \(launchPlan.experienceMode.toneDirective)"
        }
        return launchPlan.experienceMode.toneDirective
    }

    private func profileContinuityFacts(characters: [String]) -> [String] {
        var facts: [String] = [
            "Story mode: \(launchPlan.experienceMode.title)",
            "Mode guidance: \(launchPlan.experienceMode.summaryLine)",
            "Mode tone: \(launchPlan.experienceMode.toneDirective)"
        ]

        if let profile = sessionProfile {
            facts.append("Child name: \(profile.displayName)")
            facts.append("Child age: \(profile.age)")
            facts.append("Sensitivity: \(profile.contentSensitivity.title)")
            facts.append(profile.contentSensitivity.generationDirective)
        }

        if !characters.isEmpty {
            facts.append("Requested characters: \(characters.joined(separator: ", "))")
        }

        return uniqueFacts(facts)
    }
}
