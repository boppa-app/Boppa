import Foundation
import SQLiteData

@Table("artists")
nonisolated struct StoredArtist: Identifiable {
    let id: Int
    var mediaId: String
    var mediaSourceId: String
    var name: String
    var artworkUrl: String?
    var metadataJSON: Data
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
