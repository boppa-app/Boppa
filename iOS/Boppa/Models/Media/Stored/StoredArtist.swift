import Foundation
import SQLiteData

@Table("artists")
nonisolated struct StoredArtist {
    @Column(primaryKey: true) var mediaId: String
    var mediaSourceId: String
    var name: String
    var lowResArtworkUrl: String?
    var highResArtworkUrl: String?
    var url: String?
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
            lowResArtworkUrl: self.lowResArtworkUrl,
            highResArtworkUrl: self.highResArtworkUrl,
            url: self.url
        )
    }

    func contentMatches(_ artist: Artist) -> Bool {
        self.mediaId == artist.mediaId
            && self.mediaSourceId == artist.mediaSourceId
            && Self.fieldMatches(stored: self.name, incoming: artist.name)
            && Self.fieldMatches(stored: self.lowResArtworkUrl, incoming: artist.lowResArtworkUrl)
            && Self.fieldMatches(stored: self.highResArtworkUrl, incoming: artist.highResArtworkUrl)
            && Self.fieldMatches(stored: self.url, incoming: artist.url)
    }

    private static func fieldMatches(stored: String, incoming: String) -> Bool {
        incoming.isEmpty || stored == incoming
    }

    private static func fieldMatches<T: Equatable>(stored: T?, incoming: T?) -> Bool {
        incoming == nil || stored == incoming
    }
}
