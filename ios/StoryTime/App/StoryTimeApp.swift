import SwiftUI
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        return true
    }
}

@main
struct StoryTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store: StoryLibraryStore

    init() {
        UITestSeed.prepareIfNeeded()
        _store = StateObject(wrappedValue: StoryLibraryStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
