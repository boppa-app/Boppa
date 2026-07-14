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
    @State private var libraryPendingArtist: Artist?
    @State private var libraryPendingTracklist: Tracklist?
    @State private var searchPendingArtist: Artist?
    @State private var searchPendingTracklist: Tracklist?

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    private var showMiniPlayer: Bool {
        self.selectedTab != 2 && self.playbackService.hasTrack
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            VStack(spacing: 0) {
                ZStack {
                    SearchView(navigationResetId: self.searchResetId, focusSearchId: self.searchFocusId, isAtNavigationRoot: self.$searchIsAtRoot, externalPendingArtist: self.$searchPendingArtist, externalPendingTracklist: self.$searchPendingTracklist)
                        .opacity(self.selectedTab == 0 ? 1 : 0)
                        .allowsHitTesting(self.selectedTab == 0)
                    LibraryView(
                        navigationResetId: self.libraryResetId,
                        isAtNavigationRoot: self.$libraryIsAtRoot,
                        externalPendingArtist: self.$libraryPendingArtist,
                        externalPendingTracklist: self.$libraryPendingTracklist
                    )
                    .opacity(self.selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 1)
                    SettingsView(selectedTab: self.$selectedTab, navigationResetId: self.settingsResetId, isAtNavigationRoot: self.$settingsIsAtRoot)
                        .opacity(self.selectedTab == 2 ? 1 : 0)
                        .allowsHitTesting(self.selectedTab == 2)
                }
                .frame(maxHeight: .infinity)
                .onReceive(NotificationCenter.default.publisher(for: .navigateToArtistInSearch)) { notification in
                    guard let artist = notification.object as? Artist else { return }
                    self.searchPendingArtist = artist
                    self.selectedTab = 0
                }
                .onReceive(NotificationCenter.default.publisher(for: .navigateToTracklistInSearch)) { notification in
                    guard let tracklist = notification.object as? Tracklist else { return }
                    self.searchPendingTracklist = tracklist
                    self.selectedTab = 0
                }
                .onReceive(NotificationCenter.default.publisher(for: .navigateToTracklistInLibrary)) { notification in
                    guard let tracklist = notification.object as? Tracklist else { return }
                    self.libraryPendingTracklist = tracklist
                    self.selectedTab = 1
                }
                .onChange(of: DeepLinkAddMediaSourceRequest.shared.pending) { _, newValue in
                    if newValue != nil {
                        self.selectedTab = 2
                    }
                }

                if self.showMiniPlayer {
                    VStack(spacing: 0) {
                        MiniPlayerView(showNowPlaying: self.$showNowPlaying)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if !isLandscape {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: self.$showNowPlaying) {
            NowPlayingView(
                viewModel: self.nowPlayingViewModel,
                onArtistSelected: { artist in
                    NotificationCenter.default.post(name: .navigateToArtistInSearch, object: artist)
                },
                onAlbumSelected: { tracklist in postTracklistNavigation(tracklist) }
            )
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.black)
        }
        .sheet(item: Binding(
            get: { DeepLinkAddMediaSourceRequest.shared.pending },
            set: { newValue in
                if newValue == nil {
                    DeepLinkAddMediaSourceRequest.shared.clear()
                }
            }
        )) { request in
            AddMediaSourceView(initialConfigUrl: request.configUrl)
                .id(request.id)
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
