import Foundation

struct StoryBrief: Codable {
    let theme: String
    let characters: [String]
    let setting: String
    let tone: String
    let episodeIntent: String?
    let lesson: String?

    enum CodingKeys: String, CodingKey {
        case theme
        case characters
        case setting
        case tone
        case episodeIntent = "episode_intent"
        case lesson
    }
}

struct GenerateStoryRequest: Encodable {
    let childProfileId: String
    let ageBand: String
    let language: String
    let lengthMinutes: Int
    let voice: String
    let questionCount: Int
    let storyBrief: StoryBrief
    let continuityFacts: [String]

    enum CodingKeys: String, CodingKey {
        case childProfileId = "child_profile_id"
        case ageBand = "age_band"
        case language
        case lengthMinutes = "length_minutes"
        case voice
        case questionCount = "question_count"
        case storyBrief = "story_brief"
        case continuityFacts = "continuity_facts"
    }
}

struct StoryScene: Codable, Identifiable, Hashable {
    let sceneId: String
    let text: String
    let durationSec: Int

    enum CodingKeys: String, CodingKey {
        case sceneId = "scene_id"
        case text
        case durationSec = "duration_sec"
    }

    var id: String { sceneId }
}

struct StoryEngineCharacter: Codable, Hashable {
    let name: String
    let role: String
    let traits: [String]
}

struct StorySeriesMemoryData: Codable, Hashable {
    let title: String?
    let recurringCharacters: [String]
    let priorEpisodeRecap: String?
    let worldFacts: [String]
    let openLoops: [String]
    let favoritePlaces: [String]
    let relationshipFacts: [String]
    let arcSummary: String?
    let nextEpisodeHook: String?

    enum CodingKeys: String, CodingKey {
        case title
        case recurringCharacters = "recurring_characters"
        case priorEpisodeRecap = "prior_episode_recap"
        case worldFacts = "world_facts"
        case openLoops = "open_loops"
        case favoritePlaces = "favorite_places"
        case relationshipFacts = "relationship_facts"
        case arcSummary = "arc_summary"
        case nextEpisodeHook = "next_episode_hook"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        recurringCharacters = try container.decodeIfPresent([String].self, forKey: .recurringCharacters) ?? []
        priorEpisodeRecap = try container.decodeIfPresent(String.self, forKey: .priorEpisodeRecap)
        worldFacts = try container.decodeIfPresent([String].self, forKey: .worldFacts) ?? []
        openLoops = try container.decodeIfPresent([String].self, forKey: .openLoops) ?? []
        favoritePlaces = try container.decodeIfPresent([String].self, forKey: .favoritePlaces) ?? []
        relationshipFacts = try container.decodeIfPresent([String].self, forKey: .relationshipFacts) ?? []
        arcSummary = try container.decodeIfPresent(String.self, forKey: .arcSummary)
        nextEpisodeHook = try container.decodeIfPresent(String.self, forKey: .nextEpisodeHook)
    }
}

struct StoryBeatData: Codable, Hashable {
    let beatId: String
    let sceneIndex: Int
    let label: String
    let purpose: String
    let targetDurationSec: Int

    enum CodingKeys: String, CodingKey {
        case beatId = "beat_id"
        case sceneIndex = "scene_index"
        case label
        case purpose
        case targetDurationSec = "target_duration_sec"
    }
}

struct StoryQualityData: Codable, Hashable {
    let passed: Bool
    let issues: [String]
    let totalDurationSec: Int
    let targetDurationSec: Int
    let repeatedPhraseCount: Int

    enum CodingKeys: String, CodingKey {
        case passed
        case issues
        case totalDurationSec = "total_duration_sec"
        case targetDurationSec = "target_duration_sec"
        case repeatedPhraseCount = "repeated_phrase_count"
    }
}

struct StoryEngineData: Codable, Hashable {
    let episodeRecap: String?
    let seriesMemory: StorySeriesMemoryData
    let characterBible: [StoryEngineCharacter]
    let beatPlan: [StoryBeatData]
    let continuityFacts: [String]
    let quality: StoryQualityData?

    enum CodingKeys: String, CodingKey {
        case episodeRecap = "episode_recap"
        case seriesMemory = "series_memory"
        case characterBible = "character_bible"
        case beatPlan = "beat_plan"
        case continuityFacts = "continuity_facts"
        case quality
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodeRecap = try container.decodeIfPresent(String.self, forKey: .episodeRecap)
        seriesMemory = try container.decode(StorySeriesMemoryData.self, forKey: .seriesMemory)
        characterBible = try container.decodeIfPresent([StoryEngineCharacter].self, forKey: .characterBible) ?? []
        beatPlan = try container.decodeIfPresent([StoryBeatData].self, forKey: .beatPlan) ?? []
        continuityFacts = try container.decodeIfPresent([String].self, forKey: .continuityFacts) ?? []
        quality = try container.decodeIfPresent(StoryQualityData.self, forKey: .quality)
    }
}

struct StorySafety: Codable, Hashable {
    let inputModeration: String
    let outputModeration: String

    enum CodingKeys: String, CodingKey {
        case inputModeration = "input_moderation"
        case outputModeration = "output_moderation"
    }
}

struct StoryData: Codable, Hashable {
    let storyId: String
    let title: String
    let estimatedDurationSec: Int
    let scenes: [StoryScene]
    let safety: StorySafety
    let engine: StoryEngineData?

    enum CodingKeys: String, CodingKey {
        case storyId = "story_id"
        case title
        case estimatedDurationSec = "estimated_duration_sec"
        case scenes
        case safety
        case engine
    }
}

struct GenerateStoryEnvelope: Codable, Hashable {
    let blocked: Bool
    let safeMessage: String?
    let data: StoryData

    enum CodingKeys: String, CodingKey {
        case blocked
        case safeMessage = "safe_message"
        case data
    }
}

struct ReviseStoryRequest: Encodable {
    let storyId: String
    let currentSceneIndex: Int
    let storyTitle: String?
    let userUpdate: String
    let completedScenes: [StoryScene]
    let remainingScenes: [StoryScene]

    enum CodingKeys: String, CodingKey {
        case storyId = "story_id"
        case currentSceneIndex = "current_scene_index"
        case storyTitle = "story_title"
        case userUpdate = "user_update"
        case completedScenes = "completed_scenes"
        case remainingScenes = "remaining_scenes"
    }
}

struct RevisedStoryData: Codable, Hashable {
    let storyId: String
    let revisedFromSceneIndex: Int
    let scenes: [StoryScene]
    let safety: StorySafety
    let engine: StoryEngineData?

    enum CodingKeys: String, CodingKey {
        case storyId = "story_id"
        case revisedFromSceneIndex = "revised_from_scene_index"
        case scenes
        case safety
        case engine
    }
}

struct ReviseStoryEnvelope: Codable, Hashable {
    let blocked: Bool
    let safeMessage: String?
    let data: RevisedStoryData

    enum CodingKeys: String, CodingKey {
        case blocked
        case safeMessage = "safe_message"
        case data
    }
}

struct RealtimeSessionRequest: Encodable {
    let childProfileId: String
    let voice: String
    let region: String

    enum CodingKeys: String, CodingKey {
        case childProfileId = "child_profile_id"
        case voice
        case region
    }
}

struct RealtimeSessionData: Codable, Hashable {
    let ticket: String
    let expiresAt: Int
    let model: String
    let voice: String
    let inputAudioTranscriptionModel: String

    enum CodingKeys: String, CodingKey {
        case ticket
        case expiresAt = "expires_at"
        case model
        case voice
        case inputAudioTranscriptionModel = "input_audio_transcription_model"
    }
}

struct RealtimeSessionEnvelope: Codable, Hashable {
    let session: RealtimeSessionData
    let transport: String
    let endpoint: String
}

struct DiscoverySlotState: Codable, Hashable {
    var theme: String?
    var characters: [String]
    var setting: String?
    var tone: String?
    var episodeIntent: String?

    init(
        theme: String? = nil,
        characters: [String] = [],
        setting: String? = nil,
        tone: String? = nil,
        episodeIntent: String? = nil
    ) {
        self.theme = theme
        self.characters = characters
        self.setting = setting
        self.tone = tone
        self.episodeIntent = episodeIntent
    }

    enum CodingKeys: String, CodingKey {
        case theme
        case characters
        case setting
        case tone
        case episodeIntent = "episode_intent"
    }
}

struct DiscoveryRequest: Encodable {
    let childProfileId: String
    let transcript: String
    let questionCount: Int
    let slotState: DiscoverySlotState
    let mode: String
    let previousEpisodeRecap: String?

    enum CodingKeys: String, CodingKey {
        case childProfileId = "child_profile_id"
        case transcript
        case questionCount = "question_count"
        case slotState = "slot_state"
        case mode
        case previousEpisodeRecap = "previous_episode_recap"
    }
}

struct DiscoveryData: Codable, Hashable {
    let slotState: DiscoverySlotState
    let questionCount: Int
    let readyToGenerate: Bool
    let assistantMessage: String
    let transcript: String

    enum CodingKeys: String, CodingKey {
        case slotState = "slot_state"
        case questionCount = "question_count"
        case readyToGenerate = "ready_to_generate"
        case assistantMessage = "assistant_message"
        case transcript
    }
}

struct DiscoveryEnvelope: Codable, Hashable {
    let blocked: Bool
    let safeMessage: String?
    let data: DiscoveryData

    enum CodingKeys: String, CodingKey {
        case blocked
        case safeMessage = "safe_message"
        case data
    }
}

struct EmbeddingsCreateRequest: Encodable {
    let inputs: [String]
}

struct EmbeddingsCreateResponse: Codable, Hashable {
    let embeddings: [[Double]]
}
