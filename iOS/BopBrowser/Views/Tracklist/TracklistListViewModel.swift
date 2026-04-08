import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "TracklistListViewModel"
)

@MainActor
@Observable
class TracklistListViewModel {
    var albums: [Album] = []
    var playlists: [Playlist] = []
    var isLoading = false
    var errorMessage: String?

    private var fetchTask: Task<Void, Never>?
    private var didLoad = false

    func load(
        artist: Artist,
        artistDetail: ArtistDetail,
        source: MediaSource
    ) {
        guard !self.didLoad else { return }
        self.didLoad = true

        if source.config.data?.getPlaylistsForArtist != nil {
            self.fetchPlaylists(artist: artist, artistDetail: artistDetail, source: source)
        } else {
            self.fetchAlbums(artist: artist, artistDetail: artistDetail, source: source)
        }
    }

    private func fetchAlbums(
        artist: Artist,
        artistDetail: ArtistDetail,
        source: MediaSource
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let result = try await TracklistService.shared.fetchAlbumsForArtist(
                    artist: artist,
                    artistDetail: artistDetail,
                    mediaSource: source
                )

                guard !Task.isCancelled else { return }

                self.albums = result
                self.isLoading = false

                logger.info("Loaded \(self.albums.count) album(s) for artist '\(artist.name)'")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger.error("Fetch albums failed for artist '\(artist.name)': \(error.localizedDescription)")
            }
        }
    }

    private func fetchPlaylists(
        artist: Artist,
        artistDetail: ArtistDetail,
        source: MediaSource
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let result = try await TracklistService.shared.fetchPlaylistsForArtist(
                    artist: artist,
                    artistDetail: artistDetail,
                    mediaSource: source
                )

                guard !Task.isCancelled else { return }

                self.playlists = result
                self.isLoading = false

                logger.info("Loaded \(self.playlists.count) playlist(s) for artist '\(artist.name)'")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger.error("Fetch playlists failed for artist '\(artist.name)': \(error.localizedDescription)")
            }
        }
    }
}
