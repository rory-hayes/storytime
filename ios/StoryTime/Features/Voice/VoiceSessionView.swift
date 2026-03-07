import SwiftUI

struct VoiceSessionView: View {
    @StateObject private var viewModel: PracticeSessionViewModel

    init(plan: StoryLaunchPlan, sourceSeries: StorySeries?, store: StoryLibraryStore) {
        _viewModel = StateObject(
            wrappedValue: PracticeSessionViewModel(plan: plan, sourceSeries: sourceSeries, store: store)
        )
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
        .safeAreaInset(edge: .bottom) {
            listeningHintBar
        }
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.startSession()
        }
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

    private var listeningHintBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                Text("Speak anytime to answer or interrupt. Raw audio is not saved, and your words are sent for live processing.")
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
}
