import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif

private let parentControlsDefaultMaxChildProfiles = 3

struct HomeView: View {
    @ObservedObject var store: StoryLibraryStore
    @State private var localShowingNewJourney = false
    @State private var parentSheet: ParentSheetDestination?
    private let showingNewJourneyOverride: Binding<Bool>?

    init(store: StoryLibraryStore, showingNewJourneyOverride: Binding<Bool>? = nil) {
        self.store = store
        self.showingNewJourneyOverride = showingNewJourneyOverride
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(
                    colors: [Color(red: 0.98, green: 0.95, blue: 0.90), Color(red: 0.92, green: 0.96, blue: 0.99)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        activeProfileCard
                        privacyCard
                        storiesSection

                        Color.clear
                            .frame(height: 96)
                    }
                    .padding(20)
                }

                Button {
                    showingNewJourneyBinding.wrappedValue = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(
                            Circle()
                                .fill(Color(red: 0.14, green: 0.50, blue: 0.96))
                        )
                        .shadow(radius: 8, y: 4)
                }
                .padding(24)
                .accessibilityIdentifier("newStoryButton")
            }
            .sheet(isPresented: showingNewJourneyBinding) {
                NavigationStack {
                    NewStoryJourneyView(store: store)
                }
            }
            .sheet(item: $parentSheet) { destination in
                NavigationStack {
                    switch destination {
                    case .gate:
                        ParentAccessGateView(
                            onUnlock: { parentSheet = .hub },
                            onCancel: { parentSheet = nil }
                        )
                    case .hub:
                        ParentTrustCenterView(store: store)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("StoryTime")
                        .font(.system(size: 36, weight: .black, design: .rounded))

                    Text("Kids shape the story while it is happening.")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("homeHeroTitle")
                }

                Spacer()

                Button {
                    parentSheet = .gate
                } label: {
                    Label("Parent", systemImage: "lock.shield")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("parentControlsButton")
            }

            Text("Start with a few live questions, then StoryTime narrates the adventure scene by scene.")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("homeHeroSummary")
        }
    }

    private var activeProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active child")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(store.activeProfile?.displayName ?? "Story Explorer")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                }

                Spacer()

                if let active = store.activeProfile {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Age \(active.age)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text(active.contentSensitivity.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if store.childProfiles.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.childProfiles) { profile in
                            Button {
                                store.selectActiveProfile(profile.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.displayName)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Text("\(profile.preferredMode.title) mode")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(store.activeChildProfileId == profile.id ? Color(red: 0.14, green: 0.50, blue: 0.96).opacity(0.18) : .white.opacity(0.85))
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("profileChip-\(profile.displayName)")
                        }
                    }
                }
            }

            Text(activeProfileSummary)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("homeActiveProfileSummary")

            Button {
                showingNewJourneyBinding.wrappedValue = true
            } label: {
                Label("Start New Story", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("newStoryInlineButton")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
        )
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Parent controls and privacy")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            HStack(spacing: 10) {
                trustPill(title: "Raw audio", value: "Not saved")
                trustPill(title: "History", value: store.storyHistorySummary)
            }

            Text("Parent Controls cover child setup, safety defaults, retention, and deletion. Raw audio is not saved. Live questions and story generation are processed during each session. Saved history and continuity stay on this device afterward.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("homePrivacySummary")

            Button {
                parentSheet = .gate
            } label: {
                Label("Open Parent Controls", systemImage: "lock.shield")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("homeParentControlsEntryButton")

            Text("PARENT is a lightweight check on this device. It is not account authentication.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("homeParentControlsFootnote")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
        )
    }

    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Saved stories")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Text(librarySummary)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("homeLibrarySummary")

            if store.visibleSeries.isEmpty {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.75))
                    .frame(height: 148)
                    .overlay(
                        VStack(spacing: 8) {
                            Text(emptyStateTitle)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .accessibilityIdentifier("storiesEmptyStateTitle")
                            Text("Tap + to start a new voice story.")
                                .multilineTextAlignment(.center)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    )
            } else {
                ForEach(store.visibleSeries) { series in
                    NavigationLink {
                        StorySeriesDetailView(seriesId: series.id, store: store)
                    } label: {
                        StorySeriesCard(series: series, profileName: store.profileById(series.childProfileId)?.displayName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("seriesCard-\(series.id.uuidString)")
                }
            }
        }
    }

    private var emptyStateTitle: String {
        if let active = store.activeProfile {
            return "No stories yet for \(active.displayName)."
        }
        return "No stories yet."
    }

    private var activeProfileSummary: String {
        if let active = store.activeProfile {
            return "\(active.displayName) will answer a few live questions first, then StoryTime tells the story scene by scene."
        }
        return "Start with a few live questions, then StoryTime tells the story scene by scene."
    }

    private var librarySummary: String {
        if let active = store.activeProfile {
            if store.visibleSeries.isEmpty {
                return "Start a first story for \(active.displayName). Saved adventures can come back here for replay or a new episode."
            }
            return "Replay favorites or start a new episode for \(active.displayName) without losing the saved story world."
        }

        if store.visibleSeries.isEmpty {
            return "Start a first story. Saved adventures can come back here for replay or a new episode."
        }

        return "Replay favorites or start a new episode from the saved library."
    }

    private func trustPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Capsule(style: .continuous).fill(.white))
    }

    private var showingNewJourneyBinding: Binding<Bool> {
        showingNewJourneyOverride ?? $localShowingNewJourney
    }
}

private enum ParentSheetDestination: String, Identifiable {
    case gate
    case hub

    var id: String { rawValue }
}

struct ParentAccessGateView: View {
    private static let confirmationCode = "PARENT"

    let onUnlock: () -> Void
    let onCancel: () -> Void

    @State private var confirmationText = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            Image(systemName: "lock.shield")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color(red: 0.14, green: 0.50, blue: 0.96))

            Text("Parents only")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .accessibilityIdentifier("parentAccessGateTitle")

            Text("Type PARENT for a lightweight parent check before opening profile, privacy, and saved-story controls.")
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("parentAccessGateMessage")

            Text("This keeps quick taps out on this device. It is not a password or purchase login.")
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("parentAccessGateFootnote")

            TextField("Type PARENT", text: $confirmationText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .accessibilityIdentifier("parentAccessGateField")

            Button("Open Parent Controls") {
                guard isConfirmationValid else { return }
                onUnlock()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isConfirmationValid)
            .accessibilityIdentifier("unlockParentControlsButton")

            Button("Not now") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("cancelParentAccessGateButton")

            Spacer()
        }
        .padding(24)
        .navigationTitle("Parents Only")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isConfirmationValid: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == Self.confirmationCode
    }
}

private struct StorySeriesCard: View {
    let series: StorySeries
    let profileName: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(series.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .lineLimit(2)

                if let profileName, !profileName.isEmpty {
                    Text(profileName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if !series.characterHints.isEmpty {
                    Text(series.characterHints.joined(separator: ", "))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let latest = series.latestEpisode {
                    Text("Latest adventure: \(latest.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Text(episodeSummary)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("seriesCardEpisodeSummary-\(series.id.uuidString)")

                    Text("Repeat or continue")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("seriesCardActionHint-\(series.id.uuidString)")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(series.episodeCount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(red: 0.24, green: 0.62, blue: 0.28)))
                .padding(12)
                .accessibilityIdentifier("episodeCountBadge")
        }
        .frame(height: 154)
    }

    private var episodeSummary: String {
        if series.episodeCount == 1 {
            return "1 episode saved"
        }

        return "\(series.episodeCount) episodes saved"
    }
}

struct ParentTrustCenterView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: StoryLibraryStore
    @StateObject private var entitlementManager = EntitlementManager()

    @State private var editingProfile: ChildProfile?
    @State private var showProfileEditor = false
    @State private var pendingProfileDeletion: ChildProfile?
    @State private var pendingSeriesDeletion: StorySeries?
    @State private var showDeleteHistoryConfirmation = false
    @State private var isRefreshingPlan = false
    @State private var isRestoringPurchases = false
    @State private var isLoadingPurchaseOptions = false
    @State private var isPurchasingUpgrade = false
    @State private var availablePurchaseOptions: [ParentManagedPurchaseOption] = []
    @State private var planActionMessage: String?
    @State private var planErrorMessage: String?

    var body: some View {
        Form {
            Section("Plan") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentPlanTitle)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .accessibilityIdentifier("parentPlanTitle")

                    Text(currentPlanSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlanSummary")
                }

                if let snapshot = entitlementManager.snapshot {
                    Text("Child profiles saved on this device: \(store.childProfiles.count) of \(snapshot.maxChildProfiles) allowed")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlanProfilesSummary")

                    Text(storyStartsSummary(for: snapshot))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlanStartsSummary")

                    Text(continuationsSummary(for: snapshot))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlanContinuationsSummary")

                    if let storyLengthSummary = storyLengthSummary(for: snapshot) {
                        Text(storyLengthSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("parentPlanLengthSummary")
                    }
                } else {
                    Text("Plan status is not loaded yet for this device. Refresh here if a parent needs the latest plan details before starting another story.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlanUnavailableSummary")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Starter")
                        .font(.subheadline.bold())
                    Text("Keeps the smaller launch allowance on this device while replay, privacy controls, and saved stories stay parent-managed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentStarterPlanSummary")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Plus")
                        .font(.subheadline.bold())
                    Text("Expands child-profile room and launch allowance while replay, trust settings, and saved-story control stay in parent-managed surfaces.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlusPlanSummary")
                }

                if currentPlanIsPlus {
                    Text("Plus is already active on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlusActiveSummary")
                } else if let purchaseOption = preferredPurchaseOption {
                    Text("Upgrade to Plus here before starting more remote story launches. The App Store purchase sheet stays inside Parent Controls.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPurchaseSummary")

                    Button(upgradeButtonTitle(for: purchaseOption)) {
                        Task {
                            await purchasePlus(using: purchaseOption)
                        }
                    }
                    .disabled(isRefreshingPlan || isRestoringPurchases || isPurchasingUpgrade)
                    .accessibilityIdentifier("parentUpgradeToPlusButton")
                } else if isLoadingPurchaseOptions {
                    ProgressView("Checking Plus purchase options...")
                        .accessibilityIdentifier("parentPurchaseLoadingIndicator")
                } else {
                    Text("Plus purchase isn't available on this device right now. Restore and plan review still stay here in Parent Controls.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPurchaseUnavailableSummary")
                }

                if let planActionMessage {
                    Text(planActionMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlanActionStatus")
                }

                if let planErrorMessage {
                    Text(planErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlanActionError")
                }

                Button(refreshPlanButtonTitle) {
                    Task {
                        await refreshPlanStatus()
                    }
                }
                .disabled(isRefreshingPlan || isRestoringPurchases)
                .accessibilityIdentifier("parentRefreshPlanButton")

                Button(restorePurchasesButtonTitle) {
                    Task {
                        await restorePurchases()
                    }
                }
                .disabled(isRefreshingPlan || isRestoringPurchases)
                .accessibilityIdentifier("parentRestorePurchasesButton")

                Text("Current plan review, restore, and future upgrades stay here in Parent Controls. Live child sessions stay free of purchase UI.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("parentPlanFootnote")
            }

            Section("Privacy") {
                Label("Raw audio is not saved", systemImage: "waveform.slash")
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("parentRawAudioStatusLabel")
                Text("Use Parent Controls for child setup, privacy, retention, and deletion on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("parentPrivacySummary")
                Text("What stays on this device: saved stories and continuity after the session ends.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("parentPrivacyLocalSummary")
                Text("What goes live during a session: microphone audio, spoken prompts, story generation, and revisions. Raw audio is not saved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("parentPrivacyLiveSummary")
                Toggle("Save story history", isOn: Binding(
                    get: { store.privacySettings.saveStoryHistory },
                    set: { store.setSaveStoryHistory($0) }
                ))
                .accessibilityIdentifier("saveStoryHistoryToggle")
                if store.privacySettings.saveStoryHistory {
                    Picker("Retention", selection: Binding(
                        get: { store.privacySettings.retentionPolicy },
                        set: { store.setRetentionPolicy($0) }
                    )) {
                        ForEach(StoryRetentionPolicy.allCases) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    .accessibilityIdentifier("retentionPicker")
                }
                Toggle("Clear transcripts after each session", isOn: Binding(
                    get: { store.privacySettings.clearTranscriptsAfterSession },
                    set: { store.setClearTranscriptsAfterSession($0) }
                ))
                .accessibilityIdentifier("clearTranscriptsToggle")
            }

            Section("Child profiles") {
                ForEach(store.childProfiles) { profile in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.displayName)
                                    .font(.headline)
                                Text("Age \(profile.age) • \(profile.contentSensitivity.title) • \(profile.preferredMode.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.activeChildProfileId == profile.id {
                                Text("Active")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                        }

                        HStack {
                            Button(store.activeChildProfileId == profile.id ? "Selected" : "Use This Profile") {
                                store.selectActiveProfile(profile.id)
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.activeChildProfileId == profile.id)
                            .accessibilityIdentifier("useProfileButton-\(profile.displayName)")

                            Button("Edit") {
                                editingProfile = profile
                                showProfileEditor = true
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("editProfileButton-\(profile.displayName)")

                            if store.childProfiles.count > 1 {
                                Button("Delete", role: .destructive) {
                                    pendingProfileDeletion = profile
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("deleteProfileButton-\(profile.displayName)")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if canAddProfilesUnderCurrentPlan {
                    Button {
                        editingProfile = nil
                        showProfileEditor = true
                    } label: {
                        Label("Add Child Profile", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("addChildProfileButton")
                } else {
                    Text(childProfileLimitMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentChildProfileLimitMessage")
                }
            }

            if let active = store.activeProfile {
                Section("Safety defaults for \(active.displayName)") {
                    Stepper("Age: \(active.age)", value: activeAgeBinding, in: 3...8)

                    Picker("Sensitivity", selection: activeSensitivityBinding) {
                        ForEach(ContentSensitivity.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }

                    Picker("Default mode", selection: activeModeBinding) {
                        ForEach(StoryExperienceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }
            }

            Section("Saved story management") {
                Text(storyHistoryScopeSummary)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("storyHistoryScopeLabel")

                if store.series.isEmpty {
                    Text("No saved story history on this device yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("storyHistoryEmptyStateLabel")
                } else {
                    ForEach(store.series) { series in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(series.title)
                                .font(.headline)
                            Text(seriesHistorySubtitle(for: series))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Delete Series", role: .destructive) {
                                pendingSeriesDeletion = series
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("deleteManagedSeriesButton-\(series.id.uuidString)")
                        }
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("managedSeriesRow-\(series.id.uuidString)")
                    }
                }

                Text("Deletes saved stories and local continuity for every child profile on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("deleteAllStoryHistoryHint")

                Button("Delete All Saved Story History on This Device", role: .destructive) {
                    showDeleteHistoryConfirmation = true
                }
                .accessibilityIdentifier("deleteAllStoryHistoryButton")
            }
        }
        .navigationTitle("Parent Controls")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            entitlementManager.reloadFromCache()
            ClientLaunchTelemetry.recordParentPlanPresented(snapshot: entitlementManager.snapshot)
            Task {
                await loadPurchaseOptionsIfNeeded()
            }
        }
        .sheet(isPresented: $showProfileEditor) {
            NavigationStack {
                ChildProfileEditorView(store: store, profile: editingProfile, maxProfiles: effectiveChildProfileLimit)
            }
        }
        .alert("Delete saved story history?", isPresented: $showDeleteHistoryConfirmation) {
            Button("Delete", role: .destructive) {
                store.clearStoryHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all saved stories and local continuity memory on this device.")
        }
        .alert(item: $pendingProfileDeletion) { profile in
            Alert(
                title: Text("Delete \(profile.displayName)?"),
                message: Text("This also removes any saved stories tied to this child on this device."),
                primaryButton: .destructive(Text("Delete")) {
                    store.deleteChildProfile(profile.id)
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $pendingSeriesDeletion) { series in
            Alert(
                title: Text("Delete \(series.title)?"),
                message: Text("This removes the saved episodes and local continuity memory for this series on this device."),
                primaryButton: .destructive(Text("Delete")) {
                    store.deleteSeries(series.id)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var storyHistoryScopeSummary: String {
        let count = store.series.count
        return "\(count) saved series across all children on this device"
    }

    private func seriesHistorySubtitle(for series: StorySeries) -> String {
        let profileName = store.profileById(series.childProfileId)?.displayName ?? "Shared or legacy story"
        return "\(profileName) • \(series.episodeCount) episode\(series.episodeCount == 1 ? "" : "s")"
    }

    private var currentPlanTitle: String {
        if let snapshot = entitlementManager.snapshot {
            return snapshot.tier == .plus ? "Plus" : "Starter"
        }

        return "Plan status unavailable"
    }

    private var currentPlanSummary: String {
        guard let snapshot = entitlementManager.snapshot else {
            return "Use Refresh Plan Status or Restore Purchases here when a parent needs the latest plan details on this device."
        }

        return planAllowanceSummary(for: snapshot)
    }

    private var refreshPlanButtonTitle: String {
        isRefreshingPlan ? "Refreshing Plan..." : "Refresh Plan Status"
    }

    private var restorePurchasesButtonTitle: String {
        isRestoringPurchases ? "Restoring Purchases..." : "Restore Purchases"
    }

    private var currentPlanIsPlus: Bool {
        entitlementManager.snapshot?.tier == .plus
    }

    private var preferredPurchaseOption: ParentManagedPurchaseOption? {
        availablePurchaseOptions.first
    }

    private func storyStartsSummary(for snapshot: EntitlementSnapshot) -> String {
        if let remaining = snapshot.remainingStoryStarts {
            return "New story starts remaining in the current window: \(remaining)"
        }

        return snapshot.canStartNewStories
            ? "New story starts are available under the current plan snapshot."
            : "New story starts are currently blocked under this plan snapshot."
    }

    private func continuationsSummary(for snapshot: EntitlementSnapshot) -> String {
        if let remaining = snapshot.remainingContinuations {
            return "Saved-series continuations remaining in the current window: \(remaining)"
        }

        return snapshot.canContinueSavedSeries
            ? "Saved-series continuations are available under the current plan snapshot."
            : "Saved-series continuations are currently blocked under this plan snapshot."
    }

    private func storyLengthSummary(for snapshot: EntitlementSnapshot) -> String? {
        guard let maxStoryLengthMinutes = snapshot.maxStoryLengthMinutes else { return nil }
        return "Story length preflight currently checks up to \(maxStoryLengthMinutes) minutes."
    }

    private var effectiveChildProfileLimit: Int {
        entitlementManager.snapshot?.maxChildProfiles ?? parentControlsDefaultMaxChildProfiles
    }

    private var canAddProfilesUnderCurrentPlan: Bool {
        store.canAddMoreProfiles(maxProfiles: effectiveChildProfileLimit)
    }

    private var childProfileLimitMessage: String {
        let profileLabel = effectiveChildProfileLimit == 1 ? "child profile" : "child profiles"
        if store.childProfiles.count > effectiveChildProfileLimit {
            return "This device already has \(store.childProfiles.count) child profiles saved. The current plan allows \(effectiveChildProfileLimit) \(profileLabel), so another story can stay blocked until a parent reviews profiles or plan options."
        }

        return "This device already uses all \(effectiveChildProfileLimit) \(profileLabel) allowed on this plan."
    }

    private func planAllowanceSummary(for snapshot: EntitlementSnapshot) -> String {
        let planName = snapshot.tier == .plus ? "Plus" : "Starter"
        let profileLabel = snapshot.maxChildProfiles == 1 ? "child profile" : "child profiles"
        return "\(planName) currently allows up to \(snapshot.maxChildProfiles) \(profileLabel), \(allowanceSummary(for: snapshot.remainingStoryStarts, singular: "new story start", plural: "new story starts", available: snapshot.canStartNewStories)), and \(allowanceSummary(for: snapshot.remainingContinuations, singular: "saved-series continuation", plural: "saved-series continuations", available: snapshot.canContinueSavedSeries)). Replay and parent controls stay available on this device."
    }

    private func allowanceSummary(
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

    @MainActor
    private func refreshPlanStatus() async {
        planActionMessage = nil
        planErrorMessage = nil
        ClientLaunchTelemetry.recordParentPlanRefresh(outcome: .started, snapshot: entitlementManager.snapshot)
        isRefreshingPlan = true
        defer { isRefreshingPlan = false }

        do {
            try await entitlementManager.refreshFromBootstrap(using: APIClient())
            await loadPurchaseOptionsIfNeeded(force: true)
            planActionMessage = "Plan status refreshed for this device."
            ClientLaunchTelemetry.recordParentPlanRefresh(outcome: .completed, snapshot: entitlementManager.snapshot)
        } catch {
            planErrorMessage = "I couldn't refresh this device's plan right now. Ask a grown-up to try again."
            ClientLaunchTelemetry.recordParentPlanRefresh(outcome: .failed, snapshot: entitlementManager.snapshot)
        }
    }

    @MainActor
    private func restorePurchases() async {
        planActionMessage = nil
        planErrorMessage = nil
        ClientLaunchTelemetry.recordRestorePurchases(outcome: .started, snapshot: entitlementManager.snapshot)
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

#if canImport(StoreKit)
        if #available(iOS 17.0, *) {
            do {
                try await AppStore.sync()
                try await entitlementManager.refreshFromPurchaseState(
                    using: APIClient(),
                    purchaseStateProvider: StoreKitEntitlementStateProvider(),
                    reason: .restore
                )
                await loadPurchaseOptionsIfNeeded(force: true)
                planActionMessage = "Restore check finished. StoryTime refreshed the plan for this device."
                ClientLaunchTelemetry.recordRestorePurchases(outcome: .completed, snapshot: entitlementManager.snapshot)
            } catch {
                planErrorMessage = "I couldn't restore purchases right now. Ask a grown-up to try again."
                ClientLaunchTelemetry.recordRestorePurchases(outcome: .failed, snapshot: entitlementManager.snapshot)
            }
        } else {
            planErrorMessage = "Restore purchases is not available on this device right now."
            ClientLaunchTelemetry.recordRestorePurchases(outcome: .failed, snapshot: entitlementManager.snapshot)
        }
#else
        planErrorMessage = "Restore purchases is not available on this device right now."
        ClientLaunchTelemetry.recordRestorePurchases(outcome: .failed, snapshot: entitlementManager.snapshot)
#endif
    }

    @MainActor
    private func purchasePlus(using purchaseOption: ParentManagedPurchaseOption) async {
        planActionMessage = nil
        planErrorMessage = nil
        isPurchasingUpgrade = true
        defer { isPurchasingUpgrade = false }

        do {
            let outcome = try await entitlementManager.purchaseProduct(
                using: APIClient(),
                purchaseProvider: resolvedPurchaseProvider(),
                productID: purchaseOption.productID
            )
            await loadPurchaseOptionsIfNeeded(force: true)

            switch outcome {
            case .purchased:
                planActionMessage = currentPlanIsPlus
                    ? "Plus is now ready on this device."
                    : "Purchase finished. StoryTime refreshed the plan for this device."
            case .pending:
                planActionMessage = "Purchase is pending approval. The current plan stays active until the App Store confirms it."
            case .cancelled:
                planActionMessage = "Purchase wasn't completed. The current plan stays the same on this device."
            }
        } catch ParentManagedPurchaseError.unavailable {
            planErrorMessage = "Plus purchase isn't available on this device right now."
        } catch ParentManagedPurchaseError.verificationFailed {
            planErrorMessage = "I couldn't verify that purchase right now. Ask a grown-up to try again."
        } catch {
            planErrorMessage = "I couldn't upgrade this device right now. Ask a grown-up to try again."
        }
    }

    @MainActor
    private func loadPurchaseOptionsIfNeeded(force: Bool = false) async {
        if currentPlanIsPlus {
            availablePurchaseOptions = []
            isLoadingPurchaseOptions = false
            return
        }

        if !force && (!availablePurchaseOptions.isEmpty || isLoadingPurchaseOptions) {
            return
        }

        isLoadingPurchaseOptions = true
        defer { isLoadingPurchaseOptions = false }

        do {
            availablePurchaseOptions = try await resolvedPurchaseProvider().availableOptions()
        } catch {
            availablePurchaseOptions = []
        }
    }

    private func upgradeButtonTitle(for purchaseOption: ParentManagedPurchaseOption) -> String {
        if isPurchasingUpgrade {
            return "Upgrading to Plus..."
        }

        return "Upgrade to Plus - \(purchaseOption.displayPrice)"
    }

    private func resolvedPurchaseProvider() -> any ParentManagedPurchaseProviding {
        if let uiTestProvider = UITestSeed.parentManagedPurchaseProviderIfNeeded() {
            return uiTestProvider
        }

#if canImport(StoreKit)
        if #available(iOS 17.0, *) {
            return StoreKitParentManagedPurchaseProvider()
        }
#endif

        return UnsupportedParentManagedPurchaseProvider()
    }

    private var activeAgeBinding: Binding<Int> {
        Binding(
            get: { store.activeProfile?.age ?? 5 },
            set: { newValue in
                guard var profile = store.activeProfile else { return }
                profile.age = newValue
                store.updateChildProfile(profile)
            }
        )
    }

    private var activeSensitivityBinding: Binding<ContentSensitivity> {
        Binding(
            get: { store.activeProfile?.contentSensitivity ?? .extraGentle },
            set: { newValue in
                guard var profile = store.activeProfile else { return }
                profile.contentSensitivity = newValue
                store.updateChildProfile(profile)
            }
        )
    }

    private var activeModeBinding: Binding<StoryExperienceMode> {
        Binding(
            get: { store.activeProfile?.preferredMode ?? .classic },
            set: { newValue in
                guard var profile = store.activeProfile else { return }
                profile.preferredMode = newValue
                store.updateChildProfile(profile)
            }
        )
    }
}

struct ChildProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: StoryLibraryStore
    let profile: ChildProfile?
    let maxProfiles: Int

    @State private var name: String
    @State private var age: Int
    @State private var sensitivity: ContentSensitivity
    @State private var mode: StoryExperienceMode

    init(store: StoryLibraryStore, profile: ChildProfile?, maxProfiles: Int = parentControlsDefaultMaxChildProfiles) {
        self.store = store
        self.profile = profile
        self.maxProfiles = maxProfiles
        _name = State(initialValue: profile?.displayName ?? "")
        _age = State(initialValue: profile?.age ?? 5)
        _sensitivity = State(initialValue: profile?.contentSensitivity ?? .extraGentle)
        _mode = State(initialValue: profile?.preferredMode ?? .classic)
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("childNameField")
                Stepper("Age: \(age)", value: $age, in: 3...8)
                    .accessibilityIdentifier("childAgeStepper")
                Picker("Sensitivity", selection: $sensitivity) {
                    ForEach(ContentSensitivity.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .accessibilityIdentifier("childSensitivityPicker")
                Picker("Default mode", selection: $mode) {
                    ForEach(StoryExperienceMode.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .accessibilityIdentifier("childModePicker")
            }
        }
        .navigationTitle(profile == nil ? "Add Child" : "Edit Child")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cannotSaveNewProfile)
                .accessibilityIdentifier("saveChildProfileButton")
            }
        }
    }

    private func saveProfile() {
        if var profile {
            profile.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.age = age
            profile.contentSensitivity = sensitivity
            profile.preferredMode = mode
            store.updateChildProfile(profile)
        } else {
            store.addChildProfile(name: name, age: age, sensitivity: sensitivity, preferredMode: mode, maxProfiles: maxProfiles)
        }
        dismiss()
    }

    private var cannotSaveNewProfile: Bool {
        profile == nil && !store.canAddMoreProfiles(maxProfiles: maxProfiles)
    }
}

struct FirstRunOnboardingView: View {
    @ObservedObject var store: StoryLibraryStore
    let onFinish: (Bool) -> Void

    @State private var stepIndex = 0
    @State private var showingParentControls = false
    @State private var showingChildEditor = false

    private let steps = OnboardingStep.allCases

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.95, blue: 0.89), Color(red: 0.89, green: 0.95, blue: 1.00)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                progressHeader
                stepCard
                actionBar
            }
            .padding(20)
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showingParentControls) {
            NavigationStack {
                ParentTrustCenterView(store: store)
            }
        }
        .sheet(isPresented: $showingChildEditor) {
            NavigationStack {
                ChildProfileEditorView(store: store, profile: store.activeProfile)
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Welcome to StoryTime")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .accessibilityIdentifier("onboardingHeaderTitle")
                Spacer()
                Text("Step \(stepIndex + 1) of \(steps.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboardingStepCounter")
            }

            HStack(spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, _ in
                    Capsule(style: .continuous)
                        .fill(index == stepIndex ? Color(red: 0.14, green: 0.50, blue: 0.96) : Color.white.opacity(0.7))
                        .frame(height: 8)
                }
            }
            .accessibilityIdentifier("onboardingProgressBar")
        }
    }

    @ViewBuilder
    private var stepCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(currentStep.title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .accessibilityIdentifier("onboardingStepTitle")

            Text(currentStep.summary)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("onboardingStepSummary")

            switch currentStep {
            case .welcome:
                welcomeStep
            case .trust:
                trustStep
            case .childSetup:
                childSetupStep
            case .expectations:
                expectationsStep
            case .handoff:
                handoffStep
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
        )
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if stepIndex > 0 {
                Button("Back") {
                    stepIndex = max(stepIndex - 1, 0)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboardingBackButton")
            }

            Spacer()

            if currentStep == .handoff {
                Button("Finish Later") {
                    onFinish(false)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboardingFinishLaterButton")

                Button("Start First Story") {
                    onFinish(true)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("onboardingStartFirstStoryButton")
            } else {
                Button(stepIndex == 2 ? childStepContinueLabel : "Continue") {
                    stepIndex = min(stepIndex + 1, steps.count - 1)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("onboardingContinueButton")
            }
        }
        .padding(.horizontal, 4)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingHighlight(
                title: "Kids shape the story live",
                summary: "StoryTime starts with a few live questions so the child can steer what happens before narration begins.",
                identifier: "onboardingWelcomeValueCard"
            )

            onboardingHighlight(
                title: "Narration stays scene-based",
                summary: "After the live questions, StoryTime tells the adventure one scene at a time and still listens for interruptions.",
                identifier: "onboardingWelcomeNarrationCard"
            )

            onboardingHighlight(
                title: "Parent setup comes first",
                summary: "Before the first story starts, confirm privacy defaults and make sure the child profile is ready.",
                identifier: "onboardingWelcomeParentCard"
            )
        }
    }

    private var trustStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingHighlight(
                title: "Raw audio is not saved",
                summary: "StoryTime listens live during the session, but it does not keep raw microphone recordings afterward.",
                identifier: "onboardingTrustAudioCard"
            )

            onboardingHighlight(
                title: "Some processing happens live",
                summary: "Live questions, story prompts, and generated scenes are sent for live processing while the session is happening.",
                identifier: "onboardingTrustLiveCard"
            )

            onboardingHighlight(
                title: "Saved stories stay on this device",
                summary: "When history is on, saved stories and continuity stay local after the session ends.",
                identifier: "onboardingTrustLocalCard"
            )

            Button("Review Parent Controls") {
                showingParentControls = true
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("onboardingReviewParentControlsButton")
        }
    }

    private var childSetupStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let activeProfile = store.activeProfile {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activeProfile.displayName)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .accessibilityIdentifier("onboardingChildName")
                    Text("Age \(activeProfile.age) • \(activeProfile.contentSensitivity.title) • \(activeProfile.preferredMode.title)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("onboardingChildDetails")
                }
                .accessibilityIdentifier("onboardingChildSummary")

                Text(childSetupSummary(for: activeProfile))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboardingChildSetupSummary")
            }

            Button("Edit Child Setup") {
                showingChildEditor = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("onboardingEditChildButton")
        }
    }

    private var expectationsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingExpectation(
                title: "Live follow-up first",
                summary: "StoryTime asks up to 3 live questions before it builds the story."
            )
            .accessibilityIdentifier("onboardingExpectationLive")

            onboardingExpectation(
                title: "Scene-by-scene narration",
                summary: "After the live questions, StoryTime narrates the adventure one scene at a time."
            )
            .accessibilityIdentifier("onboardingExpectationNarration")

            onboardingExpectation(
                title: "Interruptions stay live",
                summary: "During narration, the child can still ask a question, ask for repetition, or change what happens next."
            )
            .accessibilityIdentifier("onboardingExpectationInterruptions")
        }
    }

    private var handoffStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingHighlight(
                title: "Parent setup is done",
                summary: handoffSummary,
                identifier: "onboardingHandoffSummary"
            )

            onboardingHighlight(
                title: "Next screen",
                summary: "StoryTime will open the normal story setup flow so the parent can choose story path and length before handing the device to the child.",
                identifier: "onboardingHandoffNextScreen"
            )
        }
    }

    private func onboardingHighlight(title: String, summary: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(summary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.96, green: 0.97, blue: 1.00))
        )
        .accessibilityIdentifier(identifier)
    }

    private func onboardingExpectation(title: String, summary: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(summary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var currentStep: OnboardingStep {
        steps[stepIndex]
    }

    private var childStepContinueLabel: String {
        if let activeProfile = store.activeProfile, activeProfile.displayName == "Story Explorer" {
            return "Use Story Explorer For Now"
        }
        return "Continue"
    }

    private func childSetupSummary(for profile: ChildProfile) -> String {
        if profile.displayName == "Story Explorer" {
            return "Story Explorer is the fallback child profile. You can keep it for now or edit it before the first story starts."
        }

        return "\(profile.displayName) is ready for the first story. You can still update name, age, sensitivity, or default mode before launch."
    }

    private var handoffSummary: String {
        if let activeProfile = store.activeProfile {
            return "StoryTime is ready to set up \(activeProfile.displayName)'s first story. Finish here, then hand the device to the child for the live questions."
        }

        return "StoryTime is ready for the first story. Finish here, then hand the device to the child for the live questions."
    }
}

private enum OnboardingStep: CaseIterable {
    case welcome
    case trust
    case childSetup
    case expectations
    case handoff

    var title: String {
        switch self {
        case .welcome:
            return "Kids shape the story while it is happening."
        case .trust:
            return "Start with trust and privacy"
        case .childSetup:
            return "Make sure the child profile is ready"
        case .expectations:
            return "Explain what the child will experience"
        case .handoff:
            return "Hand off into the first story"
        }
    }

    var summary: String {
        switch self {
        case .welcome:
            return "StoryTime is a live storytelling app, not a passive audiobook library. A few guided questions come first, then narration begins."
        case .trust:
            return "Before the first story starts, make the live-processing and on-device history rules clear."
        case .childSetup:
            return "Confirm who the story is for and make any changes to name, age, sensitivity, or default mode now."
        case .expectations:
            return "The first session should feel predictable before the child starts speaking."
        case .handoff:
            return "Finish setup here, then move into the normal story launch flow."
        }
    }
}
