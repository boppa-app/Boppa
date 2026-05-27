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
    var artistsJSON: Data
    var albumsJSON: Data
}

extension StoredTrack {
    var metadata: [String: Any] {
        guard let dict = try? JSONSerialization.jsonObject(with: self.metadataJSON) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    var artists: [Artist] {
        guard !self.artistsJSON.isEmpty,
              let raw = try? JSONSerialization.jsonObject(with: self.artistsJSON) as? [[String: Any]]
        else { return [] }
        return raw.compactMap { data in
            guard let id = data["id"] as? String,
                  let name = data["name"] as? String
            else { return nil }
            return Artist(
                mediaId: id,
                mediaSourceId: self.mediaSourceId,
                name: name,
                artworkUrl: data["artworkUrl"] as? String,
                metadata: data["metadata"] as? [String: Any] ?? [:]
            )
        }
    }

    var albums: [Tracklist] {
        guard !self.albumsJSON.isEmpty,
              let raw = try? JSONSerialization.jsonObject(with: self.albumsJSON) as? [[String: Any]]
        else { return [] }
        return raw.compactMap { data in
            guard let id = data["id"] as? String,
                  let title = data["title"] as? String
            else { return nil }
            return Tracklist(
                mediaId: id,
                mediaSourceId: self.mediaSourceId,
                title: title,
                subtitle: data["subtitle"] as? String,
                artworkUrl: data["artworkUrl"] as? String,
                metadata: data["metadata"] as? [String: Any] ?? [:],
                tracklistType: .album
            )
        }
    }

    func toTrack() -> Track {
        Track(
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            title: self.title,
            subtitle: self.subtitle,
            duration: self.duration,
            artworkUrl: self.artworkUrl,
            url: self.url,
            artists: self.artists,
            albums: self.albums,
            metadata: self.metadata
        )
    }

    func identityMatches(_ track: Track) -> Bool {
        self.mediaId == track.mediaId
            && self.title == track.title
            && self.subtitle == track.subtitle
            && self.url == track.url
            && self.mediaSourceId == track.mediaSourceId
    }

    func contentMatches(_ track: Track) -> Bool {
        self.identityMatches(track)
            && self.duration == track.duration
            && self.artworkUrl == track.artworkUrl
            && NSDictionary(dictionary: self.metadata).isEqual(to: track.metadata)
            && self.artists == track.artists
            && self.albums == track.albums
    }

    static func encodeArtists(_ artists: [Artist]) -> Data {
        guard !artists.isEmpty else { return Data() }
        let raw: [[String: Any]] = artists.map { artist in
            var data: [String: Any] = ["id": artist.mediaId, "name": artist.name]
            if let artworkUrl = artist.artworkUrl { data["artworkUrl"] = artworkUrl }
            if !artist.metadata.isEmpty { data["metadata"] = artist.metadata }
            return data
        }
        return (try? JSONSerialization.data(withJSONObject: raw)) ?? Data()
    }

    static func encodeAlbums(_ albums: [Tracklist]) -> Data {
        guard !albums.isEmpty else { return Data() }
        let raw: [[String: Any]] = albums.map { album in
            var data: [String: Any] = ["id": album.mediaId, "title": album.title]
            if let subtitle = album.subtitle { data["subtitle"] = subtitle }
            if let artworkUrl = album.artworkUrl { data["artworkUrl"] = artworkUrl }
            if !album.metadata.isEmpty { data["metadata"] = album.metadata }
            return data
        }
        return (try? JSONSerialization.data(withJSONObject: raw)) ?? Data()
    }
}
