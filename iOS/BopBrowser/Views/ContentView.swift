import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 0:
                        BrowserView()
                    case 1:
                        SearchView()
                    case 2:
                        PlaylistsView()
                    case 3:
                        SettingsView()
                    default:
                        BrowserView()
                    }
                }
                .frame(maxHeight: .infinity)

                ContentTabView(selectedTab: $selectedTab)
            }
            // .ignoresSafeArea(edges: .bottom)

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
                            .foregroundColor(selectedTab == tab.num ? .accentColor : Color(.systemGray))
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
