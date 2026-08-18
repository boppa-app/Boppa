import SwiftUI

struct AddToPlaylistSheet: View {
    let track: Track
    var onBack: (() -> Void)?

    @State private var playlists: [StoredTracklist] = []
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            ZStack {
                Text("Add to Playlist")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                if let onBack = self.onBack {
                    HStack {
                        Button {
                            onBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.purp)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                        .accessibilityHint("Return to options")
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(height: 44)

            List {
                self.newPlaylistRow

                ForEach(self.playlists) { playlist in
                    self.playlistRow(playlist)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color(.systemGray6))
        .onAppear {
            self.playlists = TracklistStorageManager.shared.fetchPlaylists()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tracklistLibraryChanged)) { _ in
            self.playlists = TracklistStorageManager.shared.fetchPlaylists()
        }
        .alert("New Playlist", isPresented: self.$showNewPlaylistAlert) {
            TextField("Playlist Name", text: self.$newPlaylistName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                self.createPlaylist()
            }
            .tint(.purp)
            .disabled(self.newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var newPlaylistRow: some View {
        Button {
            self.newPlaylistName = ""
            self.showNewPlaylistAlert = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.purp)
                    .frame(width: 24)
                Text("New Playlist")
                    .font(.body)
                    .foregroundColor(.white)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.systemGray6))
        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
        .listRowSeparator(.hidden)
        .accessibilityLabel("New Playlist")
        .accessibilityHint("Create a new playlist")
    }

    private func playlistRow(_ playlist: StoredTracklist) -> some View {
        let isInPlaylist = PlaylistManager.shared.isInPlaylist(self.track, playlistId: playlist.mediaId)
        return Button {
            PlaylistManager.shared.togglePlaylist(self.track, playlistId: playlist.mediaId)
        } label: {
            ZStack(alignment: .trailing) {
                TracklistRow(
                    tracklist: Tracklist(storedTracklist: playlist),
                    placeholderBackground: .charcoal,
                    isSelected: isInPlaylist
                )
                if isInPlaylist {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purp)
                        .padding(.trailing, 16)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transaction { $0.disablesAnimations = true }
        .listRowBackground(Color(.systemGray6))
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        .accessibilityLabel(playlist.title)
        .accessibilityHint(isInPlaylist ? "Remove from \(playlist.title)" : "Add to \(playlist.title)")
    }

    private func createPlaylist() {
        let trimmed = self.newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        PlaylistManager.shared.createPlaylist(title: trimmed)
    }
}
