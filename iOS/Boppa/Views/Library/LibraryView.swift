import SwiftUI

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var isSearchVisible = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var scrollHandler = SearchBarScrollHandler()
    @State private var trackFuzzyHandler = FuzzySearchHandler<StoredTrack>()
    @State private var tracklistFuzzyHandler = FuzzySearchHandler<StoredTracklist>()
    @State private var trackForActions: Track?
    @State private var pendingArtist: Artist?
    @State private var pendingTracklist: Tracklist?
    var navigationResetId: Int = 0
    @Binding var isAtNavigationRoot: Bool

    private var isSearchQueryEmpty: Bool {
        self.viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                self.toolbar
                ZStack(alignment: .top) {
                    if self.isSearchVisible {
                        self.searchResultsContent
                    } else {
                        self.sectionList
                    }
                    if self.isSearchVisible && !self.viewModel.availableLibraryCategories.isEmpty {
                        self.categoryBubblesBar
                    }
                }
            }
            .onChange(of: self.isSearchFieldFocused) { _, focused in
                if focused {
                    self.scrollHandler.showSearchBar = true
                } else if self.isSearchQueryEmpty {
                    self.viewModel.searchQuery = ""
                    withAnimation(.easeInOut(duration: 0.25)) { self.isSearchVisible = false }
                }
            }
            .onChange(of: self.viewModel.searchQuery) { _, query in
                self.trackFuzzyHandler.updateSearch(query, items: self.viewModel.categoryFilteredTracks)
                self.tracklistFuzzyHandler.updateSearch(query, items: self.viewModel.categoryFilteredTracklists)
            }
            .onChange(of: self.viewModel.selectedLibraryCategory) { _, category in
                self.trackFuzzyHandler.updateSearch("", items: [])
                self.tracklistFuzzyHandler.updateSearch("", items: [])
                let query = self.viewModel.searchQuery
                if category == .songs || category == .videos {
                    self.trackFuzzyHandler.updateSearch(query, items: self.viewModel.categoryFilteredTracks)
                } else {
                    self.tracklistFuzzyHandler.updateSearch(query, items: self.viewModel.categoryFilteredTracklists)
                }
            }
            .onAppear {
                self.viewModel.loadSources()
                self.isAtNavigationRoot = true
            }
            .onDisappear {
                self.isAtNavigationRoot = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceAdded)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceRemoved)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceEnabled)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mediaSourceDisabled)) { _ in
                self.viewModel.loadSources()
            }
            .onReceive(NotificationCenter.default.publisher(for: .tracklistPinChanged)) { _ in
                self.viewModel.loadPinnedTracklists()
            }
            .sheet(isPresented: self.$viewModel.showFilterSheet) {
                MediaSourcePickerSheet(
                    mediaSources: self.viewModel.mediaSources,
                    mediaSourcePickerMode: .multi(selectedMediaSourceIds: self.$viewModel.visibleMediaSourceIds)
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGray6))
            }
            .sheet(item: self.$trackForActions) { track in
                if let mediaSource = self.viewModel.mediaSources.first(where: { $0.id == track.mediaSourceId }) {
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
                if let mediaSource = self.viewModel.mediaSources.first(where: { $0.id == artist.mediaSourceId }) {
                    ArtistDetailView(artist: artist, mediaSource: mediaSource)
                }
            }
            .navigationDestination(item: self.$pendingTracklist) { tracklist in
                TracklistView(
                    tracklist: Tracklist(
                        mediaId: tracklist.mediaId,
                        mediaSourceId: tracklist.mediaSourceId,
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
        .id(self.navigationResetId)
    }

    @ViewBuilder
    private var toolbar: some View {
        if self.isSearchVisible {
            LibrarySearchToolbarView(
                searchQuery: self.$viewModel.searchQuery,
                isSearchFieldFocused: self.$isSearchFieldFocused,
                isFuzzySearching: self.trackFuzzyHandler.isFuzzySearching || self.tracklistFuzzyHandler.isFuzzySearching,
                selectedCategory: self.viewModel.selectedLibraryCategory,
                onClear: {
                    if !self.isSearchFieldFocused {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.isSearchVisible = false
                        }
                    }
                }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
        } else {
            HStack {
                Text("Library")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Button {
                    self.viewModel.showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 20))
                        .foregroundColor(.purp)
                }
                .accessibilityLabel("Filter")
                .accessibilityHint("Filter library by media source")
                Spacer()
                Button {
                    self.viewModel.loadAllContent()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.isSearchVisible = true
                    }
                    self.isSearchFieldFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.purp)
                }
                .accessibilityLabel("Search Library")
                .accessibilityHint("Search your library")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .transition(.opacity)
        }
    }

    private var categoryBubblesBar: some View {
        CategoryBubblesBar(
            categories: self.viewModel.availableLibraryCategories,
            selectedCategory: self.viewModel.selectedLibraryCategory,
            scrollHandler: self.scrollHandler,
            isFocused: self.isSearchFieldFocused,
            highlightSelectedWhenFocused: true,
            onSelect: { category in
                self.viewModel.selectedLibraryCategory = category
            }
        )
    }

    private var sectionList: some View {
        ScrollFadeView {
            List {
                self.pinnedHeader
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)

                if self.viewModel.isPinnedExpanded {
                    if self.viewModel.pinnedTracklists.isEmpty {
                        Image(systemName: "zzz")
                            .font(.system(size: 20))
                            .foregroundColor(Color(.systemGray3))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.leading, 76)
                            .padding(.trailing, 16)
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(Array(self.viewModel.pinnedTracklists.enumerated()), id: \.element.id) { _, stored in
                            TracklistRow(
                                tracklist: Tracklist(storedTracklist: stored),
                                showMediaSourceIcon: true,
                                showChevron: true
                            )
                            .background(
                                NavigationLink(destination: TracklistView(tracklist: Tracklist(storedTracklist: stored))) { EmptyView() }
                                    .opacity(0)
                            )
                            .listRowBackground(Color.black)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                        }
                    }
                }

                ForEach(LibraryViewModel.LibrarySection.allCases, id: \.self) { section in
                    self.sectionButton(section)
                }
            }
            .listStyle(.plain)
            // .padding(.top, -10)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var searchResultsContent: some View {
        let isEmpty: Bool = {
            if self.viewModel.selectedLibraryCategory == .songs || self.viewModel.selectedLibraryCategory == .videos {
                return self.trackFuzzyHandler.filteredItems?.isEmpty == true && !self.trackFuzzyHandler.isFuzzySearching
            } else {
                return self.tracklistFuzzyHandler.filteredItems?.isEmpty == true && !self.tracklistFuzzyHandler.isFuzzySearching
            }
        }()

        return ZStack(alignment: .top) {
            ScrollFadeView {
                List {
                    Color.black
                        .frame(height: categoryBubblesBarHeight)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)

                    self.searchResultRows
                }
                .listStyle(.plain)
                .padding(.top, -10)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .modifier(ScrollDirectionTracker(
                    isEnabled: true,
                    onScrollChange: { oldInfo, newInfo in
                        self.scrollHandler.handleScrollChange(
                            oldInfo: oldInfo,
                            newInfo: newInfo,
                            isSearchFieldFocused: self.isSearchFieldFocused
                        )
                    }
                ))
            }

            if isEmpty {
                self.emptySearchState
            }
        }
    }

    @ViewBuilder
    private var searchResultRows: some View {
        if self.viewModel.selectedLibraryCategory == .songs || self.viewModel.selectedLibraryCategory == .videos {
            if let tracks = self.trackFuzzyHandler.filteredItems, !tracks.isEmpty {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, stored in
                    TrackRow(
                        track: stored.toTrack(),
                        isSelected: PlaybackService.shared.currentTrack?.url == stored.url &&
                            stored.url != nil &&
                            PlaybackService.shared.currentContextId == "library",
                        isLoading: PlaybackService.shared.isLoading,
                        isPlaying: PlaybackService.shared.isPlaying,
                        onTap: {
                            let queue = tracks.map { $0.toTrack() }
                            PlaybackService.shared.playTrack(stored.toTrack(), queue: queue, startingAt: index, contextId: "library")
                        },
                        onEllipsisTap: {
                            self.isSearchFieldFocused = false
                            self.trackForActions = TracklistStorageService.shared.loadTrackWithRelations(stored)
                        }
                    )
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            }
        } else {
            if let tracklists = self.tracklistFuzzyHandler.filteredItems, !tracklists.isEmpty {
                ForEach(tracklists, id: \.id) { stored in
                    TracklistRow(
                        tracklist: Tracklist(storedTracklist: stored),
                        showMediaSourceIcon: true,
                        showChevron: true
                    )
                    .background(
                        NavigationLink(destination: TracklistView(tracklist: Tracklist(storedTracklist: stored))) { EmptyView() }
                            .opacity(0)
                    )
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    private var emptySearchState: some View {
        Image(systemName: "zzz")
            .font(.system(size: 40))
            .foregroundColor(Color(.systemGray5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .ignoresSafeArea()
    }

    private var pinnedHeader: some View {
        Button {
            withAnimation {
                self.viewModel.isPinnedExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.purp)
                    .frame(width: 48, height: 48)
                Text("Pinned")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Image(systemName: self.viewModel.isPinnedExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.systemGray))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(self.viewModel.isPinnedExpanded ? "Pinned, expanded" : "Pinned, collapsed")
        .accessibilityHint(self.viewModel.isPinnedExpanded ? "Collapse pinned section" : "Expand pinned section")
    }

    private func sectionButton(_ section: LibraryViewModel.LibrarySection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: section.icon)
                .font(.system(size: 16))
                .foregroundColor(.purp)
                .frame(width: 48, height: 48)

            Text(section.displayName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.purp)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .contentShape(Rectangle())
        .background(
            NavigationLink(destination: self.destinationView(for: section)) { EmptyView() }
                .opacity(0)
        )
        .listRowBackground(Color.black)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        .accessibilityLabel(section.displayName)
        .accessibilityHint("Open \(section.displayName)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func destinationView(for section: LibraryViewModel.LibrarySection) -> some View {
        let visibleIds = self.viewModel.visibleMediaSourceStringIds
        switch section {
        case .likes:
            TracklistView(
                tracklist: Tracklist(
                    mediaId: "likes",
                    mediaSourceId: "boppa.app",
                    title: "Likes",
                    tracklistType: .likes
                )
            )
        case .playlists:
            TracklistListView(type: .playlists, title: "Playlists", visibleMediaSourceIds: visibleIds)
        case .albums:
            TracklistListView(type: .albums, title: "Albums", visibleMediaSourceIds: visibleIds)
        }
    }
}

#Preview {
    LibraryView(isAtNavigationRoot: .constant(true))
        .preferredColorScheme(.dark)
}
