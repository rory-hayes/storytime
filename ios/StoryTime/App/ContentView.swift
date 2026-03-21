import SwiftUI

struct ContentView: View {
    @ObservedObject var store: StoryLibraryStore
    @StateObject private var firstRunExperience = FirstRunExperienceStore()
    @State private var showingNewJourney = false

    var body: some View {
        Group {
            if firstRunExperience.needsOnboarding {
                FirstRunOnboardingView(store: store) {
                    firstRunExperience.completeOnboarding()
                }
            } else {
                HomeView(store: store, showingNewJourneyOverride: $showingNewJourney)
            }
        }
    }
}

final class FirstRunExperienceStore: ObservableObject {
    static let onboardingCompletedKey = "storytime.first-run.completed.v1"

    @Published private(set) var hasCompletedOnboarding: Bool

    private let userDefaults: UserDefaults

    var needsOnboarding: Bool {
        hasCompletedOnboarding == false
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasCompletedOnboarding = userDefaults.bool(forKey: Self.onboardingCompletedKey)
    }

    func completeOnboarding() {
        guard hasCompletedOnboarding == false else { return }
        userDefaults.set(true, forKey: Self.onboardingCompletedKey)
        hasCompletedOnboarding = true
    }
}

enum FirstRunActivationStep: Int, CaseIterable {
    case welcome
    case howItWorks
    case childSetup
    case trust
    case account
    case plan
    case completion

    var title: String {
        switch self {
        case .welcome:
            return "StoryTime lets kids shape the story while it's happening."
        case .howItWorks:
            return "How StoryTime works"
        case .childSetup:
            return "Set up the child profile"
        case .trust:
            return "Start with trust and privacy"
        case .account:
            return "Create or sign in to the parent account"
        case .plan:
            return "Choose the parent plan"
        case .completion:
            return "Finish setup and enter StoryTime"
        }
    }

    var summary: String {
        switch self {
        case .welcome:
            return "StoryTime is a voice-first storytelling app where the child helps guide what happens next while the story is still unfolding."
        case .howItWorks:
            return "Parents set up the basics first, then the child gets adaptive story sessions that can continue over time."
        case .childSetup:
            return "Confirm the starter profile, age range, and default story mode before the first story session begins."
        case .trust:
            return "Explain how live processing works, what stays local, and where parent controls live after onboarding."
        case .account:
            return "First-run activation now requires a parent account so identity, payments, and entitlements stay parent-managed."
        case .plan:
            return "Choose Starter or unlock Plus here. Restore purchases and promo redemption stay in this parent-only step."
        case .completion:
            return "Review the setup, confirm the account and plan are ready, and then continue into the main app."
        }
    }
}

enum FirstRunActivationPlanChoice: String, Equatable {
    case starter
    case plus
}

struct FirstRunActivationGateState: Equatable {
    var currentStep: FirstRunActivationStep
    var isParentSignedIn: Bool
    var selectedPlanChoice: FirstRunActivationPlanChoice?

    var canAdvance: Bool {
        switch currentStep {
        case .account:
            return isParentSignedIn
        case .plan:
            return selectedPlanChoice != nil
        case .completion:
            return canFinish
        default:
            return true
        }
    }

    var canFinish: Bool {
        isParentSignedIn && selectedPlanChoice != nil
    }
}
