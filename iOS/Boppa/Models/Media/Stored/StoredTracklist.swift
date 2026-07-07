import Foundation
import SQLiteData

@Table("tracklists")
nonisolated struct StoredTracklist {
    @Column(primaryKey: true) var mediaId: String
    var mediaSourceId: String
    var title: String
    var subtitle: String?
    var year: Int?
    var artworkUrl: String?
    var url: String?
    var trackCount: Int?
    var tracklistType: String
    var isPinned: Bool
    var isSavedToLibrary: Bool
    var sortOrder: String
    var lastViewedTimestamp: Double? = nil
    var isRecent: Bool = false
}

extension StoredTracklist: Identifiable {
    var id: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }
}

extension StoredTracklist {
    var isMediaSourceEnabled: Bool {
        guard let source = MediaSourceStorageManager.shared.fetchOne(id: self.mediaSourceId) else {
            return false
        }
        return source.isEnabled
    }
}

extension StoredTracklist: FuzzySearchable {
    var fuzzyTitle: String {
        self.title
    }

    var fuzzySubtitle: String? {
        self.subtitle
    }
}

extension StoredTracklist {
    func contentMatches(_ tracklist: Tracklist) -> Bool {
        self.mediaId == tracklist.mediaId
            && self.mediaSourceId == tracklist.mediaSourceId
            && Self.fieldMatches(stored: self.title, incoming: tracklist.title)
            && Self.fieldMatches(stored: self.subtitle, incoming: tracklist.subtitle)
            && Self.fieldMatches(stored: self.artworkUrl, incoming: tracklist.artworkUrl)
            && Self.fieldMatches(stored: self.url, incoming: tracklist.url)
            && Self.fieldMatches(stored: self.trackCount, incoming: tracklist.trackCount)
    }

    private static func fieldMatches(stored: String, incoming: String) -> Bool {
        incoming.isEmpty || stored == incoming
    }

    private static func fieldMatches<T: Equatable>(stored: T?, incoming: T?) -> Bool {
        incoming == nil || stored == incoming
    }
}
