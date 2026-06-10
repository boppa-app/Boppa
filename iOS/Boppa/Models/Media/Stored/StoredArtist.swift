import Foundation
import SQLiteData

@Table("artists")
nonisolated struct StoredArtist {
    @Column(primaryKey: true) var mediaId: String
    var mediaSourceId: String
    var name: String
    var artworkUrl: String?
    var metadataJSON: Data
}

extension StoredArtist: Identifiable {
    var id: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }
}

extension StoredArtist {
    var metadata: [String: Any] {
        (try? JSONSerialization.jsonObject(with: self.metadataJSON) as? [String: Any]) ?? [:]
    }

    func toArtist() -> Artist {
        Artist(
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            name: self.name,
            artworkUrl: self.artworkUrl,
            metadata: self.metadata
        )
    }
}
