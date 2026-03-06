import Foundation

@MainActor
final class StoryLibraryStore: ObservableObject {
    @Published private(set) var series: [StorySeries] = []
    @Published private(set) var childProfiles: [ChildProfile] = []
    @Published private(set) var activeChildProfileId: UUID?
    @Published private(set) var privacySettings: ParentPrivacySettings = .default

    private let seriesStorageKey = "storytime.series.library.v1"
    private let profilesStorageKey = "storytime.child.profiles.v1"
    private let activeProfileStorageKey = "storytime.active.child.profile.v1"
    private let privacyStorageKey = "storytime.parent.privacy.v1"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadProfiles()
        loadPrivacySettings()
        loadSeries()
        ensureActiveProfile()
        applyRetentionPolicy()
    }

    var activeProfile: ChildProfile? {
        profileById(activeChildProfileId) ?? childProfiles.first
    }

    var canAddMoreProfiles: Bool {
        childProfiles.count < 3
    }

    var visibleSeries: [StorySeries] {
        guard let activeChildProfileId else {
            return series
        }

        let filtered = series.filter { $0.childProfileId == nil || $0.childProfileId == activeChildProfileId }
        return filtered.isEmpty ? series : filtered
    }

    var storyHistorySummary: String {
        guard privacySettings.saveStoryHistory else {
            return "Story history is off"
        }
        return "History retained for \(privacySettings.retentionPolicy.title)"
    }

    func seriesById(_ id: UUID?) -> StorySeries? {
        guard let id else { return nil }
        return series.first(where: { $0.id == id })
    }

    func profileById(_ id: UUID?) -> ChildProfile? {
        guard let id else { return nil }
        return childProfiles.first(where: { $0.id == id })
    }

    func selectActiveProfile(_ id: UUID) {
        guard childProfiles.contains(where: { $0.id == id }) else { return }
        activeChildProfileId = id
        persistActiveProfile()
    }

    func addChildProfile(name: String, age: Int, sensitivity: ContentSensitivity, preferredMode: StoryExperienceMode) {
        guard canAddMoreProfiles else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Story Explorer" : trimmedName
        let profile = ChildProfile(
            id: UUID(),
            displayName: resolvedName,
            age: min(max(age, 3), 8),
            contentSensitivity: sensitivity,
            preferredMode: preferredMode
        )

        childProfiles.append(profile)
        childProfiles.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        if activeChildProfileId == nil {
            activeChildProfileId = profile.id
            persistActiveProfile()
        }
        persistProfiles()
    }

    func updateChildProfile(_ profile: ChildProfile) {
        guard let index = childProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        childProfiles[index] = profile
        childProfiles.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        persistProfiles()
    }

    func deleteChildProfile(_ id: UUID) {
        guard let index = childProfiles.firstIndex(where: { $0.id == id }) else { return }
        let removedSeriesIds = series.filter { $0.childProfileId == id }.map(\.id)
        childProfiles.remove(at: index)

        if childProfiles.isEmpty {
            let fallback = Self.defaultProfiles()
            childProfiles = fallback
            activeChildProfileId = fallback.first?.id
        } else if activeChildProfileId == id {
            activeChildProfileId = childProfiles.first?.id
        }

        series.removeAll { $0.childProfileId == id }
        persistProfiles()
        persistActiveProfile()
        persistSeries()
        Task {
            for seriesId in removedSeriesIds {
                await ContinuityMemoryStore.shared.clearSeries(seriesId)
            }
        }
    }

    func setSaveStoryHistory(_ enabled: Bool) {
        privacySettings.saveStoryHistory = enabled
        persistPrivacySettings()
        applyRetentionPolicy()
    }

    func setRetentionPolicy(_ policy: StoryRetentionPolicy) {
        privacySettings.retentionPolicy = policy
        persistPrivacySettings()
        applyRetentionPolicy()
    }

    func setClearTranscriptsAfterSession(_ enabled: Bool) {
        privacySettings.clearTranscriptsAfterSession = enabled
        persistPrivacySettings()
    }

    func addStory(_ story: StoryData, characters: [String], plan: StoryLaunchPlan) -> UUID? {
        guard privacySettings.saveStoryHistory else { return nil }
        applyRetentionPolicy()

        switch plan.mode {
        case .new:
            if plan.usePastStory, let selectedId = plan.selectedSeriesId {
                _ = appendEpisode(story, to: selectedId, childProfileId: plan.childProfileId)
                return selectedId
            } else {
                return createNewSeries(story, characters: characters, childProfileId: plan.childProfileId)
            }
        case .extend(let seriesId):
            return appendEpisode(story, to: seriesId, childProfileId: plan.childProfileId)
        case .repeatEpisode:
            return nil
        }
    }

    private func createNewSeries(_ story: StoryData, characters: [String], childProfileId: UUID) -> UUID {
        let now = Date()
        let resolvedCharacters = characters.isEmpty
            ? (story.engine?.characterBible.map(\.name) ?? [])
            : characters
        let memory = story.engine?.seriesMemory
        let episode = StoryEpisode(
            id: UUID(),
            title: story.title,
            storyId: story.storyId,
            scenes: story.scenes,
            estimatedDurationSec: story.estimatedDurationSec,
            engine: story.engine,
            createdAt: now
        )

        let created = StorySeries(
            id: UUID(),
            childProfileId: childProfileId,
            title: story.title,
            characterHints: resolvedCharacters,
            arcSummary: memory?.arcSummary,
            relationshipFacts: memory?.relationshipFacts,
            favoritePlaces: memory?.favoritePlaces,
            unresolvedThreads: memory?.openLoops,
            episodes: [episode],
            createdAt: now,
            updatedAt: now
        )

        series.insert(created, at: 0)
        persistSeries()
        return created.id
    }

    private func appendEpisode(_ story: StoryData, to seriesId: UUID, childProfileId: UUID) -> UUID {
        guard let index = series.firstIndex(where: { $0.id == seriesId }) else {
            return createNewSeries(story, characters: [], childProfileId: childProfileId)
        }

        let episode = StoryEpisode(
            id: UUID(),
            title: story.title,
            storyId: story.storyId,
            scenes: story.scenes,
            estimatedDurationSec: story.estimatedDurationSec,
            engine: story.engine,
            createdAt: Date()
        )

        series[index].childProfileId = childProfileId
        series[index].episodes.append(episode)
        series[index].updatedAt = Date()

        if !story.title.isEmpty {
            series[index].title = story.title
        }

        let engineCharacters = story.engine?.characterBible.map(\.name) ?? []
        if !engineCharacters.isEmpty {
            series[index].characterHints = Array(Set(series[index].characterHints + engineCharacters)).sorted()
        }
        applyContinuityMetadata(from: story, to: index)

        let moved = series.remove(at: index)
        series.insert(moved, at: 0)
        persistSeries()
        return moved.id
    }

    func replaceStory(_ story: StoryData) -> UUID? {
        guard privacySettings.saveStoryHistory else { return nil }

        for seriesIndex in series.indices {
            guard let episodeIndex = series[seriesIndex].episodes.firstIndex(where: { $0.storyId == story.storyId }) else {
                continue
            }

            let existing = series[seriesIndex].episodes[episodeIndex]
            series[seriesIndex].episodes[episodeIndex] = StoryEpisode(
                id: existing.id,
                title: story.title,
                storyId: story.storyId,
                scenes: story.scenes,
                estimatedDurationSec: story.estimatedDurationSec,
                engine: story.engine,
                createdAt: existing.createdAt
            )
            let engineCharacters = story.engine?.characterBible.map(\.name) ?? []
            if !engineCharacters.isEmpty {
                series[seriesIndex].characterHints = Array(Set(series[seriesIndex].characterHints + engineCharacters)).sorted()
            }
            applyContinuityMetadata(from: story, to: seriesIndex)
            series[seriesIndex].updatedAt = Date()
            persistSeries()
            return series[seriesIndex].id
        }
        return nil
    }

    func deleteSeries(_ id: UUID) {
        series.removeAll { $0.id == id }
        persistSeries()
        Task {
            await ContinuityMemoryStore.shared.clearSeries(id)
        }
    }

    func clearStoryHistory() {
        series = []
        persistSeries()
        Task {
            await ContinuityMemoryStore.shared.clearAll()
        }
    }

    private func applyContinuityMetadata(from story: StoryData, to seriesIndex: Int) {
        guard let engine = story.engine else { return }
        series[seriesIndex].arcSummary = engine.seriesMemory.arcSummary ?? series[seriesIndex].arcSummary

        if !engine.seriesMemory.relationshipFacts.isEmpty {
            let merged = Set((series[seriesIndex].relationshipFacts ?? []) + engine.seriesMemory.relationshipFacts)
            series[seriesIndex].relationshipFacts = Array(merged).sorted()
        }

        if !engine.seriesMemory.favoritePlaces.isEmpty {
            let merged = Set((series[seriesIndex].favoritePlaces ?? []) + engine.seriesMemory.favoritePlaces)
            series[seriesIndex].favoritePlaces = Array(merged).sorted()
        }

        if !engine.seriesMemory.openLoops.isEmpty {
            let merged = Set((series[seriesIndex].unresolvedThreads ?? []) + engine.seriesMemory.openLoops)
            series[seriesIndex].unresolvedThreads = Array(merged).sorted()
        }
    }

    private func applyRetentionPolicy() {
        guard privacySettings.saveStoryHistory else {
            if !series.isEmpty {
                series = []
                persistSeries()
            }
            Task {
                await ContinuityMemoryStore.shared.clearAll()
            }
            return
        }

        guard let days = privacySettings.retentionPolicy.dayCount,
              let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            syncContinuityMemoryWithLibrary()
            return
        }

        let pruned = series.compactMap { current -> StorySeries? in
            var copy = current
            copy.episodes = current.episodes.filter { $0.createdAt >= cutoffDate }
            guard !copy.episodes.isEmpty else { return nil }
            copy.updatedAt = copy.episodes.map(\.createdAt).max() ?? current.updatedAt
            return copy
        }

        if pruned != series {
            series = pruned
            persistSeries()
        }
        syncContinuityMemoryWithLibrary()
    }

    private func syncContinuityMemoryWithLibrary() {
        let allowedSeries = Set(series.map(\.id))
        let allowedStoryIds = Set(series.flatMap { $0.episodes.map(\.storyId) })
        Task {
            await ContinuityMemoryStore.shared.prune(toSeriesIDs: allowedSeries, storyIDs: allowedStoryIds)
        }
    }

    private func ensureActiveProfile() {
        if activeProfile == nil {
            activeChildProfileId = childProfiles.first?.id
            persistActiveProfile()
        }
    }

    private func persistSeries() {
        do {
            let data = try JSONEncoder().encode(series)
            userDefaults.set(data, forKey: seriesStorageKey)
        } catch {
            print("Failed to persist Story library: \(error)")
        }
    }

    private func persistProfiles() {
        do {
            let data = try JSONEncoder().encode(childProfiles)
            userDefaults.set(data, forKey: profilesStorageKey)
        } catch {
            print("Failed to persist child profiles: \(error)")
        }
    }

    private func persistActiveProfile() {
        userDefaults.set(activeChildProfileId?.uuidString, forKey: activeProfileStorageKey)
    }

    private func persistPrivacySettings() {
        do {
            let data = try JSONEncoder().encode(privacySettings)
            userDefaults.set(data, forKey: privacyStorageKey)
        } catch {
            print("Failed to persist privacy settings: \(error)")
        }
    }

    private func loadSeries() {
        guard let data = userDefaults.data(forKey: seriesStorageKey) else {
            series = []
            return
        }

        do {
            series = try JSONDecoder().decode([StorySeries].self, from: data)
        } catch {
            series = []
            print("Failed to decode Story library: \(error)")
        }
    }

    private func loadProfiles() {
        guard let data = userDefaults.data(forKey: profilesStorageKey) else {
            childProfiles = Self.defaultProfiles()
            persistProfiles()
            return
        }

        do {
            let decoded = try JSONDecoder().decode([ChildProfile].self, from: data)
            childProfiles = decoded.isEmpty ? Self.defaultProfiles() : decoded
            if decoded.isEmpty {
                persistProfiles()
            }
        } catch {
            childProfiles = Self.defaultProfiles()
            persistProfiles()
            print("Failed to decode child profiles: \(error)")
        }

        if let storedId = userDefaults.string(forKey: activeProfileStorageKey),
           let parsed = UUID(uuidString: storedId) {
            activeChildProfileId = parsed
        }
    }

    private func loadPrivacySettings() {
        guard let data = userDefaults.data(forKey: privacyStorageKey) else {
            privacySettings = .default
            persistPrivacySettings()
            return
        }

        do {
            privacySettings = try JSONDecoder().decode(ParentPrivacySettings.self, from: data)
        } catch {
            privacySettings = .default
            persistPrivacySettings()
            print("Failed to decode privacy settings: \(error)")
        }
    }

    private static func defaultProfiles() -> [ChildProfile] {
        [
            ChildProfile(
                id: UUID(),
                displayName: "Story Explorer",
                age: 5,
                contentSensitivity: .extraGentle,
                preferredMode: .classic
            )
        ]
    }
}

struct ContinuityFactRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let seriesId: UUID
    let storyId: String
    let text: String
    let embedding: [Double]
    let updatedAt: Date
}

actor ContinuityMemoryStore {
    static let shared = ContinuityMemoryStore()

    private let storageKey = "storytime.continuity.memory.v1"
    private var facts: [ContinuityFactRecord]
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ContinuityFactRecord].self, from: data) {
            self.facts = decoded
        } else {
            self.facts = []
        }
        self.userDefaults = userDefaults
    }

    func replaceFacts(seriesId: UUID, storyId: String, texts: [String], embeddings: [[Double]]) {
        guard texts.count == embeddings.count else { return }

        facts.removeAll { $0.seriesId == seriesId && $0.storyId == storyId }

        let now = Date()
        let appended = zip(texts, embeddings).map { text, embedding in
            ContinuityFactRecord(
                id: UUID(),
                seriesId: seriesId,
                storyId: storyId,
                text: text,
                embedding: embedding,
                updatedAt: now
            )
        }

        facts.append(contentsOf: appended)
        persist()
    }

    func topFactTexts(seriesId: UUID, queryEmbedding: [Double], limit: Int) -> [String] {
        let ranked = facts
            .filter { $0.seriesId == seriesId && !$0.embedding.isEmpty }
            .map { ($0.text, cosineSimilarity($0.embedding, queryEmbedding)) }
            .sorted { lhs, rhs in lhs.1 > rhs.1 }
            .filter { $0.1 > 0.18 }

        var results: [String] = []
        for (text, _) in ranked {
            if !results.contains(text) {
                results.append(text)
            }
            if results.count >= limit {
                break
            }
        }

        return results
    }

    func clearSeries(_ seriesId: UUID) {
        facts.removeAll { $0.seriesId == seriesId }
        persist()
    }

    func clearAll() {
        facts = []
        persist()
    }

    func prune(toSeriesIDs seriesIDs: Set<UUID>, storyIDs: Set<String>) {
        facts.removeAll { !seriesIDs.contains($0.seriesId) || !storyIDs.contains($0.storyId) }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(facts) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    private func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }

        var dot = 0.0
        var lhsMagnitude = 0.0
        var rhsMagnitude = 0.0

        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            lhsMagnitude += lhs[index] * lhs[index]
            rhsMagnitude += rhs[index] * rhs[index]
        }

        guard lhsMagnitude > 0, rhsMagnitude > 0 else { return 0 }
        return dot / (sqrt(lhsMagnitude) * sqrt(rhsMagnitude))
    }
}
