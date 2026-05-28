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
        (try? JSONSerialization.jsonObject(with: metadataJSON) as? [String: Any]) ?? [:]
    }

    func toArtist() -> Artist {
        Artist(
            mediaId: mediaId,
            mediaSourceId: mediaSourceId,
            name: name,
            artworkUrl: artworkUrl,
            metadata: metadata
        )
    }
}
