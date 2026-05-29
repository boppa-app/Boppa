import SwiftUI

// TODO: Swiping up in search view should refresh results

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var cacheManager = SearchCacheManager()
    @State private var trackForActions: Track?
    @State private var pendingArtist: Artist?
    @State private var pendingTracklist: Tracklist?
    @FocusState private var isSearchFieldFocused: Bool
    var navigationResetId: Int = 0
    @Binding var isAtNavigationRoot: Bool

    private var showRecentSearches: Bool {
        self.isSearchFieldFocused
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchToolbarView(
                    viewModel: self.viewModel,
                    isSearchFieldFocused: self.$isSearchFieldFocused,
                    onSearch: {
                        self.cacheManager.saveQuery(self.viewModel.searchQuery)
                    }
                )
                if self.showRecentSearches {
                    self.recentSearchesView
                } else {
                    self.contentArea
                }
            }
            .onChange(of: self.isSearchFieldFocused) { _, focused in
                if !focused {
                    self.viewModel.searchQuery = self.viewModel.lastSearchedQuery
                }
            }
            .onAppear {
                self.viewModel.loadSources()
                self.cacheManager.load()
                self.isAtNavigationRoot = true
            }
            .onDisappear {
                self.isAtNavigationRoot = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceAdded)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceRemoved)) { notification in
                let removedIds = notification.userInfo?["ids"] as? [String] ?? []
                if let selected = self.viewModel.selectedMediaSource, removedIds.contains(selected.id) {
                    self.viewModel.clearSearch()
                }
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceEnabled)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceDisabled)) { _ in
                self.viewModel.loadSources()
            }
        }
        .id(self.navigationResetId)
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
            SearchCacheView(
                cachedQueries: self.cacheManager.cachedQueries,
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
        .contentShape(Rectangle())
        .onTapGesture {
            self.isSearchFieldFocused = false
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Color(.systemGray5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            self.isSearchFieldFocused = false
        }
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
        .contentShape(Rectangle())
        .onTapGesture {
            self.isSearchFieldFocused = false
        }
    }

    private var resultsList: some View {
        ScrollFadeView {
            List {
                switch self.viewModel.results {
                case let .songs(tracks), let .videos(tracks):
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { _, track in
                        TrackRow(
                            track: track,
                            isSelected: PlaybackService.shared.currentTrack?.url == track.url && track.url != nil,
                            isLoading: PlaybackService.shared.isLoading,
                            isPlaying: PlaybackService.shared.isPlaying,
                            onTap: { self.playTrack(track, from: tracks) },
                            onEllipsisTap: { self.trackForActions = track }
                        )
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                case let .albums(tracklists):
                    ForEach(Array(tracklists.enumerated()), id: \.element.id) { _, tracklist in
                        if let mediaSource = self.viewModel.selectedMediaSource,
                           mediaSource.config.data?.getAlbum != nil
                        {
                            TracklistRow(tracklist: tracklist, showChevron: true)
                                .background(
                                    NavigationLink(destination: TracklistView(
                                        tracklist: Tracklist(
                                            mediaId: tracklist.mediaId,
                                            mediaSourceId: mediaSource.id,
                                            title: tracklist.title,
                                            subtitle: tracklist.subtitle,
                                            artworkUrl: tracklist.artworkUrl,
                                            metadata: tracklist.metadata,
                                            tracklistType: .album,
                                            artists: tracklist.artists,
                                            storedTracklist: TracklistStorageService.shared.findStoredTracklist(mediaId: tracklist.mediaId, mediaSourceId: tracklist.mediaSourceId)
                                        )
                                    )) { EmptyView() }
                                        .opacity(0)
                                )
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
                           mediaSource.config.data?.getArtist != nil
                        {
                            ArtistRow(artist: artist, showChevron: true)
                                .background(
                                    NavigationLink(destination: ArtistDetailView(
                                        artist: artist,
                                        mediaSource: mediaSource
                                    )) { EmptyView() }
                                        .opacity(0)
                                )
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
                           mediaSource.config.data?.getPlaylist != nil
                        {
                            TracklistRow(tracklist: tracklist, showChevron: true)
                                .background(
                                    NavigationLink(destination: TracklistView(
                                        tracklist: Tracklist(
                                            mediaId: tracklist.mediaId,
                                            mediaSourceId: mediaSource.id,
                                            title: tracklist.title,
                                            subtitle: tracklist.subtitle,
                                            artworkUrl: tracklist.artworkUrl,
                                            metadata: tracklist.metadata,
                                            tracklistType: .playlist,
                                            artists: tracklist.artists,
                                            storedTracklist: TracklistStorageService.shared.findStoredTracklist(mediaId: tracklist.mediaId, mediaSourceId: tracklist.mediaSourceId)
                                        )
                                    )) { EmptyView() }
                                        .opacity(0)
                                )
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
                        .onAppear {
                            self.viewModel.loadNextPage()
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
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
        .navigationDestination(item: self.$pendingArtist) { artist in
            if let mediaSource = self.viewModel.selectedMediaSource {
                ArtistDetailView(artist: artist, mediaSource: mediaSource)
            }
        }
        .navigationDestination(item: self.$pendingTracklist) { tracklist in
            if let mediaSource = self.viewModel.selectedMediaSource {
                TracklistView(
                    tracklist: Tracklist(
                        mediaId: tracklist.mediaId,
                        mediaSourceId: mediaSource.id,
                        title: tracklist.title,
                        subtitle: tracklist.subtitle,
                        artworkUrl: tracklist.artworkUrl,
                        metadata: tracklist.metadata,
                        tracklistType: tracklist.tracklistType,
                        artists: tracklist.artists,
                        storedTracklist: TracklistStorageService.shared.findStoredTracklist(mediaId: tracklist.mediaId, mediaSourceId: tracklist.mediaSourceId)
                    )
                )
            }
        }
    }

    private func playTrack(_ track: Track, from tracks: [Track]) {
        PlaybackService.shared.playTrack(track, queue: tracks)
    }
}

#Preview {
    SearchView(isAtNavigationRoot: .constant(true))
        .preferredColorScheme(.dark)
}
