import Foundation
import SQLiteData

@Table("tracklists")
nonisolated struct StoredTracklist: Identifiable {
    let id: Int
    var mediaId: String
    var mediaSourceId: String
    var title: String
    var subtitle: String?
    var artworkUrl: String?
    var tracklistType: String
    var metadataJSON: Data
    var fromArtistId: Int?
    var isPinned: Bool
    var prevId: Int?
    var nextId: Int?
}

extension StoredTracklist {
    var metadata: [String: Any] {
        (try? JSONSerialization.jsonObject(with: self.metadataJSON) as? [String: Any]) ?? [:]
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
