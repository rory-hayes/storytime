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
    case booting
    case ready
    case discovering
    case generating
    case narrating
    case interrupting
    case revising
    case completed
    case failed
}

struct VoiceSessionReadyState: Equatable {
    enum Mode: Equatable {
        case discovery(stepNumber: Int)
    }

    let mode: Mode
}

extension VoiceSessionReadyState.Mode {
    var logDescription: String {
        switch self {
        case .discovery(let stepNumber):
            return "discovery(stepNumber: \(stepNumber))"
        }
    }
}

enum VoiceSessionState: Equatable {
    case idle
    case booting
    case ready(VoiceSessionReadyState)
    case discovering(turnID: Int)
    case generating
    case narrating(sceneIndex: Int)
    case paused(sceneIndex: Int)
    case interrupting(sceneIndex: Int)
    case revising(sceneIndex: Int, queuedUpdates: Int)
    case completed
    case failed

    var phase: ConversationPhase {
        switch self {
        case .idle:
            return .idle
        case .booting:
            return .booting
        case .ready:
            return .ready
        case .discovering:
            return .discovering
        case .generating:
            return .generating
        case .narrating, .paused:
            return .narrating
        case .interrupting:
            return .interrupting
        case .revising:
            return .revising
        case .completed:
            return .completed
        case .failed:
            return .failed
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        case .idle, .booting, .ready, .discovering, .generating, .narrating, .paused, .interrupting, .revising:
            return false
        }
    }

    var canStartSession: Bool {
        switch self {
        case .idle, .completed, .failed:
            return true
        case .booting, .ready, .discovering, .generating, .narrating, .paused, .interrupting, .revising:
            return false
        }
    }

    var sceneIndex: Int? {
        switch self {
        case .narrating(let sceneIndex), .paused(let sceneIndex), .interrupting(let sceneIndex), .revising(let sceneIndex, _):
            return sceneIndex
        case .idle, .booting, .ready, .discovering, .generating, .completed, .failed:
            return nil
        }
    }

    var logDescription: String {
        switch self {
        case .idle:
            return "idle"
        case .booting:
            return "booting"
        case .ready(let readyState):
            return "ready(mode: \(readyState.mode.logDescription))"
        case .discovering(let turnID):
            return "discovering(turnID: \(turnID))"
        case .generating:
            return "generating"
        case .narrating(let sceneIndex):
            return "narrating(sceneIndex: \(sceneIndex))"
        case .paused(let sceneIndex):
            return "paused(sceneIndex: \(sceneIndex))"
        case .interrupting(let sceneIndex):
            return "interrupting(sceneIndex: \(sceneIndex))"
        case .revising(let sceneIndex, let queuedUpdates):
            return "revising(sceneIndex: \(sceneIndex), queuedUpdates: \(queuedUpdates))"
        case .completed:
            return "completed"
        case .failed:
            return "failed"
        }
    }
}

enum HybridRuntimeMode: Equatable {
    case interaction(HybridInteractionPhase)
    case narration(sceneIndex: Int)

    var usesRealtimeInteraction: Bool {
        switch self {
        case .interaction:
            return true
        case .narration:
            return false
        }
    }

    var usesLongFormTTS: Bool {
        switch self {
        case .interaction:
            return false
        case .narration:
            return true
        }
    }
}

enum HybridInteractionPhase: Equatable {
    case setupFollowUp(stepNumber: Int)
    case interruption(sceneIndex: Int)
    case answerOnly(sceneIndex: Int)
    case reviseFutureScenes(sceneIndex: Int)
    case repeatOrClarify(sceneIndex: Int)
}

enum InterruptionIntent: String, Codable, CaseIterable, Equatable {
    case answerOnly = "answer_only"
    case reviseFutureScenes = "revise_future_scenes"
    case repeatOrClarify = "repeat_or_clarify"

    var mutatesFutureScenes: Bool {
        switch self {
        case .answerOnly, .repeatOrClarify:
            return false
        case .reviseFutureScenes:
            return true
        }
    }
}

struct InterruptionIntentRouteDecision: Equatable {
    let transcript: String
    let intent: InterruptionIntent
    let answerContext: StoryAnswerContext
    let revisionBoundary: StoryRevisionBoundary?

    var canApplyImmediately: Bool {
        switch intent {
        case .answerOnly, .repeatOrClarify:
            return true
        case .reviseFutureScenes:
            return revisionBoundary != nil
        }
    }
}

enum InterruptionIntentRouter {
    static func classify(
        transcript: String,
        sceneState: AuthoritativeStorySceneState
    ) -> InterruptionIntentRouteDecision? {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else { return nil }

        let normalizedTranscript = cleanTranscript.lowercased()
        let intent = classifyIntent(normalizedTranscript)
        let revisionBoundary = intent == .reviseFutureScenes ? sceneState.revisionBoundary : nil

        return InterruptionIntentRouteDecision(
            transcript: cleanTranscript,
            intent: intent,
            answerContext: sceneState.answerContext,
            revisionBoundary: revisionBoundary
        )
    }

    private static func classifyIntent(_ transcript: String) -> InterruptionIntent {
        if containsAnyPhrase(
            transcript,
            phrases: [
                "repeat",
                "say that again",
                "again please",
                "can you repeat",
                "what did you say",
                "i did not hear",
                "i didn't hear",
                "slower",
                "clarify"
            ]
        ) {
            return .repeatOrClarify
        }

        if containsAnyPhrase(
            transcript,
            phrases: [
                "change what happens next",
                "change the ending",
                "add a ",
                "add an ",
                "also add",
                "and add",
                "make the ending",
                "instead",
                "please add",
                "can they",
                "have them",
                "let them",
                "let the",
                "turn the",
                "i want",
                "make it so"
            ]
        ) {
            return .reviseFutureScenes
        }

        return .answerOnly
    }

    private static func containsAnyPhrase(_ transcript: String, phrases: [String]) -> Bool {
        phrases.contains(where: { transcript.contains($0) })
    }
}

enum NarrationResumeDecision: Equatable {
    case replayCurrentScene(sceneIndex: Int)
    case replayCurrentSceneWithRevisedFuture(sceneIndex: Int, revisedFutureStartIndex: Int)
    case continueToNextScene(sceneIndex: Int)

    var sceneIndex: Int {
        switch self {
        case .replayCurrentScene(let sceneIndex),
             .replayCurrentSceneWithRevisedFuture(let sceneIndex, _),
             .continueToNextScene(let sceneIndex):
            return sceneIndex
        }
    }

    var revisedFutureStartIndex: Int? {
        switch self {
        case .replayCurrentSceneWithRevisedFuture(_, let revisedFutureStartIndex):
            return revisedFutureStartIndex
        case .replayCurrentScene, .continueToNextScene:
            return nil
        }
    }

    var reusesExistingFutureScenes: Bool {
        switch self {
        case .replayCurrentScene, .continueToNextScene:
            return true
        case .replayCurrentSceneWithRevisedFuture:
            return false
        }
    }
}

enum StorySceneMutationScope: Equatable {
    case none
    case futureScenes(startingAt: Int)

    var firstMutableSceneIndex: Int? {
        switch self {
        case .none:
            return nil
        case .futureScenes(let startingAt):
            return startingAt
        }
    }
}

struct StorySceneBoundary: Equatable {
    let sceneIndex: Int
    let sceneId: String

    var replayDecision: NarrationResumeDecision {
        .replayCurrentScene(sceneIndex: sceneIndex)
    }
}

struct StoryAnswerContext: Equatable {
    let storyId: String
    let storyTitle: String
    let currentBoundary: StorySceneBoundary
    let completedScenes: [StoryScene]
    let currentScene: StoryScene
    let remainingScenes: [StoryScene]
    let futureScenes: [StoryScene]
    let mutationScope: StorySceneMutationScope
}

struct StoryRevisionBoundary: Equatable {
    let storyId: String
    let storyTitle: String
    let resumeBoundary: StorySceneBoundary
    let preservedScenes: [StoryScene]
    let futureScenes: [StoryScene]
    let mutationScope: StorySceneMutationScope

    var narrationResumeDecision: NarrationResumeDecision {
        .replayCurrentSceneWithRevisedFuture(
            sceneIndex: resumeBoundary.sceneIndex,
            revisedFutureStartIndex: resumeBoundary.sceneIndex + 1
        )
    }

    func makeRequest(userUpdate: String) -> ReviseStoryRequest {
        ReviseStoryRequest(
            storyId: storyId,
            currentSceneIndex: resumeBoundary.sceneIndex + 1,
            storyTitle: storyTitle,
            userUpdate: userUpdate,
            completedScenes: preservedScenes,
            remainingScenes: futureScenes
        )
    }
}

struct AuthoritativeStorySceneState: Equatable {
    let storyId: String
    let storyTitle: String
    let scenes: [StoryScene]
    let currentSceneIndex: Int

    init?(story: StoryData, currentSceneIndex: Int) {
        guard story.scenes.indices.contains(currentSceneIndex) else { return nil }

        self.storyId = story.storyId
        self.storyTitle = story.title
        self.scenes = story.scenes
        self.currentSceneIndex = currentSceneIndex
    }

    var completedScenes: [StoryScene] {
        Array(scenes.prefix(currentSceneIndex))
    }

    var currentScene: StoryScene {
        scenes[currentSceneIndex]
    }

    var remainingScenes: [StoryScene] {
        Array(scenes.suffix(from: currentSceneIndex))
    }

    var futureScenes: [StoryScene] {
        let futureStartIndex = currentSceneIndex + 1
        guard futureStartIndex < scenes.count else { return [] }
        return Array(scenes.suffix(from: futureStartIndex))
    }

    var currentBoundary: StorySceneBoundary {
        StorySceneBoundary(sceneIndex: currentSceneIndex, sceneId: currentScene.sceneId)
    }

    var answerContext: StoryAnswerContext {
        StoryAnswerContext(
            storyId: storyId,
            storyTitle: storyTitle,
            currentBoundary: currentBoundary,
            completedScenes: completedScenes,
            currentScene: currentScene,
            remainingScenes: remainingScenes,
            futureScenes: futureScenes,
            mutationScope: .none
        )
    }

    var revisionBoundary: StoryRevisionBoundary? {
        guard !futureScenes.isEmpty else { return nil }

        return StoryRevisionBoundary(
            storyId: storyId,
            storyTitle: storyTitle,
            resumeBoundary: currentBoundary,
            preservedScenes: Array(scenes.prefix(currentSceneIndex + 1)),
            futureScenes: futureScenes,
            mutationScope: .futureScenes(startingAt: currentSceneIndex + 1)
        )
    }
}

extension StoryData {
    func authoritativeSceneState(at currentSceneIndex: Int) -> AuthoritativeStorySceneState? {
        AuthoritativeStorySceneState(story: self, currentSceneIndex: currentSceneIndex)
    }
}

enum HybridRuntimeStateNode: Equatable {
    case setupInteraction(stepNumber: Int)
    case narration(sceneIndex: Int)
    case interruptionIntake(sceneIndex: Int)
    case answerOnly(sceneIndex: Int)
    case reviseFutureScenes(sceneIndex: Int)
    case repeatOrClarify(sceneIndex: Int)
    case completed
    case failed

    var mode: HybridRuntimeMode? {
        switch self {
        case .setupInteraction(let stepNumber):
            return .interaction(.setupFollowUp(stepNumber: stepNumber))
        case .narration(let sceneIndex):
            return .narration(sceneIndex: sceneIndex)
        case .interruptionIntake(let sceneIndex):
            return .interaction(.interruption(sceneIndex: sceneIndex))
        case .answerOnly(let sceneIndex):
            return .interaction(.answerOnly(sceneIndex: sceneIndex))
        case .reviseFutureScenes(let sceneIndex):
            return .interaction(.reviseFutureScenes(sceneIndex: sceneIndex))
        case .repeatOrClarify(let sceneIndex):
            return .interaction(.repeatOrClarify(sceneIndex: sceneIndex))
        case .completed, .failed:
            return nil
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        case .setupInteraction, .narration, .interruptionIntake, .answerOnly, .reviseFutureScenes, .repeatOrClarify:
            return false
        }
    }

    func transition(using trigger: HybridRuntimeTransitionTrigger) -> HybridRuntimeStateNode? {
        switch (self, trigger) {
        case (.setupInteraction, .advanceSetupInteraction(let stepNumber)):
            guard stepNumber >= 1 else { return nil }
            return .setupInteraction(stepNumber: stepNumber)

        case (.setupInteraction, .beginNarration(let sceneIndex)):
            guard sceneIndex >= 0 else { return nil }
            return .narration(sceneIndex: sceneIndex)

        case (.setupInteraction, .failSession):
            return .failed

        case (.narration(let sceneIndex), .interruptNarration(let interruptedSceneIndex)):
            guard interruptedSceneIndex == sceneIndex else { return nil }
            return .interruptionIntake(sceneIndex: sceneIndex)

        case (.narration, .finishNarrationScene(let nextSceneIndex)):
            if let nextSceneIndex {
                guard nextSceneIndex >= 0 else { return nil }
                return .narration(sceneIndex: nextSceneIndex)
            }
            return .completed

        case (.narration, .completeSession):
            return .completed

        case (.narration, .failSession):
            return .failed

        case (.interruptionIntake(let sceneIndex), .routeInterruption(let intent)):
            switch intent {
            case .answerOnly:
                return .answerOnly(sceneIndex: sceneIndex)
            case .reviseFutureScenes:
                return .reviseFutureScenes(sceneIndex: sceneIndex)
            case .repeatOrClarify:
                return .repeatOrClarify(sceneIndex: sceneIndex)
            }

        case (.interruptionIntake, .failSession):
            return .failed

        case (.answerOnly(let sceneIndex), .resumeNarration(let decision)):
            guard decision == .replayCurrentScene(sceneIndex: sceneIndex) else { return nil }
            return .narration(sceneIndex: sceneIndex)

        case (.answerOnly, .failSession):
            return .failed

        case (.reviseFutureScenes(let sceneIndex), .resumeNarration(let decision)):
            guard case .replayCurrentSceneWithRevisedFuture(
                sceneIndex: sceneIndex,
                revisedFutureStartIndex: let revisedFutureStartIndex
            ) = decision,
            revisedFutureStartIndex > sceneIndex else { return nil }
            return .narration(sceneIndex: sceneIndex)

        case (.reviseFutureScenes, .failSession):
            return .failed

        case (.repeatOrClarify(let sceneIndex), .resumeNarration(let decision)):
            guard decision == .replayCurrentScene(sceneIndex: sceneIndex) else { return nil }
            return .narration(sceneIndex: sceneIndex)

        case (.repeatOrClarify, .failSession):
            return .failed

        case (.completed, _), (.failed, _):
            return nil

        default:
            return nil
        }
    }
}

enum HybridRuntimeTransitionTrigger: Equatable {
    case advanceSetupInteraction(stepNumber: Int)
    case beginNarration(sceneIndex: Int)
    case interruptNarration(sceneIndex: Int)
    case routeInterruption(InterruptionIntent)
    case resumeNarration(NarrationResumeDecision)
    case finishNarrationScene(nextSceneIndex: Int?)
    case completeSession
    case failSession
}

extension VoiceSessionState {
    var hybridRuntimeStateNode: HybridRuntimeStateNode? {
        switch self {
        case .ready(let readyState):
            switch readyState.mode {
            case .discovery(let stepNumber):
                return .setupInteraction(stepNumber: stepNumber)
            }
        case .narrating(let sceneIndex), .paused(let sceneIndex):
            return .narration(sceneIndex: sceneIndex)
        case .interrupting(let sceneIndex):
            return .interruptionIntake(sceneIndex: sceneIndex)
        case .revising(let sceneIndex, _):
            return .reviseFutureScenes(sceneIndex: sceneIndex)
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .idle, .booting, .discovering, .generating:
            return nil
        }
    }
}

enum StoryTimeAppErrorCategory: String, Equatable {
    case startup
    case moderationBlock
    case networkFailure
    case backendFailure
    case decodeFailure
    case persistenceFailure
    case cancellation
}

struct StoryTimeAppError: Equatable {
    let category: StoryTimeAppErrorCategory
    let statusMessage: String
    let userMessage: String
}
