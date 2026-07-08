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
        if played != self.recentlyPlayed {
            self.recentlyPlayed = played
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

    func clearRecentlyPlayed(mediaSourceId: String) {
        RecentsStorageManager.shared.clearRecentlyPlayed(mediaSourceId: mediaSourceId)
        self.recentlyPlayed = []
        logger.info("Cleared recently played")
    }

    func clearRecentlyViewed(mediaSourceId: String) {
        RecentsStorageManager.shared.clearRecentlyViewed(mediaSourceId: mediaSourceId)
        self.recentlyViewed = []
        logger.info("Cleared recently viewed")
    }
}
