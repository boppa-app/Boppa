import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ZStack {
                    BrowserView()
                        .opacity(selectedTab == 0 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 0)
                    SearchView()
                        .opacity(selectedTab == 1 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 1)
                    PlaylistsView()
                        .opacity(selectedTab == 2 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 2)
                    SettingsView()
                        .opacity(selectedTab == 3 ? 1 : 0)
                        .allowsHitTesting(selectedTab == 3)
                }
                .frame(maxHeight: .infinity)

                ContentTabView(selectedTab: $selectedTab)
            }

            MiniPlayerView()
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
                ForEach(tabs, id: \.num) { tab in
                    Button(action: {
                        selectedTab = tab.num
                    }) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 24))
                            .foregroundColor(selectedTab == tab.num ? .purp : Color(.systemGray))
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
