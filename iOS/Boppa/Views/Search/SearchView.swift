import SwiftUI

// TODO: Swiping up in search view should refresh results

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var cacheManager = SearchCacheManager()
    @State private var recentsManager = RecentsManager()
    @State private var scrollHandler = SearchBarScrollHandler()
    @State private var trackForActions: Track?
    @State private var pendingArtist: Artist?
    @State private var pendingTracklist: Tracklist?
    @State private var path = NavigationPath()
    @State private var activeMediaSourceId: String?
    @State private var keyboardTop: CGFloat = UIScreen.main.bounds.height
    @FocusState private var isSearchFieldFocused: Bool
    var navigationResetId: Int = 0
    var focusSearchId: Int = 0
    @Binding var isAtNavigationRoot: Bool
    @Binding var externalPendingArtist: Artist?
    @Binding var externalPendingTracklist: Tracklist?

    private var showBubbles: Bool {
        (self.isSearchFieldFocused || self.viewModel.isQueryActive) && !self.viewModel.availableCategories.isEmpty
    }

    private var showRecentSearches: Bool {
        self.isSearchFieldFocused
    }

    var body: some View {
        NavigationStack(path: self.$path) {
            VStack(spacing: 0) {
                SearchToolbarView(
                    viewModel: self.viewModel,
                    isSearchFieldFocused: self.$isSearchFieldFocused,
                    onSearch: {
                        self.cacheManager.saveQuery(self.viewModel.searchQuery)
                    }
                )
                ZStack(alignment: .top) {
                    if self.showRecentSearches {
                        self.recentSearchesView
                    } else {
                        self.contentArea
                    }
                    if self.showBubbles {
                        self.categoryBubblesBar
                    }
                }
            }
            .onChange(of: self.isSearchFieldFocused) { _, focused in
                if !focused {
                    self.viewModel.searchQuery = self.viewModel.lastSearchedQuery
                } else {
                    self.scrollHandler.showSearchBar = true
                    self.cacheManager.updateFilter(self.viewModel.searchQuery)
                }
            }
            .onChange(of: self.viewModel.searchQuery) { _, query in
                if self.isSearchFieldFocused {
                    self.cacheManager.updateFilter(query)
                }
            }
            .onChange(of: self.viewModel.lastSearchedQuery) { _, _ in
                self.scrollHandler.showSearchBar = true
            }
            .onAppear {
                self.viewModel.loadSources()
                self.cacheManager.load()
                self.recentsManager.load(mediaSourceId: self.viewModel.selectedMediaSource?.id)
            }
            .onChange(of: self.viewModel.selectedMediaSource?.id) { _, mediaSourceId in
                self.recentsManager.load(mediaSourceId: mediaSourceId)
            }
            .onChange(of: self.path.count, initial: true) { oldCount, count in
                self.isAtNavigationRoot = count == 0
                if count == 0 {
                    self.activeMediaSourceId = nil
                } else if oldCount == 0 {
                    self.activeMediaSourceId = self.viewModel.selectedMediaSource?.id
                }
            }
            .onChange(of: self.navigationResetId) { _, _ in
                self.path = NavigationPath()
                self.pendingArtist = nil
                self.pendingTracklist = nil
            }
            .onChange(of: self.focusSearchId) { _, _ in
                self.isSearchFieldFocused = true
            }
            .onChange(of: self.pendingArtist) { _, artist in
                guard let artist, let mediaSource = self.viewModel.selectedMediaSource else { return }
                self.path.append(SearchDestination.artist(artist, mediaSource))
                self.pendingArtist = nil
            }
            .onChange(of: self.pendingTracklist) { _, tracklist in
                guard let tracklist, let mediaSource = self.viewModel.selectedMediaSource else { return }
                self.path.append(SearchDestination.tracklist(Tracklist(
                    mediaId: tracklist.mediaId,
                    mediaSourceId: mediaSource.id,
                    title: tracklist.title,
                    subtitle: tracklist.subtitle,
                    artworkUrl: tracklist.artworkUrl,

                    tracklistType: tracklist.tracklistType,
                    storedTracklist: TracklistStorageManager.shared.findStoredTracklist(mediaId: tracklist.mediaId, mediaSourceId: tracklist.mediaSourceId)
                )))
                self.pendingTracklist = nil
            }
            .onChange(of: self.externalPendingArtist) { _, artist in
                guard let artist,
                      let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: artist.mediaSourceId)
                else { return }
                self.path.append(SearchDestination.artist(artist, mediaSource))
                self.externalPendingArtist = nil
            }
            .onChange(of: self.externalPendingTracklist) { _, tracklist in
                guard let tracklist,
                      let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: tracklist.mediaSourceId)
                else { return }
                self.path.append(SearchDestination.tracklist(Tracklist(
                    mediaId: tracklist.mediaId,
                    mediaSourceId: mediaSource.id,
                    title: tracklist.title,
                    subtitle: tracklist.subtitle,
                    artworkUrl: tracklist.artworkUrl,

                    tracklistType: tracklist.tracklistType,
                    storedTracklist: TracklistStorageManager.shared.findStoredTracklist(mediaId: tracklist.mediaId, mediaSourceId: tracklist.mediaSourceId)
                )))
                self.externalPendingTracklist = nil
            }
            .navigationDestination(for: SearchDestination.self) { destination in
                switch destination {
                case let .tracklist(tracklist):
                    TracklistView(tracklist: tracklist)
                case let .artist(artist, mediaSource):
                    ArtistDetailView(artist: artist, mediaSource: mediaSource)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                self.keyboardTop = frame.origin.y
            }
            .onReceive(NotificationCenter.default.publisher(for: .recentlyPlayedChanged)) { _ in
                self.recentsManager.loadRecentlyPlayed(mediaSourceId: self.viewModel.selectedMediaSource?.id)
            }
            .onReceive(NotificationCenter.default.publisher(for: .recentlyViewedChanged)) { _ in
                self.recentsManager.loadRecentlyViewed(mediaSourceId: self.viewModel.selectedMediaSource?.id)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceAdded)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceRemoved)) { notification in
                let removedId = notification.userInfo?["id"] as? String
                if let selected = self.viewModel.selectedMediaSource, selected.id == removedId {
                    self.viewModel.clearSearch()
                    self.isSearchFieldFocused = false
                }
                if let active = self.activeMediaSourceId, active == removedId {
                    self.path = NavigationPath()
                }
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceEnabled)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceDisabled)) { notification in
                let disabledId = notification.userInfo?["id"] as? String
                if let disabledId, self.viewModel.selectedMediaSource?.id == disabledId {
                    self.viewModel.clearSearch()
                    self.isSearchFieldFocused = false
                }
                if let disabledId, self.activeMediaSourceId == disabledId {
                    self.path = NavigationPath()
                }
                self.viewModel.loadSources()
            }
            .sheet(item: self.$trackForActions) { track in
                if let mediaSource = self.viewModel.selectedMediaSource {
                    TrackActionsSheet(
                        track: track,
                        mediaSource: mediaSource,
                        onArtistSelected: { artist in self.pendingArtist = artist },
                        onAlbumSelected: { tracklist in self.pendingTracklist = tracklist }
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color(.systemGray6))
                }
            }
        }
    }

    private enum SearchDestination: Hashable {
        case tracklist(Tracklist)
        case artist(Artist, MediaSource)
    }

    private var categoryBubblesBar: some View {
        CategoryBubblesBar(
            categories: self.viewModel.availableCategories,
            selectedCategory: self.viewModel.selectedCategory,
            scrollHandler: self.scrollHandler,
            isFocused: self.isSearchFieldFocused,
            onSelect: { category in
                self.cacheManager.saveQuery(self.viewModel.searchQuery)
                self.viewModel.selectCategory(category)
                self.isSearchFieldFocused = false
            }
        )
    }

    private var contentArea: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.lastSearchedQuery.isEmpty {
                self.recentsSectionsView
            } else if self.viewModel.results.isEmpty, !self.viewModel.isSearching {
                self.emptyStateView
            } else {
                self.resultsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentsSectionsView: some View {
        RecentsSectionsView(
            recentlyPlayed: self.recentsManager.recentlyPlayed,
            recentlyViewed: self.recentsManager.recentlyViewed,
            onSelectTrack: { track in
                guard let index = self.recentsManager.recentlyPlayed.firstIndex(where: { $0.id == track.id }) else { return }
                self.playRecentlyPlayedTrack(track, at: index)
            },
            onShowTrackActions: { track in
                self.trackForActions = track
            },
            onSelectArtist: { artist in
                guard let mediaSource = self.viewModel.selectedMediaSource else { return }
                self.path.append(SearchDestination.artist(artist, mediaSource))
            },
            onSelectTracklist: { tracklist in
                guard let mediaSource = self.viewModel.selectedMediaSource else { return }
                self.path.append(SearchDestination.tracklist(Tracklist(
                    mediaId: tracklist.mediaId,
                    mediaSourceId: mediaSource.id,
                    title: tracklist.title,
                    subtitle: tracklist.subtitle,
                    artworkUrl: tracklist.artworkUrl,

                    tracklistType: tracklist.tracklistType,
                    storedTracklist: TracklistStorageManager.shared.findStoredTracklist(mediaId: tracklist.mediaId, mediaSourceId: tracklist.mediaSourceId)
                )))
            },
            onClearRecentlyPlayed: {
                guard let mediaSourceId = self.viewModel.selectedMediaSource?.id else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.recentsManager.clearRecentlyPlayed(mediaSourceId: mediaSourceId)
                }
            },
            onClearRecentlyViewed: {
                guard let mediaSourceId = self.viewModel.selectedMediaSource?.id else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.recentsManager.clearRecentlyViewed(mediaSourceId: mediaSourceId)
                }
            }
        )
    }

    private var recentSearchesView: some View {
        GeometryReader { geo in
            let keyboardOverlap = max(0, geo.frame(in: .global).maxY - self.keyboardTop)
            VStack(spacing: 0) {
                if self.showBubbles {
                    Color.clear.frame(height: self.scrollHandler.bubblesBarHeight)
                    Rectangle()
                        .fill(Color.purp)
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                SearchCacheView(
                    cachedQueries: self.cacheManager.displayedQueries,
                    keyboardHeight: keyboardOverlap,
                    onSelect: { cached in
                        self.viewModel.searchQuery = cached.query
                        self.viewModel.search()
                        self.isSearchFieldFocused = false
                        self.cacheManager.saveQuery(cached.query)
                    },
                    onRemove: { cached in
                        self.cacheManager.removeQuery(cached)
                    },
                    onClearAll: {
                        self.cacheManager.clearAll()
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Color(.systemGray5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(self.viewModel.mediaSources.count == 0 ? Color(.systemGray) : .red)
            Text(message)
                .font(.callout)
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        ScrollFadeView {
            List {
                switch self.viewModel.results {
                case let .songs(tracks), let .videos(tracks):
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(
                            track: track,
                            isSelected: PlaybackService.shared.currentTrack?.url == track.url &&
                                track.url != nil &&
                                TrackQueueManager.shared.contextId == self.viewModel.searchContextId,
                            isLoading: PlaybackService.shared.isLoading,
                            isPlaying: PlaybackService.shared.isPlaying,
                            onTap: { self.playTrack(track, from: tracks, at: index) },
                            onEllipsisTap: { self.trackForActions = track }
                        )
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                case let .albums(tracklists):
                    ForEach(Array(tracklists.enumerated()), id: \.element.id) { _, tracklist in
                        if let mediaSource = self.viewModel.selectedMediaSource,
                           mediaSource.config.data.list?.album != nil
                        {
                            Button {
                                self.path.append(SearchDestination.tracklist(Tracklist(
                                    mediaId: tracklist.mediaId,
                                    mediaSourceId: mediaSource.id,
                                    title: tracklist.title,
                                    subtitle: tracklist.subtitle,
                                    year: tracklist.year,
                                    artworkUrl: tracklist.artworkUrl,

                                    tracklistType: .album,
                                    storedTracklist: TracklistStorageManager.shared.findStoredTracklist(mediaId: tracklist.mediaId, mediaSourceId: tracklist.mediaSourceId)
                                )))
                            } label: {
                                TracklistRow(tracklist: tracklist, showChevron: true)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                        } else {
                            TracklistRow(tracklist: tracklist)
                                .listRowBackground(Color.black)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                        }
                    }
                case let .artists(artists):
                    ForEach(Array(artists.enumerated()), id: \.element.id) { _, artist in
                        if let mediaSource = self.viewModel.selectedMediaSource,
                           mediaSource.config.data.get?.artist != nil
                        {
                            Button {
                                self.path.append(SearchDestination.artist(artist, mediaSource))
                            } label: {
                                ArtistRow(artist: artist, showChevron: true)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                        } else {
                            ArtistRow(artist: artist)
                                .listRowBackground(Color.black)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                        }
                    }
                case let .playlists(tracklists):
                    ForEach(Array(tracklists.enumerated()), id: \.element.id) { _, tracklist in
                        if let mediaSource = self.viewModel.selectedMediaSource,
                           mediaSource.config.data.list?.playlist != nil
                        {
                            Button {
                                self.path.append(SearchDestination.tracklist(Tracklist(
                                    mediaId: tracklist.mediaId,
                                    mediaSourceId: mediaSource.id,
                                    title: tracklist.title,
                                    subtitle: tracklist.subtitle,
                                    artworkUrl: tracklist.artworkUrl,

                                    tracklistType: .playlist,
                                    storedTracklist: TracklistStorageManager.shared.findStoredTracklist(mediaId: tracklist.mediaId, mediaSourceId: tracklist.mediaSourceId)
                                )))
                            } label: {
                                TracklistRow(tracklist: tracklist, showChevron: true)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                        } else {
                            TracklistRow(tracklist: tracklist)
                                .listRowBackground(Color.black)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                        }
                    }
                }

                if self.viewModel.hasMorePages {
                    ProgressView()
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .id(self.viewModel.results.count)
                        .onAppear {
                            self.viewModel.loadNextPage()
                        }
                }
            }
            .listStyle(.plain)
            .contentMargins(.top, self.showBubbles ? self.scrollHandler.bubblesBarHeight : 0)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .modifier(ScrollDirectionTracker(
                isEnabled: self.showBubbles,
                onScrollChange: { oldInfo, newInfo in
                    self.scrollHandler.handleScrollChange(
                        oldInfo: oldInfo,
                        newInfo: newInfo,
                        isSearchFieldFocused: self.isSearchFieldFocused
                    )
                }
            ))
        }
    }

    private func playTrack(_ track: Track, from tracks: [Track], at index: Int) {
        TrackQueueManager.shared.setQueue(tracks, startingAt: index, contextId: self.viewModel.searchContextId)
        PlaybackService.shared.playTrack(track)
    }

    private func playRecentlyPlayedTrack(_ track: Track, at index: Int) {
        TrackQueueManager.shared.setQueue(self.recentsManager.recentlyPlayed, startingAt: index, contextId: "recentlyPlayed")
        PlaybackService.shared.playTrack(track, notifyRecentsChanged: false)
    }
}

#Preview {
    SearchView(isAtNavigationRoot: .constant(true), externalPendingArtist: .constant(nil), externalPendingTracklist: .constant(nil))
        .preferredColorScheme(.dark)
}
