import Foundation
import SQLiteData

@Table("tracklists")
nonisolated struct StoredTracklist {
    @Column(primaryKey: true) var mediaId: String
    var mediaSourceId: String
    var title: String
    var subtitle: String?
    var artworkUrl: String?
    var tracklistType: String
    var metadataJSON: Data
    var fromArtistMediaId: String?
    var isPinned: Bool
    var isSavedToLibrary: Bool
    var prevMediaId: String?
    var prevMediaSourceId: String?
    var nextMediaId: String?
    var nextMediaSourceId: String?
}

extension StoredTracklist: Identifiable {
    var id: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }
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
