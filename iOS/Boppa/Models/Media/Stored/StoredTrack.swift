import Foundation
import SQLiteData

@Table("tracks")
nonisolated struct StoredTrack {
    @Column(primaryKey: true) var mediaId: String
    var mediaSourceId: String
    var title: String
    var subtitle: String?
    var duration: Int?
    var artworkUrl: String?
    var url: String?
    var lastPlayedTimestamp: Double? = nil
    var isRecent: Bool = false
}

extension StoredTrack: Identifiable {
    var id: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }
}

extension StoredTrack {
    var isMediaSourceEnabled: Bool {
        guard let source = MediaSourceStorageManager.shared.fetchOne(id: self.mediaSourceId) else {
            return false
        }
        return source.isEnabled
    }
}

extension StoredTrack: FuzzySearchable {
    var fuzzyTitle: String {
        self.title
    }

    var fuzzySubtitle: String? {
        self.subtitle
    }
}

extension StoredTrack {
    func toTrack(artists: [Artist] = [], albums: [Tracklist] = []) -> Track {
        Track(
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            title: self.title,
            subtitle: self.subtitle,
            duration: self.duration,
            artworkUrl: self.artworkUrl,
            url: self.url,
            artists: artists,
            albums: albums
        )
    }

    func identityMatches(_ track: Track) -> Bool {
        self.mediaId == track.mediaId
            && self.title == track.title
            && self.subtitle == track.subtitle
            && self.url == track.url
            && self.mediaSourceId == track.mediaSourceId
    }

    func contentMatches(_ track: Track, artists: [Artist] = [], albums: [Tracklist] = []) -> Bool {
        self.identityMatches(track)
            && self.duration == track.duration
            && self.artworkUrl == track.artworkUrl
            && artists == track.artists
            && albums == track.albums
    }
}
