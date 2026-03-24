import SwiftData
import SwiftUI

// TODO: Add search bar button to the top right and ensure the search bar is always visible when toggled (follows DetailHeaderView)

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PlaylistDetailViewModel()
    @State private var showSortSheet = false

    let playlist: StoredPlaylist
    let source: MediaSource

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.playlist.name,
                onBack: { self.dismiss() },
                trailing: {
                    Button {
                        self.showSortSheet = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16))
                            .foregroundColor(self.viewModel.sortMode == .defaultOrder ? .white : .purp)
                    }
                    .frame(width: 44, height: 44)
                },
                centerTrailing: {
                    self.refreshButton
                }
            )
            self.content
        }
        .navigationBarHidden(true)
        .onAppear {
            self.viewModel.fetchIfEmpty(
                playlist: self.playlist,
                config: self.source.config,
                mediaSourceName: self.source.name,
                modelContext: self.modelContext
            )
        }
        .sheet(isPresented: self.$showSortSheet) {
            SortPickerSheet(
                currentMode: self.viewModel.sortMode,
                onSelect: { mode in
                    self.viewModel.setSortMode(mode, playlist: self.playlist, modelContext: self.modelContext)
                    self.showSortSheet = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemGray6))
        }
    }

    private var content: some View {
        Group {
            if let errorMessage = self.viewModel.errorMessage {
                self.errorView(message: errorMessage)
            } else if self.viewModel.songs.isEmpty && self.viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if self.viewModel.songs.isEmpty {
                self.emptyState
            } else {
                self.songList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var refreshButton: some View {
        Button {
            self.viewModel.refresh(
                playlist: self.playlist,
                config: self.source.config,
                mediaSourceName: self.source.name,
                modelContext: self.modelContext
            )
        } label: {
            Group {
                if self.viewModel.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 20, height: 20)
        }
        .disabled(self.viewModel.isRefreshing)
    }

    private var songList: some View {
        List {
            ForEach(Array(self.viewModel.displaySongs.enumerated()), id: \.element.id) { index, song in
                Button {
                    self.playSong(song)
                } label: {
                    SongRow(
                        song: song,
                        isSelected: PlaybackService.shared.currentTrack?.url == song.url && song.url != nil,
                        isLoading: PlaybackService.shared.isLoading,
                        isPlaying: PlaybackService.shared.isPlaying
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparatorTint(index == self.viewModel.displaySongs.count - 1 ? .clear : Color(.systemGray5))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // TODO: Check if user is signed in and if not display button to go to settings to sign in to media source config
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

    private func playSong(_ song: Song) {
        PlaybackService.shared.playTrack(song, queue: self.viewModel.displaySongs, mediaSource: self.source)
    }
}
