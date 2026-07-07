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
    var type: String
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
            type: Track.TrackType(rawValue: self.type) ?? .song,
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
            && self.type == track.type.rawValue
    }

    func contentMatches(_ track: Track, artists: [StoredArtist] = [], albums: [StoredTracklist] = []) -> Bool {
        self.identityMatches(track)
            && self.duration == track.duration
            && self.artworkUrl == track.artworkUrl
            && Self.artistsContentMatch(artists, track.artists)
            && Self.albumsContentMatch(albums, track.albums)
    }

    private static func artistsContentMatch(_ stored: [StoredArtist], _ incoming: [Artist]) -> Bool {
        guard stored.count == incoming.count else { return false }
        return zip(stored, incoming).allSatisfy { $0.contentMatches($1) }
    }

    private static func albumsContentMatch(_ stored: [StoredTracklist], _ incoming: [Tracklist]) -> Bool {
        guard stored.count == incoming.count else { return false }
        return zip(stored, incoming).allSatisfy { $0.contentMatches($1) }
    }
}
