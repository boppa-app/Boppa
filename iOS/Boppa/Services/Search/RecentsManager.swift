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

    private static let displayLimit = 10

    func load(mediaSourceId: String?) {
        guard let mediaSourceId else {
            self.recentlyPlayed = []
            self.recentlyViewed = []
            return
        }
        self.recentlyPlayed = RecentsStorageManager.shared.fetchRecentlyPlayed(mediaSourceId: mediaSourceId, limit: Self.displayLimit)
        self.recentlyViewed = RecentsStorageManager.shared.fetchRecentlyViewed(mediaSourceId: mediaSourceId, limit: Self.displayLimit)
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
