import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    @State private var nowPlayingViewModel = NowPlayingViewModel()
    @State private var searchResetId = 0
    @State private var libraryResetId = 0
    @State private var settingsResetId = 0
    @State private var searchFocusId = 0
    @State private var searchIsAtRoot = true
    @State private var libraryIsAtRoot = true
    @State private var settingsIsAtRoot = true

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    private var showMiniPlayer: Bool {
        self.selectedTab != 2 && self.playbackService.hasTrack
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                SearchView(navigationResetId: self.searchResetId, focusSearchId: self.searchFocusId, isAtNavigationRoot: self.$searchIsAtRoot)
                    .opacity(self.selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 0)
                LibraryView(navigationResetId: self.libraryResetId, isAtNavigationRoot: self.$libraryIsAtRoot)
                    .opacity(self.selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 1)
                SettingsView(selectedTab: self.$selectedTab, navigationResetId: self.settingsResetId, isAtNavigationRoot: self.$settingsIsAtRoot)
                    .opacity(self.selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 2)
            }
            .frame(maxHeight: .infinity)

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
                        case 0:
                            if !self.searchIsAtRoot { self.searchResetId += 1 }
                            self.searchFocusId += 1
                        case 1: if !self.libraryIsAtRoot { self.libraryResetId += 1 }
                        case 2: if !self.settingsIsAtRoot { self.settingsResetId += 1 }
                        default: break
                        }
                    }
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: self.$showNowPlaying) {
            NowPlayingView(viewModel: self.nowPlayingViewModel)
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.black)
        }
    }
}

struct ContentTabView: View {
    @Binding var selectedTab: Int
    var hideSeparator: Bool = false
    var onSameTabTapped: ((Int) -> Void)? = nil

    let tabs: [(icon: String, name: String, num: Int)] = [
        ("magnifyingglass", "Search", 0),
        ("bookmark", "Library", 1),
        ("gear", "Settings", 2),
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
                    .accessibilityLabel(tab.name)
                    .accessibilityHint(self.selectedTab == tab.num ? "Currently selected" : "Switch to \(tab.name)")
                }
            }
            .frame(height: 60)
        }
    }
}

#Preview {
    ContentView()
}
