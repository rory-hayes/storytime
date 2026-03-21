import SwiftUI
import FirebaseCore

private func configureFirebaseIfNeeded() {
    if FirebaseApp.app() == nil {
        FirebaseApp.configure()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureFirebaseIfNeeded()

        return true
    }
}

@main
struct StoryTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store: StoryLibraryStore
    @StateObject private var parentAuthManager: ParentAuthManager

    init() {
        configureFirebaseIfNeeded()
        UITestSeed.prepareIfNeeded()
        _store = StateObject(wrappedValue: StoryLibraryStore())
        _parentAuthManager = StateObject(
            wrappedValue: ParentAuthManager(
                provider: UITestSeed.parentAuthProviderIfNeeded() ?? FirebaseParentAuthProvider()
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .environmentObject(parentAuthManager)
        }
    }
}
