import SwiftData
import SwiftUI

// TODO: Disable hiding bars when browser is tapped, fix size of mini url toolbar
// TODO: Tapping again on a category in the bottom menu bar takes you back to the main view (ex: Tapping playlist again takes you out of playlist detail view and back to playlist view)
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    @State private var browserViewModel = BrowserViewModel()
    @State private var nowPlayingViewModel = NowPlayingViewModel()

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    private var bottomBarsHidden: Bool {
        self.selectedTab == 0 && self.browserViewModel.barsHidden
    }

    private var showMiniPlayer: Bool {
        self.selectedTab != 0 && self.selectedTab != 3 && self.playbackService.hasTrack
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
                LibraryView()
                    .opacity(self.selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 2)
                SettingsView()
                    .opacity(self.selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 3)
            }
            .frame(maxHeight: .infinity)

            if !self.bottomBarsHidden {
                if self.showMiniPlayer {
                    VStack(spacing: 0) {
                        MiniPlayerView(showNowPlaying: self.$showNowPlaying)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                ContentTabView(selectedTab: self.$selectedTab, hideSeparator: self.showMiniPlayer)
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
    var hideSeparator: Bool = false

    let tabs: [(icon: String, num: Int)] = [
        ("safari", 0),
        ("magnifyingglass", 1),
        ("bookmark", 2),
        ("gear", 3),
    ]

    var body: some View {
        VStack(spacing: 0) {
            if !self.hideSeparator {
                Spacer().frame(height: 6)
                Rectangle().fill(Color(.systemGray6)).frame(height: 3)
            }

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
