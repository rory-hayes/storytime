import CoreData
import Foundation

private let storyLibraryDefaultMaxChildProfiles = 3

struct StoryLibraryV2Snapshot: Codable, Equatable {
    var migrationVersion: Int
    var series: [StorySeries]
    var childProfiles: [ChildProfile]
    var activeChildProfileId: UUID?
    var privacySettings: ParentPrivacySettings
}

extension StoryLibraryV2Snapshot {
    static let currentMigrationVersion = 2
}

struct ContinuityStoryReference: Hashable {
    let seriesId: UUID
    let storyId: String
}

final class StoryLibraryV2Storage {
    private enum EntityName {
        static let settings = "StoredLibrarySettings"
        static let profile = "StoredChildProfile"
        static let series = "StoredStorySeries"
        static let episode = "StoredStoryEpisode"
        static let continuity = "StoredContinuityFact"
        static let migrationLog = "StoredMigrationLog"
    }

    private let url: URL
    private let container: NSPersistentContainer
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    static func defaultStorageURL() -> URL {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return supportDirectory.appendingPathComponent("storytime-v2.sqlite", isDirectory: false)
    }

    init(storageURL: URL? = nil) {
        self.url = storageURL ?? Self.defaultStorageURL()
        self.container = Self.makeContainer(storeURL: self.url)
    }

    func migrationVersion() -> Int {
        do {
            return try withContext { context in
                try self.fetchMigrationVersion(in: context)
            }
        } catch {
            print("Failed to read StoryLibrary v2 migration version: \(error)")
            return 0
        }
    }

    func hasMigrationNote(_ note: String) -> Bool {
        do {
            return try withContext { context in
                let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.migrationLog)
                request.fetchLimit = 1
                request.predicate = NSPredicate(format: "notes == %@", note)
                return try context.fetch(request).isEmpty == false
            }
        } catch {
            print("Failed to query StoryLibrary v2 migration note: \(error)")
            return false
        }
    }

    func recordMigration(version: Int, notes: String) {
        do {
            try withContext { context in
                self.insertMigration(version: version, notes: notes, in: context)
                try self.saveContext(context)
            }
        } catch {
            print("Failed to record StoryLibrary v2 migration: \(error)")
        }
    }

    func loadSnapshot() -> StoryLibraryV2Snapshot? {
        do {
            return try withContext { context in
                guard let settings = try self.fetchSettings(in: context) else {
                    return nil
                }

                let migrationVersion = try self.fetchMigrationVersion(in: context)
                guard migrationVersion > 0 else {
                    return nil
                }

                let profiles = try self.fetchProfiles(in: context)
                let series = try self.fetchSeries(in: context)

                return StoryLibraryV2Snapshot(
                    migrationVersion: migrationVersion,
                    series: series,
                    childProfiles: profiles.isEmpty ? Self.defaultProfiles() : profiles,
                    activeChildProfileId: settings.activeChildProfileId,
                    privacySettings: settings.privacySettings
                )
            }
        } catch {
            print("Failed to load StoryLibrary v2 snapshot: \(error)")
            return nil
        }
    }

    func saveSnapshot(_ snapshot: StoryLibraryV2Snapshot) {
        do {
            try withContext { context in
                try self.clearSnapshotRows(in: context)

                let settings = NSEntityDescription.insertNewObject(forEntityName: EntityName.settings, into: context)
                settings.setValue(UUID(), forKey: "id")
                settings.setValue(snapshot.activeChildProfileId, forKey: "activeChildProfileId")
                settings.setValue(snapshot.privacySettings.saveStoryHistory, forKey: "saveStoryHistory")
                settings.setValue(snapshot.privacySettings.retentionPolicy.rawValue, forKey: "retentionPolicy")
                settings.setValue(snapshot.privacySettings.saveRawAudio, forKey: "saveRawAudio")
                settings.setValue(snapshot.privacySettings.clearTranscriptsAfterSession, forKey: "clearTranscriptsAfterSession")
                settings.setValue(Date(), forKey: "updatedAt")

                for profile in snapshot.childProfiles {
                    let object = NSEntityDescription.insertNewObject(forEntityName: EntityName.profile, into: context)
                    object.setValue(profile.id, forKey: "id")
                    object.setValue(profile.displayName, forKey: "displayName")
                    object.setValue(Int16(profile.age), forKey: "age")
                    object.setValue(profile.contentSensitivity.rawValue, forKey: "contentSensitivity")
                    object.setValue(profile.preferredMode.rawValue, forKey: "preferredMode")
                    object.setValue(Date(), forKey: "updatedAt")
                }

                for (libraryPosition, series) in snapshot.series.enumerated() {
                    let seriesObject = NSEntityDescription.insertNewObject(forEntityName: EntityName.series, into: context)
                    seriesObject.setValue(series.id, forKey: "id")
                    seriesObject.setValue(series.childProfileId, forKey: "childProfileId")
                    seriesObject.setValue(series.title, forKey: "title")
                    seriesObject.setValue(try self.encode(series.characterHints), forKey: "characterHintsData")
                    seriesObject.setValue(try self.encode(series.relationshipFacts), forKey: "relationshipFactsData")
                    seriesObject.setValue(try self.encode(series.favoritePlaces), forKey: "favoritePlacesData")
                    seriesObject.setValue(try self.encode(series.unresolvedThreads), forKey: "unresolvedThreadsData")
                    seriesObject.setValue(series.arcSummary, forKey: "arcSummary")
                    seriesObject.setValue(series.createdAt, forKey: "createdAt")
                    seriesObject.setValue(series.updatedAt, forKey: "updatedAt")
                    seriesObject.setValue(Int32(libraryPosition), forKey: "libraryPosition")

                    for (storyIndex, episode) in series.episodes.enumerated() {
                        let episodeObject = NSEntityDescription.insertNewObject(forEntityName: EntityName.episode, into: context)
                        episodeObject.setValue(episode.id, forKey: "id")
                        episodeObject.setValue(series.id, forKey: "seriesId")
                        episodeObject.setValue(episode.storyId, forKey: "storyId")
                        episodeObject.setValue(episode.title, forKey: "title")
                        episodeObject.setValue(try self.encode(episode.scenes), forKey: "scenesData")
                        episodeObject.setValue(try self.encode(episode.engine), forKey: "engineData")
                        episodeObject.setValue(Int32(episode.estimatedDurationSec), forKey: "estimatedDurationSec")
                        episodeObject.setValue(Int32(storyIndex), forKey: "storyIndex")
                        episodeObject.setValue(episode.createdAt, forKey: "createdAt")
                    }
                }

                self.insertMigration(version: snapshot.migrationVersion, notes: "StoryLibrary v2 snapshot write", in: context)

                try self.saveContext(context)
            }
        } catch {
            print("Failed to persist StoryLibrary v2 snapshot: \(error)")
        }
    }

    func insertSeries(_ series: StorySeries, orderedSeries: [StorySeries]) {
        do {
            try withContext { context in
                if try self.fetchSeriesObject(id: series.id, in: context) != nil {
                    try self.replaceAllSeries(orderedSeries, in: context)
                    return
                }

                try self.updateLibraryPositions(for: orderedSeries.map(\.id), in: context)
                let position = orderedSeries.firstIndex(where: { $0.id == series.id }).map(Int32.init) ?? 0
                _ = try self.upsertSeriesObject(for: series, libraryPosition: position, in: context)
                for (storyIndex, episode) in series.episodes.enumerated() {
                    try self.insertEpisode(episode, seriesId: series.id, storyIndex: Int32(storyIndex), in: context)
                }
                try self.saveContext(context)
            }
        } catch {
            print("Failed to insert StoryLibrary series: \(error)")
        }
    }

    func appendEpisode(_ episode: StoryEpisode, to updatedSeries: StorySeries, orderedSeries: [StorySeries]) {
        do {
            try withContext { context in
                guard try self.fetchSeriesObject(id: updatedSeries.id, in: context) != nil else {
                    try self.replaceAllSeries(orderedSeries, in: context)
                    return
                }

                let position = orderedSeries.firstIndex(where: { $0.id == updatedSeries.id }).map(Int32.init) ?? 0
                _ = try self.upsertSeriesObject(for: updatedSeries, libraryPosition: position, in: context)
                try self.updateLibraryPositions(for: orderedSeries.map(\.id), in: context)
                try self.insertEpisode(
                    episode,
                    seriesId: updatedSeries.id,
                    storyIndex: Int32(updatedSeries.episodes.count - 1),
                    in: context
                )
                try self.saveContext(context)
            }
        } catch {
            print("Failed to append StoryLibrary episode: \(error)")
        }
    }

    func replaceEpisode(storyId: String, in updatedSeries: StorySeries, orderedSeries: [StorySeries]) {
        do {
            try withContext { context in
                guard let episodeObject = try self.fetchEpisodeObject(storyId: storyId, in: context) else {
                    try self.replaceAllSeries(orderedSeries, in: context)
                    return
                }

                let position = try self.fetchSeriesObject(id: updatedSeries.id, in: context)?
                    .value(forKey: "libraryPosition") as? Int32 ?? 0
                _ = try self.upsertSeriesObject(for: updatedSeries, libraryPosition: position, in: context)
                guard let updatedEpisode = updatedSeries.episodes.first(where: { $0.storyId == storyId }) else {
                    try self.saveContext(context)
                    return
                }

                let storyIndex = episodeObject.value(forKey: "storyIndex") as? Int32 ?? 0
                try self.writeEpisode(updatedEpisode, seriesId: updatedSeries.id, storyIndex: storyIndex, to: episodeObject)
                try self.saveContext(context)
            }
        } catch {
            print("Failed to replace StoryLibrary episode: \(error)")
        }
    }

    func deleteSeries(_ seriesID: UUID, orderedSeriesIDs: [UUID]) {
        do {
            try withContext { context in
                try self.deleteEpisodes(forSeriesID: seriesID, in: context)
                try self.deleteSeriesRow(id: seriesID, in: context)
                try self.updateLibraryPositions(for: orderedSeriesIDs, in: context)
                try self.saveContext(context)
            }
        } catch {
            print("Failed to delete StoryLibrary series: \(error)")
        }
    }

    func clearStoryHistory() {
        do {
            try withContext { context in
                try self.clearStoryRows(in: context)
                try self.saveContext(context)
            }
        } catch {
            print("Failed to clear StoryLibrary history: \(error)")
        }
    }

    func saveSettings(activeChildProfileId: UUID?, privacySettings: ParentPrivacySettings) {
        do {
            try withContext { context in
                let settings = try self.fetchSettingsObject(in: context)
                    ?? NSEntityDescription.insertNewObject(forEntityName: EntityName.settings, into: context)
                self.writeSettings(
                    activeChildProfileId: activeChildProfileId,
                    privacySettings: privacySettings,
                    to: settings
                )
                try self.saveContext(context)
            }
        } catch {
            print("Failed to persist StoryLibrary settings: \(error)")
        }
    }

    func applyRetentionPrune(_ retainedSeries: [StorySeries]) {
        do {
            try withContext { context in
                let allowedSeriesIDs = Set(retainedSeries.map(\.id))
                let seriesRequest = NSFetchRequest<NSManagedObject>(entityName: EntityName.series)
                let episodeRequest = NSFetchRequest<NSManagedObject>(entityName: EntityName.episode)

                let existingSeries = try context.fetch(seriesRequest)
                let existingEpisodes = try context.fetch(episodeRequest)

                var episodeObjectsBySeriesID: [UUID: [String: NSManagedObject]] = [:]
                for episodeObject in existingEpisodes {
                    guard let seriesID = episodeObject.value(forKey: "seriesId") as? UUID,
                          let storyID = episodeObject.value(forKey: "storyId") as? String else {
                        continue
                    }
                    if allowedSeriesIDs.contains(seriesID) == false {
                        context.delete(episodeObject)
                        continue
                    }
                    episodeObjectsBySeriesID[seriesID, default: [:]][storyID] = episodeObject
                }

                for seriesObject in existingSeries {
                    guard let seriesID = seriesObject.value(forKey: "id") as? UUID else {
                        continue
                    }
                    if allowedSeriesIDs.contains(seriesID) == false {
                        context.delete(seriesObject)
                    }
                }

                for (libraryPosition, series) in retainedSeries.enumerated() {
                    _ = try self.upsertSeriesObject(for: series, libraryPosition: Int32(libraryPosition), in: context)

                    let allowedStoryIDs = Set(series.episodes.map(\.storyId))
                    let existingObjects = episodeObjectsBySeriesID[series.id] ?? [:]
                    for (storyID, episodeObject) in existingObjects where allowedStoryIDs.contains(storyID) == false {
                        context.delete(episodeObject)
                    }

                    for (storyIndex, episode) in series.episodes.enumerated() {
                        if let existingEpisodeObject = existingObjects[episode.storyId] {
                            try self.writeEpisode(
                                episode,
                                seriesId: series.id,
                                storyIndex: Int32(storyIndex),
                                to: existingEpisodeObject
                            )
                        } else {
                            try self.insertEpisode(
                                episode,
                                seriesId: series.id,
                                storyIndex: Int32(storyIndex),
                                in: context
                            )
                        }
                    }
                }

                try self.saveContext(context)
            }
        } catch {
            print("Failed to apply StoryLibrary retention prune: \(error)")
        }
    }

    func replaceSeriesCollection(_ series: [StorySeries]) {
        do {
            try withContext { context in
                try self.replaceAllSeries(series, in: context)
            }
        } catch {
            print("Failed to replace StoryLibrary series collection: \(error)")
        }
    }

    func loadContinuityFacts() -> [ContinuityFactRecord]? {
        do {
            return try withContext { context in
                let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.continuity)
                request.sortDescriptors = [
                    NSSortDescriptor(key: "updatedAt", ascending: true),
                    NSSortDescriptor(key: "text", ascending: true)
                ]

                return try context.fetch(request).compactMap { object in
                    guard let id = object.value(forKey: "id") as? UUID,
                          let seriesId = object.value(forKey: "seriesId") as? UUID,
                          let storyId = object.value(forKey: "storyId") as? String,
                          let text = object.value(forKey: "text") as? String,
                          let updatedAt = object.value(forKey: "updatedAt") as? Date,
                          let embedding = self.decode([Double].self, from: object.value(forKey: "embeddingData") as? Data) else {
                        return nil
                    }

                    return ContinuityFactRecord(
                        id: id,
                        seriesId: seriesId,
                        storyId: storyId,
                        text: text,
                        embedding: embedding,
                        updatedAt: updatedAt
                    )
                }
            }
        } catch {
            print("Failed to load StoryLibrary continuity facts: \(error)")
            return nil
        }
    }

    func replaceContinuityFacts(_ facts: [ContinuityFactRecord]) {
        do {
            try withContext { context in
                try self.clearContinuityRows(in: context)
                for fact in facts {
                    let object = NSEntityDescription.insertNewObject(forEntityName: EntityName.continuity, into: context)
                    object.setValue(fact.id, forKey: "id")
                    object.setValue(fact.seriesId, forKey: "seriesId")
                    object.setValue(fact.storyId, forKey: "storyId")
                    object.setValue(fact.text, forKey: "text")
                    object.setValue(try self.encode(fact.embedding), forKey: "embeddingData")
                    object.setValue(fact.updatedAt, forKey: "updatedAt")
                }
                try self.saveContext(context)
            }
        } catch {
            print("Failed to persist StoryLibrary continuity facts: \(error)")
        }
    }

    func clear() {
        do {
            try withContext { context in
                try self.clearAllRows(in: context)
            }
        } catch {
            print("Failed to clear StoryLibrary v2 storage: \(error)")
        }
    }

    private struct SettingsSnapshot {
        let activeChildProfileId: UUID?
        let privacySettings: ParentPrivacySettings
    }

    private func fetchSettings(in context: NSManagedObjectContext) throws -> SettingsSnapshot? {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.settings)
        request.fetchLimit = 1
        guard let settings = try context.fetch(request).first else {
            return nil
        }

        let retentionRawValue = settings.value(forKey: "retentionPolicy") as? String
        let retentionPolicy = retentionRawValue.flatMap(StoryRetentionPolicy.init(rawValue:)) ?? ParentPrivacySettings.default.retentionPolicy
        let privacy = ParentPrivacySettings(
            saveStoryHistory: settings.value(forKey: "saveStoryHistory") as? Bool ?? ParentPrivacySettings.default.saveStoryHistory,
            retentionPolicy: retentionPolicy,
            saveRawAudio: settings.value(forKey: "saveRawAudio") as? Bool ?? false,
            clearTranscriptsAfterSession: settings.value(forKey: "clearTranscriptsAfterSession") as? Bool ?? ParentPrivacySettings.default.clearTranscriptsAfterSession
        )

        return SettingsSnapshot(
            activeChildProfileId: settings.value(forKey: "activeChildProfileId") as? UUID,
            privacySettings: privacy
        )
    }

    private func fetchProfiles(in context: NSManagedObjectContext) throws -> [ChildProfile] {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.profile)
        request.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]

        return try context.fetch(request).compactMap { object in
            guard let id = object.value(forKey: "id") as? UUID,
                  let displayName = object.value(forKey: "displayName") as? String,
                  let contentSensitivityRaw = object.value(forKey: "contentSensitivity") as? String,
                  let preferredModeRaw = object.value(forKey: "preferredMode") as? String,
                  let contentSensitivity = ContentSensitivity(rawValue: contentSensitivityRaw),
                  let preferredMode = StoryExperienceMode(rawValue: preferredModeRaw) else {
                return nil
            }

            return ChildProfile(
                id: id,
                displayName: displayName,
                age: Int(object.value(forKey: "age") as? Int16 ?? 5),
                contentSensitivity: contentSensitivity,
                preferredMode: preferredMode
            )
        }
    }

    private func fetchSeries(in context: NSManagedObjectContext) throws -> [StorySeries] {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.series)
        request.sortDescriptors = [
            NSSortDescriptor(key: "libraryPosition", ascending: true),
            NSSortDescriptor(key: "updatedAt", ascending: false)
        ]

        return try context.fetch(request).compactMap { object in
            guard let id = object.value(forKey: "id") as? UUID,
                  let title = object.value(forKey: "title") as? String,
                  let createdAt = object.value(forKey: "createdAt") as? Date,
                  let updatedAt = object.value(forKey: "updatedAt") as? Date else {
                return nil
            }

            let childProfileId = object.value(forKey: "childProfileId") as? UUID
            let characterHints: [String] = decode([String].self, from: object.value(forKey: "characterHintsData") as? Data) ?? []
            let relationshipFacts: [String]? = decode([String].self, from: object.value(forKey: "relationshipFactsData") as? Data)
            let favoritePlaces: [String]? = decode([String].self, from: object.value(forKey: "favoritePlacesData") as? Data)
            let unresolvedThreads: [String]? = decode([String].self, from: object.value(forKey: "unresolvedThreadsData") as? Data)
            let episodes = try fetchEpisodes(in: context, seriesId: id)

            return StorySeries(
                id: id,
                childProfileId: childProfileId,
                title: title,
                characterHints: characterHints,
                arcSummary: object.value(forKey: "arcSummary") as? String,
                relationshipFacts: relationshipFacts,
                favoritePlaces: favoritePlaces,
                unresolvedThreads: unresolvedThreads,
                episodes: episodes,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    private func fetchEpisodes(in context: NSManagedObjectContext, seriesId: UUID) throws -> [StoryEpisode] {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.episode)
        request.predicate = NSPredicate(format: "seriesId == %@", seriesId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "storyIndex", ascending: true)]

        return try context.fetch(request).compactMap { object in
            guard let id = object.value(forKey: "id") as? UUID,
                  let title = object.value(forKey: "title") as? String,
                  let storyId = object.value(forKey: "storyId") as? String,
                  let createdAt = object.value(forKey: "createdAt") as? Date,
                  let scenesData = object.value(forKey: "scenesData") as? Data,
                  let scenes = decode([StoryScene].self, from: scenesData) else {
                return nil
            }

            let engine = decode(StoryEngineData.self, from: object.value(forKey: "engineData") as? Data)
            return StoryEpisode(
                id: id,
                title: title,
                storyId: storyId,
                scenes: scenes,
                estimatedDurationSec: Int(object.value(forKey: "estimatedDurationSec") as? Int32 ?? 0),
                engine: engine,
                createdAt: createdAt
            )
        }
    }

    private func fetchMigrationVersion(in context: NSManagedObjectContext) throws -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.migrationLog)
        request.sortDescriptors = [NSSortDescriptor(key: "toVersion", ascending: false)]
        request.fetchLimit = 1
        let version = try context.fetch(request).first?.value(forKey: "toVersion") as? Int16
        return Int(version ?? 0)
    }

    private func fetchSettingsObject(in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.settings)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchSeriesObject(id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.series)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
    }

    private func fetchEpisodeObject(storyId: String, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.episode)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "storyId == %@", storyId)
        return try context.fetch(request).first
    }

    private func upsertSeriesObject(
        for series: StorySeries,
        libraryPosition: Int32,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        let object = try fetchSeriesObject(id: series.id, in: context)
            ?? NSEntityDescription.insertNewObject(forEntityName: EntityName.series, into: context)

        object.setValue(series.id, forKey: "id")
        object.setValue(series.childProfileId, forKey: "childProfileId")
        object.setValue(series.title, forKey: "title")
        object.setValue(try self.encode(series.characterHints), forKey: "characterHintsData")
        object.setValue(series.arcSummary, forKey: "arcSummary")
        object.setValue(try self.encode(series.relationshipFacts), forKey: "relationshipFactsData")
        object.setValue(try self.encode(series.favoritePlaces), forKey: "favoritePlacesData")
        object.setValue(try self.encode(series.unresolvedThreads), forKey: "unresolvedThreadsData")
        object.setValue(series.createdAt, forKey: "createdAt")
        object.setValue(series.updatedAt, forKey: "updatedAt")
        object.setValue(libraryPosition, forKey: "libraryPosition")
        return object
    }

    private func insertEpisode(
        _ episode: StoryEpisode,
        seriesId: UUID,
        storyIndex: Int32,
        in context: NSManagedObjectContext
    ) throws {
        let object = NSEntityDescription.insertNewObject(forEntityName: EntityName.episode, into: context)
        try self.writeEpisode(episode, seriesId: seriesId, storyIndex: storyIndex, to: object)
    }

    private func writeEpisode(
        _ episode: StoryEpisode,
        seriesId: UUID,
        storyIndex: Int32,
        to object: NSManagedObject
    ) throws {
        object.setValue(episode.id, forKey: "id")
        object.setValue(seriesId, forKey: "seriesId")
        object.setValue(episode.storyId, forKey: "storyId")
        object.setValue(episode.title, forKey: "title")
        object.setValue(try self.encode(episode.scenes), forKey: "scenesData")
        object.setValue(try self.encode(episode.engine), forKey: "engineData")
        object.setValue(Int32(episode.estimatedDurationSec), forKey: "estimatedDurationSec")
        object.setValue(storyIndex, forKey: "storyIndex")
        object.setValue(episode.createdAt, forKey: "createdAt")
    }

    private func updateLibraryPositions(for orderedSeriesIDs: [UUID], in context: NSManagedObjectContext) throws {
        guard orderedSeriesIDs.isEmpty == false else { return }

        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.series)
        let objects = try context.fetch(request)
        let positions = Dictionary(uniqueKeysWithValues: orderedSeriesIDs.enumerated().map { ($1, Int32($0)) })

        for object in objects {
            guard let id = object.value(forKey: "id") as? UUID,
                  let position = positions[id] else {
                continue
            }
            object.setValue(position, forKey: "libraryPosition")
        }
    }

    private func clearSnapshotRows(in context: NSManagedObjectContext) throws {
        try deleteRows(entityName: EntityName.episode, in: context)
        try deleteRows(entityName: EntityName.series, in: context)
        try deleteRows(entityName: EntityName.profile, in: context)
        try deleteRows(entityName: EntityName.settings, in: context)
    }

    private func clearStoryRows(in context: NSManagedObjectContext) throws {
        try deleteRows(entityName: EntityName.episode, in: context)
        try deleteRows(entityName: EntityName.series, in: context)
    }

    private func clearContinuityRows(in context: NSManagedObjectContext) throws {
        try deleteRows(entityName: EntityName.continuity, in: context)
    }

    private func clearAllRows(in context: NSManagedObjectContext) throws {
        for entityName in [EntityName.episode, EntityName.series, EntityName.profile, EntityName.settings, EntityName.continuity, EntityName.migrationLog] {
            try deleteRows(entityName: entityName, in: context)
        }
        try saveContext(context)
    }

    private func deleteRows(entityName: String, in context: NSManagedObjectContext) throws {
        try deleteRows(entityName: entityName, predicate: nil, in: context)
    }

    private func deleteRows(entityName: String, predicate: NSPredicate?, in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        request.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        try context.execute(deleteRequest)
    }

    private func deleteEpisodes(forSeriesID seriesID: UUID, in context: NSManagedObjectContext) throws {
        try deleteRows(
            entityName: EntityName.episode,
            predicate: NSPredicate(format: "seriesId == %@", seriesID as CVarArg),
            in: context
        )
    }

    private func deleteSeriesRow(id: UUID, in context: NSManagedObjectContext) throws {
        try deleteRows(
            entityName: EntityName.series,
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            in: context
        )
    }

    private func replaceAllSeries(_ series: [StorySeries], in context: NSManagedObjectContext) throws {
        try clearStoryRows(in: context)
        for (libraryPosition, currentSeries) in series.enumerated() {
            _ = try upsertSeriesObject(for: currentSeries, libraryPosition: Int32(libraryPosition), in: context)
            for (storyIndex, episode) in currentSeries.episodes.enumerated() {
                try insertEpisode(episode, seriesId: currentSeries.id, storyIndex: Int32(storyIndex), in: context)
            }
        }
        try saveContext(context)
    }

    private func insertMigration(version: Int, notes: String, in context: NSManagedObjectContext) {
        let migration = NSEntityDescription.insertNewObject(forEntityName: EntityName.migrationLog, into: context)
        migration.setValue(UUID(), forKey: "id")
        migration.setValue(Int16(version), forKey: "toVersion")
        migration.setValue(Date(), forKey: "appliedAt")
        migration.setValue(notes, forKey: "notes")
    }

    private func saveContext(_ context: NSManagedObjectContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }

    private func writeSettings(
        activeChildProfileId: UUID?,
        privacySettings: ParentPrivacySettings,
        to settings: NSManagedObject
    ) {
        if settings.value(forKey: "id") as? UUID == nil {
            settings.setValue(UUID(), forKey: "id")
        }
        settings.setValue(activeChildProfileId, forKey: "activeChildProfileId")
        settings.setValue(privacySettings.saveStoryHistory, forKey: "saveStoryHistory")
        settings.setValue(privacySettings.retentionPolicy.rawValue, forKey: "retentionPolicy")
        settings.setValue(privacySettings.saveRawAudio, forKey: "saveRawAudio")
        settings.setValue(privacySettings.clearTranscriptsAfterSession, forKey: "clearTranscriptsAfterSession")
        settings.setValue(Date(), forKey: "updatedAt")
    }

    private func encode<T: Encodable>(_ value: T?) throws -> Data? {
        guard let value else { return nil }
        return try encoder.encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private static func makeContainer(storeURL: URL) -> NSPersistentContainer {
        ensureDirectoryExists(for: storeURL)

        let model = managedObjectModel()
        let container = NSPersistentContainer(name: "StoryLibraryV2", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError {
            print("Failed to load StoryLibrary v2 persistent store at \(storeURL.path): \(loadError)")
            let fallbackContainer = NSPersistentContainer(name: "StoryLibraryV2Fallback", managedObjectModel: model)
            let fallbackDescription = NSPersistentStoreDescription()
            fallbackDescription.type = NSInMemoryStoreType
            fallbackDescription.shouldAddStoreAsynchronously = false
            fallbackContainer.persistentStoreDescriptions = [fallbackDescription]
            fallbackContainer.loadPersistentStores { _, error in
                if let error {
                    print("Failed to load in-memory StoryLibrary v2 fallback store: \(error)")
                }
            }
            fallbackContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            fallbackContainer.viewContext.automaticallyMergesChangesFromParent = true
            return fallbackContainer
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }

    private static func ensureDirectoryExists(for storeURL: URL) {
        let directory = storeURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func withContext<T>(_ work: @escaping (NSManagedObjectContext) throws -> T) throws -> T {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true

        var result: Result<T, Error>!
        context.performAndWait {
            result = Result {
                try work(context)
            }
        }
        return try result.get()
    }

    private static func managedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let settings = NSEntityDescription()
        settings.name = EntityName.settings
        settings.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        settings.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "activeChildProfileId", type: .UUIDAttributeType, isOptional: true),
            attribute(name: "saveStoryHistory", type: .booleanAttributeType, defaultValue: true),
            attribute(name: "retentionPolicy", type: .stringAttributeType, defaultValue: StoryRetentionPolicy.ninetyDays.rawValue),
            attribute(name: "saveRawAudio", type: .booleanAttributeType, defaultValue: false),
            attribute(name: "clearTranscriptsAfterSession", type: .booleanAttributeType, defaultValue: true),
            attribute(name: "updatedAt", type: .dateAttributeType)
        ]

        let profile = NSEntityDescription()
        profile.name = EntityName.profile
        profile.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        profile.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "displayName", type: .stringAttributeType),
            attribute(name: "age", type: .integer16AttributeType),
            attribute(name: "contentSensitivity", type: .stringAttributeType),
            attribute(name: "preferredMode", type: .stringAttributeType),
            attribute(name: "updatedAt", type: .dateAttributeType)
        ]

        let series = NSEntityDescription()
        series.name = EntityName.series
        series.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        series.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "childProfileId", type: .UUIDAttributeType, isOptional: true),
            attribute(name: "title", type: .stringAttributeType),
            attribute(name: "characterHintsData", type: .binaryDataAttributeType, isOptional: true),
            attribute(name: "relationshipFactsData", type: .binaryDataAttributeType, isOptional: true),
            attribute(name: "favoritePlacesData", type: .binaryDataAttributeType, isOptional: true),
            attribute(name: "unresolvedThreadsData", type: .binaryDataAttributeType, isOptional: true),
            attribute(name: "arcSummary", type: .stringAttributeType, isOptional: true),
            attribute(name: "createdAt", type: .dateAttributeType),
            attribute(name: "updatedAt", type: .dateAttributeType),
            attribute(name: "libraryPosition", type: .integer32AttributeType, defaultValue: 0)
        ]

        let episode = NSEntityDescription()
        episode.name = EntityName.episode
        episode.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        episode.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "seriesId", type: .UUIDAttributeType),
            attribute(name: "storyId", type: .stringAttributeType),
            attribute(name: "title", type: .stringAttributeType),
            attribute(name: "scenesData", type: .binaryDataAttributeType),
            attribute(name: "engineData", type: .binaryDataAttributeType, isOptional: true),
            attribute(name: "estimatedDurationSec", type: .integer32AttributeType, defaultValue: 0),
            attribute(name: "storyIndex", type: .integer32AttributeType, defaultValue: 0),
            attribute(name: "createdAt", type: .dateAttributeType)
        ]

        let continuity = NSEntityDescription()
        continuity.name = EntityName.continuity
        continuity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        continuity.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "seriesId", type: .UUIDAttributeType),
            attribute(name: "storyId", type: .stringAttributeType),
            attribute(name: "text", type: .stringAttributeType),
            attribute(name: "embeddingData", type: .binaryDataAttributeType),
            attribute(name: "updatedAt", type: .dateAttributeType)
        ]

        let migrationLog = NSEntityDescription()
        migrationLog.name = EntityName.migrationLog
        migrationLog.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        migrationLog.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "toVersion", type: .integer16AttributeType),
            attribute(name: "appliedAt", type: .dateAttributeType),
            attribute(name: "notes", type: .stringAttributeType, isOptional: true)
        ]

        model.entities = [settings, profile, series, episode, continuity, migrationLog]
        return model
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        isOptional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        attribute.defaultValue = defaultValue
        return attribute
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
    private let continuitySyncOwnerID = UUID()
    private let userDefaults: UserDefaults
    private let v2Storage: StoryLibraryV2Storage
    private var continuitySyncVersion = 0

    init(
        userDefaults: UserDefaults = .standard,
        storageURL: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.v2Storage = StoryLibraryV2Storage(storageURL: storageURL)
        migrateLegacyDataIfNeeded()
        loadPersistedStore()
        ensureActiveProfile()
        applyRetentionPolicy()
    }

    var activeProfile: ChildProfile? {
        profileById(activeChildProfileId) ?? childProfiles.first
    }

    var canAddMoreProfiles: Bool {
        canAddMoreProfiles(maxProfiles: storyLibraryDefaultMaxChildProfiles)
    }

    func canAddMoreProfiles(maxProfiles: Int) -> Bool {
        childProfiles.count < max(1, maxProfiles)
    }

    var visibleSeries: [StorySeries] {
        visibleSeries(for: activeChildProfileId)
    }

    func visibleSeries(for childProfileId: UUID?) -> [StorySeries] {
        guard let childProfileId else {
            return series
        }

        return series.filter { $0.childProfileId == nil || $0.childProfileId == childProfileId }
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
        persistStore()
    }

    func addChildProfile(
        name: String,
        age: Int,
        sensitivity: ContentSensitivity,
        preferredMode: StoryExperienceMode,
        maxProfiles: Int = storyLibraryDefaultMaxChildProfiles
    ) {
        guard canAddMoreProfiles(maxProfiles: maxProfiles) else { return }

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
            persistStore()
        }
        persistStore()
    }

    func updateChildProfile(_ profile: ChildProfile) {
        guard let index = childProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        childProfiles[index] = profile
        childProfiles.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        persistStore()
    }

    func deleteChildProfile(_ id: UUID) {
        guard childProfiles.contains(where: { $0.id == id }) else { return }

        let removedSeriesIds = Set(series.lazy.filter { $0.childProfileId == id }.map(\.id))
        let remainingProfiles = childProfiles.filter { $0.id != id }

        if remainingProfiles.isEmpty {
            let fallback = Self.defaultProfiles()
            childProfiles = fallback
            activeChildProfileId = fallback.first?.id
        } else {
            childProfiles = remainingProfiles
            if activeChildProfileId == id {
                activeChildProfileId = remainingProfiles.first?.id
            }
        }

        series.removeAll { $0.childProfileId == id }
        persistStore()

        let orderedRemovedSeriesIds = removedSeriesIds.sorted { $0.uuidString < $1.uuidString }
        Task {
            for seriesId in orderedRemovedSeriesIds {
                await ContinuityMemoryStore.shared.clearSeries(seriesId)
            }
        }
    }

    func setSaveStoryHistory(_ enabled: Bool) {
        privacySettings.saveStoryHistory = enabled
        applyRetentionPolicy()
        v2Storage.saveSettings(activeChildProfileId: activeChildProfileId, privacySettings: privacySettings)
    }

    func setRetentionPolicy(_ policy: StoryRetentionPolicy) {
        privacySettings.retentionPolicy = policy
        applyRetentionPolicy()
        v2Storage.saveSettings(activeChildProfileId: activeChildProfileId, privacySettings: privacySettings)
    }

    func setClearTranscriptsAfterSession(_ enabled: Bool) {
        privacySettings.clearTranscriptsAfterSession = enabled
        persistStore()
    }

    func addStory(_ story: StoryData, characters: [String], plan: StoryLaunchPlan) -> UUID? {
        guard privacySettings.saveStoryHistory else { return nil }
        applyRetentionPolicy(syncContinuity: false)

        let persistedSeriesId: UUID?
        switch plan.mode {
        case .new:
            if plan.usePastStory, let selectedId = plan.selectedSeriesId {
                _ = appendEpisode(story, to: selectedId, childProfileId: plan.childProfileId)
                persistedSeriesId = selectedId
            } else {
                persistedSeriesId = createNewSeries(story, characters: characters, childProfileId: plan.childProfileId)
            }
        case .extend(let existingSeriesId):
            persistedSeriesId = appendEpisode(story, to: existingSeriesId, childProfileId: plan.childProfileId)
        case .repeatEpisode:
            persistedSeriesId = nil
        }

        syncContinuityMemoryWithLibrary()
        return persistedSeriesId
    }

    private func createNewSeries(_ story: StoryData, characters: [String], childProfileId: UUID) -> UUID {
        let now = Date()
        let resolvedCharacters = characters.isEmpty
            ? (story.engine?.characterBible.map(\.name) ?? [])
            : characters
        let episode = StoryEpisode(
            id: UUID(),
            title: story.title,
            storyId: story.storyId,
            scenes: story.scenes,
            estimatedDurationSec: story.estimatedDurationSec,
            engine: story.engine,
            createdAt: now
        )

        var created = StorySeries(
            id: UUID(),
            childProfileId: childProfileId,
            title: story.title,
            characterHints: resolvedCharacters,
            arcSummary: nil,
            relationshipFacts: nil,
            favoritePlaces: nil,
            unresolvedThreads: nil,
            episodes: [episode],
            createdAt: now,
            updatedAt: now
        )
        applyContinuityMetadata(to: &created)

        series.insert(created, at: 0)
        v2Storage.insertSeries(created, orderedSeries: series)
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
        rebuildContinuityMetadata(at: index)

        let moved = series.remove(at: index)
        series.insert(moved, at: 0)
        v2Storage.appendEpisode(episode, to: moved, orderedSeries: series)
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
            rebuildContinuityMetadata(at: seriesIndex)
            series[seriesIndex].updatedAt = Date()
            v2Storage.replaceEpisode(storyId: story.storyId, in: series[seriesIndex], orderedSeries: series)
            return series[seriesIndex].id
        }
        return nil
    }

    func deleteSeries(_ id: UUID) {
        series.removeAll { $0.id == id }
        v2Storage.deleteSeries(id, orderedSeriesIDs: series.map(\.id))
        Task {
            await ContinuityMemoryStore.shared.clearSeries(id)
        }
    }

    func clearStoryHistory() {
        series = []
        v2Storage.clearStoryHistory()
        Task {
            await ContinuityMemoryStore.shared.clearAll()
        }
    }

    private func rebuildContinuityMetadata(at seriesIndex: Int) {
        guard series.indices.contains(seriesIndex) else { return }
        applyContinuityMetadata(to: &series[seriesIndex])
    }

    private func applyContinuityMetadata(to series: inout StorySeries) {
        let metadata = continuityMetadata(for: series.episodes)
        guard metadata.hasSeriesMemory else { return }
        series.arcSummary = metadata.arcSummary
        series.relationshipFacts = metadata.relationshipFacts
        series.favoritePlaces = metadata.favoritePlaces
        series.unresolvedThreads = metadata.unresolvedThreads
    }

    private func continuityMetadata(for episodes: [StoryEpisode]) -> (
        hasSeriesMemory: Bool,
        arcSummary: String?,
        relationshipFacts: [String]?,
        favoritePlaces: [String]?,
        unresolvedThreads: [String]?
    ) {
        var hasSeriesMemory = false
        var arcSummary: String?
        var relationshipFacts = Set<String>()
        var favoritePlaces = Set<String>()
        var unresolvedThreads = Set<String>()

        for episode in episodes {
            guard let memory = episode.engine?.seriesMemory else { continue }
            hasSeriesMemory = true

            if let candidateArcSummary = normalizedContinuityString(memory.arcSummary) {
                arcSummary = candidateArcSummary
            }

            relationshipFacts.formUnion(normalizedContinuityValues(memory.relationshipFacts))
            favoritePlaces.formUnion(normalizedContinuityValues(memory.favoritePlaces))
            unresolvedThreads.formUnion(normalizedContinuityValues(memory.openLoops))
        }

        return (
            hasSeriesMemory,
            arcSummary,
            normalizedContinuitySet(relationshipFacts),
            normalizedContinuitySet(favoritePlaces),
            normalizedContinuitySet(unresolvedThreads)
        )
    }

    private func normalizedContinuityString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedContinuityValues(_ values: [String]) -> [String] {
        values.compactMap(normalizedContinuityString)
    }

    private func normalizedContinuitySet(_ values: Set<String>) -> [String]? {
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        return normalized.isEmpty ? nil : normalized
    }

    private func applyRetentionPolicy(syncContinuity: Bool = true) {
        guard privacySettings.saveStoryHistory else {
            if !series.isEmpty {
                series = []
                v2Storage.clearStoryHistory()
            }
            if syncContinuity {
                Task {
                    await ContinuityMemoryStore.shared.clearAll()
                }
            }
            return
        }

        guard let days = privacySettings.retentionPolicy.dayCount,
              let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            if syncContinuity {
                syncContinuityMemoryWithLibrary()
            }
            return
        }

        let pruned = series.compactMap { current -> StorySeries? in
            var copy = current
            copy.episodes = current.episodes.filter { $0.createdAt >= cutoffDate }
            guard !copy.episodes.isEmpty else { return nil }
            applyContinuityMetadata(to: &copy)
            copy.updatedAt = copy.episodes.map(\.createdAt).max() ?? current.updatedAt
            return copy
        }

        if pruned != series {
            series = pruned
            v2Storage.applyRetentionPrune(pruned)
        }
        if syncContinuity {
            syncContinuityMemoryWithLibrary()
        }
    }

    private func syncContinuityMemoryWithLibrary() {
        let ownerID = continuitySyncOwnerID
        continuitySyncVersion += 1
        let version = continuitySyncVersion
        let v2Storage = v2Storage
        Task {
            let snapshotSeries = v2Storage.loadSnapshot()?.series ?? []
            let allowedStoryReferences = Set(snapshotSeries.flatMap { currentSeries in
                currentSeries.episodes.map { episode in
                    ContinuityStoryReference(seriesId: currentSeries.id, storyId: episode.storyId)
                }
            })
            await ContinuityMemoryStore.shared.prune(
                toStoryReferences: allowedStoryReferences,
                ownerID: ownerID,
                version: version
            )
        }
    }

    private func ensureActiveProfile() {
        if activeProfile == nil {
            activeChildProfileId = childProfiles.first?.id
            persistStore()
        }
    }

    private func persistStore() {
        let snapshot = StoryLibraryV2Snapshot(
            migrationVersion: StoryLibraryV2Snapshot.currentMigrationVersion,
            series: series,
            childProfiles: childProfiles,
            activeChildProfileId: activeChildProfileId,
            privacySettings: privacySettings
        )
        v2Storage.saveSnapshot(snapshot)
    }

    private func migrateLegacyDataIfNeeded() {
        let persistedVersion = v2Storage.migrationVersion()
        let persistedSnapshot = v2Storage.loadSnapshot()

        if persistedSnapshot == nil {
            performLegacyMigration()
            return
        }

        if persistedVersion > StoryLibraryV2Snapshot.currentMigrationVersion {
            v2Storage.clear()
            performLegacyMigration()
            return
        }

        guard persistedVersion < StoryLibraryV2Snapshot.currentMigrationVersion else {
            return
        }

        guard let snapshot = persistedSnapshot else {
            performLegacyMigration()
            return
        }

        v2Storage.saveSnapshot(
            StoryLibraryV2Snapshot(
                migrationVersion: StoryLibraryV2Snapshot.currentMigrationVersion,
                series: snapshot.series,
                childProfiles: snapshot.childProfiles,
                activeChildProfileId: snapshot.activeChildProfileId,
                privacySettings: snapshot.privacySettings
            )
        )
    }

    private func performLegacyMigration() {
        let migratedProfiles = loadLegacyProfiles()
        var migratedActiveProfileId = loadLegacyActiveProfile()
        if !migratedProfiles.contains(where: { $0.id == migratedActiveProfileId }) {
            migratedActiveProfileId = migratedProfiles.first?.id
        }
        let snapshot = StoryLibraryV2Snapshot(
            migrationVersion: StoryLibraryV2Snapshot.currentMigrationVersion,
            series: loadLegacySeries(),
            childProfiles: migratedProfiles,
            activeChildProfileId: migratedActiveProfileId,
            privacySettings: loadLegacyPrivacySettings()
        )
        v2Storage.saveSnapshot(snapshot)
    }

    private func loadPersistedStore() {
        guard let snapshot = v2Storage.loadSnapshot() else {
            series = []
            childProfiles = Self.defaultProfiles()
            privacySettings = .default
            return
        }
        series = snapshot.series
        childProfiles = snapshot.childProfiles
        activeChildProfileId = snapshot.activeChildProfileId
        privacySettings = snapshot.privacySettings
    }

    private func loadLegacySeries() -> [StorySeries] {
        guard let data = userDefaults.data(forKey: seriesStorageKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([StorySeries].self, from: data)
        } catch {
            return []
        }
    }

    private func loadLegacyProfiles() -> [ChildProfile] {
        guard let data = userDefaults.data(forKey: profilesStorageKey) else {
            return Self.defaultProfiles()
        }

        do {
            let decoded = try JSONDecoder().decode([ChildProfile].self, from: data)
            return decoded.isEmpty ? Self.defaultProfiles() : decoded
        } catch {
            return Self.defaultProfiles()
        }
    }

    private func loadLegacyActiveProfile() -> UUID? {
        guard let activeId = userDefaults.string(forKey: activeProfileStorageKey),
              let parsed = UUID(uuidString: activeId) else {
            return nil
        }
        return parsed
    }

    private func loadLegacyPrivacySettings() -> ParentPrivacySettings {
        guard let data = userDefaults.data(forKey: privacyStorageKey) else {
            return .default
        }

        do {
            return try JSONDecoder().decode(ParentPrivacySettings.self, from: data)
        } catch {
            return .default
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

    private static let continuityMigrationNote = "Continuity legacy import complete"
    private static let legacyStorageKey = "storytime.continuity.memory.v1"
    private var facts: [ContinuityFactRecord]
    private var latestPruneVersionByOwner: [UUID: Int] = [:]
    private let v2Storage: StoryLibraryV2Storage

    init(userDefaults: UserDefaults = .standard, storageURL: URL? = nil) {
        let storage = StoryLibraryV2Storage(storageURL: storageURL)
        let migrationComplete = storage.hasMigrationNote(Self.continuityMigrationNote)
        let persistedFacts = storage.loadContinuityFacts()

        let initialFacts: [ContinuityFactRecord]
        let shouldRecordMigration: Bool

        if migrationComplete {
            if let persistedFacts {
                initialFacts = persistedFacts
            } else {
                let recoveredFacts = Self.loadLegacyFacts(from: userDefaults, key: Self.legacyStorageKey)
                storage.replaceContinuityFacts(recoveredFacts)
                initialFacts = recoveredFacts
            }
            shouldRecordMigration = false
        } else if let persistedFacts, persistedFacts.isEmpty == false {
            initialFacts = persistedFacts
            shouldRecordMigration = true
        } else {
            let recoveredFacts = Self.loadLegacyFacts(from: userDefaults, key: Self.legacyStorageKey)
            storage.replaceContinuityFacts(recoveredFacts)
            initialFacts = recoveredFacts
            shouldRecordMigration = true
        }

        self.v2Storage = storage
        self.facts = initialFacts

        if shouldRecordMigration {
            storage.recordMigration(
                version: StoryLibraryV2Snapshot.currentMigrationVersion,
                notes: Self.continuityMigrationNote
            )
        }
        userDefaults.removeObject(forKey: Self.legacyStorageKey)
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

    func factRecords(seriesId: UUID? = nil, storyId: String? = nil) -> [ContinuityFactRecord] {
        facts
            .filter { record in
                (seriesId == nil || record.seriesId == seriesId) &&
                (storyId == nil || record.storyId == storyId)
            }
            .sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt < $1.updatedAt
                }
                if $0.seriesId != $1.seriesId {
                    return $0.seriesId.uuidString < $1.seriesId.uuidString
                }
                if $0.storyId != $1.storyId {
                    return $0.storyId < $1.storyId
                }
                return $0.text < $1.text
            }
    }

    func clearSeries(_ seriesId: UUID) {
        facts.removeAll { $0.seriesId == seriesId }
        persist()
    }

    func clearAll() {
        facts = []
        persist()
    }

    func prune(toStoryReferences storyReferences: Set<ContinuityStoryReference>) {
        facts.removeAll {
            !storyReferences.contains(ContinuityStoryReference(seriesId: $0.seriesId, storyId: $0.storyId))
        }
        persist()
    }

    func prune(toStoryReferences storyReferences: Set<ContinuityStoryReference>, ownerID: UUID, version: Int) {
        let latestVersion = latestPruneVersionByOwner[ownerID] ?? 0
        guard version >= latestVersion else { return }
        latestPruneVersionByOwner[ownerID] = version
        facts.removeAll {
            !storyReferences.contains(ContinuityStoryReference(seriesId: $0.seriesId, storyId: $0.storyId))
        }
        persist()
    }

    private func persist() {
        v2Storage.replaceContinuityFacts(facts)
    }

    private static func loadLegacyFacts(from userDefaults: UserDefaults, key: String) -> [ContinuityFactRecord] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ContinuityFactRecord].self, from: data) else {
            return []
        }
        return decoded
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
