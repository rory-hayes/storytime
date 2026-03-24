import SwiftUI

struct StorySeriesDetailView: View {
    let seriesId: UUID
    @ObservedObject var store: StoryLibraryStore
    @State private var shouldStartNewEpisode = false
    @State private var isCheckingPlan = false
    @State private var blockedPreflightResponse: EntitlementPreflightResponse?
    @State private var launchErrorMessage: String?
    @State private var parentUpgradeSheet: SeriesDetailParentUpgradeSheet?
    @State private var planCheckDebugEntries: [PlanCheckDebugEntry] = []

    var body: some View {
        Group {
            if let series {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(series)
                        continueStoryCard(series)
                        continuityCard(series)
                        episodeList(series)
                        managementCard
                    }
                    .padding(20)
                }
            } else {
                Text("Series not found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("seriesNotFoundLabel")
            }
        }
        .navigationDestination(isPresented: $shouldStartNewEpisode) {
            if let series {
                VoiceSessionView(
                    plan: newEpisodeLaunchPlan(for: series),
                    sourceSeries: series,
                    store: store
                )
            }
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
                    if let presentation = detailLaunchBlockPresentation {
                        SeriesDetailUpgradeReviewView(
                            store: store,
                            presentation: presentation,
                            onDone: { parentUpgradeSheet = nil }
                        )
                    }
                }
            }
        }
        .onChange(of: parentUpgradeSheet) { _, destination in
            if destination == nil {
                refreshBlockedStateAfterParentReview()
            }
        }
        .overlay(alignment: .bottom) {
            if PlanCheckDebugOverlay.isEnabled() {
                PlanCheckDebugOverlayView(entries: planCheckDebugEntries)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .navigationTitle("Story Series")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ series: StorySeries) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(series.title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .accessibilityIdentifier("seriesDetailTitle")

            Text("Episodes: \(series.episodeCount)")
                .foregroundStyle(.secondary)

            if let profileName = store.profileById(series.childProfileId)?.displayName {
                Text(profileName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white))
            }
        }
    }

    private func continueStoryCard(_ series: StorySeries) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Continue this story")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .accessibilityIdentifier("seriesDetailContinueTitle")

            Text("Replay the latest adventure or start a new episode that keeps this world, these characters, and this child's saved continuity together.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailContinueSummary")

            if let presentation = detailLaunchBlockPresentation {
                detailLaunchBlockCard(presentation)
            } else if let launchErrorMessage {
                detailLaunchErrorCard(launchErrorMessage)
            }

            HStack(spacing: 10) {
                NavigationLink {
                    VoiceSessionView(
                        plan: repeatEpisodeLaunchPlan(for: series),
                        sourceSeries: series,
                        store: store
                    )
                } label: {
                    Label("Repeat", systemImage: "repeat")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("repeatEpisodeButton")

                Button {
                    if blockedPreflightResponse != nil {
                        parentUpgradeSheet = .gate
                        return
                    }

                    if let override = UITestSeed.entitlementPreflightOverride(
                        for: newEpisodeLaunchPlan(for: series),
                        childProfileCount: store.childProfiles.count
                    ) {
                        handlePreflightDecision(override)
                        return
                    }

                    Task {
                        await startNewEpisodeIfAllowed(for: series)
                    }
                } label: {
                    Label(newEpisodeButtonTitle, systemImage: newEpisodeButtonSystemImage)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCheckingPlan)
                .accessibilityIdentifier("newEpisodeButton")
            }

            Text("New episodes stay linked to this saved series for the selected child.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailContinueScopeHint")

            if isCheckingPlan {
                ProgressView()
                    .accessibilityIdentifier("seriesDetailPlanCheckProgress")
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func continuityCard(_ series: StorySeries) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story memory for the next episode")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .accessibilityIdentifier("seriesDetailContinuityTitle")

            Text("StoryTime uses these saved details to keep future episodes familiar without changing earlier ones.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailContinuitySummary")

            if let arcSummary = series.arcSummary, !arcSummary.isEmpty {
                Text(arcSummary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }

            if let places = series.favoritePlaces, !places.isEmpty {
                Text("Places to revisit: \(places.prefix(3).joined(separator: ", "))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let relationships = series.relationshipFacts, !relationships.isEmpty {
                Text("Important relationships: \(relationships.prefix(2).joined(separator: " • "))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let threads = series.unresolvedThreads, !threads.isEmpty {
                Text("Open story threads: \(threads.prefix(2).joined(separator: " • "))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var managementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved-story management")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .accessibilityIdentifier("seriesDetailManagementTitle")

            Text("Parents can remove saved stories or clear all saved story history from Parent Controls.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailParentControlsHint")
        }
        .padding(.top, 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.white.opacity(0.88))
    }

    private func episodeList(_ series: StorySeries) -> some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(series.episodes.reversed()) { episode in
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.headline)
                    Text(episode.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Scenes: \(episode.scenes.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white)
                )
            }
        }
    }

    private var series: StorySeries? {
        store.seriesById(seriesId)
    }

    private var detailLaunchBlockPresentation: SeriesDetailLaunchBlockPresentation? {
        guard let series, let blockedPreflightResponse else { return nil }
        return SeriesDetailLaunchBlockPresentation(
            response: blockedPreflightResponse,
            childName: store.profileById(series.childProfileId)?.displayName ?? store.activeProfile?.displayName,
            seriesTitle: series.title
        )
    }

    private var newEpisodeButtonTitle: String {
        if isCheckingPlan {
            return "Checking Plan..."
        }

        if blockedPreflightResponse != nil {
            return "Ask a Parent"
        }

        return "New Episode"
    }

    private var newEpisodeButtonSystemImage: String {
        blockedPreflightResponse == nil ? "plus.app" : "lock.shield"
    }

    private func launchChildProfileID(for series: StorySeries) -> UUID {
        store.activeProfile?.id ?? series.childProfileId ?? UUID()
    }

    private func repeatEpisodeLaunchPlan(for series: StorySeries) -> StoryLaunchPlan {
        StoryLaunchPlan(
            mode: .repeatEpisode(seriesId: series.id),
            childProfileId: launchChildProfileID(for: series),
            experienceMode: store.activeProfile?.preferredMode ?? .classic,
            usePastStory: true,
            selectedSeriesId: series.id,
            usePastCharacters: true,
            lengthMinutes: max(1, min(10, (series.latestEpisode?.estimatedDurationSec ?? 240) / 60))
        )
    }

    private func newEpisodeLaunchPlan(for series: StorySeries) -> StoryLaunchPlan {
        StoryLaunchPlan(
            mode: .extend(seriesId: series.id),
            childProfileId: launchChildProfileID(for: series),
            experienceMode: store.activeProfile?.preferredMode ?? .classic,
            usePastStory: true,
            selectedSeriesId: series.id,
            usePastCharacters: true,
            lengthMinutes: 4
        )
    }

    private func detailLaunchBlockCard(_ presentation: SeriesDetailLaunchBlockPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Needs a parent", systemImage: "lock.shield")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.50, blue: 0.96))

            Text(presentation.title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .accessibilityIdentifier("seriesDetailLaunchBlockTitle")

            Text(presentation.summary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailLaunchBlockSummary")

            Text(presentation.footnote)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailLaunchBlockFootnote")

            Button("Ask a Parent to Review Plans") {
                parentUpgradeSheet = .gate
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("seriesDetailAskParentButton")
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
        .accessibilityIdentifier("seriesDetailLaunchBlockCard")
    }

    private func detailLaunchErrorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plan check unavailable")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .accessibilityIdentifier("seriesDetailLaunchErrorTitle")

            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailLaunchErrorSummary")
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
        .accessibilityIdentifier("seriesDetailLaunchErrorCard")
    }

    @MainActor
    private func startNewEpisodeIfAllowed(for series: StorySeries) async {
        launchErrorMessage = nil
        for message in AppConfig.debugCandidateBaseURLMessages() {
            appendPlanCheckDebug(message)
        }
        appendPlanCheckDebug(PlanCheckDebugKind.continueStory.preparingMessage)
        guard let request = EntitlementPreflightRequest(
            plan: newEpisodeLaunchPlan(for: series),
            childProfileCount: store.childProfiles.count
        ) else {
            appendPlanCheckDebug(PlanCheckDebugKind.continueStory.skippedMessage)
            allowNewEpisodeLaunch()
            return
        }

        isCheckingPlan = true
        defer { isCheckingPlan = false }

        do {
            let client = configuredPlanCheckClient()
            let response = try await client.preflightEntitlements(request: request)
            appendPlanCheckDebug(PlanCheckDebugKind.continueStory.decisionMessage(for: response))
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
            allowNewEpisodeLaunch()
        } else {
            blockedPreflightResponse = response
        }
    }

    @MainActor
    private func allowNewEpisodeLaunch() {
        blockedPreflightResponse = nil
        shouldStartNewEpisode = true
    }

    private func refreshBlockedStateAfterParentReview() {
        guard let blockedResponse = blockedPreflightResponse,
              let currentSnapshot = AppEntitlements.currentSnapshot else {
            return
        }

        let tokenChanged = AppEntitlements.currentToken != blockedResponse.entitlements?.token
        let snapshotChanged = currentSnapshot != blockedResponse.snapshot
        if tokenChanged || snapshotChanged {
            blockedPreflightResponse = nil
            launchErrorMessage = nil
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
}

private enum SeriesDetailParentUpgradeSheet: String, Identifiable {
    case gate
    case review

    var id: String { rawValue }
}

private struct SeriesDetailLaunchBlockPresentation {
    let response: EntitlementPreflightResponse
    let title: String
    let summary: String
    let footnote: String
    let planTitle: String
    let planSummary: String

    init(response: EntitlementPreflightResponse, childName: String?, seriesTitle: String) {
        self.response = response
        let childName = childName ?? "this child"
        self.planTitle = response.snapshot.tier == .plus ? "Plus" : "Starter"
        self.planSummary = Self.planAllowanceSummary(for: response.snapshot)

        switch response.blockReason ?? .continuationNotAllowed {
        case .childProfileLimit:
            title = "This plan is set up for fewer child profiles right now."
            summary = "Ask a parent to review plan options before continuing \(seriesTitle) for \(childName)."
            footnote = "Replay of saved stories stays available on this device."
        case .storyLengthExceeded:
            title = "This next episode is longer than this plan allows right now."
            summary = "Ask a parent to review plan options before StoryTime starts another episode in \(seriesTitle)."
            footnote = "Replay of the latest saved episode stays available on this device."
        case .newStoryNotAllowed, .storyStartsExhausted, .continuationNotAllowed, .continuationsExhausted:
            title = "This plan can't start a new episode right now."
            summary = "Ask a parent to review plan options before continuing \(seriesTitle)."
            footnote = "Replay of the latest saved episode stays available on this device."
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

private struct SeriesDetailUpgradeReviewView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: StoryLibraryStore
    let presentation: SeriesDetailLaunchBlockPresentation
    let onDone: () -> Void

    var body: some View {
        List {
            Section {
                Text("Parent plan review")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .accessibilityIdentifier("seriesDetailUpgradeReviewTitle")

                Text(presentation.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("seriesDetailUpgradeReviewBlockTitle")

                Text(presentation.summary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("seriesDetailUpgradeReviewSummary")
            }

            Section("Current plan") {
                Text(presentation.planTitle)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .accessibilityIdentifier("seriesDetailUpgradeReviewPlanTitle")

                Text(presentation.planSummary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("seriesDetailUpgradeReviewPlanSummary")

                Text(presentation.footnote)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("seriesDetailUpgradeReviewFootnote")
            }

            Section("Next steps") {
                NavigationLink("Open Parent Controls") {
                    ParentTrustCenterView(store: store)
                }
                .accessibilityIdentifier("seriesDetailUpgradeReviewParentControlsButton")

                Text("Current plan review, upgrades, and restore stay in Parent Controls. After a parent updates the plan there, come back here and try this next episode again while replay stays separate.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("seriesDetailUpgradeReviewNextStepsSummary")
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
                surface: .storySeriesDetail,
                response: presentation.response
            )
        }
    }
}
