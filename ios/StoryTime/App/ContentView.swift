import SwiftUI

struct ContentView: View {
    @ObservedObject var store: StoryLibraryStore

    var body: some View {
        HomeView(store: store)
    }
}
