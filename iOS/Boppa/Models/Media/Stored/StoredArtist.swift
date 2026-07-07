import Foundation
import SQLiteData

@Table("artists")
nonisolated struct StoredArtist {
    @Column(primaryKey: true) var mediaId: String
    var mediaSourceId: String
    var name: String
    var artworkUrl: String?
    var lastViewedTimestamp: Double? = nil
    var isRecent: Bool = false
}

extension StoredArtist: Identifiable {
    var id: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }
}

extension StoredArtist {
    func toArtist() -> Artist {
        Artist(
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            name: self.name,
            artworkUrl: self.artworkUrl
        )
    }
}
