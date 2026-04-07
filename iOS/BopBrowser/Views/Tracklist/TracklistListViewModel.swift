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
    var isLoading = false
    var errorMessage: String?
    var fallbackAlbums: [Album] = []

    private var fetchTask: Task<Void, Never>?
    private var didLoad = false

    func load(
        artist: Artist,
        artistDetail: ArtistDetail,
        source: MediaSource,
        preloadedAlbums: [Album]?
    ) {
        guard !self.didLoad else { return }
        self.didLoad = true

        if let preloadedAlbums {
            self.albums = preloadedAlbums
            logger.info("Using \(preloadedAlbums.count) preloaded album(s) for artist '\(artist.name)'")
        } else {
            self.fetch(artist: artist, artistDetail: artistDetail, source: source)
        }
    }

    private func fetch(
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

                self.albums = result.isEmpty ? self.fallbackAlbums : result
                self.isLoading = false

                logger.info("Loaded \(self.albums.count) album(s) for artist '\(artist.name)'\(result.isEmpty && !self.fallbackAlbums.isEmpty ? " (fallback)" : "")")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger.error("Fetch albums failed for artist '\(artist.name)': \(error.localizedDescription)")
            }
        }
    }
}
