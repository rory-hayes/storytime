import AVFoundation
import CoreGraphics
import Foundation

@MainActor
final class PracticeSessionViewModel: ObservableObject {
    @Published var voices: [String] = []
    @Published var selectedVoice: String = "alloy"
    @Published var phase: ConversationPhase = .idle
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

    let launchPlan: StoryLaunchPlan
    let realtimeVoiceClient: RealtimeVoiceClient?

    private let sourceSeries: StorySeries?
    private let store: StoryLibraryStore
    private let continuityMemory: ContinuityMemoryStore
    private let api: APIClienting
    private let voiceCore: RealtimeVoiceControlling
    private let usesMockVoiceCore: Bool

    private var themeSlot: String?
    private var charactersSlot: [String] = []
    private var settingSlot: String?
    private var toneSlot: String?
    private var episodeIntentSlot: String?

    private var narrationTask: Task<Void, Never>?
    private var waveTimer: Timer?
    private var discoveryFallbackTask: Task<Void, Never>?
    private var pendingAssistantResponse = false
    private var pendingNarrationInterruption = false
    private var isRevisionInFlight = false
    private var queuedRevisionUpdate: String?
    private var latestRealtimeSession: RealtimeSessionData?
    private var latestRealtimeEndpointPath: String?
    private var latestRealtimeBaseURL: URL?

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

        bindRealtimeEvents()
        startWaveTimer()
    }

    deinit {
        narrationTask?.cancel()
        waveTimer?.invalidate()
        discoveryFallbackTask?.cancel()
    }

    var childName: String {
        sessionProfile?.displayName ?? "Story Explorer"
    }

    var modeTitle: String {
        launchPlan.experienceMode.title
    }

    var privacySummary: String {
        if store.privacySettings.clearTranscriptsAfterSession {
            return "Live conversation is on. Raw audio is not saved, and transcripts clear when the session ends."
        }
        return "Live conversation is on. Raw audio is not saved."
    }

    func startSession() async {
        errorMessage = ""
        statusMessage = ""
        latestUserTranscript = ""

        if usesMockVoiceCore {
            await startMockSession()
            return
        }

        do {
            let connectedURL = try await api.prepareConnection()
            latestRealtimeBaseURL = connectedURL

            if voices.isEmpty {
                voices = try await api.fetchVoices()
                selectedVoice = voices.first ?? "alloy"
            }

                let envelope = try await api.createRealtimeSession(
                    request: RealtimeSessionRequest(
                    childProfileId: launchPlan.childProfileId.uuidString,
                        voice: selectedVoice,
                        region: "US"
                    )
                )

            latestRealtimeSession = envelope.session
            latestRealtimeEndpointPath = envelope.endpoint
            statusMessage = "Connecting live voice"

            try await voiceCore.connect(
                baseURL: connectedURL,
                endpointPath: envelope.endpoint,
                session: envelope.session,
                installId: AppInstall.identity
            )

            statusMessage = "Live conversation is on"
            await beginLaunchFlow()
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Connection failed"
        }
    }

    func childDidSpeak() async {
        guard usesMockVoiceCore else { return }

        switch phase {
        case .gatheringInput:
            await captureMockFollowUpAnswer()
        case .narrating:
            await interruptAndRevise(userUpdate: scriptedUpdateRequest())
        default:
            break
        }
    }

    private func bindRealtimeEvents() {
        voiceCore.onConnected = { [weak self] in
            Task { @MainActor in
                self?.statusMessage = "Live conversation is on"
            }
        }

        voiceCore.onDisconnected = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.phase != .completed {
                    self.statusMessage = "Voice session disconnected"
                    self.activeSpeaker = .idle
                }
            }
        }

        voiceCore.onTranscriptPartial = { [weak self] text in
            Task { @MainActor in
                guard let self else { return }
                self.latestUserTranscript = text
                if self.phase == .gatheringInput || self.phase == .narrating || self.phase == .revising {
                    self.activeSpeaker = .child
                    self.statusMessage = "Listening..."
                }
            }
        }

        voiceCore.onTranscriptFinal = { [weak self] text in
            Task { @MainActor in
                await self?.handleFinalTranscript(text)
            }
        }

        voiceCore.onLevels = { [weak self] local, remote in
            Task { @MainActor in
                self?.handleAudioLevels(local: local, remote: remote)
            }
        }

        voiceCore.onUserSpeechChanged = { [weak self] speaking in
            Task { @MainActor in
                await self?.handleUserSpeechChanged(speaking)
            }
        }

        voiceCore.onAssistantResponseCompleted = { [weak self] in
            Task { @MainActor in
                self?.pendingAssistantResponse = true
                if self?.phase != .completed {
                    self?.activeSpeaker = .idle
                }
            }
        }

        voiceCore.onError = { [weak self] message in
            Task { @MainActor in
                self?.errorMessage = message
                self?.statusMessage = "Voice session error"
            }
        }
    }

    private func startMockSession() async {
        if voices.isEmpty {
            voices = ["alloy"]
            selectedVoice = "alloy"
        }

        statusMessage = "Demo voice session"
        await beginLaunchFlow()
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
                aiPrompt = "Replaying the latest episode now."
                phase = .narrating
                beginNarration(from: 0)
            } else {
                aiPrompt = "I couldn't find an episode to replay. Start a new story instead."
                phase = .completed
            }

        case .new, .extend:
            await beginDiscoveryConversation()
        }
    }

    private func beginDiscoveryConversation() async {
        phase = .gatheringInput
        followUpQuestionCount = 0
        latestUserTranscript = ""
        themeSlot = nil
        charactersSlot = []
        settingSlot = nil
        toneSlot = nil
        episodeIntentSlot = seededEpisodeIntent()
        await deliverDiscoveryQuestion(discoveryOpeningPrompt(), stepNumber: 1)
    }

    private func deliverDiscoveryQuestion(_ text: String, stepNumber: Int) async {
        aiPrompt = text
        activeSpeaker = .ai
        statusMessage = "Voice input step \(min(3, stepNumber)) of 3"

        discoveryFallbackTask?.cancel()

        if usesMockVoiceCore {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard phase == .gatheringInput else { return }
            activeSpeaker = .idle
            statusMessage = "Listening..."
            scheduleMockDiscoveryFallback(forStep: stepNumber)
            return
        }

        pendingAssistantResponse = false
        await voiceCore.speak(text: text)
        await waitForAssistantResponse(timeoutSeconds: 8)

        guard phase == .gatheringInput else { return }
        activeSpeaker = .idle
        statusMessage = "Listening..."
    }

    private func handleFinalTranscript(_ transcript: String) async {
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        latestUserTranscript = clean

        switch phase {
        case .gatheringInput:
            await analyzeDiscoveryTurn(transcript: clean)
        case .narrating, .revising:
            await interruptAndRevise(userUpdate: clean)
        default:
            break
        }
    }

    private func analyzeDiscoveryTurn(transcript: String) async {
        guard phase == .gatheringInput else { return }
        activeSpeaker = .child
        statusMessage = "Understanding story request"

        do {
            let envelope = try await api.discoverStoryTurn(
                    request: DiscoveryRequest(
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
            )

            themeSlot = envelope.data.slotState.theme ?? themeSlot
            if !envelope.data.slotState.characters.isEmpty {
                charactersSlot = envelope.data.slotState.characters
            }
            settingSlot = envelope.data.slotState.setting ?? settingSlot
            toneSlot = envelope.data.slotState.tone ?? toneSlot
            episodeIntentSlot = envelope.data.slotState.episodeIntent ?? episodeIntentSlot
            followUpQuestionCount = min(3, envelope.data.questionCount)

            if envelope.blocked {
                let safeReply = envelope.safeMessage ?? envelope.data.assistantMessage
                await deliverDiscoveryQuestion(safeReply, stepNumber: followUpQuestionCount + 1)
                return
            }

            if envelope.data.readyToGenerate {
                await generateStoryFromVoiceAnswers()
                return
            }

            await deliverDiscoveryQuestion(envelope.data.assistantMessage, stepNumber: followUpQuestionCount + 1)
        } catch {
            errorMessage = error.localizedDescription
            phase = .completed
        }
    }

    private func generateStoryFromVoiceAnswers() async {
        phase = .generating
        activeSpeaker = .ai
        statusMessage = "Generating story"
        aiPrompt = "Thanks. I have enough information. Creating your story now."

        let selectedSeries = seriesForContext()
        let defaultCharacters = selectedSeries?.characterHints ?? ["Bunny", "Fox"]
        let characters = charactersSlot.isEmpty ? defaultCharacters : charactersSlot
        let resolvedTone = resolvedTone

        if usesMockVoiceCore {
            let story = mockGeneratedStory(
                characters: characters,
                theme: themeSlot ?? "A kind forest adventure",
                setting: settingSlot ?? "a friendly park",
                tone: resolvedTone
            )
            generatedStory = story
            _ = store.addStory(story, characters: characters, plan: launchPlan)
            statusMessage = "Story ready"
            phase = .narrating
            beginNarration(from: 0)
            return
        }

        do {
            let continuity = await combinedContinuityFacts(
                from: selectedSeries,
                theme: themeSlot ?? "A kind forest adventure",
                characters: characters,
                setting: settingSlot ?? "a friendly park",
                tone: resolvedTone,
                episodeIntent: episodeIntentSlot
            )

            let request = GenerateStoryRequest(
                childProfileId: launchPlan.childProfileId.uuidString,
                ageBand: "3-8",
                language: "en",
                lengthMinutes: launchPlan.lengthMinutes,
                voice: selectedVoice,
                questionCount: min(3, followUpQuestionCount),
                storyBrief: StoryBrief(
                    theme: themeSlot ?? "A kind forest adventure",
                    characters: characters,
                    setting: settingSlot ?? "a friendly park",
                    tone: resolvedTone,
                    episodeIntent: episodeIntentSlot,
                    lesson: launchPlan.experienceMode.lessonDirective
                ),
                continuityFacts: uniqueFacts(continuity + profileContinuityFacts(characters: characters))
            )

            let envelope = try await api.generateStory(request: request)
            generatedStory = envelope.data
            let seriesId = store.addStory(envelope.data, characters: characters, plan: launchPlan)
            if let seriesId {
                Task {
                    await self.indexContinuityMemory(for: envelope.data, seriesId: seriesId)
                }
            }

            if envelope.blocked {
                statusMessage = envelope.safeMessage ?? "Story generated with safety adjustments"
            } else {
                statusMessage = "Story ready"
            }

            phase = .narrating
            beginNarration(from: 0)
        } catch {
            errorMessage = error.localizedDescription
            phase = .completed
            activeSpeaker = .idle
        }
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

    private func beginNarration(from startIndex: Int) {
        guard let story = generatedStory else { return }

        narrationTask?.cancel()
        narrationTask = Task { [weak self] in
            guard let self else { return }
            guard !story.scenes.isEmpty else {
                await MainActor.run {
                    self.phase = .completed
                    self.activeSpeaker = .idle
                }
                return
            }

            for idx in startIndex..<story.scenes.count {
                if Task.isCancelled { return }

                await MainActor.run {
                    self.currentSceneIndex = idx
                    self.nowNarratingText = story.scenes[idx].text
                    self.aiPrompt = "Narrating scene \(idx + 1) of \(story.scenes.count)"
                    self.activeSpeaker = .ai
                    self.pendingNarrationInterruption = false
                    self.pendingAssistantResponse = false
                }

                if self.usesMockVoiceCore {
                    let seconds = min(max(Double(story.scenes[idx].durationSec) / 14.0, 1.2), 4.0)
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    continue
                }

                await self.voiceCore.speak(text: story.scenes[idx].text)
                await self.waitForAssistantResponse(timeoutSeconds: Double(story.scenes[idx].durationSec) + 4)
            }

            if Task.isCancelled { return }

            await MainActor.run {
                self.phase = .completed
                self.statusMessage = "Story complete"
                self.aiPrompt = "The story has ended. You can start another episode."
                self.activeSpeaker = .idle
                if self.store.privacySettings.clearTranscriptsAfterSession {
                    self.latestUserTranscript = ""
                }
            }
        }
    }

    private func interruptAndRevise(userUpdate: String) async {
        guard let currentStory = generatedStory else { return }
        guard phase == .narrating || phase == .revising else { return }
        let cleanUpdate = userUpdate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUpdate.isEmpty else { return }

        if isRevisionInFlight {
            queuedRevisionUpdate = cleanUpdate
            activeSpeaker = .child
            statusMessage = "Finishing the current story update"
            return
        }

        isRevisionInFlight = true

        narrationTask?.cancel()
        pendingNarrationInterruption = false
        phase = .revising
        statusMessage = "Updating story from current scene"
        activeSpeaker = .child
        aiPrompt = "Got it. I'll update the rest of the story with your new idea."

        if !usesMockVoiceCore {
            await voiceCore.cancelAssistantSpeech()
        }

        do {
            let remaining = Array(currentStory.scenes.dropFirst(currentSceneIndex))
            let envelope = try await api.reviseStory(
                request: ReviseStoryRequest(
                    storyId: currentStory.storyId,
                    currentSceneIndex: currentSceneIndex,
                    storyTitle: currentStory.title,
                    userUpdate: cleanUpdate,
                    completedScenes: Array(currentStory.scenes.prefix(currentSceneIndex)),
                    remainingScenes: remaining
                )
            )

            let mergedScenes = Array(currentStory.scenes.prefix(currentSceneIndex)) + envelope.data.scenes
            let updated = StoryData(
                storyId: currentStory.storyId,
                title: currentStory.title,
                estimatedDurationSec: currentStory.estimatedDurationSec,
                scenes: mergedScenes,
                safety: envelope.data.safety,
                engine: envelope.data.engine ?? currentStory.engine
            )

            generatedStory = updated
            let seriesId = store.replaceStory(updated)
            if let seriesId {
                Task {
                    await self.indexContinuityMemory(for: updated, seriesId: seriesId)
                }
            }
            if envelope.blocked {
                statusMessage = envelope.safeMessage ?? "Update was softened for safety."
            } else {
                statusMessage = "Story updated. Continuing narration."
            }

            phase = .narrating
            beginNarration(from: currentSceneIndex)
            let queuedUpdate = queuedRevisionUpdate
            queuedRevisionUpdate = nil
            isRevisionInFlight = false
            if let queuedUpdate {
                await interruptAndRevise(userUpdate: queuedUpdate)
            }
        } catch {
            errorMessage = error.localizedDescription
            phase = .completed
            activeSpeaker = .idle
            queuedRevisionUpdate = nil
            isRevisionInFlight = false
        }
    }

    private func handleAudioLevels(local: CGFloat, remote: CGFloat) {
        microphoneLevel = local
        aiVoiceLevel = remote

        if remote > 0.035 {
            activeSpeaker = .ai
        } else if local > 0.055 {
            activeSpeaker = .child
        } else if phase == .generating || phase == .revising {
            activeSpeaker = .ai
        } else {
            activeSpeaker = .idle
        }
    }

    private func handleUserSpeechChanged(_ speaking: Bool) async {
        guard speaking else { return }

        if phase == .gatheringInput && !usesMockVoiceCore {
            await voiceCore.cancelAssistantSpeech()
            activeSpeaker = .child
            statusMessage = "Listening..."
        }

        if phase == .narrating {
            pendingNarrationInterruption = true
            narrationTask?.cancel()
            statusMessage = "Listening for a story update"
            activeSpeaker = .child
            if !usesMockVoiceCore {
                await voiceCore.cancelAssistantSpeech()
            }
        }
    }

    private func waitForAssistantResponse(timeoutSeconds: Double) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if pendingAssistantResponse {
                pendingAssistantResponse = false
                return
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
    }

    private var shouldGenerateNow: Bool {
        if followUpQuestionCount >= 3 {
            return true
        }
        return themeSlot != nil && !charactersSlot.isEmpty && settingSlot != nil
    }

    private func captureMockFollowUpAnswer() async {
        guard phase == .gatheringInput else { return }

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
            await generateStoryFromVoiceAnswers()
            return
        }

        await deliverDiscoveryQuestion(
            scriptedFollowUpPrompt(for: followUpQuestionCount),
            stepNumber: followUpQuestionCount + 1
        )
    }

    private func scheduleMockDiscoveryFallback(forStep stepNumber: Int) {
        discoveryFallbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self else { return }
            guard self.phase == .gatheringInput else { return }
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
        let requestedTone = toneSlot?.trimmingCharacters(in: .whitespacesAndNewlines)
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
            facts.append("Current requested characters: \(characters.joined(separator: ", "))")
        }

        return facts
    }
}
