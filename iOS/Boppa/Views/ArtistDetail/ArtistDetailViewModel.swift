import Foundation
import os

extension Notification.Name {
    static let artistLibraryChanged = Notification.Name("artistLibraryChanged")
}

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "ArtistDetailViewModel"
)

@MainActor
@Observable
class ArtistDetailViewModel {
    var detail: ArtistDetail?
    var isLoading = false
    var errorMessage: String?
    var isSaved = false

    private var fetchTask: Task<Void, Never>?
    private var currentArtist: Artist?

    @ObservationIgnored
    private var observers: [NSObjectProtocol] = []

    init() {
        self.observers.append(
            NotificationCenter.default.addObserver(
                forName: .artistLibraryChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, let artist = self.currentArtist else { return }
                self.isSaved = ArtistStorageManager.shared.isArtistSaved(
                    mediaId: artist.mediaId,
                    mediaSourceId: artist.mediaSourceId
                )
            }
        )
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func load(
        artist: Artist,
        mediaSource: StoredMediaSource
    ) {
        self.currentArtist = artist
        self.isSaved = ArtistStorageManager.shared.isArtistSaved(
            mediaId: artist.mediaId,
            mediaSourceId: artist.mediaSourceId
        )

        guard self.detail == nil else { return }
        self.fetch(artist: artist, mediaSource: mediaSource)
    }

    func saveToLibrary() {
        guard let artist = self.currentArtist else { return }
        do {
            try ArtistStorageManager.shared.saveArtistToLibrary(artist)
            self.isSaved = true
            NotificationCenter.default.post(name: .artistLibraryChanged, object: nil)
            logger.info("Saved artist '\(artist.name)' to library")
        } catch {
            self.errorMessage = error.localizedDescription
            logger.error("Failed to save artist '\(artist.name)': \(error.localizedDescription)")
        }
    }

    func removeFromLibrary() {
        guard let artist = self.currentArtist else { return }
        do {
            try ArtistStorageManager.shared.removeArtistFromLibrary(
                mediaId: artist.mediaId,
                mediaSourceId: artist.mediaSourceId
            )
            self.isSaved = false
            NotificationCenter.default.post(name: .artistLibraryChanged, object: nil)
            logger.info("Removed artist '\(artist.name)' from library")
        } catch {
            self.errorMessage = error.localizedDescription
            logger.error("Failed to remove artist '\(artist.name)': \(error.localizedDescription)")
        }
    }

    private func fetch(
        artist: Artist,
        mediaSource: StoredMediaSource
    ) {
        self.fetchTask?.cancel()
        self.isLoading = true
        self.errorMessage = nil

        self.fetchTask = Task {
            do {
                let result = try await TracklistFetchService.shared.fetchArtist(
                    artist: artist,
                    mediaSource: mediaSource
                )

                guard !Task.isCancelled else { return }

                self.detail = result
                self.isLoading = false

                RecentsStorageManager.shared.recordViewedArtist(artist.merging(detail: result))

                logger
                    .info(
                        "Loaded artist '\(artist.name)': \(result.songs?.count ?? 0) song(s), \(result.albums?.count ?? 0) album(s), \(result.videos?.count ?? 0) video(s), \(result.playlists?.count ?? 0) playlist(s)"
                    )
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger
                    .error(
                        "Fetch failed for artist '\(artist.name)': \(error.localizedDescription)"
                    )
            }
        }
    }
}
