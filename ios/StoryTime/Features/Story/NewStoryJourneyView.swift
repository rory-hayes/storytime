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

    @State private var isStarting = false
    @State private var shouldStart = false
    @State private var blockedPreflightResponse: EntitlementPreflightResponse?
    @State private var launchErrorMessage: String?
    @State private var parentUpgradeSheet: JourneyParentUpgradeSheet?
    @State private var planCheckDebugEntries: [PlanCheckDebugEntry] = []

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
                    Text("Set Up the Next Story")
                        .font(.system(size: 34, weight: .black, design: .rounded))

                    Text("Choose who this story is for, how it should feel, and what StoryTime should carry into the live questions before narration begins.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    preflightCard
                    if let launchBlockPresentation {
                        launchBlockCard(launchBlockPresentation)
                    } else if let launchErrorMessage {
                        launchErrorCard(launchErrorMessage)
                    }
                    childCard
                    modeCard
                    optionsCard
                    storySourceCard
                    lengthCard
                    expectationsCard
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
                store: store,
                onReturnToLibrary: { dismiss() }
            )
        }
        .sheet(item: $parentUpgradeSheet) { destination in
            NavigationStack {
                switch destination {
                case .gate:
                    ParentAccessGateView(
                        onUnlock: { parentUpgradeSheet = .review },
                        onCancel: { parentUpgradeSheet = nil }
                    )
                case .review:
                    if let presentation = launchBlockPresentation {
                        JourneyUpgradeReviewView(
                            store: store,
                            presentation: presentation,
                            onDone: { parentUpgradeSheet = nil }
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .overlay(alignment: .bottom) {
            if PlanCheckDebugOverlay.isEnabled() {
                PlanCheckDebugOverlayView(entries: planCheckDebugEntries)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 112)
            }
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
            syncSelectedSeriesSelection()
        }
        .onChange(of: selectedChildProfileId) { _, _ in
            syncSelectedSeriesSelection()
            clearLaunchBlockState()
        }
        .onChange(of: usePastStory) { _, isEnabled in
            if !isEnabled {
                usePastCharacters = false
            }
            syncSelectedSeriesSelection()
            clearLaunchBlockState()
        }
        .onChange(of: selectedSeriesId) { _, _ in
            if !characterReuseAvailable {
                usePastCharacters = false
            }
            clearLaunchBlockState()
        }
        .onChange(of: usePastCharacters) { _, _ in
            clearLaunchBlockState()
        }
        .onChange(of: lengthMinutes) { _, _ in
            clearLaunchBlockState()
        }
        .onChange(of: parentUpgradeSheet) { _, destination in
            if destination == nil {
                refreshBlockedStateAfterParentReview()
            }
        }
    }

    private var selectedSeries: StorySeries? {
        scopedVisibleSeries.first(where: { $0.id == selectedSeriesId })
    }

    private var selectedChildProfile: ChildProfile? {
        store.profileById(selectedChildProfileId) ?? store.activeProfile
    }

    private var scopedVisibleSeries: [StorySeries] {
        store.visibleSeries(for: selectedChildProfile?.id ?? store.activeProfile?.id)
    }

    private var characterReuseAvailable: Bool {
        guard usePastStory, let selectedSeries else { return false }
        return !selectedSeries.characterHints.isEmpty
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
                        syncSelectedSeriesSelection()
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

    private var preflightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Before the voice session")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(preflightSummary)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("journeyPreflightSummary")

            Text(parentHandoffSummary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyParentHandoffSummary")
        }
        .padding(16)
        .background(cardBackground)
    }

    private func launchBlockCard(_ presentation: JourneyLaunchBlockPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Needs a parent", systemImage: "lock.shield")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.50, blue: 0.96))

            Text(presentation.title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .accessibilityIdentifier("journeyLaunchBlockTitle")

            Text(presentation.summary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyLaunchBlockSummary")

            Text(presentation.footnote)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyLaunchBlockFootnote")

            Button("Ask a Parent to Review Plans") {
                parentUpgradeSheet = .gate
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("journeyAskParentButton")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(red: 0.97, green: 0.48, blue: 0.46).opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("journeyLaunchBlockCard")
    }

    private func launchErrorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plan check unavailable")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .accessibilityIdentifier("journeyLaunchErrorTitle")

            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyLaunchErrorSummary")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
        )
        .accessibilityIdentifier("journeyLaunchErrorCard")
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
            Text("Story path")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text("Choose whether this starts fresh or continues one saved series for this child.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyStoryPathIntro")

            Toggle("Use past story", isOn: $usePastStory)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .accessibilityIdentifier("usePastStoryToggle")

            Text(pastStoryOptionSummary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("pastStoryOptionSummary")

            Toggle("Use old characters", isOn: $usePastCharacters)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .accessibilityIdentifier("useOldCharactersToggle")
                .disabled(!characterReuseAvailable)

            Text(pastCharactersOptionSummary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("pastCharactersOptionSummary")
        }
        .padding(16)
        .background(cardBackground)
    }

    @ViewBuilder
    private var storySourceCard: some View {
        if usePastStory {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved series to continue")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("journeyStorySourceTitle")

                if scopedVisibleSeries.isEmpty {
                    Text("No past stories for this child yet. We will start a fresh story.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("noPastStoriesMessage")
                } else {
                    Picker("Past story", selection: Binding(
                        get: { selectedSeriesId ?? scopedVisibleSeries.first?.id },
                        set: { selectedSeriesId = $0 }
                    )) {
                        ForEach(scopedVisibleSeries) { series in
                            Text(series.title).tag(Optional(series.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("pastStoryPicker")
                    .onAppear {
                        syncSelectedSeriesSelection()
                    }

                    Text(selectedPastStorySummary)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("selectedPastStorySummary")
                }
            }
            .padding(16)
            .background(cardBackground)
        }
    }

    private var lengthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Length and pacing")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            HStack {
                Text("\(lengthMinutes) min")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                Spacer()
                Text("~\(max(1, lengthMinutes * 2)) scenes")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(lengthSummary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyLengthSummary")

            Stepper("Adjust length", value: $lengthMinutes, in: 1...10)
                .labelsHidden()
                .accessibilityIdentifier("storyLengthStepper")
        }
        .padding(16)
        .background(cardBackground)
    }

    private var expectationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What happens next")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            expectationLine(
                title: "Live follow-up first",
                summary: "StoryTime asks up to 3 live questions before it builds the story."
            )
            .accessibilityIdentifier("journeyExpectationLive")

            expectationLine(
                title: "Scene-by-scene narration",
                summary: "After the live questions, StoryTime narrates the adventure one scene at a time."
            )
            .accessibilityIdentifier("journeyExpectationNarration")

            expectationLine(
                title: "Interruptions stay live",
                summary: "During narration, the child can still ask a question, ask for repetition, or change what happens next."
            )
            .accessibilityIdentifier("journeyExpectationInterruptions")
        }
        .padding(16)
        .background(cardBackground)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Privacy and retention")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text("Raw audio is not saved. Live questions, story prompts, and generated scenes are sent for live processing. \(historyRetentionSummary).")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyPrivacySummary")

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
            Text("Launch preview")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Text(liveFollowUpSummary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyLiveFollowUpSummary")

            Text(continuitySummary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyContinuitySummary")

            Text(characterPlanSummary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyCharacterPlanSummary")

            Text(summaryLine)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("journeyLaunchSummary")
        }
        .padding(16)
        .background(cardBackground)
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            Text("Parents finish setup here, then hand the device to the child for the live questions. Parent controls stay outside the live story.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .accessibilityIdentifier("journeyStartFooterSummary")

            Button(primaryActionTitle) {
                if blockedPreflightResponse != nil {
                    parentUpgradeSheet = .gate
                    return
                }

                if let override = UITestSeed.entitlementPreflightOverride(
                    for: launchPlan,
                    childProfileCount: store.childProfiles.count
                ) {
                    handlePreflightDecision(override)
                    return
                }

                Task {
                    await startSessionIfAllowed()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .disabled(isStarting)
            .accessibilityIdentifier("startVoiceSessionButton")

            if isStarting {
                ProgressView()
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("journeyPlanCheckProgress")
            }
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

    private var primaryActionTitle: String {
        if isStarting {
            return "Checking Plan..."
        }

        if blockedPreflightResponse != nil {
            return "Ask a Parent to Review Plans"
        }

        return "Start Voice Session"
    }

    private var launchBlockPresentation: JourneyLaunchBlockPresentation? {
        guard let blockedPreflightResponse else { return nil }
        return JourneyLaunchBlockPresentation(
            response: blockedPreflightResponse,
            childName: selectedChildProfile?.displayName,
            seriesTitle: selectedSeries?.title
        )
    }

    private var historyRetentionSummary: String {
        if store.privacySettings.saveStoryHistory {
            return "\(store.storyHistorySummary) on this device"
        }
        return "Story history is off on this device"
    }

    private var preflightSummary: String {
        if let profile = selectedChildProfile {
            return "Set up \(profile.displayName)'s child profile, story path, and session length before the live questions begin."
        }

        return "Set up the child profile, story path, and session length before the live questions begin."
    }

    private var parentHandoffSummary: String {
        "This screen is the preflight step. It keeps setup and continuity choices clear before the child starts speaking."
    }

    private var liveFollowUpSummary: String {
        "Before narration, StoryTime asks up to 3 live questions and then builds the story scene by scene."
    }

    private var pastStoryOptionSummary: String {
        guard !scopedVisibleSeries.isEmpty else {
            return "This child has no saved stories yet, so StoryTime will start fresh."
        }

        if usePastStory {
            return "Continue the selected saved series for this child. StoryTime will recap the latest episode during the live questions before it creates the next episode."
        }

        return "Turn on Use past story to continue one saved series for this child. StoryTime will recap the latest episode during the live questions."
    }

    private var pastCharactersOptionSummary: String {
        guard usePastStory else {
            return "Turn on Use past story to reuse familiar characters from one saved series."
        }

        guard let selectedSeries else {
            return "Choose a saved series first if you want to reuse familiar characters."
        }

        guard !selectedSeries.characterHints.isEmpty else {
            return "This saved series does not have reusable character hints yet, so StoryTime will ask for fresh characters."
        }

        return "If you turn on Use old characters, StoryTime will reuse \(familiarCharactersText(for: selectedSeries)) from \(selectedSeries.title)."
    }

    private var selectedPastStorySummary: String {
        guard let selectedSeries else {
            return "Choose a saved story to continue."
        }

        return "Selected series: \(selectedSeries.title). StoryTime will recap the latest episode during the live questions before it creates the next episode."
    }

    private var continuitySummary: String {
        if usePastStory, let selectedSeries {
            return "Story path: Continue \(selectedSeries.title) as a new episode after the live questions."
        }

        return "Story path: Start a brand-new story after the live questions."
    }

    private var characterPlanSummary: String {
        if characterReuseAvailable, usePastCharacters, let selectedSeries {
            return "Character plan: Reuse \(familiarCharactersText(for: selectedSeries)) while the next episode is planned."
        }

        if usePastStory {
            return "Character plan: The live questions can keep familiar characters or add new ones for this next episode."
        }

        return "Character plan: The live questions will decide the characters for this new story."
    }

    private var lengthSummary: String {
        "Shorter stories move faster. Longer stories add more narrated scenes after the live questions."
    }

    private func familiarCharactersText(for series: StorySeries) -> String {
        let hints = series.characterHints.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        switch hints.count {
        case 0:
            return "familiar characters"
        case 1:
            return hints[0]
        case 2:
            return "\(hints[0]) and \(hints[1])"
        default:
            let prefix = hints.dropLast().joined(separator: ", ")
            return "\(prefix), and \(hints.last ?? "a familiar friend")"
        }
    }

    private var launchPlan: StoryLaunchPlan {
        let mode: StoryLaunchMode
        if usePastStory, let id = selectedSeries?.id {
            mode = .extend(seriesId: id)
        } else {
            mode = .new
        }

        return StoryLaunchPlan(
            mode: mode,
            childProfileId: selectedChildProfile?.id ?? store.activeProfile?.id ?? UUID(),
            experienceMode: experienceMode,
            usePastStory: usePastStory,
            selectedSeriesId: selectedSeries?.id,
            usePastCharacters: usePastCharacters,
            lengthMinutes: lengthMinutes
        )
    }

    @MainActor
    private func startSessionIfAllowed() async {
        launchErrorMessage = nil
        for message in AppConfig.debugCandidateBaseURLMessages() {
            appendPlanCheckDebug(message)
        }
        appendPlanCheckDebug(PlanCheckDebugKind.newStory.preparingMessage)

        guard let request = EntitlementPreflightRequest(plan: launchPlan, childProfileCount: store.childProfiles.count) else {
            appendPlanCheckDebug(PlanCheckDebugKind.newStory.skippedMessage)
            allowLaunch()
            return
        }

        isStarting = true
        defer { isStarting = false }

        do {
            let client = configuredPlanCheckClient()
            let response = try await client.preflightEntitlements(request: request)
            appendPlanCheckDebug(PlanCheckDebugKind.newStory.decisionMessage(for: response))
            handlePreflightDecision(response)
        } catch {
            blockedPreflightResponse = nil
            appendPlanCheckDebug(PlanCheckDebugOverlay.failureMessage(for: error))
            launchErrorMessage = PlanStatusPresentation.launchCheckMessage(for: error)
        }
    }

    @MainActor
    private func handlePreflightDecision(_ response: EntitlementPreflightResponse) {
        launchErrorMessage = nil

        if response.allowed {
            blockedPreflightResponse = nil
            allowLaunch()
        } else {
            blockedPreflightResponse = response
        }
    }

    @MainActor
    private func allowLaunch() {
        blockedPreflightResponse = nil
        if let profileId = selectedChildProfile?.id {
            store.selectActiveProfile(profileId)
        }
        shouldStart = true
    }

    private func clearLaunchBlockState() {
        blockedPreflightResponse = nil
        launchErrorMessage = nil
    }

    private func refreshBlockedStateAfterParentReview() {
        guard let blockedResponse = blockedPreflightResponse,
              let currentSnapshot = AppEntitlements.currentSnapshot else {
            return
        }

        let tokenChanged = AppEntitlements.currentToken != blockedResponse.entitlements?.token
        let snapshotChanged = currentSnapshot != blockedResponse.snapshot
        if tokenChanged || snapshotChanged {
            clearLaunchBlockState()
        }
    }

    private func configuredPlanCheckClient() -> APIClient {
        let client = APIClient()
        client.traceHandler = { event in
            guard let message = PlanCheckDebugOverlay.traceMessage(for: event) else {
                return
            }

            Task { @MainActor in
                appendPlanCheckDebug(message)
            }
        }
        return client
    }

    @MainActor
    private func appendPlanCheckDebug(_ message: String) {
        guard PlanCheckDebugOverlay.isEnabled() else { return }
        guard planCheckDebugEntries.last?.message != message else { return }

        planCheckDebugEntries.append(PlanCheckDebugEntry(message: message))
        if planCheckDebugEntries.count > 6 {
            planCheckDebugEntries.removeFirst(planCheckDebugEntries.count - 6)
        }
    }

    private func syncSelectedSeriesSelection() {
        guard let selectedSeriesId else {
            self.selectedSeriesId = scopedVisibleSeries.first?.id
            return
        }

        guard scopedVisibleSeries.contains(where: { $0.id == selectedSeriesId }) else {
            self.selectedSeriesId = scopedVisibleSeries.first?.id
            return
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.white.opacity(0.88))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
            )
    }

    private func expectationLine(title: String, summary: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(summary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

private enum JourneyParentUpgradeSheet: String, Identifiable {
    case gate
    case review

    var id: String { rawValue }
}

private struct JourneyLaunchBlockPresentation {
    let response: EntitlementPreflightResponse
    let title: String
    let summary: String
    let footnote: String
    let planTitle: String
    let planSummary: String

    init(
        response: EntitlementPreflightResponse,
        childName: String?,
        seriesTitle: String?
    ) {
        self.response = response
        let childName = childName ?? "this child"
        let seriesTitle = seriesTitle ?? "this saved story"
        self.planTitle = response.snapshot.tier == .plus ? "Plus" : "Starter"
        self.planSummary = Self.planAllowanceSummary(for: response.snapshot)

        switch response.blockReason ?? .newStoryNotAllowed {
        case .childProfileLimit:
            title = "This plan is set up for fewer child profiles right now."
            summary = "Ask a parent to review plan options before starting another story for \(childName)."
            footnote = "Parent controls and saved-story replay still stay available on this device."
        case .storyLengthExceeded:
            title = "This story is longer than this plan allows right now."
            summary = "Try a shorter story length or ask a parent to review plan options before \(childName) starts."
            footnote = "Live questions and narration do not begin until a parent finishes setup here."
        case .newStoryNotAllowed, .storyStartsExhausted:
            title = "This plan can't start another new story right now."
            summary = "Ask a parent to review plan options before \(childName) starts a fresh live story."
            footnote = "Saved stories already on this device can still be replayed."
        case .continuationNotAllowed, .continuationsExhausted:
            title = "This plan can't start a new episode right now."
            summary = "Ask a parent to review plan options before continuing \(seriesTitle)."
            footnote = "Replay of saved stories stays available on this device."
        }
    }

    private static func planAllowanceSummary(for snapshot: EntitlementSnapshot) -> String {
        let planName = snapshot.tier == .plus ? "Plus" : "Starter"
        let profileLabel = snapshot.maxChildProfiles == 1 ? "child profile" : "child profiles"
        return "\(planName) currently allows up to \(snapshot.maxChildProfiles) \(profileLabel), \(allowanceSummary(for: snapshot.remainingStoryStarts, singular: "new story start", plural: "new story starts", available: snapshot.canStartNewStories)), and \(allowanceSummary(for: snapshot.remainingContinuations, singular: "saved-series continuation", plural: "saved-series continuations", available: snapshot.canContinueSavedSeries)) in the current window."
    }

    private static func allowanceSummary(
        for remaining: Int?,
        singular: String,
        plural: String,
        available: Bool
    ) -> String {
        if let remaining {
            let label = remaining == 1 ? singular : plural
            return "\(remaining) \(label)"
        }

        return available ? plural : "no \(plural)"
    }
}

private struct JourneyUpgradeReviewView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: StoryLibraryStore
    let presentation: JourneyLaunchBlockPresentation
    let onDone: () -> Void

    var body: some View {
        List {
            Section {
                Text("Parent plan review")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .accessibilityIdentifier("journeyUpgradeReviewTitle")

                Text(presentation.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("journeyUpgradeReviewBlockTitle")

                Text(presentation.summary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("journeyUpgradeReviewSummary")
            }

            Section("Current plan") {
                Text(presentation.planTitle)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .accessibilityIdentifier("journeyUpgradeReviewPlanTitle")

                Text(presentation.planSummary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("journeyUpgradeReviewPlanSummary")

                Text(presentation.footnote)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("journeyUpgradeReviewFootnote")
            }

            Section("Next steps") {
                NavigationLink("Open Parent Controls") {
                    ParentTrustCenterView(store: store)
                }
                .accessibilityIdentifier("journeyUpgradeReviewParentControlsButton")

                Text("Current plan review, upgrades, and restore stay in Parent Controls. After a parent updates the plan there, come back here and try again without moving purchase UI into the live child story.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("journeyUpgradeReviewNextStepsSummary")
            }
        }
        .navigationTitle("Plan Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    onDone()
                    dismiss()
                }
            }
        }
        .onAppear {
            ClientLaunchTelemetry.recordBlockedReviewPresented(
                surface: .newStoryJourney,
                response: presentation.response
            )
        }
    }
}
