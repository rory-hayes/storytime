import SwiftUI

struct NewStoryJourneyView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: StoryLibraryStore

    @State private var selectedChildProfileId: UUID?
    @State private var usePastStory = false
    @State private var selectedSeriesId: UUID?
    @State private var usePastCharacters = false
    @State private var lengthMinutes = 4
    @State private var experienceMode: StoryExperienceMode = .classic

    @State private var shouldStart = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.96, blue: 0.90), Color(red: 0.90, green: 0.95, blue: 1.00)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("New Story Journey")
                        .font(.system(size: 34, weight: .black, design: .rounded))

                    Text("Choose the child, story mood, and continuity rules before the live voice session starts.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    childCard
                    modeCard
                    optionsCard
                    storySourceCard
                    lengthCard
                    privacyCard
                    launchSummaryCard
                }
                .padding(20)
                .padding(.bottom, 96)
            }
        }
        .navigationDestination(isPresented: $shouldStart) {
            VoiceSessionView(
                plan: launchPlan,
                sourceSeries: selectedSeries,
                store: store
            )
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear {
            if selectedChildProfileId == nil {
                selectedChildProfileId = store.activeProfile?.id
                experienceMode = store.activeProfile?.preferredMode ?? .classic
            }
            if selectedSeriesId == nil {
                selectedSeriesId = store.visibleSeries.first?.id
            }
        }
    }

    private var selectedSeries: StorySeries? {
        store.seriesById(selectedSeriesId)
    }

    private var selectedChildProfile: ChildProfile? {
        store.profileById(selectedChildProfileId) ?? store.activeProfile
    }

    private var childCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Child profile")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            if store.childProfiles.count == 1, let profile = selectedChildProfile {
                childSummary(profile)
            } else {
                Picker("Child", selection: Binding(
                    get: { selectedChildProfileId ?? store.activeProfile?.id },
                    set: { newValue in
                        selectedChildProfileId = newValue
                        if let profile = store.profileById(newValue) {
                            experienceMode = profile.preferredMode
                        }
                    }
                )) {
                    ForEach(store.childProfiles) { profile in
                        Text(profile.displayName).tag(Optional(profile.id))
                    }
                }
                .pickerStyle(.menu)

                if let profile = selectedChildProfile {
                    childSummary(profile)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func childSummary(_ profile: ChildProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Text("Age \(profile.age) • \(profile.contentSensitivity.title)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(profile.preferredMode.title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(red: 0.14, green: 0.50, blue: 0.96).opacity(0.14)))
        }
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story mode")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(StoryExperienceMode.allCases) { mode in
                    Button {
                        experienceMode = mode
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(mode.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text(mode.summaryLine)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(experienceMode == mode ? Color(red: 0.14, green: 0.50, blue: 0.96).opacity(0.16) : .white)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Use past story", isOn: $usePastStory)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .accessibilityIdentifier("usePastStoryToggle")

            Toggle("Use old characters", isOn: $usePastCharacters)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .accessibilityIdentifier("useOldCharactersToggle")
        }
        .padding(16)
        .background(cardBackground)
    }

    @ViewBuilder
    private var storySourceCard: some View {
        if usePastStory {
            VStack(alignment: .leading, spacing: 12) {
                Text("Story Source")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                if store.visibleSeries.isEmpty {
                    Text("No past stories for this child yet. We will start a fresh story.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Past story", selection: Binding(
                        get: { selectedSeriesId ?? store.visibleSeries.first?.id },
                        set: { selectedSeriesId = $0 }
                    )) {
                        ForEach(store.visibleSeries) { series in
                            Text(series.title).tag(Optional(series.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("pastStoryPicker")
                    .onAppear {
                        if selectedSeriesId == nil {
                            selectedSeriesId = store.visibleSeries.first?.id
                        }
                    }
                }
            }
            .padding(16)
            .background(cardBackground)
        }
    }

    private var lengthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story length")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            HStack {
                Text("\(lengthMinutes) min")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                Spacer()
                Text("~\(max(1, lengthMinutes * 2)) scenes")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Stepper("Adjust length", value: $lengthMinutes, in: 1...10)
                .labelsHidden()
                .accessibilityIdentifier("storyLengthStepper")
        }
        .padding(16)
        .background(cardBackground)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Privacy and retention")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text("Raw audio is not saved. \(store.storyHistorySummary.lowercased()).")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if let profile = selectedChildProfile {
                Text(profile.contentSensitivity.generationDirective)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var launchSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session preview")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(summaryLine)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button("Start Voice Session") {
                if let profileId = selectedChildProfile?.id {
                    store.selectActiveProfile(profileId)
                }
                shouldStart = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .accessibilityIdentifier("startVoiceSessionButton")
        }
        .background(.ultraThinMaterial)
    }

    private var summaryLine: String {
        var parts: [String] = []
        if let profile = selectedChildProfile {
            parts.append("\(profile.displayName), age \(profile.age)")
            parts.append(profile.contentSensitivity.title.lowercased())
        }
        parts.append(experienceMode.title.lowercased())
        parts.append(usePastStory ? "continue from a saved story" : "start a brand-new story")
        parts.append(usePastCharacters ? "reuse earlier characters" : "create fresh characters")
        parts.append("\(lengthMinutes)-minute target")
        return parts.joined(separator: ", ")
    }

    private var launchPlan: StoryLaunchPlan {
        let mode: StoryLaunchMode
        if usePastStory, let id = selectedSeriesId {
            mode = .extend(seriesId: id)
        } else {
            mode = .new
        }

        return StoryLaunchPlan(
            mode: mode,
            childProfileId: selectedChildProfile?.id ?? store.activeProfile?.id ?? UUID(),
            experienceMode: experienceMode,
            usePastStory: usePastStory,
            selectedSeriesId: selectedSeriesId,
            usePastCharacters: usePastCharacters,
            lengthMinutes: lengthMinutes
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.white.opacity(0.88))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
            )
    }
}
