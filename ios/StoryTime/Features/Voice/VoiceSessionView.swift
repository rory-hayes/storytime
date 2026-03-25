import SwiftUI

struct VoiceStartupDebugOverlay: View {
    let snapshot: PracticeSessionViewModel.VoiceStartupDebugSnapshot

    static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment["STORYTIME_DEBUG_VOICE_STARTUP_OVERLAY"] == "1"
    }

    static func messages(for snapshot: PracticeSessionViewModel.VoiceStartupDebugSnapshot) -> [String] {
        var messages = ["Phase: \(snapshot.phase)"]

        if let startupStage = snapshot.startupStage {
            messages.append("Startup step: \(startupStage)")
        }
        if !snapshot.statusMessage.isEmpty {
            messages.append("Status: \(snapshot.statusMessage)")
        }
        if let lastStartupFailure = snapshot.lastStartupFailure {
            messages.append("Startup failure: \(lastStartupFailure)")
        }
        if let startupDetail = snapshot.startupDetail, !startupDetail.isEmpty {
            messages.append("Bridge detail: \(startupDetail)")
        }
        if !snapshot.errorMessage.isEmpty {
            messages.append("Error: \(snapshot.errorMessage)")
        }

        messages.append(contentsOf: snapshot.traceEvents.map(traceMessage(for:)))
        return messages
    }

    static func traceMessage(for event: PracticeSessionViewModel.SessionTraceEvent) -> String {
        let operation = event.apiOperation?.rawValue ?? "none"
        if let statusCode = event.statusCode {
            return "Trace: \(event.kind.rawValue) \(event.source) (\(operation) \(statusCode))"
        }
        return "Trace: \(event.kind.rawValue) \(event.source) (\(operation))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Voice Startup Debug")
                .font(.system(size: 12, weight: .black, design: .rounded))

            ForEach(Self.messages(for: snapshot), id: \.self) { message in
                Text(message)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .foregroundStyle(.white)
        .padding(12)
        .accessibilityIdentifier("voiceStartupDebugOverlay")
    }
}

private final class UITestSessionAPIClient: APIClienting {
    var traceHandler: ((APIClientTraceEvent) -> Void)? {
        get { base.traceHandler }
        set { base.traceHandler = newValue }
    }

    var resolvedRegion: StoryTimeRegion? { base.resolvedRegion }

    private let base: APIClienting

    init(base: APIClienting) {
        self.base = base
    }

    func prepareConnection() async throws -> URL {
        try await base.prepareConnection()
    }

    func bootstrapSessionIdentity(baseURL: URL) async throws {
        try await base.bootstrapSessionIdentity(baseURL: baseURL)
    }

    func fetchLaunchTelemetryReport() async throws -> LaunchTelemetryJoinedReport {
        try await base.fetchLaunchTelemetryReport()
    }

    func syncEntitlements(request body: EntitlementSyncRequest) async throws -> EntitlementBootstrapEnvelope {
        try await base.syncEntitlements(request: body)
    }

    func redeemPromoCode(request body: PromoCodeRedemptionRequest) async throws -> EntitlementBootstrapEnvelope {
        try await base.redeemPromoCode(request: body)
    }

    func preflightEntitlements(request body: EntitlementPreflightRequest) async throws -> EntitlementPreflightResponse {
        try await base.preflightEntitlements(request: body)
    }

    func fetchVoices() async throws -> [String] {
        try await base.fetchVoices()
    }

    func createRealtimeSession(request body: RealtimeSessionRequest) async throws -> RealtimeSessionEnvelope {
        try await base.createRealtimeSession(request: body)
    }

    func discoverStoryTurn(request body: DiscoveryRequest) async throws -> DiscoveryEnvelope {
        try await base.discoverStoryTurn(request: body)
    }

    func generateStory(request body: GenerateStoryRequest) async throws -> GenerateStoryEnvelope {
        let titlePrefix = body.storyBrief.characters.first ?? "StoryTime"
        let title = "\(titlePrefix) and the Glow Trail"
        let scenes = [
            StoryScene(
                sceneId: "1",
                text: "\(titlePrefix) answered the live questions and followed a glowing trail through \(body.storyBrief.setting).",
                durationSec: 35
            ),
            StoryScene(
                sceneId: "2",
                text: "\(titlePrefix) explored a \(body.storyBrief.tone) surprise about \(body.storyBrief.theme.lowercased()) with \(body.storyBrief.characters.joined(separator: " and ")).",
                durationSec: 35
            )
        ]

        return GenerateStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: StoryData(
                storyId: "ui-test-story-\(UUID().uuidString)",
                title: title,
                estimatedDurationSec: scenes.reduce(0) { $0 + $1.durationSec },
                scenes: scenes,
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: nil
            )
        )
    }

    func reviseStory(request body: ReviseStoryRequest) async throws -> ReviseStoryEnvelope {
        let revisedScenes = body.remainingScenes.enumerated().map { index, scene in
            StoryScene(
                sceneId: scene.sceneId,
                text: index == 0 ? "\(scene.text) StoryTime also added: \(body.userUpdate)." : scene.text,
                durationSec: scene.durationSec
            )
        }

        return ReviseStoryEnvelope(
            blocked: false,
            safeMessage: nil,
            data: RevisedStoryData(
                storyId: body.storyId,
                revisedFromSceneIndex: body.currentSceneIndex,
                scenes: revisedScenes,
                safety: StorySafety(inputModeration: "pass", outputModeration: "pass"),
                engine: nil
            )
        )
    }

    func createEmbeddings(inputs: [String]) async throws -> [[Double]] {
        try await base.createEmbeddings(inputs: inputs)
    }
}

struct VoiceSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PracticeSessionViewModel
    @State private var completionDestination: CompletionDestination?

    private let store: StoryLibraryStore
    private let onReturnToLibrary: (() -> Void)?

    init(
        plan: StoryLaunchPlan,
        sourceSeries: StorySeries?,
        store: StoryLibraryStore,
        onReturnToLibrary: (() -> Void)? = nil
    ) {
        let apiClient: APIClienting
        if ProcessInfo.processInfo.environment["STORYTIME_UI_TEST_MODE"] == "1" {
            apiClient = UITestSessionAPIClient(base: APIClient())
        } else {
            apiClient = APIClient()
        }

        _viewModel = StateObject(
            wrappedValue: PracticeSessionViewModel(plan: plan, sourceSeries: sourceSeries, store: store, api: apiClient)
        )
        self.store = store
        self.onReturnToLibrary = onReturnToLibrary
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.95, blue: 0.99), Color(red: 0.90, green: 0.97, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                headerCard
                sessionCueCard
                if let completionPresentation {
                    completionCard(completionPresentation)
                }

                WaveformView(
                    speaker: viewModel.activeSpeaker,
                    phase: viewModel.waveformPhase,
                    childLevel: viewModel.microphoneLevel,
                    aiLevel: viewModel.aiVoiceLevel
                )
                    .accessibilityIdentifier("waveformModule")

                transcriptCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(20)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .overlay(alignment: .bottomTrailing) {
            if let realtimeVoiceClient = viewModel.realtimeVoiceClient {
                RealtimeVoiceBridgeView(client: realtimeVoiceClient)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if VoiceStartupDebugOverlay.isEnabled() {
                VoiceStartupDebugOverlay(snapshot: viewModel.voiceStartupDebugSnapshot)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let completionPresentation {
                completionActionBar(completionPresentation)
            } else {
                listeningHintBar
            }
        }
        .navigationDestination(item: $completionDestination) { destination in
            switch destination {
            case .seriesDetail(let seriesID):
                StorySeriesDetailView(seriesId: seriesID, store: store)
            }
        }
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.startSession()
        }
    }

    private enum CompletionDestination: Hashable, Identifiable {
        case seriesDetail(UUID)

        var id: String {
            switch self {
            case .seriesDetail(let seriesID):
                return "series-\(seriesID.uuidString)"
            }
        }
    }

    private struct CompletionPresentation {
        let title: String
        let summary: String
        let trustNote: String
        let libraryButtonTitle: String
        let series: StorySeries?
    }

    private var sessionCueCard: some View {
        let cue = viewModel.sessionCue
        let accentColor = cueColor(for: cue.tone)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 12, height: 12)

                Text(cue.title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("sessionStateTitleLabel")

                Spacer()
            }

            Text(cue.detail)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("sessionStateDetailLabel")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cue.title)
        .accessibilityValue("\(cue.detail)\n\(cue.actionHint)")
        .accessibilityIdentifier("sessionCueCard")
    }

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Voice Story Session")
                    .font(.system(size: 32, weight: .black, design: .rounded))

                HStack(spacing: 8) {
                    Text(viewModel.childName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(viewModel.modeTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.8)))
                }
            }

            Spacer()

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(.white.opacity(0.75)))
                    .accessibilityIdentifier("statusMessageLabel")
            }
        }
    }

    private var transcriptCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.aiPrompt)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .accessibilityIdentifier("aiPromptLabel")

                if !viewModel.latestUserTranscript.isEmpty {
                    Text("You said: \(viewModel.latestUserTranscript)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("userTranscriptLabel")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("errorLabel")
                }

                if let story = viewModel.generatedStory {
                    Divider()
                    Text(story.title)
                        .font(.title3.bold())
                        .accessibilityIdentifier("storyTitleLabel")

                    Text("Scene \(viewModel.currentSceneIndex + 1)/\(max(story.scenes.count, 1))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !viewModel.nowNarratingText.isEmpty {
                        Text(viewModel.nowNarratingText)
                            .font(.body)
                            .accessibilityIdentifier("narrationTextLabel")
                    }
                } else {
                    Divider()
                    Text("The storyteller will ask up to 3 follow-up questions before narration starts.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Divider()
                Text(viewModel.privacySummary)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("voicePrivacySummaryLabel")
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
        )
        .scrollIndicators(.hidden)
    }

    private var completionPresentation: CompletionPresentation? {
        guard viewModel.hasCompletedStory, let story = viewModel.generatedStory else { return nil }

        let series = viewModel.completionSeries
        let childName = viewModel.childName
        let savedSummary: String
        if series != nil {
            savedSummary = "“\(story.title)” is ready for \(childName). Replay it now, start a new episode later, or head back to saved stories."
        } else {
            savedSummary = "“\(story.title)” is ready for \(childName). Replay it now, or head back home when you're finished."
        }

        let trustNote: String
        if series != nil {
            trustNote = "Saved-story controls stay outside this finished story. Raw audio was not saved."
        } else {
            trustNote = "Raw audio was not saved. Parent controls stay outside this finished story."
        }

        return CompletionPresentation(
            title: "Story finished",
            summary: savedSummary,
            trustNote: trustNote,
            libraryButtonTitle: series == nil ? "Back to Home" : "Back to Saved Stories",
            series: series
        )
    }

    private func completionCard(_ presentation: CompletionPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(presentation.title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .accessibilityIdentifier("sessionCompletionTitleLabel")

            Text(presentation.summary)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("sessionCompletionSummaryLabel")

            Text(presentation.trustNote)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("sessionCompletionTrustLabel")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.green.opacity(0.20), lineWidth: 1)
        )
        .accessibilityIdentifier("sessionCompletionCard")
    }

    private var listeningHintBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(cueColor(for: viewModel.sessionCue.tone))
                        .frame(width: 8, height: 8)

                    Text(viewModel.sessionCue.actionHint)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("voiceActionHintLabel")
                }

                Text("Speak anytime to answer or interrupt. Ask a grown-up to leave the live story if you need parent controls.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("voiceProcessingHintLabel")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    private func completionActionBar(_ presentation: CompletionPresentation) -> some View {
        VStack(spacing: 0) {
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Task {
                        await viewModel.replayCompletedStory()
                    }
                } label: {
                    Label("Replay This Story", systemImage: "repeat")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("completionReplayButton")

                if let series = presentation.series {
                    Button {
                        if shouldReturnToExistingSeriesDetail {
                            dismiss()
                        } else {
                            completionDestination = .seriesDetail(series.id)
                        }
                    } label: {
                        Label("Start a New Episode", systemImage: "plus.app")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("completionContinueButton")
                }

                Button(presentation.libraryButtonTitle) {
                    if let onReturnToLibrary {
                        onReturnToLibrary()
                    } else {
                        dismiss()
                    }
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("completionLibraryButton")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial)
    }

    private var shouldReturnToExistingSeriesDetail: Bool {
        switch viewModel.launchPlan.mode {
        case .repeatEpisode, .extend:
            return true
        case .new:
            return false
        }
    }

    private func cueColor(for tone: PracticeSessionViewModel.SessionCueTone) -> Color {
        switch tone {
        case .neutral:
            return Color.blue.opacity(0.75)
        case .listening:
            return Color.green.opacity(0.80)
        case .storytelling:
            return Color.orange.opacity(0.85)
        case .update:
            return Color.mint.opacity(0.85)
        case .paused:
            return Color.yellow.opacity(0.85)
        case .success:
            return Color.green.opacity(0.90)
        case .warning:
            return Color.pink.opacity(0.75)
        case .error:
            return Color.red.opacity(0.80)
        }
    }
}
