import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                BrowserView()
                    .tabItem {
                        Label("", systemImage: "safari")
                    }
                    .tag(0)
                SearchView()
                    .tabItem {
                        Label("", systemImage: "magnifyingglass")
                    }
                    .tag(1)
                PlaylistsView()
                    .tabItem {
                        Label("", systemImage: "music.note.list")
                    }
                    .tag(2)
                SettingsView()
                    .tabItem {
                        Label("", systemImage: "gear")
                    }
                    .tag(3)
            }

            MiniPlayerView()
        }
    }
}

#Preview {
    ContentView()
}
