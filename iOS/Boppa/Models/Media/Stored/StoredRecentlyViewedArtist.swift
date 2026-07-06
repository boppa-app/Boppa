import Foundation
import SQLiteData

@Table("recentlyViewedArtists")
nonisolated struct StoredRecentlyViewedArtist {
    @Column(primaryKey: true) var mediaId: String
    var mediaSourceId: String
    var name: String
    var artworkUrl: String?
    var viewedAt: Double
}

extension StoredRecentlyViewedArtist: Identifiable {
    var id: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }
}

extension StoredRecentlyViewedArtist {
    func toArtist() -> Artist {
        Artist(
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            name: self.name,
            artworkUrl: self.artworkUrl
        )
    }
}
