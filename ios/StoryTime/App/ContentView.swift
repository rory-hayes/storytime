import SwiftUI

struct ContentView: View {
    @ObservedObject var store: StoryLibraryStore
    @StateObject private var firstRunExperience = FirstRunExperienceStore()
    @State private var showingNewJourney = false

    var body: some View {
        Group {
            if firstRunExperience.needsOnboarding {
                FirstRunOnboardingView(store: store) { shouldStartFirstStory in
                    firstRunExperience.completeOnboarding()
                    if shouldStartFirstStory {
                        showingNewJourney = true
                    }
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
