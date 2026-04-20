import SwiftData
import SwiftUI

// TODO: Add search bar button to the top right and ensure the search bar is always visible when toggled (follows DetailHeaderView)

struct TracklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TracklistViewModel
    @State private var showSortSheet = false
    @State private var trackForActions: Track?
    @State private var pendingArtist: Artist?
    @State private var pendingTracklist: Tracklist?

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
                highlightedTitle: self.viewModel.tracklist.artist?.name,
                onBack: { self.dismiss() },
                centerLeading: {
                    if self.isSaved {
                        Button {
                            self.viewModel.togglePin(modelContext: self.modelContext)
                        } label: {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 14))
                                .foregroundColor(self.viewModel.isPinned ? .purp : .white)
                        }
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                    }
                },
                trailing: {
                    HStack(spacing: 0) {
                        if self.isSaved {
                            Button {
                                self.showSortSheet = true
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 16))
                                    .foregroundColor(self.viewModel.sortMode == .defaultOrder ? .white : .purp)
                            }
                            .frame(width: 44, height: 44)
                        } else if self.canSave {
                            Button {
                                self.viewModel.saveToLibrary(modelContext: self.modelContext)
                            } label: {
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
                            }
                            .frame(width: 44, height: 44)
                            .disabled(self.viewModel.isSaving)
                        }
                    }
                },
                centerTrailing: {
                    if self.viewModel.canRefresh {
                        self.refreshButton
                    }
                }
            )
            self.content
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
        .onAppear {
            self.viewModel.load(modelContext: self.modelContext)
        }
        .sheet(isPresented: self.$showSortSheet) {
            SortPickerSheet(
                currentMode: self.viewModel.sortMode,
                onSelect: { mode in
                    self.viewModel.setSortMode(mode, modelContext: self.modelContext)
                    self.showSortSheet = false
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
            } else if self.viewModel.tracks.isEmpty {
                self.emptyState
            } else {
                self.trackList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var refreshButton: some View {
        Button {
            self.viewModel.refresh(modelContext: self.modelContext)
        } label: {
            Group {
                if self.viewModel.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.purp)
                }
            }
            .frame(width: 20, height: 20)
        }
        .disabled(self.viewModel.isRefreshing)
    }

    private var trackList: some View {
        ScrollFadeView {
            List {
                ForEach(Array(self.viewModel.displayTracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        isSelected: PlaybackService.shared.currentTrack?.url == track.url && track.url != nil,
                        isLoading: PlaybackService.shared.isLoading,
                        isPlaying: PlaybackService.shared.isPlaying,
                        onTap: { self.playTrack(track) },
                        onEllipsisTap: { self.trackForActions = track }
                    )
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(index == self.viewModel.displayTracks.count - 1 && !self.viewModel.hasMorePages ? .clear : Color(.systemGray5))
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
    }

    private func playTrack(_ track: Track) {
        guard let mediaSource = TracklistService.shared.resolveMediaSource(mediaSourceId: track.mediaSourceId, modelContext: self.modelContext) else { return }
        PlaybackService.shared.playTrack(track, queue: self.viewModel.displayTracks, mediaSource: mediaSource)
    }
}
