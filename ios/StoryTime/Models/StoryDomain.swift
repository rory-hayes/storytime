import Foundation

enum ContentSensitivity: String, Codable, CaseIterable, Identifiable {
    case standard
    case extraGentle
    case mostGentle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .extraGentle:
            return "Extra Gentle"
        case .mostGentle:
            return "Most Gentle"
        }
    }

    var generationDirective: String {
        switch self {
        case .standard:
            return "Keep the story child-safe, warm, and low-stress."
        case .extraGentle:
            return "Keep the story extra gentle, with very light conflict and quick reassurance."
        case .mostGentle:
            return "Keep the story deeply calming with no suspense, no peril, and soft reassuring language."
        }
    }
}

enum StoryExperienceMode: String, Codable, CaseIterable, Identifiable {
    case classic
    case bedtime
    case calm
    case educational

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return "Classic"
        case .bedtime:
            return "Bedtime"
        case .calm:
            return "Calm"
        case .educational:
            return "Educational"
        }
    }

    var toneDirective: String {
        switch self {
        case .classic:
            return "gentle and playful"
        case .bedtime:
            return "sleepy, cozy, and reassuring"
        case .calm:
            return "soft, peaceful, and low-energy"
        case .educational:
            return "curious, encouraging, and learning-focused"
        }
    }

    var lessonDirective: String {
        switch self {
        case .classic:
            return "kindness and teamwork"
        case .bedtime:
            return "feeling safe, calm, and ready for rest"
        case .calm:
            return "patience, breathing, and gentle problem-solving"
        case .educational:
            return "learning something simple about the world"
        }
    }

    var summaryLine: String {
        switch self {
        case .classic:
            return "Playful voice-led storytelling"
        case .bedtime:
            return "Quieter pacing for bedtime"
        case .calm:
            return "Low-stimulation and extra soothing"
        case .educational:
            return "Storytelling with light learning moments"
        }
    }
}

enum StoryRetentionPolicy: String, Codable, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sevenDays:
            return "7 days"
        case .thirtyDays:
            return "30 days"
        case .ninetyDays:
            return "90 days"
        case .forever:
            return "Keep until deleted"
        }
    }

    var dayCount: Int? {
        switch self {
        case .sevenDays:
            return 7
        case .thirtyDays:
            return 30
        case .ninetyDays:
            return 90
        case .forever:
            return nil
        }
    }
}

struct ParentPrivacySettings: Codable, Hashable {
    var saveStoryHistory: Bool
    var retentionPolicy: StoryRetentionPolicy
    var saveRawAudio: Bool
    var clearTranscriptsAfterSession: Bool

    static let `default` = ParentPrivacySettings(
        saveStoryHistory: true,
        retentionPolicy: .ninetyDays,
        saveRawAudio: false,
        clearTranscriptsAfterSession: true
    )
}

struct ChildProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var age: Int
    var contentSensitivity: ContentSensitivity
    var preferredMode: StoryExperienceMode
}

enum StoryLaunchMode: Hashable {
    case new
    case extend(seriesId: UUID)
    case repeatEpisode(seriesId: UUID)
}

struct StoryLaunchPlan: Hashable {
    let mode: StoryLaunchMode
    let childProfileId: UUID
    let experienceMode: StoryExperienceMode
    let usePastStory: Bool
    let selectedSeriesId: UUID?
    let usePastCharacters: Bool
    let lengthMinutes: Int
}

struct StoryEpisode: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let storyId: String
    let scenes: [StoryScene]
    let estimatedDurationSec: Int
    let engine: StoryEngineData?
    let createdAt: Date
}

struct StorySeries: Codable, Identifiable, Hashable {
    let id: UUID
    var childProfileId: UUID?
    var title: String
    var characterHints: [String]
    var arcSummary: String?
    var relationshipFacts: [String]?
    var favoritePlaces: [String]?
    var unresolvedThreads: [String]?
    var episodes: [StoryEpisode]
    let createdAt: Date
    var updatedAt: Date

    var episodeCount: Int {
        episodes.count
    }

    var latestEpisode: StoryEpisode? {
        episodes.last
    }
}

enum VoiceSpeaker {
    case idle
    case ai
    case child
}

enum ConversationPhase: String {
    case idle
    case gatheringInput
    case generating
    case narrating
    case revising
    case completed
}
