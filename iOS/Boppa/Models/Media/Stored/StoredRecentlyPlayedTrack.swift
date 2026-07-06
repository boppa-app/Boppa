import Foundation
import SQLiteData

@Table("recentlyPlayedTracks")
nonisolated struct StoredRecentlyPlayedTrack {
    @Column(primaryKey: true) var mediaId: String
    var mediaSourceId: String
    var title: String
    var subtitle: String?
    var duration: Int?
    var artworkUrl: String?
    var url: String?
    var playedAt: Double
}

extension StoredRecentlyPlayedTrack: Identifiable {
    var id: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }
}

extension StoredRecentlyPlayedTrack {
    func toTrack() -> Track {
        Track(
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            title: self.title,
            subtitle: self.subtitle,
            duration: self.duration,
            artworkUrl: self.artworkUrl,
            url: self.url
        )
    }
}
