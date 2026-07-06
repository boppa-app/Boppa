import Foundation
import SQLiteData

@Table("recentlyViewedTracklists")
nonisolated struct StoredRecentlyViewedTracklist {
    @Column(primaryKey: true) var mediaId: String
    var mediaSourceId: String
    var title: String
    var subtitle: String?
    var artworkUrl: String?
    var tracklistType: String
    var viewedAt: Double
}

extension StoredRecentlyViewedTracklist: Identifiable {
    var id: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }
}

extension StoredRecentlyViewedTracklist {
    func toTracklist() -> Tracklist {
        Tracklist(
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            title: self.title,
            subtitle: self.subtitle,
            artworkUrl: self.artworkUrl,
            tracklistType: Tracklist.TracklistType(rawValue: self.tracklistType) ?? .playlist
        )
    }
}
