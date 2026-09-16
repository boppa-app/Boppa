import SwiftUI

private struct BottomBarInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var bottomBarInset: CGFloat {
        get { self[BottomBarInsetKey.self] }
        set { self[BottomBarInsetKey.self] = newValue }
    }
}

private struct ScrollFadeBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var scrollFadeBottomInset: CGFloat {
        get { self[ScrollFadeBottomInsetKey.self] }
        set { self[ScrollFadeBottomInsetKey.self] = newValue }
    }
}

private struct ScrollFadeBottomOpaqueKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var scrollFadeBottomOpaque: Bool {
        get { self[ScrollFadeBottomOpaqueKey.self] }
        set { self[ScrollFadeBottomOpaqueKey.self] = newValue }
    }
}

private struct IsActiveTabKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var isActiveTab: Bool {
        get { self[IsActiveTabKey.self] }
        set { self[IsActiveTabKey.self] = newValue }
    }
}

@Observable
private final class TabBarGradientState {
    var visibility: CGFloat = 1
}

private struct BottomScrollProximityModifier: ViewModifier {
    let fadeThreshold: CGFloat
    let hasMorePages: Bool
    @Environment(\.isActiveTab) private var isActiveTab
    @Environment(TabBarGradientState.self) private var gradientState
    @State private var localProximity: CGFloat = 1

    private func reportedVisibility(proximity: CGFloat) -> CGFloat {
        self.hasMorePages ? 1 : proximity
    }

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    ScrollFadeEdge.bottom.proximity(in: geometry, threshold: self.fadeThreshold)
                } action: { _, newValue in
                    self.localProximity = newValue
                    if self.isActiveTab {
                        self.gradientState.visibility = self.reportedVisibility(proximity: newValue)
                    }
                }
                .onChange(of: self.hasMorePages) { _, _ in
                    if self.isActiveTab {
                        self.gradientState.visibility = self
                            .reportedVisibility(proximity: self.localProximity)
                    }
                }
                .onChange(of: self.isActiveTab) { _, active in
                    if active {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            self.gradientState.visibility = self
                                .reportedVisibility(proximity: self.localProximity)
                        }
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func reportsBottomScrollProximity(
        fadeThreshold: CGFloat = 25,
        hasMorePages: Bool = false
    ) -> some View {
        self.modifier(BottomScrollProximityModifier(
            fadeThreshold: fadeThreshold,
            hasMorePages: hasMorePages
        ))
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    @State private var nowPlayingViewModel = NowPlayingViewModel()
    @State private var searchNavigationReset = NavigationResetSignal()
    @State private var libraryNavigationReset = NavigationResetSignal()
    @State private var settingsResetId = 0
    @State private var searchFocusId = 0
    @State private var searchIsAtRoot = true
    @State private var libraryIsAtRoot = true
    @State private var settingsIsAtRoot = true
    @State private var libraryPendingArtist: Artist?
    @State private var libraryPendingTracklist: Tracklist?
    @State private var searchPendingArtist: Artist?
    @State private var searchPendingTracklist: Tracklist?
    @State private var gradientState = TabBarGradientState()

    private var playbackService: PlaybackService {
        PlaybackService.shared
    }

    private var showMiniPlayer: Bool {
        self.selectedTab != 2 && self.playbackService.hasTrack
    }

    private func miniPlayerShows(onTab tab: Int) -> Bool {
        tab != 2 && self.playbackService.hasTrack
    }

    private func bottomBarInset(forTab tab: Int, isLandscape: Bool) -> CGFloat {
        guard !isLandscape else { return 0 }
        return ContentTabView
            .height + (self.miniPlayerShows(onTab: tab) ? MiniPlayerView.height : 0)
    }

    private func scrollFadeBottomInset(forTab tab: Int, isLandscape: Bool) -> CGFloat {
        guard !isLandscape, self.miniPlayerShows(onTab: tab) else { return 0 }
        return self.bottomBarInset(forTab: tab, isLandscape: isLandscape)
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack(alignment: .bottom) {
                ZStack {
                    SearchView(
                        navigationReset: self.searchNavigationReset,
                        focusSearchId: self.searchFocusId,
                        selectedTab: self.$selectedTab,
                        isAtNavigationRoot: self.$searchIsAtRoot,
                        externalPendingArtist: self.$searchPendingArtist,
                        externalPendingTracklist: self.$searchPendingTracklist
                    )
                    .opacity(self.selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 0)
                    .environment(\.isActiveTab, self.selectedTab == 0)
                    .environment(
                        \.bottomBarInset,
                        self.bottomBarInset(forTab: 0, isLandscape: isLandscape)
                    )
                    .environment(
                        \.scrollFadeBottomInset,
                        self.scrollFadeBottomInset(forTab: 0, isLandscape: isLandscape)
                    )
                    LibraryView(
                        navigationReset: self.libraryNavigationReset,
                        isAtNavigationRoot: self.$libraryIsAtRoot,
                        externalPendingArtist: self.$libraryPendingArtist,
                        externalPendingTracklist: self.$libraryPendingTracklist
                    )
                    .opacity(self.selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 1)
                    .environment(\.isActiveTab, self.selectedTab == 1)
                    .environment(
                        \.bottomBarInset,
                        self.bottomBarInset(forTab: 1, isLandscape: isLandscape)
                    )
                    .environment(
                        \.scrollFadeBottomInset,
                        self.scrollFadeBottomInset(forTab: 1, isLandscape: isLandscape)
                    )
                    SettingsView(
                        selectedTab: self.$selectedTab,
                        navigationResetId: self.settingsResetId,
                        isAtNavigationRoot: self.$settingsIsAtRoot
                    )
                    .opacity(self.selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(self.selectedTab == 2)
                    .environment(\.isActiveTab, self.selectedTab == 2)
                    .environment(
                        \.bottomBarInset,
                        self.bottomBarInset(forTab: 2, isLandscape: isLandscape)
                    )
                    .environment(
                        \.scrollFadeBottomInset,
                        self.scrollFadeBottomInset(forTab: 2, isLandscape: isLandscape)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onReceive(NotificationCenter.default
                    .publisher(for: .navigateToArtistInSearch))
                { notification in
                    guard let artist = notification.object as? Artist else { return }
                    self.searchPendingArtist = artist
                    self.selectedTab = 0
                }
                .onReceive(NotificationCenter.default
                    .publisher(for: .navigateToTracklistInSearch))
                { notification in
                    guard let tracklist = notification.object as? Tracklist else { return }
                    self.searchPendingTracklist = tracklist
                    self.selectedTab = 0
                }
                .onReceive(NotificationCenter.default
                    .publisher(for: .navigateToTracklistInLibrary))
                { notification in
                    guard let tracklist = notification.object as? Tracklist else { return }
                    self.libraryPendingTracklist = tracklist
                    self.selectedTab = 1
                }
                .onChange(of: DeepLinkAddMediaSourceRequest.shared.pending) { _, newValue in
                    if newValue != nil {
                        self.selectedTab = 2
                    }
                }

                if !isLandscape {
                    VStack(spacing: 0) {
                        if self.showMiniPlayer {
                            MiniPlayerView(showNowPlaying: self.$showNowPlaying)
                                .background(Color.black)
                                .zIndex(1)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        ContentTabView(
                            selectedTab: self.$selectedTab,
                            isMiniPlayerVisible: self.showMiniPlayer,
                            onSameTabTapped: { tab in
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    switch tab {
                                    case 0:
                                        if !self
                                            .searchIsAtRoot { self.searchNavigationReset.fire() }
                                        self.searchFocusId += 1
                                    case 1:
                                        if !self
                                            .libraryIsAtRoot { self.libraryNavigationReset.fire() }
                                    case 2: if !self.settingsIsAtRoot { self.settingsResetId += 1 }
                                    default: break
                                    }
                                }
                            }
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(self.gradientState)
            .environment(
                \.scrollFadeBottomOpaque,
                !ContentTabView.keepsGradientWithMiniPlayer
            )
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
    var isMiniPlayerVisible: Bool = false
    var onSameTabTapped: ((Int) -> Void)? = nil

    @Environment(TabBarGradientState.self) private var gradientState

    static let height: CGFloat = 60

    static let keepsGradientWithMiniPlayer = true
    private var usesOpaqueBar: Bool {
        self.isMiniPlayerVisible && !Self.keepsGradientWithMiniPlayer
    }

    private var windowBottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }

    private var effectiveGradientVisibility: CGFloat {
        self.usesOpaqueBar ? 0 : self.gradientState.visibility
    }

    let tabs: [(icon: String, name: String, num: Int)] = [
        ("magnifyingglass", "Search", 0),
        ("Library", "Library", 1),
        ("gear", "Settings", 2),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(self.tabs, id: \.num) { tab in
                let isSelected = self.selectedTab == tab.num

                Button(action: {
                    if isSelected {
                        self.onSameTabTapped?(tab.num)
                    } else {
                        self.selectedTab = tab.num
                    }
                }) {
                    VStack(spacing: 8) {
                        Group {
                            if tab.icon == "Library" {
                                Image("Library")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 24))
                            }
                        }
                        .foregroundColor(isSelected ? .purp : Color(.systemGray))

                        Capsule()
                            .fill(Color.purp)
                            .frame(width: 24, height: 3)
                            .shadow(color: .purp.opacity(isSelected ? 0.7 : 0), radius: 4, y: 2)
                            .shadow(color: .purp.opacity(isSelected ? 0.5 : 0), radius: 8, y: 5)
                            .shadow(color: .purp.opacity(isSelected ? 0.3 : 0), radius: 14, y: 8)
                            .opacity(isSelected ? 1 : 0)
                            .animation(.easeInOut(duration: 0.1), value: isSelected)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.name)
                .accessibilityHint(isSelected ? "Currently selected" : "Switch to \(tab.name)")
            }
        }
        .frame(height: Self.height)
        .background(alignment: .bottom) {
            EdgeGradientFade(
                edge: .bottom,
                visibility: self.effectiveGradientVisibility,
                gradientExtension: 150,
                solidExtent: Self.height / 2
            )
            .overlay(alignment: .bottom) {
                Color.black
                    .frame(height: Self.height)
                    .opacity(self.usesOpaqueBar ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: self.usesOpaqueBar)
            }
            .overlay(alignment: .bottom) {
                let inset = self.windowBottomSafeAreaInset
                Color.black
                    .frame(height: inset)
                    .offset(y: inset)
            }
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    ContentView()
}
