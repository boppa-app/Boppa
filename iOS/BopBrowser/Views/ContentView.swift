import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showNowPlaying = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                BrowserView()
                    .opacity(self.selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 0)
                SearchView()
                    .opacity(self.selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 1)
                PlaylistsView()
                    .opacity(self.selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 2)
                SettingsView()
                    .opacity(self.selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 3)
            }
            .frame(maxHeight: .infinity)
            MiniPlayerView(showNowPlaying: self.$showNowPlaying)
            ContentTabView(selectedTab: self.$selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: self.$showNowPlaying) {
            NowPlayingView()
                .presentationDragIndicator(.visible)
        }
    }
}

struct ContentTabView: View {
    @Binding var selectedTab: Int

    let tabs: [(icon: String, num: Int)] = [
        ("safari", 0),
        ("magnifyingglass", 1),
        ("music.note.list", 2),
        ("gear", 3),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(.systemGray6)).frame(height: 3)

            HStack(spacing: 0) {
                ForEach(self.tabs, id: \.num) { tab in
                    Button(action: {
                        self.selectedTab = tab.num
                    }) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 24))
                            .foregroundColor(self.selectedTab == tab.num ? .purp : Color(.systemGray))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 60)
        }
    }
}

#Preview {
    ContentView()
}
