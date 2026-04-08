import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "ArtistDetailViewModel"
)

@MainActor
@Observable
class ArtistDetailViewModel {
    var detail: ArtistDetail?
    var isLoading = false
    var errorMessage: String?

    private var fetchTask: Task<Void, Never>?

    func load(
        artist: Artist,
        source: MediaSource
    ) {
        guard self.detail == nil else { return }
        self.fetch(artist: artist, source: source)
    }

    private func fetch(
        artist: Artist,
        source: MediaSource
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let result = try await TracklistService.shared.fetchArtist(
                    artist: artist,
                    mediaSource: source
                )

                guard !Task.isCancelled else { return }

                self.detail = result
                self.isLoading = false

                logger.info("Loaded artist '\(artist.name)': \(result.songs?.count ?? 0) song(s), \(result.albums?.count ?? 0) album(s), \(result.videos?.count ?? 0) video(s), \(result.playlists?.count ?? 0) playlist(s)")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger.error("Fetch failed for artist '\(artist.name)': \(error.localizedDescription)")
            }
        }
    }
}
