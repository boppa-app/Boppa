import SwiftData
import SwiftUI

private struct ScrollInfo: Equatable {
    var contentOffset: CGFloat
    var contentHeight: CGFloat
    var containerHeight: CGFloat
}

private struct ScrollDirectionTracker: ViewModifier {
    let isEnabled: Bool
    let onScrollChange: (_ oldInfo: ScrollInfo, _ newInfo: ScrollInfo) -> Void

    func body(content: Content) -> some View {
        if self.isEnabled {
            if #available(iOS 18.0, *) {
                content
                    .onScrollGeometryChange(for: ScrollInfo.self) { geometry in
                        ScrollInfo(
                            contentOffset: geometry.contentOffset.y,
                            contentHeight: geometry.contentSize.height,
                            containerHeight: geometry.visibleRect.height
                        )
                    } action: { oldInfo, newInfo in
                        self.onScrollChange(oldInfo, newInfo)
                    }
            } else {
                content
            }
        } else {
            content
        }
    }
}

struct TracklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TracklistViewModel
    @State private var showActionSheet = false
    @State private var trackForActions: Track?
    @State private var pendingArtist: Artist?
    @State private var pendingTracklist: Tracklist?
    @State private var searchText = ""
    @State private var showSearchBar = true
    @FocusState private var isSearchFieldFocused: Bool
    @State private var accumulatedScrollDelta: CGFloat = 0

    init(tracklist: Tracklist) {
        self._viewModel = State(initialValue: TracklistViewModel(tracklist: tracklist))
    }

    private var isSaved: Bool {
        self.viewModel.tracklist.isPersisted
    }

    private var canSave: Bool {
        switch self.viewModel.tracklist.tracklistType {
        case .playlist, .album:
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.viewModel.tracklist.title,
                highlightedTitle: self.viewModel.tracklist.fromArtist?.name,
                onBack: { self.dismiss() },
                trailing: {
                    HStack(spacing: 0) {
                        if self.isSaved {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16))
                                .foregroundColor(.purp)
                                .rotationEffect(.degrees(90))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    self.showActionSheet = true
                                }
                        } else if self.canSave {
                            Group {
                                if self.viewModel.isSaving {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bookmark")
                                        .font(.system(size: 18))
                                        .foregroundColor(.purp)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !self.viewModel.isSaving {
                                    self.viewModel.saveToLibrary(modelContext: self.modelContext)
                                }
                            }
                        }
                    }
                },
                centerTrailing: {
                    if self.viewModel.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    }
                },
                searchText: self.isSaved ? self.$searchText : nil,
                showSearchBar: self.isSaved ? self.$showSearchBar : nil,
                searchPlaceholder: "Search tracks",
                isSearchFieldFocused: self.isSaved ? self.$isSearchFieldFocused : nil
            )

            self.content
                .contentShape(Rectangle())
                .onTapGesture {
                    self.isSearchFieldFocused = false
                }
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
        .onAppear {
            self.viewModel.load(modelContext: self.modelContext)
        }
        .sheet(isPresented: self.$showActionSheet) {
            TracklistActionSheet(
                tracklist: self.viewModel.tracklist,
                mediaSource: TracklistService.shared.resolveMediaSource(mediaSourceId: self.viewModel.tracklist.mediaSourceId, modelContext: self.modelContext),
                isPinned: self.viewModel.isPinned,
                isRefreshing: self.viewModel.isRefreshing,
                sortMode: self.viewModel.sortMode,
                onPin: {
                    self.viewModel.togglePin(modelContext: self.modelContext)
                },
                onRefresh: {
                    self.viewModel.refresh(modelContext: self.modelContext)
                },
                onSortSelected: { mode in
                    self.viewModel.setSortMode(mode, modelContext: self.modelContext)
                },
                onArtistSelected: { artist in self.pendingArtist = artist },
                onDelete: {
                    self.viewModel.deleteFromLibrary(modelContext: self.modelContext)
                    self.dismiss()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemGray6))
        }
        .sheet(item: self.$trackForActions) { track in
            if let mediaSource = TracklistService.shared.resolveMediaSource(mediaSourceId: track.mediaSourceId, modelContext: self.modelContext) {
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
            if let mediaSource = TracklistService.shared.resolveMediaSource(mediaSourceId: self.viewModel.tracklist.mediaSourceId, modelContext: self.modelContext) {
                ArtistDetailView(artist: artist, mediaSource: mediaSource)
            }
        }
        .navigationDestination(item: self.$pendingTracklist) { tracklist in
            TracklistView(
                tracklist: Tracklist(
                    id: tracklist.id,
                    mediaSourceId: tracklist.mediaSourceId,
                    title: tracklist.title,
                    subtitle: tracklist.subtitle,
                    artworkUrl: tracklist.artworkUrl,
                    metadata: tracklist.metadata,
                    tracklistType: tracklist.tracklistType,
                    artists: tracklist.artists,
                    storedTracklist: TracklistService.shared.findStoredTracklist(id: tracklist.id, modelContext: self.modelContext)
                )
            )
        }
    }

    private var content: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.tracks.isEmpty && self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.isSearchFieldFocused = false
                    }
            } else if self.viewModel.tracks.isEmpty {
                self.emptyState
            } else {
                self.trackList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trackList: some View {
        ScrollFadeView {
            List {
                ForEach(Array(self.viewModel.displayTracks.enumerated()), id: \.element.id) { _, track in
                    TrackRow(
                        track: track,
                        isSelected: PlaybackService.shared.currentTrack?.url == track.url && track.url != nil,
                        isLoading: PlaybackService.shared.isLoading,
                        isPlaying: PlaybackService.shared.isPlaying,
                        onTap: {
                            self.isSearchFieldFocused = false
                            self.playTrack(track)
                        },
                        onEllipsisTap: {
                            self.isSearchFieldFocused = false
                            self.trackForActions = track
                        }
                    )
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }

                if self.viewModel.hasMorePages {
                    ProgressView()
                        .id(self.viewModel.pageLoadId)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .onAppear {
                            self.viewModel.loadNextPage(modelContext: self.modelContext)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .modifier(ScrollDirectionTracker(
                isEnabled: self.isSaved,
                onScrollChange: self.handleScrollChange
            ))
        }
    }

    // TODO: Place StoredSearchToolbar on top of list, add padding to the top of the list
    private func handleScrollChange(oldInfo: ScrollInfo, newInfo: ScrollInfo) {
        let isScrollable = newInfo.contentHeight > newInfo.containerHeight + 50
        guard isScrollable else { return }

        let delta = newInfo.contentOffset - oldInfo.contentOffset
        let scrollThreshold: CGFloat = 50

        // Always show when at or near the top
        if newInfo.contentOffset <= 0 {
            self.accumulatedScrollDelta = 0
            if !self.showSearchBar {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showSearchBar = true
                }
            }
            return
        }

        // Accumulate delta in the same direction, reset if direction changes
        if (delta > 0 && self.accumulatedScrollDelta < 0) || (delta < 0 && self.accumulatedScrollDelta > 0) {
            self.accumulatedScrollDelta = 0
        }
        
        self.accumulatedScrollDelta += delta

        // Hide on accumulated scroll down exceeds threshold
        if self.accumulatedScrollDelta > scrollThreshold {
            if self.showSearchBar {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showSearchBar = false
                }
                self.accumulatedScrollDelta = 0
            }
        }
        // Show on accumulated scroll up exceeds threshold
        else if self.accumulatedScrollDelta < -scrollThreshold {
            if !self.showSearchBar {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.showSearchBar = true
                }
                self.accumulatedScrollDelta = 0
            }
        }
    }

    // TODO: Check if user is signed in and if not display button to go to settings to sign in to media mediaSource config
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
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
                .foregroundColor(.red)
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

    private func playTrack(_ track: Track) {
        guard let mediaSource = TracklistService.shared.resolveMediaSource(mediaSourceId: track.mediaSourceId, modelContext: self.modelContext) else { return }
        PlaybackService.shared.playTrack(track, queue: self.viewModel.displayTracks, mediaSource: mediaSource)
    }
}
