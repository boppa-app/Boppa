import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "RecentsManager"
)

@MainActor
@Observable
class RecentsManager {
    var recentlyPlayed: [Track] = []
    var recentlyViewed: [RecentlyViewedItem] = []
    private(set) var hasLoadedOnce = false

    var recentlyPlayedEntries: [RecentlyPlayedEntry] {
        RecentlyPlayedEntry.grouping(self.recentlyPlayed)
    }

    private static let displayLimit = 10

    func load(mediaSourceId: String?) {
        self.loadRecentlyPlayed(mediaSourceId: mediaSourceId)
        self.loadRecentlyViewed(mediaSourceId: mediaSourceId)
        if !self.hasLoadedOnce {
            DispatchQueue.main.async {
                self.hasLoadedOnce = true
            }
        }
    }

    func loadRecentlyPlayed(mediaSourceId: String?) {
        guard let mediaSourceId else {
            if !self.recentlyPlayed.isEmpty { self.recentlyPlayed = [] }
            return
        }
        let played = RecentsStorageManager.shared.fetchRecentlyPlayed(
            mediaSourceId: mediaSourceId, limit: Self.displayLimit
        )
        let reordered = RecentlyPlayedEntry.flattenedOrder(played)
        if reordered != self.recentlyPlayed {
            self.recentlyPlayed = reordered
        }
    }

    func loadRecentlyViewed(mediaSourceId: String?) {
        guard let mediaSourceId else {
            if !self.recentlyViewed.isEmpty { self.recentlyViewed = [] }
            return
        }
        let viewed = RecentsStorageManager.shared.fetchRecentlyViewed(
            mediaSourceId: mediaSourceId, limit: Self.displayLimit
        )
        if viewed != self.recentlyViewed {
            self.recentlyViewed = viewed
        }
    }

    func popRecentlyPlayed(mediaSourceId: String) {
        guard let entry = self.recentlyPlayedEntries.first else { return }
        let trackToRemove: Track? =
            switch entry {
            case let .track(track): track
            case let .album(group): group.tracks.first
            }
        guard let trackToRemove else { return }

        RecentsStorageManager.shared.removeRecentlyPlayed(
            mediaIds: [trackToRemove.mediaId], mediaSourceId: mediaSourceId
        )
        self.recentlyPlayed.removeAll { $0.trackKey == trackToRemove.trackKey }
        logger.info("Popped most recently played track")
    }

    func popRecentlyViewed(mediaSourceId: String) {
        guard let item = self.recentlyViewed.first else { return }
        switch item {
        case let .artist(artist, _):
            RecentsStorageManager.shared.removeRecentlyViewedArtist(
                mediaId: artist.mediaId, mediaSourceId: mediaSourceId
            )
        case let .tracklist(tracklist, _):
            RecentsStorageManager.shared.removeRecentlyViewedTracklist(
                mediaId: tracklist.mediaId, mediaSourceId: mediaSourceId
            )
        }
        self.recentlyViewed.removeFirst()
        logger.info("Popped most recently viewed item")
    }
}
