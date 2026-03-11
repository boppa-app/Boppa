import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    @State private var browserViewModel = BrowserViewModel()
    @State private var nowPlayingViewModel = NowPlayingViewModel()

    private var bottomBarsHidden: Bool {
        self.selectedTab == 0 && self.browserViewModel.barsHidden
    }

    private var showMiniPlayer: Bool {
        self.selectedTab != 0 && self.selectedTab != 3
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                BrowserView(viewModel: self.browserViewModel)
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

            if !self.bottomBarsHidden {
                if self.showMiniPlayer {
                    MiniPlayerView(showNowPlaying: self.$showNowPlaying)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                ContentTabView(selectedTab: self.$selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if self.bottomBarsHidden {
                BottomSafeAreaTapTarget {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.browserViewModel.showBars()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: self.bottomBarsHidden)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: self.$showNowPlaying) {
            NowPlayingView(viewModel: self.nowPlayingViewModel)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            self.nowPlayingViewModel.onOpenInBrowser = { url in
                self.browserViewModel.loadURL(urlString: url)
                self.selectedTab = 0
            }
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

private struct BottomSafeAreaTapTarget: View {
    let onTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            VStack(spacing: 0) {
                Spacer()
                Color.black.opacity(0.001)
                    .frame(height: max(bottomInset, 20))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { self.onTap() }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    ContentView()
}
