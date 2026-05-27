import SwiftUI

// TODO: Disable hiding bars when browser is tapped, fix size of mini url toolbar
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    @State private var browserViewModel = BrowserViewModel()
    @State private var nowPlayingViewModel = NowPlayingViewModel()
    @State private var searchResetId = 0
    @State private var libraryResetId = 0
    @State private var settingsResetId = 0
    @State private var searchIsAtRoot = true
    @State private var libraryIsAtRoot = true
    @State private var settingsIsAtRoot = true

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
                SearchView(navigationResetId: self.searchResetId, isAtNavigationRoot: self.$searchIsAtRoot)
                    .opacity(self.selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 1)
                LibraryView(navigationResetId: self.libraryResetId, isAtNavigationRoot: self.$libraryIsAtRoot)
                    .opacity(self.selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 2)
                SettingsView(selectedTab: self.$selectedTab, navigationResetId: self.settingsResetId, isAtNavigationRoot: self.$settingsIsAtRoot)
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
                ContentTabView(
                    selectedTab: self.$selectedTab,
                    hideSeparator: self.showMiniPlayer,
                    onSameTabTapped: { tab in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            switch tab {
                            case 1: if !self.searchIsAtRoot { self.searchResetId += 1 }
                            case 2: if !self.libraryIsAtRoot { self.libraryResetId += 1 }
                            case 3: if !self.settingsIsAtRoot { self.settingsResetId += 1 }
                            default: break
                            }
                        }
                    }
                )
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
    var onSameTabTapped: ((Int) -> Void)? = nil

    let tabs: [(icon: String, num: Int)] = [
        ("safari", 0),
        ("magnifyingglass", 1),
        ("bookmark", 2),
        ("gear", 3),
    ]

    var body: some View {
        VStack(spacing: 0) {
            if !self.hideSeparator {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.5), location: 0),
                                .init(color: .clear, location: 0.5),
                                .init(color: .black.opacity(0.5), location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
            }

            HStack(spacing: 0) {
                ForEach(self.tabs, id: \.num) { tab in
                    Button(action: {
                        if self.selectedTab == tab.num {
                            self.onSameTabTapped?(tab.num)
                        } else {
                            self.selectedTab = tab.num
                        }
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
