import SwiftData
import SwiftUI

// TODO: Add search bar button to the top right and ensure the search bar is always visible when toggled (follows DetailHeaderView)

struct TracklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TracklistViewModel()
    @State private var showSortSheet = false

    let tracklist: Tracklist
    let source: MediaSource
    var fallbackTracks: [Track] = []

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(
                title: self.tracklist.name,
                highlightedTitle: self.tracklist.artist?.name,
                onBack: { self.dismiss() },
                trailing: {
                    if self.tracklist.isPersisted {
                        Button {
                            self.showSortSheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16))
                                .foregroundColor(self.viewModel.sortMode == .defaultOrder ? .white : .purp)
                        }
                        .frame(width: 44, height: 44)
                    }
                },
                centerTrailing: {
                    if self.tracklist.isPersisted {
                        self.refreshButton
                    }
                }
            )
            self.content
        }
        .navigationBarHidden(true)
        .onAppear {
            self.viewModel.fallbackTracks = self.fallbackTracks
            self.viewModel.load(
                tracklist: self.tracklist,
                source: self.source,
                modelContext: self.modelContext
            )
        }
        .sheet(isPresented: self.$showSortSheet) {
            SortPickerSheet(
                currentMode: self.viewModel.sortMode,
                onSelect: { mode in
                    self.viewModel.setSortMode(mode, tracklist: self.tracklist, modelContext: self.modelContext)
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
            self.viewModel.refresh(
                tracklist: self.tracklist,
                source: self.source,
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

    private var trackList: some View {
        ScrollFadeView {
            List {
                ForEach(Array(self.viewModel.displayTracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        self.playTrack(track)
                    } label: {
                        TrackRow(
                            track: track,
                            isSelected: PlaybackService.shared.currentTrack?.url == track.url && track.url != nil,
                            isLoading: PlaybackService.shared.isLoading,
                            isPlaying: PlaybackService.shared.isPlaying
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(index == self.viewModel.displayTracks.count - 1 && !self.viewModel.hasMorePages ? .clear : Color(.systemGray5))
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
        }
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

    private func playTrack(_ track: Track) {
        PlaybackService.shared.playTrack(track, queue: self.viewModel.displayTracks, mediaSource: self.source)
    }
}
