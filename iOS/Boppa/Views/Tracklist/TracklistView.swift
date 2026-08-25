import SwiftUI

struct TracklistView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TracklistViewModel
    @State private var showActionSheet = false
    @State private var trackForActions: Track?
    @State private var scrollHandler = ScrollAwareVisibilityHandler()
    @State private var navigatingAwayHideOverlayButton = false
    var navigationReset: NavigationResetSignal
    init(tracklist: Tracklist, navigationReset: NavigationResetSignal = NavigationResetSignal()) {
        self._viewModel = State(initialValue: TracklistViewModel(tracklist: tracklist))
        self.navigationReset = navigationReset
    }

    private var isSaved: Bool {
        self.viewModel.isPersisted
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
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                DetailHeaderView(
                    title: self.viewModel.tracklist.title,
                    highlightedTitle: self.viewModel.tracklist.fromArtist?.name,
                    onBack: {
                        if self.viewModel.isEditing {
                            self.viewModel.exitEditMode()
                        } else {
                            self.navigatingAwayHideOverlayButton = true
                            self.dismiss()
                        }
                    },
                    trailing: {
                        HStack(spacing: 0) {
                            if self.viewModel.isEditing {
                                Image(systemName: "door.left.hand.open")
                                    .font(.system(size: 16))
                                    .foregroundColor(.purp)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        self.viewModel.exitEditMode()
                                    }
                                    .accessibilityLabel("Done Editing")
                                    .accessibilityHint("Exit edit mode")
                                    .accessibilityAddTraits(.isButton)
                            } else if self.isSaved {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16))
                                    .foregroundColor(.purp)
                                    .rotationEffect(.degrees(90))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        self.showActionSheet = true
                                    }
                                    .accessibilityLabel("More Options")
                                    .accessibilityHint("View options for this tracklist")
                                    .accessibilityAddTraits(.isButton)
                            } else if self.canSave {
                                Group {
                                    if self.viewModel.isSaving {
                                        SpinnerView(tint: .purp, lineWidth: 2)
                                            .frame(width: 14, height: 14)
                                            .accessibilityLabel("Saving to Library")
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
                                        self.viewModel.saveToLibrary()
                                    }
                                }
                                .accessibilityLabel("Save to Library")
                                .accessibilityHint("Save this tracklist to your library")
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                    },
                    centerTrailing: {
                        if self.viewModel.isRefreshing {
                            SpinnerView(lineWidth: 2)
                                .frame(width: 14, height: 14)
                        }
                    }
                )

                self.content
            }

            if self.isSaved && !self.viewModel.tracks.isEmpty {
                DetailHeaderOverlayButton(
                    systemImage: "shuffle",
                    accessibilityLabel: "Shuffle",
                    accessibilityHint: "Play this tracklist in shuffled order",
                    scrollHandler: self.scrollHandler,
                    isHidden: self.navigatingAwayHideOverlayButton || self.viewModel.isEditing,
                    action: { self.shuffleAndPlay() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
        .onChange(of: self.navigationReset.id) { _, _ in
            self.navigatingAwayHideOverlayButton = true
        }
        .onAppear {
            self.viewModel.load()
        }
        .sheet(isPresented: self.$showActionSheet) {
            TracklistActionSheet(
                tracklist: self.viewModel.tracklist,
                mediaSource: MediaSourceStorageManager.shared
                    .fetchOne(id: self.viewModel.tracklist.mediaSourceId),
                isMediaSourceEnabled: self.viewModel.tracklist.isMediaSourceEnabled,
                isPinned: self.viewModel.isPinned,
                isRefreshing: self.viewModel.isRefreshing,
                sortMode: self.viewModel.sortMode,
                onPin: {
                    self.viewModel.togglePin()
                },
                onRefresh: {
                    self.viewModel.refresh()
                },
                onSortSelected: { mode in
                    self.viewModel.setSortMode(mode)
                },
                onArtistSelected: nil,
                onDelete: {
                    self.viewModel.deleteFromLibrary()
                    self.dismiss()
                },
                onEdit: self.viewModel.canReorder ? { self.viewModel.enterEditMode() } : nil
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemGray6))
        }
        .sheet(item: self.$trackForActions) { track in
            if let mediaSource = MediaSourceStorageManager.shared
                .fetchOne(id: track.mediaSourceId)
            {
                TrackActionsSheet(
                    track: track,
                    mediaSource: mediaSource,
                    isMediaSourceEnabled: track.isMediaSourceEnabled,
                    onArtistSelected: { artist in
                        NotificationCenter.default.post(
                            name: .navigateToArtistInSearch,
                            object: artist
                        )
                    },
                    onAlbumSelected: { tracklist in postTracklistNavigation(tracklist) }
                )
            }
        }
    }

    private var content: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.tracks.isEmpty && self.viewModel.isLoading {
                SpinnerView(tint: Color(.systemGray), lineWidth: 4)
                    .frame(width: 40, height: 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.viewModel.displayTracks.isEmpty {
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
                ForEach(
                    Array(self.viewModel.displayTracks.enumerated()),
                    id: \.element.id
                ) { index, track in
                    HStack(spacing: 0) {
                        if self.viewModel.isEditing {
                            Button {
                                withAnimation {
                                    self.viewModel.removeTrack(track)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(track.title) from Playlist")
                            .accessibilityHint("Remove this track from the playlist")
                        }

                        TrackRow(
                            track: track,
                            isSelected: track.isMediaSourceEnabled && TrackQueueManager.shared
                                .isTrackSelected(
                                    track,
                                    contextId: self.contextId
                                ),
                            isLoading: PlaybackService.shared.isLoading,
                            isPlaying: PlaybackService.shared.isPlaying,
                            isMediaSourceEnabled: track.isMediaSourceEnabled,
                            showTrailingControls: !self.viewModel.isEditing,
                            onTap: {
                                guard !self.viewModel.isEditing else { return }
                                self.playTrack(track, at: index)
                            },
                            onEllipsisTap: {
                                self.trackForActions = track
                            }
                        )
                    }
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
                .onMove { source, destination in
                    self.viewModel.moveTrack(from: source, to: destination)
                }

                if self.viewModel.hasMorePages {
                    NextPageSpinnerView {
                        self.viewModel.loadNextPage()
                    }
                    .id(self.viewModel.pageLoadId)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(self.viewModel.isEditing ? .active : .inactive))
            .animation(.easeInOut(duration: 0.2), value: self.viewModel.isEditing)
            .modifier(ScrollDirectionTracker(
                isEnabled: true,
                onScrollChange: { oldInfo, newInfo in
                    self.scrollHandler.handleScrollChange(
                        oldInfo: oldInfo,
                        newInfo: newInfo,
                        isSearchFieldFocused: false
                    )
                }
            ))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "zzz")
                .font(.system(size: 40))
                .foregroundColor(Color(.systemGray5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ErrorMessageView(message: message)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contextId: String {
        "tracklist:\(self.viewModel.tracklist.mediaSourceId):\(self.viewModel.tracklist.mediaId)"
    }

    private func playTrack(_ track: Track, at index: Int) {
        TrackQueueManager.shared.setQueue(
            self.viewModel.displayTracks,
            startingAt: index,
            contextId: self.contextId
        )
        PlaybackService.shared.playTrack(track)
    }

    private func shuffleAndPlay() {
        let tracks = self.viewModel.displayTracks
        guard !tracks.isEmpty else { return }

        TrackQueueManager.shared.setQueue(
            tracks,
            startingAt: Int.random(in: tracks.indices),
            contextId: self.contextId
        )
        TrackQueueManager.shared.setShuffleMode(.shuffle)
        if let currentTrack = TrackQueueManager.shared.currentTrack {
            PlaybackService.shared.playTrack(currentTrack)
        }
    }
}
