import SwiftUI

// TODO: Swiping up in search view should refresh results

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var cacheManager = SearchCacheManager()
    @State private var scrollHandler = SearchBarScrollHandler()
    @State private var trackForActions: Track?
    @State private var pendingArtist: Artist?
    @State private var pendingTracklist: Tracklist?
    @State private var path = NavigationPath()
    @State private var activeMediaSourceId: String?
    @FocusState private var isSearchFieldFocused: Bool
    var navigationResetId: Int = 0
    @Binding var isAtNavigationRoot: Bool

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
                    self.cacheManager.updateFilter("")
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
            .navigationDestination(for: SearchDestination.self) { destination in
                switch destination {
                case let .tracklist(tracklist):
                    TracklistView(tracklist: tracklist)
                case let .artist(artist, mediaSource):
                    ArtistDetailView(artist: artist, mediaSource: mediaSource)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceAdded)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceRemoved)) { notification in
                let removedIds = notification.userInfo?["ids"] as? [String] ?? []
                if let selected = self.viewModel.selectedMediaSource, removedIds.contains(selected.id) {
                    self.viewModel.clearSearch()
                    self.isSearchFieldFocused = false
                }
                if let active = self.activeMediaSourceId, removedIds.contains(active) {
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
            } else if self.viewModel.results.isEmpty, !self.viewModel.isSearching {
                self.emptyStateView
            } else {
                self.resultsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentSearchesView: some View {
        VStack(spacing: 0) {
            if self.showBubbles {
                Color.clear.frame(height: categoryBubblesBarHeight)
            }
            SearchCacheView(
                cachedQueries: self.cacheManager.displayedQueries,
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
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                if self.showBubbles {
                    Color.black
                        .frame(height: categoryBubblesBarHeight)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                }

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
            .padding(.top, -10)
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

    private func playTrack(_ track: Track, from tracks: [Track], at index: Int) {
        TrackQueueManager.shared.setQueue(tracks, startingAt: index, contextId: self.viewModel.searchContextId)
        PlaybackService.shared.playTrack(track)
    }
}

#Preview {
    SearchView(isAtNavigationRoot: .constant(true))
        .preferredColorScheme(.dark)
}
