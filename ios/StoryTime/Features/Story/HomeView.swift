import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif

private let parentControlsDefaultMaxChildProfiles = 3

struct PlanCheckDebugEntry: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

enum PlanCheckDebugKind {
    case newStory
    case continueStory

    var preparingMessage: String {
        switch self {
        case .newStory:
            return "Preparing plan check for a new story."
        case .continueStory:
            return "Preparing plan check for a saved-story continuation."
        }
    }

    var skippedMessage: String {
        switch self {
        case .newStory:
            return "No plan check was required before starting this story."
        case .continueStory:
            return "No plan check was required before continuing this series."
        }
    }

    func decisionMessage(for response: EntitlementPreflightResponse) -> String {
        if response.allowed {
            switch self {
            case .newStory:
                return "Plan check passed. Starting the voice session."
            case .continueStory:
                return "Plan check passed. Starting the next episode."
            }
        }

        switch self {
        case .newStory:
            return "Plan check needs a parent review before this story can start."
        case .continueStory:
            return "Plan check needs a parent review before this episode can start."
        }
    }
}

enum PlanCheckDebugOverlay {
    private static let environmentKey = "STORYTIME_DEBUG_PLAN_CHECK_OVERLAY"

    static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[environmentKey] == "1"
    }

    static func traceMessage(for event: APIClientTraceEvent) -> String? {
        switch (event.operation, event.phase) {
        case (.sessionBootstrap, .started):
            return "Checking parent session on \(event.route)."
        case (.sessionBootstrap, .completed):
            if let statusCode = event.statusCode {
                return "Parent session check finished (\(statusCode)) on \(event.route)."
            }
            return "Parent session check finished on \(event.route)."
        case (.sessionBootstrap, .transportFailed):
            return "Parent session check hit a connection problem on \(event.route)."
        case (.entitlementPreflight, .started):
            return "Checking the current plan on \(event.route)."
        case (.entitlementPreflight, .completed):
            if let statusCode = event.statusCode {
                return "Plan service responded (\(statusCode)) on \(event.route)."
            }
            return "Plan service responded on \(event.route)."
        case (.entitlementPreflight, .transportFailed):
            return "Plan service connection failed on \(event.route)."
        default:
            return nil
        }
    }

    static func failureMessage(for error: Error) -> String {
        guard let apiError = error as? APIError else {
            return "Displayed error: plan check failed."
        }

        switch apiError {
        case .connectionFailed:
            return "Displayed error: couldn't reach the plan service."
        case .invalidResponse(let statusCode, let code, _, _, _):
            switch code {
            case "parent_auth_required":
                return "Displayed error: a grown-up needs to sign in."
            case let code? where !code.isEmpty:
                return "Displayed error: \(code) (\(statusCode))."
            default:
                return "Displayed error: server returned \(statusCode)."
            }
        }
    }
}

struct PlanCheckDebugOverlayView: View {
    let entries: [PlanCheckDebugEntry]

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plan Check Debug")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                ForEach(Array(entries.suffix(4))) { entry in
                    Text(entry.message)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .accessibilityIdentifier("planCheckDebugOverlay")
            .allowsHitTesting(false)
        }
    }
}

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
    @EnvironmentObject private var parentAuthManager: ParentAuthManager

    @ObservedObject var store: StoryLibraryStore
    @StateObject private var entitlementManager = EntitlementManager()

    @State private var editingProfile: ChildProfile?
    @State private var showProfileEditor = false
    @State private var pendingProfileDeletion: ChildProfile?
    @State private var pendingSeriesDeletion: StorySeries?
    @State private var showDeleteHistoryConfirmation = false
    @State private var isRefreshingPlan = false
    @State private var isRestoringPurchases = false
    @State private var isRedeemingPromo = false
    @State private var isLoadingPurchaseOptions = false
    @State private var isPurchasingUpgrade = false
    @State private var availablePurchaseOptions: [ParentManagedPurchaseOption] = []
    @State private var planActionMessage: String?
    @State private var planErrorMessage: String?
    @State private var showingParentAccountSheet = false
    @State private var promoCode = ""

    var body: some View {
        Form {
            Section("Parent account") {
                Text(parentAuthManager.accountStatusTitle)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .accessibilityIdentifier("parentAccountStatusTitle")

                Text(parentAuthManager.accountStatusSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("parentAccountStatusSummary")

                if parentAuthManager.isSignedIn {
                    Button("Manage Parent Account") {
                        showingParentAccountSheet = true
                    }
                    .accessibilityIdentifier("parentAccountManageButton")

                    Text("This device will keep the parent signed in after relaunch until a parent signs out.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentAccountPersistenceSummary")

                    Text("Use Manage Parent Account to sign out on this device without adding account prompts to child story flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentAccountManageSummary")

                    Button("Sign Out on This Device", role: .destructive) {
                        let didSignOut = parentAuthManager.signOut()
                        if didSignOut {
                            AppEntitlements.reconcileForParentChange(currentParentUserID: nil)
                            entitlementManager.reloadFromCache()
                            Task {
                                await loadPurchaseOptionsIfNeeded(force: true)
                            }
                        }
                    }
                    .accessibilityIdentifier("parentAccountSignOutButton")

                    Text("Signing out removes the parent account session from this device only. Saved child story history still stays local on device in this sprint.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentAccountSignOutSummary")
                } else {
                    Button("Create or Sign In") {
                        showingParentAccountSheet = true
                    }
                    .accessibilityIdentifier("parentAccountEntryButton")

                    Text("First-run activation now happens during onboarding. Use Parent Controls later to manage this device's parent account, purchases, restore, and promo access.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentAccountEntrySummary")
                }

                if let authErrorMessage = parentAuthManager.authErrorMessage {
                    Text(authErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentAccountErrorSummary")
                }

                Text("The PARENT check opens this screen on the current device. Firebase Auth keeps parent account identity separate from child story flow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("parentAccountStatusFootnote")
            }

            Section("Plan") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentPlanTitle)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .id(planStateIdentity)
                        .accessibilityIdentifier("parentPlanTitle")

                    Text(currentPlanSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlanSummary")
                }

                if currentPlanIsPlus {
                    Text(currentPlusSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPlusActiveSummary")
                } else if !parentAuthManager.isSignedIn {
                    Text(purchaseAccountRequirementSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPurchaseAccountRequiredSummary")

                    Button(purchaseAccountButtonTitle) {
                        showingParentAccountSheet = true
                    }
                    .disabled(isRefreshingPlan || isRestoringPurchases || isPurchasingUpgrade)
                    .accessibilityIdentifier("parentPurchaseAccountEntryButton")
                } else {
                    Text(purchaseSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPurchaseSummary")

                    Button(upgradeButtonTitle) {
                        Task {
                            await beginPlusPurchase()
                        }
                    }
                    .disabled(isRefreshingPlan || isRestoringPurchases || isPurchasingUpgrade)
                    .accessibilityIdentifier("parentUpgradeToPlusButton")
                }

                if let snapshot = displayedSnapshot {
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

                    if let ownershipSummary = planOwnershipSummary {
                        Text(ownershipSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .id("\(planStateIdentity)-ownership")
                            .accessibilityIdentifier("parentPlanOwnershipSummary")
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

                if !parentAuthManager.isSignedIn {
                    Text(restoreAccountRequirementSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentRestoreAccountRequiredSummary")
                }

                Button(restorePurchasesButtonTitle) {
                    Task {
                        await restorePurchases()
                    }
                }
                .disabled(isRefreshingPlan || isRestoringPurchases)
                .accessibilityIdentifier("parentRestorePurchasesButton")

                Text(restoreOwnershipSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("parentRestoreOwnershipSummary")

                VStack(alignment: .leading, spacing: 8) {
                    Text(promoSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("parentPromoSummary")

                    if !parentAuthManager.isSignedIn {
                        Text(promoAccountRequirementSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("parentPromoAccountRequiredSummary")
                    }

                    TextField("Promo code", text: $promoCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("parentPromoCodeField")

                    Button(redeemPromoButtonTitle) {
                        Task {
                            await redeemPromoCode()
                        }
                    }
                    .disabled(
                        isRefreshingPlan ||
                            isRestoringPurchases ||
                            isPurchasingUpgrade ||
                            isRedeemingPromo ||
                            trimmedPromoCode.isEmpty
                    )
                    .accessibilityIdentifier("parentRedeemPromoButton")
                }

                Text("Current plan review, restore, promo codes, and future upgrades stay here in Parent Controls. Live child sessions stay free of purchase UI.")
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
                await bootstrapPlanStatusIfNeeded()
                await loadPurchaseOptionsIfNeeded()
            }
        }
        .onChange(of: parentAuthManager.currentUser?.uid) { _, _ in
            entitlementManager.reloadFromCache()
            Task {
                await loadPurchaseOptionsIfNeeded(force: true)
            }
        }
        .sheet(isPresented: $showProfileEditor) {
            NavigationStack {
                ChildProfileEditorView(store: store, profile: editingProfile, maxProfiles: effectiveChildProfileLimit)
            }
        }
        .sheet(isPresented: $showingParentAccountSheet, onDismiss: {
            Task {
                do {
                    try await entitlementManager.refreshFromBootstrap(using: APIClient())
                } catch {
                    // Keep the parent account sheet lightweight; the explicit refresh button remains available.
                }
                await loadPurchaseOptionsIfNeeded(force: true)
            }
        }) {
            NavigationStack {
                ParentAccountSheetView(entryContext: .parentControlsManagement)
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
        PlanStatusPresentation.currentPlanTitle(snapshot: displayedSnapshot, isRefreshing: isRefreshingPlan)
    }

    private var currentPlanSummary: String {
        guard let snapshot = displayedSnapshot else {
            return PlanStatusPresentation.currentPlanSummary(snapshot: displayedSnapshot, isRefreshing: isRefreshingPlan)
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
        displayedSnapshot?.tier == .plus
    }

    private var preferredPurchaseOption: ParentManagedPurchaseOption? {
        availablePurchaseOptions.first
    }

    private var upgradeButtonTitle: String {
        if let purchaseOption = preferredPurchaseOption {
            return upgradeButtonTitle(for: purchaseOption)
        }

        return isLoadingPurchaseOptions ? "Checking Plus..." : "Upgrade to Plus"
    }

    private var purchaseSummary: String {
        if preferredPurchaseOption != nil {
            return "Upgrade to Plus here before starting more remote story launches. This purchase will be linked to \(purchaseOwnershipIdentity) and the App Store purchase sheet stays inside Parent Controls."
        }

        return "Upgrade to Plus here before starting more remote story launches. StoryTime will confirm the current App Store purchase option inside Parent Controls and link the purchase to \(purchaseOwnershipIdentity)."
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
        displayedSnapshot?.maxChildProfiles ?? parentControlsDefaultMaxChildProfiles
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
    private func bootstrapPlanStatusIfNeeded() async {
        guard entitlementManager.snapshot == nil else { return }

        isRefreshingPlan = true
        defer { isRefreshingPlan = false }

        do {
            if let uiTestEnvelope = UITestSeed.refreshedEntitlementEnvelopeIfNeeded() {
                AppEntitlements.store(envelope: uiTestEnvelope)
                entitlementManager.reloadFromCache()
            } else {
                try await entitlementManager.refreshFromBootstrap(using: APIClient())
            }
            planErrorMessage = nil
        } catch {
            planErrorMessage = PlanStatusPresentation.parentPlanRefreshMessage(for: error)
        }
    }

    @MainActor
    private func refreshPlanStatus() async {
        planActionMessage = nil
        planErrorMessage = nil
        ClientLaunchTelemetry.recordParentPlanRefresh(outcome: .started, snapshot: entitlementManager.snapshot)
        isRefreshingPlan = true
        defer { isRefreshingPlan = false }

        do {
            if let uiTestEnvelope = UITestSeed.refreshedEntitlementEnvelopeIfNeeded() {
                AppEntitlements.store(envelope: uiTestEnvelope)
                entitlementManager.reloadFromCache()
            } else {
                try await entitlementManager.refreshFromBootstrap(using: APIClient())
            }
            await loadPurchaseOptionsIfNeeded(force: true)
            planActionMessage = "Plan status refreshed for this device."
            ClientLaunchTelemetry.recordParentPlanRefresh(outcome: .completed, snapshot: entitlementManager.snapshot)
        } catch {
            planErrorMessage = PlanStatusPresentation.parentPlanRefreshMessage(for: error)
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

        guard parentAuthManager.isSignedIn else {
            showingParentAccountSheet = true
            planErrorMessage = "Sign in to a parent account before restoring Plus so the restored plan belongs to that parent."
            ClientLaunchTelemetry.recordRestorePurchases(outcome: .failed, snapshot: entitlementManager.snapshot)
            return
        }

        if let uiTestConflictMessage = UITestSeed.restoreConflictMessageIfNeeded(currentUser: parentAuthManager.currentUser) {
            planErrorMessage = uiTestConflictMessage
            ClientLaunchTelemetry.recordRestorePurchases(outcome: .failed, snapshot: entitlementManager.snapshot)
            return
        }

        if let uiTestEnvelope = UITestSeed.restoredEntitlementEnvelopeIfNeeded() {
            AppEntitlements.store(envelope: uiTestEnvelope)
            entitlementManager.reloadFromCache()
            await loadPurchaseOptionsIfNeeded(force: true)
            planActionMessage = "Restore check finished. StoryTime refreshed the plan for this device."
            ClientLaunchTelemetry.recordRestorePurchases(outcome: .completed, snapshot: entitlementManager.snapshot)
            return
        }

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
            } catch let error as APIError {
                planErrorMessage = restorePurchasesMessage(for: error)
                ClientLaunchTelemetry.recordRestorePurchases(outcome: .failed, snapshot: entitlementManager.snapshot)
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
    private func redeemPromoCode() async {
        planActionMessage = nil
        planErrorMessage = nil
        ClientLaunchTelemetry.recordPromoRedemption(outcome: .started, snapshot: entitlementManager.snapshot)
        isRedeemingPromo = true
        defer { isRedeemingPromo = false }

        guard parentAuthManager.isSignedIn else {
            showingParentAccountSheet = true
            planErrorMessage = "Sign in to a parent account before redeeming a promo code so the premium grant belongs to that parent."
            ClientLaunchTelemetry.recordPromoRedemption(outcome: .failed, snapshot: entitlementManager.snapshot)
            return
        }

        if let uiTestEnvelope = UITestSeed.redeemedPromoEntitlementEnvelopeIfNeeded(code: trimmedPromoCode) {
            AppEntitlements.store(envelope: uiTestEnvelope)
            entitlementManager.reloadFromCache()
            promoCode = ""
            await loadPurchaseOptionsIfNeeded(force: true)
            planActionMessage = "Promo code redeemed. Plus is now ready for \(purchaseOwnershipIdentity) on this device."
            ClientLaunchTelemetry.recordPromoRedemption(outcome: .completed, snapshot: entitlementManager.snapshot)
            return
        }

        do {
            let envelope = try await APIClient().redeemPromoCode(request: PromoCodeRedemptionRequest(code: trimmedPromoCode))
            entitlementManager.reloadFromCache()
            promoCode = ""
            await loadPurchaseOptionsIfNeeded(force: true)
            planActionMessage = envelope.snapshot.tier == .plus
                ? "Promo code redeemed. Plus is now ready for \(purchaseOwnershipIdentity) on this device."
                : "Promo code redeemed. StoryTime refreshed the plan for this device."
            ClientLaunchTelemetry.recordPromoRedemption(outcome: .completed, snapshot: entitlementManager.snapshot)
        } catch let error as APIError {
            if error.serverCode == "parent_auth_required" {
                showingParentAccountSheet = true
            }
            planErrorMessage = promoRedemptionMessage(for: error)
            ClientLaunchTelemetry.recordPromoRedemption(outcome: .failed, snapshot: entitlementManager.snapshot)
        } catch {
            planErrorMessage = "I couldn't redeem that promo code right now. Ask a grown-up to try again."
            ClientLaunchTelemetry.recordPromoRedemption(outcome: .failed, snapshot: entitlementManager.snapshot)
        }
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
                productID: purchaseOption.productID,
                parentAccount: parentAuthManager.currentUser
            )
            await loadPurchaseOptionsIfNeeded(force: true)

            switch outcome {
            case .purchased:
                planActionMessage = currentPlanIsPlus
                    ? "Plus is now ready for \(purchaseOwnershipIdentity) on this device."
                    : "Purchase finished. StoryTime refreshed the plan for this device."
            case .pending:
                planActionMessage = "Purchase is pending approval. The current plan stays active until the App Store confirms it."
            case .cancelled:
                planActionMessage = "Purchase wasn't completed. The current plan stays the same on this device."
            }
        } catch ParentManagedPurchaseError.parentAccountRequired {
            showingParentAccountSheet = true
            planErrorMessage = "Sign in to a parent account before buying Plus so the purchase belongs to that parent."
        } catch ParentManagedPurchaseError.unavailable {
            planErrorMessage = "Plus purchase isn't available on this device right now."
        } catch ParentManagedPurchaseError.verificationFailed {
            planErrorMessage = "I couldn't verify that purchase right now. Ask a grown-up to try again."
        } catch {
            planErrorMessage = "I couldn't upgrade this device right now. Ask a grown-up to try again."
        }
    }

    @MainActor
    private func beginPlusPurchase() async {
        if let purchaseOption = preferredPurchaseOption {
            await purchasePlus(using: purchaseOption)
            return
        }

        await loadPurchaseOptionsIfNeeded(force: true)

        guard let purchaseOption = preferredPurchaseOption else {
            planErrorMessage = "Plus purchase isn't available on this device right now."
            return
        }

        await purchasePlus(using: purchaseOption)
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

    private func promoRedemptionMessage(for error: APIError) -> String {
        switch error.serverCode {
        case "promo_code_invalid":
            return "That promo code isn't valid anymore. Ask a grown-up to check the code and try again."
        case "promo_code_already_redeemed":
            return "That promo code has already been used."
        case "promo_code_expired":
            return "That promo code has expired. Ask a grown-up to check the code and try again."
        case "parent_auth_required":
            return "Sign in to a parent account before redeeming a promo code so the premium grant belongs to that parent."
        default:
            return "I couldn't redeem that promo code right now. Ask a grown-up to try again."
        }
    }

    private func restorePurchasesMessage(for error: APIError) -> String {
        switch error.serverCode {
        case "parent_auth_required":
            return "Sign in to a parent account before restoring Plus so the restored plan belongs to that parent."
        case "restore_parent_mismatch":
            return "This device already restored Plus for a different parent account. Sign back into that parent account to restore here again. StoryTime won't move restored access between parent accounts on the same device."
        default:
            return "I couldn't restore purchases right now. Ask a grown-up to try again."
        }
    }

    private func upgradeButtonTitle(for purchaseOption: ParentManagedPurchaseOption) -> String {
        if isPurchasingUpgrade {
            return "Upgrading to Plus..."
        }

        return "Upgrade to Plus - \(purchaseOption.displayPrice)"
    }

    private var purchaseAccountButtonTitle: String {
        if let purchaseOption = preferredPurchaseOption {
            return "Create or Sign In to Buy Plus - \(purchaseOption.displayPrice)"
        }

        return "Create or Sign In to Buy Plus"
    }

    private var purchaseAccountRequirementSummary: String {
        "A parent account is required before buying Plus so the purchase can belong to that parent instead of staying tied only to this device."
    }

    private var restoreAccountRequirementSummary: String {
        "A parent account is required before restoring Plus so the refreshed entitlement belongs to that parent. StoryTime won't move a restored plan between different parent accounts on this device."
    }

    private var restoreOwnershipSummary: String {
        "Restore stays linked to the parent account that restores Plus on this device. If another parent signs in later, StoryTime keeps that parent's current plan instead of transferring the restored access."
    }

    private var promoAccountRequirementSummary: String {
        "A parent account is required before redeeming a promo code so the premium grant belongs to that parent instead of staying tied only to this device."
    }

    private var promoSummary: String {
        "Redeem a one-time parent promo code here. Valid codes grant Plus without using the App Store purchase flow."
    }

    private var trimmedPromoCode: String {
        promoCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var redeemPromoButtonTitle: String {
        isRedeemingPromo ? "Redeeming Promo..." : "Redeem Promo Code"
    }

    private var purchaseOwnershipIdentity: String {
        if let email = parentAuthManager.currentUser?.email, !email.isEmpty {
            return email
        }

        return "this parent account"
    }

    private var currentPlusSummary: String {
        if displayedSnapshot?.source == .promoGrant, displayedOwner?.kind == .parentUser {
            return "Plus is active for \(purchaseOwnershipIdentity) on this device through a parent promo code."
        }

        if displayedOwner?.kind == .parentUser {
            return "Plus is active for \(purchaseOwnershipIdentity) on this device."
        }

        return "Plus is already active on this device."
    }

    private var planOwnershipSummary: String? {
        guard let owner = displayedOwner else {
            return nil
        }

        switch owner.kind {
        case .parentUser:
            if displayedSnapshot?.source == .promoGrant {
                return "This entitlement snapshot is linked to \(purchaseOwnershipIdentity) through a promo grant."
            }
            return "This entitlement snapshot is linked to \(purchaseOwnershipIdentity)."
        case .install:
            if parentAuthManager.isSignedIn {
                return "This entitlement snapshot is still local to this device. New purchases made while signed in will be linked to \(purchaseOwnershipIdentity), but restored Plus won't move over if another parent already restored it here."
            }

            return "This entitlement snapshot currently belongs to this device. Signing out from a parent account returns the app to this local fallback plan."
        }
    }

    private var planStateIdentity: String {
        let tier = displayedSnapshot?.tier.rawValue ?? "unavailable"
        let ownerKind = displayedOwner?.kind.rawValue ?? "none"
        let ownerID = displayedOwner?.parentUserID ?? "device"
        return "plan-\(tier)-\(ownerKind)-\(ownerID)"
    }

    private var displayedEnvelope: EntitlementBootstrapEnvelope? {
        AppEntitlements.currentEnvelope ?? entitlementManager.envelope
    }

    private var displayedSnapshot: EntitlementSnapshot? {
        displayedEnvelope?.snapshot ?? entitlementManager.snapshot
    }

    private var displayedOwner: EntitlementOwner? {
        displayedEnvelope?.owner ?? entitlementManager.owner
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
    @EnvironmentObject private var parentAuthManager: ParentAuthManager

    @ObservedObject var store: StoryLibraryStore
    let onFinish: () -> Void

    @State private var stepIndex = 0
    @State private var showingChildEditor = false
    @State private var showingParentAccountSheet = false
    @State private var parentAccountSheetMode: ParentAccountSheetView.Mode = .createAccount
    @State private var selectedPlanChoice: FirstRunActivationPlanChoice?
    @StateObject private var entitlementManager = EntitlementManager()
    @State private var isRestoringPurchases = false
    @State private var isRedeemingPromo = false
    @State private var isLoadingPurchaseOptions = false
    @State private var isPurchasingUpgrade = false
    @State private var availablePurchaseOptions: [ParentManagedPurchaseOption] = []
    @State private var planActionMessage: String?
    @State private var planErrorMessage: String?
    @State private var promoCode = ""

    private let steps = FirstRunActivationStep.allCases

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
        .sheet(isPresented: $showingChildEditor) {
            NavigationStack {
                ChildProfileEditorView(store: store, profile: store.activeProfile)
            }
        }
        .sheet(isPresented: $showingParentAccountSheet, onDismiss: {
            Task {
                await refreshAfterParentAccountChange()
            }
        }) {
            NavigationStack {
                ParentAccountSheetView(
                    initialMode: parentAccountSheetMode,
                    entryContext: .onboardingActivation
                )
            }
        }
        .onAppear {
            entitlementManager.reloadFromCache()
            syncPlanSelectionFromEntitlements()
            Task {
                await loadPurchaseOptionsIfNeeded()
            }
        }
        .onChange(of: parentAuthManager.currentUser?.uid) { _, _ in
            Task {
                await refreshAfterParentAccountChange()
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
        ScrollView {
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
                case .howItWorks:
                    howItWorksStep
                case .childSetup:
                    childSetupStep
                case .trust:
                    trustStep
                case .account:
                    accountStep
                case .plan:
                    planStep
                case .completion:
                    completionStep
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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

            if currentStep == .completion {
                Button("Open StoryTime") {
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!gateState.canFinish)
                .accessibilityIdentifier("onboardingFinishSetupButton")
            } else {
                Button(continueButtonTitle) {
                    stepIndex = min(stepIndex + 1, steps.count - 1)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!gateState.canAdvance)
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
                title: "Voice-first, not passive",
                summary: "StoryTime reacts while the child is speaking, then keeps the story moving scene by scene so the experience still feels live.",
                identifier: "onboardingWelcomeNarrationCard"
            )

            onboardingHighlight(
                title: "Parent setup comes first",
                summary: "Before the first story opens, finish child setup, sign in the parent account, and choose the plan from this onboarding journey.",
                identifier: "onboardingWelcomeParentCard"
            )
        }
    }

    private var howItWorksStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingHighlight(
                title: "Parents set up the device first",
                summary: "A parent confirms the child profile, privacy expectations, account identity, and plan before the child starts a story session.",
                identifier: "onboardingHowItWorksParentCard"
            )

            onboardingHighlight(
                title: "Children get adaptive stories",
                summary: "The child can answer live prompts, ask questions during narration, and help shape what happens next.",
                identifier: "onboardingHowItWorksAdaptiveCard"
            )

            onboardingHighlight(
                title: "Stories can continue over time",
                summary: "Saved stories and continuity can stay on this device so the next episode can pick up where the last one ended.",
                identifier: "onboardingHowItWorksContinuityCard"
            )

            onboardingHighlight(
                title: "Parents keep the controls",
                summary: "Parent Controls stay available after onboarding for account management, plan review, restore, promo redemption, retention, and privacy settings.",
                identifier: "onboardingHowItWorksControlCard"
            )
        }
    }

    private var trustStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingHighlight(
                title: "Live story processing happens during each session",
                summary: "Microphone audio, spoken prompts, story generation, and revisions are processed while the story session is happening.",
                identifier: "onboardingTrustLiveCard"
            )

            onboardingHighlight(
                title: "Raw audio is not saved",
                summary: "StoryTime listens live during the session, but it does not keep raw microphone recordings afterward.",
                identifier: "onboardingTrustAudioCard"
            )

            onboardingHighlight(
                title: "Saved history stays local in this sprint",
                summary: "When story history is on, saved stories and continuity stay on this device after the session ends.",
                identifier: "onboardingTrustLocalCard"
            )

            onboardingHighlight(
                title: "Parent Controls manage settings later",
                summary: "After onboarding, Parent Controls remain the place to manage privacy, retention, child profiles, restore, upgrades, and promo access on this device.",
                identifier: "onboardingTrustParentControlsCard"
            )
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

            onboardingHighlight(
                title: "Minimal setup for first run",
                summary: "This starter profile captures the child name, age range, and default story mode. You can refine more settings later in Parent Controls.",
                identifier: "onboardingChildFamilySetupCard"
            )

            Button("Edit Child Setup") {
                showingChildEditor = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("onboardingEditChildButton")
        }
    }

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingHighlight(
                title: "A parent account is required now",
                summary: "First-run activation stays parent-managed. Sign in here so identity, purchases, restore, and promo grants belong to the parent account instead of staying hidden behind Parent Controls later.",
                identifier: "onboardingAccountRequiredSummary"
            )

            if parentAuthManager.isSignedIn {
                onboardingHighlight(
                    title: parentAuthManager.accountStatusTitle,
                    summary: "Parent account ready. Continue to choose the plan for this device before StoryTime opens the main app.",
                    identifier: "onboardingAccountSignedInSummary"
                )
            } else {
                Button("Create Parent Account") {
                    parentAccountSheetMode = .createAccount
                    showingParentAccountSheet = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("onboardingCreateAccountButton")

                Button("Sign In to Existing Account") {
                    parentAccountSheetMode = .signIn
                    showingParentAccountSheet = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboardingSignInButton")

                Text("Email/password and Sign in with Apple both stay inside the parent account sheet. The child story runtime stays free of sign-in prompts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboardingAccountSheetSummary")
            }
        }
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingHighlight(
                title: currentPlanStepTitle,
                summary: currentPlanStepSummary,
                identifier: "onboardingPlanSelectionStatus"
            )

            onboardingHighlight(
                title: "Starter",
                summary: "Starter keeps the smaller launch allowance on this device. Pick this if the family is starting on the free plan for now.",
                identifier: "onboardingStarterPlanCard"
            )

            Button("Choose Starter for Now") {
                selectedPlanChoice = .starter
                planActionMessage = "Starter selected for this parent account."
                planErrorMessage = nil
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("onboardingChooseStarterButton")

            onboardingHighlight(
                title: "Plus",
                summary: plusPlanSummary,
                identifier: "onboardingPlusPlanCard"
            )

            Button(upgradeButtonTitle) {
                Task {
                    await beginPlusPurchase()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRestoringPurchases || isPurchasingUpgrade)
            .accessibilityIdentifier("onboardingUpgradeToPlusButton")

            Button(restorePurchasesButtonTitle) {
                Task {
                    await restorePurchases()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRestoringPurchases || isPurchasingUpgrade)
            .accessibilityIdentifier("onboardingRestorePurchasesButton")

            Text(restoreOwnershipSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("onboardingRestoreOwnershipSummary")

            VStack(alignment: .leading, spacing: 8) {
                Text("Promo code")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                Text("Enter a parent promo code here if Plus should be granted without using the App Store purchase flow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboardingPromoSummary")

                TextField("Promo code", text: $promoCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("onboardingPromoCodeField")

                Button(redeemPromoButtonTitle) {
                    Task {
                        await redeemPromoCode()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(
                    isRestoringPurchases ||
                        isPurchasingUpgrade ||
                        isRedeemingPromo ||
                        trimmedPromoCode.isEmpty
                )
                .accessibilityIdentifier("onboardingRedeemPromoButton")
            }

            if let planActionMessage {
                Text(planActionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboardingPlanActionStatus")
            }

            if let planErrorMessage {
                Text(planErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboardingPlanActionError")
            }
        }
    }

    private var completionStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingHighlight(
                title: completionTitle,
                summary: completionSummary,
                identifier: "onboardingCompletionSummary"
            )

            onboardingHighlight(
                title: parentAuthManager.accountStatusTitle,
                summary: parentAuthManager.accountStatusSummary,
                identifier: "onboardingCompletionAccountCard"
            )

            onboardingHighlight(
                title: completionPlanTitle,
                summary: completionPlanSummary,
                identifier: "onboardingCompletionPlanCard"
            )

            onboardingHighlight(
                title: "What happens next",
                summary: "After this final step, StoryTime opens the main app. Child story setup, starting a new story, and continuing a saved series all stay behind this completed parent activation flow.",
                identifier: "onboardingCompletionNextStepCard"
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

    private var currentStep: FirstRunActivationStep {
        steps[stepIndex]
    }

    private var gateState: FirstRunActivationGateState {
        FirstRunActivationGateState(
            currentStep: currentStep,
            isParentSignedIn: parentAuthManager.isSignedIn,
            selectedPlanChoice: selectedPlanChoice
        )
    }

    private var continueButtonTitle: String {
        switch currentStep {
        case .account:
            return "Continue to Plan"
        case .plan:
            return "Review Setup"
        default:
            return "Continue"
        }
    }

    private func childSetupSummary(for profile: ChildProfile) -> String {
        if profile.displayName == "Story Explorer" {
            return "Story Explorer is the fallback child profile. You can keep it for now or edit it before first-run activation finishes."
        }

        return "\(profile.displayName) is ready for onboarding. You can still update name, age, sensitivity, or default mode before StoryTime opens the main app."
    }

    private var preferredPurchaseOption: ParentManagedPurchaseOption? {
        availablePurchaseOptions.first
    }

    private var currentPlanIsPlus: Bool {
        displayedSnapshot?.tier == .plus
    }

    private var currentPlanStepTitle: String {
        if currentPlanIsPlus {
            return "Plus is already active"
        }

        if selectedPlanChoice == .starter {
            return "Starter is selected"
        }

        return "Choose how this family starts"
    }

    private var currentPlanStepSummary: String {
        if currentPlanIsPlus {
            return plusOwnershipSummary
        }

        if selectedPlanChoice == .starter {
            return "Starter is selected for this parent account. You can continue onboarding now and still manage upgrades, restore, or promo redemption later in Parent Controls."
        }

        return "Pick Starter to continue on the free plan, or unlock Plus here before the app reaches the main story surfaces."
    }

    private var plusPlanSummary: String {
        if let purchaseOption = preferredPurchaseOption {
            return "Plus expands child-profile room and story allowance. Upgrade here for \(purchaseOption.displayPrice), or use restore or promo if the family already has access."
        }

        return "Plus expands child-profile room and story allowance. Upgrade here, restore purchases, or redeem a parent promo code before opening the main app."
    }

    private var upgradeButtonTitle: String {
        if let purchaseOption = preferredPurchaseOption {
            return isPurchasingUpgrade ? "Upgrading to Plus..." : "Upgrade to Plus - \(purchaseOption.displayPrice)"
        }

        return isLoadingPurchaseOptions ? "Checking Plus..." : "Upgrade to Plus"
    }

    private var restorePurchasesButtonTitle: String {
        isRestoringPurchases ? "Restoring Purchases..." : "Restore Purchases"
    }

    private var redeemPromoButtonTitle: String {
        isRedeemingPromo ? "Redeeming Promo..." : "Redeem Promo Code"
    }

    private var completionTitle: String {
        if let activeProfile = store.activeProfile {
            return "\(activeProfile.displayName)'s setup is ready"
        }

        return "StoryTime setup is ready"
    }

    private var completionSummary: String {
        if let activeProfile = store.activeProfile {
            return "The child profile, parent account, and plan are in place for \(activeProfile.displayName). Finish here to land in the main app, then a parent can decide when to start the first story."
        }

        return "The child profile, parent account, and plan are in place. Finish here to land in the main app, then a parent can decide when to start the first story."
    }

    private var completionPlanTitle: String {
        switch selectedPlanChoice {
        case .starter:
            return "Starter selected"
        case .plus:
            return "Plus selected"
        case .none:
            return currentPlanIsPlus ? "Plus selected" : "Plan not selected yet"
        }
    }

    private var completionPlanSummary: String {
        switch selectedPlanChoice {
        case .starter:
            return "Starter will stay active for this parent account and device. Upgrades, restore, and promo redemption remain available later in Parent Controls."
        case .plus:
            return plusOwnershipSummary
        case .none where currentPlanIsPlus:
            return plusOwnershipSummary
        case .none:
            return "Choose a plan before finishing onboarding."
        }
    }

    private var purchaseOwnershipIdentity: String {
        if let email = parentAuthManager.currentUser?.email, !email.isEmpty {
            return email
        }

        return "this parent account"
    }

    private var plusOwnershipSummary: String {
        if displayedSnapshot?.source == .promoGrant, displayedOwner?.kind == .parentUser {
            return "Plus is active for \(purchaseOwnershipIdentity) on this device through a parent promo code."
        }

        if displayedOwner?.kind == .parentUser {
            return "Plus is active for \(purchaseOwnershipIdentity) on this device."
        }

        return "Plus is active on this device."
    }

    private var trimmedPromoCode: String {
        promoCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var displayedEnvelope: EntitlementBootstrapEnvelope? {
        AppEntitlements.currentEnvelope ?? entitlementManager.envelope
    }

    private var displayedSnapshot: EntitlementSnapshot? {
        displayedEnvelope?.snapshot ?? entitlementManager.snapshot
    }

    private var displayedOwner: EntitlementOwner? {
        displayedEnvelope?.owner ?? entitlementManager.owner
    }

    @MainActor
    private func refreshAfterParentAccountChange() async {
        do {
            try await entitlementManager.refreshFromBootstrap(using: APIClient())
        } catch {
            entitlementManager.reloadFromCache()
        }
        await loadPurchaseOptionsIfNeeded(force: true)
        syncPlanSelectionFromEntitlements()
    }

    @MainActor
    private func restorePurchases() async {
        planActionMessage = nil
        planErrorMessage = nil
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        guard parentAuthManager.isSignedIn else {
            parentAccountSheetMode = .signIn
            showingParentAccountSheet = true
            planErrorMessage = "Sign in to a parent account before restoring Plus so the restored plan belongs to that parent."
            return
        }

        if let uiTestConflictMessage = UITestSeed.restoreConflictMessageIfNeeded(currentUser: parentAuthManager.currentUser) {
            planErrorMessage = uiTestConflictMessage
            return
        }

        if let uiTestEnvelope = UITestSeed.restoredEntitlementEnvelopeIfNeeded() {
            AppEntitlements.store(envelope: uiTestEnvelope)
            entitlementManager.reloadFromCache()
            await loadPurchaseOptionsIfNeeded(force: true)
            syncPlanSelectionFromEntitlements()
            planActionMessage = "Restore check finished. StoryTime refreshed the plan for this parent account."
            return
        }

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
                syncPlanSelectionFromEntitlements()
                planActionMessage = "Restore check finished. StoryTime refreshed the plan for this parent account."
            } catch let error as APIError {
                planErrorMessage = restorePurchasesMessage(for: error)
            } catch {
                planErrorMessage = "I couldn't restore purchases right now. Ask a grown-up to try again."
            }
        } else {
            planErrorMessage = "Restore purchases is not available on this device right now."
        }
#else
        planErrorMessage = "Restore purchases is not available on this device right now."
#endif
    }

    @MainActor
    private func redeemPromoCode() async {
        planActionMessage = nil
        planErrorMessage = nil
        isRedeemingPromo = true
        defer { isRedeemingPromo = false }

        guard parentAuthManager.isSignedIn else {
            parentAccountSheetMode = .signIn
            showingParentAccountSheet = true
            planErrorMessage = "Sign in to a parent account before redeeming a promo code so the premium grant belongs to that parent."
            return
        }

        if let uiTestEnvelope = UITestSeed.redeemedPromoEntitlementEnvelopeIfNeeded(code: trimmedPromoCode) {
            AppEntitlements.store(envelope: uiTestEnvelope)
            entitlementManager.reloadFromCache()
            promoCode = ""
            await loadPurchaseOptionsIfNeeded(force: true)
            syncPlanSelectionFromEntitlements()
            planActionMessage = "Promo code redeemed. Plus is now ready for \(purchaseOwnershipIdentity) on this device."
            return
        }

        do {
            _ = try await APIClient().redeemPromoCode(request: PromoCodeRedemptionRequest(code: trimmedPromoCode))
            entitlementManager.reloadFromCache()
            promoCode = ""
            await loadPurchaseOptionsIfNeeded(force: true)
            syncPlanSelectionFromEntitlements()
            planActionMessage = currentPlanIsPlus
                ? "Promo code redeemed. Plus is now ready for \(purchaseOwnershipIdentity) on this device."
                : "Promo code redeemed. StoryTime refreshed the plan for this parent account."
        } catch let error as APIError {
            if error.serverCode == "parent_auth_required" {
                parentAccountSheetMode = .signIn
                showingParentAccountSheet = true
            }
            planErrorMessage = promoRedemptionMessage(for: error)
        } catch {
            planErrorMessage = "I couldn't redeem that promo code right now. Ask a grown-up to try again."
        }
    }

    @MainActor
    private func beginPlusPurchase() async {
        if let purchaseOption = preferredPurchaseOption {
            await purchasePlus(using: purchaseOption)
            return
        }

        await loadPurchaseOptionsIfNeeded(force: true)

        guard let purchaseOption = preferredPurchaseOption else {
            planErrorMessage = "Plus purchase isn't available on this device right now."
            return
        }

        await purchasePlus(using: purchaseOption)
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
                productID: purchaseOption.productID,
                parentAccount: parentAuthManager.currentUser
            )
            await loadPurchaseOptionsIfNeeded(force: true)
            syncPlanSelectionFromEntitlements()

            switch outcome {
            case .purchased:
                planActionMessage = currentPlanIsPlus
                    ? "Plus is now ready for \(purchaseOwnershipIdentity) on this device."
                    : "Purchase finished. StoryTime refreshed the plan for this parent account."
            case .pending:
                planActionMessage = "Purchase is pending approval. The current plan stays active until the App Store confirms it."
            case .cancelled:
                planActionMessage = "Purchase wasn't completed. The current plan stays the same on this device."
            }
        } catch ParentManagedPurchaseError.parentAccountRequired {
            parentAccountSheetMode = .signIn
            showingParentAccountSheet = true
            planErrorMessage = "Sign in to a parent account before buying Plus so the purchase belongs to that parent."
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

    private func syncPlanSelectionFromEntitlements() {
        if currentPlanIsPlus {
            selectedPlanChoice = .plus
        } else if selectedPlanChoice == .plus {
            selectedPlanChoice = nil
        }
    }

    private func promoRedemptionMessage(for error: APIError) -> String {
        switch error.serverCode {
        case "promo_code_invalid":
            return "That promo code isn't valid anymore. Ask a grown-up to check the code and try again."
        case "promo_code_already_redeemed":
            return "That promo code has already been used."
        case "promo_code_expired":
            return "That promo code has expired. Ask a grown-up to check the code and try again."
        case "parent_auth_required":
            return "Sign in to a parent account before redeeming a promo code so the premium grant belongs to that parent."
        default:
            return "I couldn't redeem that promo code right now. Ask a grown-up to try again."
        }
    }

    private func restorePurchasesMessage(for error: APIError) -> String {
        switch error.serverCode {
        case "parent_auth_required":
            return "Sign in to a parent account before restoring Plus so the restored plan belongs to that parent."
        case "restore_parent_mismatch":
            return "This device already restored Plus for a different parent account. Sign back into that parent account to restore here again. StoryTime won't move restored access between parent accounts on the same device."
        default:
            return "I couldn't restore purchases right now. Ask a grown-up to try again."
        }
    }

    private var restoreOwnershipSummary: String {
        "Restore stays linked to the parent account that restores Plus on this device. If another parent signs in later, StoryTime keeps that parent's current plan instead of transferring the restored access."
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
}
