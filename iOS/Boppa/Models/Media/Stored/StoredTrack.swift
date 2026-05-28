import Foundation
import SQLiteData

@Table("tracks")
nonisolated struct StoredTrack: Identifiable {
    let id: Int
    var mediaId: String
    var mediaSourceId: String
    var title: String
    var subtitle: String?
    var duration: Int?
    var artworkUrl: String?
    var url: String?
    var metadataJSON: Data
}

extension StoredTrack {
    var metadata: [String: Any] {
        (try? JSONSerialization.jsonObject(with: metadataJSON) as? [String: Any]) ?? [:]
    }

    func toTrack(artists: [Artist] = [], albums: [Tracklist] = []) -> Track {
        Track(
            mediaId: mediaId,
            mediaSourceId: mediaSourceId,
            title: title,
            subtitle: subtitle,
            duration: duration,
            artworkUrl: artworkUrl,
            url: url,
            artists: artists,
            albums: albums,
            metadata: metadata
        )
    }

    func identityMatches(_ track: Track) -> Bool {
        mediaId == track.mediaId
            && title == track.title
            && subtitle == track.subtitle
            && url == track.url
            && mediaSourceId == track.mediaSourceId
    }

    func contentMatches(_ track: Track, artists: [Artist] = [], albums: [Tracklist] = []) -> Bool {
        identityMatches(track)
            && duration == track.duration
            && artworkUrl == track.artworkUrl
            && NSDictionary(dictionary: metadata).isEqual(to: track.metadata)
            && artists == track.artists
            && albums == track.albums
    }
}
