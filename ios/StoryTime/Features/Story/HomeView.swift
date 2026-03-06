import SwiftUI

struct HomeView: View {
    @ObservedObject var store: StoryLibraryStore
    @State private var showingNewJourney = false
    @State private var showingParentHub = false

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
                    showingNewJourney = true
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
            .sheet(isPresented: $showingNewJourney) {
                NavigationStack {
                    NewStoryJourneyView(store: store)
                }
            }
            .sheet(isPresented: $showingParentHub) {
                NavigationStack {
                    ParentTrustCenterView(store: store)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("StoryTime")
                    .font(.system(size: 36, weight: .black, design: .rounded))

                Text("Voice stories with parent controls built in")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingParentHub = true
            } label: {
                Label("Parent", systemImage: "lock.shield")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("parentControlsButton")
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

            Button {
                showingNewJourney = true
            } label: {
                Label("New Story", systemImage: "plus.circle.fill")
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
            Text("Trust controls")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            HStack(spacing: 10) {
                trustPill(title: "Raw audio", value: "Off")
                trustPill(title: "History", value: store.storyHistorySummary)
            }

            Text("Parents manage profiles, sensitivity, retention, and deletion. Raw audio is not saved by default.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
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
            Text("Past Stories")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            if store.visibleSeries.isEmpty {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.75))
                    .frame(height: 148)
                    .overlay(
                        VStack(spacing: 8) {
                            Text(emptyStateTitle)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
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
                    Text("Latest: \(latest.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
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
        .frame(height: 132)
    }
}

private struct ParentTrustCenterView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: StoryLibraryStore

    @State private var editingProfile: ChildProfile?
    @State private var showProfileEditor = false
    @State private var pendingProfileDeletion: ChildProfile?
    @State private var showDeleteHistoryConfirmation = false

    var body: some View {
        Form {
            Section("Privacy") {
                Label("Raw audio storage is off by default", systemImage: "waveform.slash")
                    .foregroundStyle(.primary)
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
                Text("Stories stay on device. Raw audio is not persisted in StoryTime V1.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

                if store.canAddMoreProfiles {
                    Button {
                        editingProfile = nil
                        showProfileEditor = true
                    } label: {
                        Label("Add Child Profile", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("addChildProfileButton")
                } else {
                    Text("V1 supports up to 3 child profiles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

            Section("Story history controls") {
                Text("\(store.visibleSeries.count) saved series for the active child")
                    .foregroundStyle(.secondary)
                Button("Delete All Saved Story History", role: .destructive) {
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
        .sheet(isPresented: $showProfileEditor) {
            NavigationStack {
                ChildProfileEditorView(store: store, profile: editingProfile)
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

private struct ChildProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: StoryLibraryStore
    let profile: ChildProfile?

    @State private var name: String
    @State private var age: Int
    @State private var sensitivity: ContentSensitivity
    @State private var mode: StoryExperienceMode

    init(store: StoryLibraryStore, profile: ChildProfile?) {
        self.store = store
        self.profile = profile
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
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            store.addChildProfile(name: name, age: age, sensitivity: sensitivity, preferredMode: mode)
        }
        dismiss()
    }
}
