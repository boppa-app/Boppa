import Foundation
import SwiftData

@Model
final class StoredTrack {
    var id: String
    var mediaSourceId: String
    var title: String
    var subtitle: String?
    var duration: Int?
    var artworkUrl: String?
    var url: String?
    var metadataJSON: Data
    var artistsJSON: Data = Data()
    var albumsJSON: Data = Data()
    var sortOrder: Int

    @Relationship(inverse: \StoredTracklist.tracks)
    var tracklist: StoredTracklist?

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
                id: id,
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
                id: id,
                mediaSourceId: self.mediaSourceId,
                title: title,
                subtitle: data["subtitle"] as? String,
                artworkUrl: data["artworkUrl"] as? String,
                metadata: data["metadata"] as? [String: Any] ?? [:],
                tracklistType: .album
            )
        }
    }

    init(
        id: String,
        mediaSourceId: String,
        title: String,
        subtitle: String? = nil,
        duration: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        metadata: [String: Any] = [:],
        artists: [Artist] = [],
        albums: [Tracklist] = [],
        sortOrder: Int = 0
    ) {
        self.id = id
        self.mediaSourceId = mediaSourceId
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.url = url
        self.metadataJSON = (try? JSONSerialization.data(withJSONObject: metadata)) ?? Data()
        self.artistsJSON = StoredTrack.encodeArtists(artists)
        self.albumsJSON = StoredTrack.encodeAlbums(albums)
        self.sortOrder = sortOrder
    }

    func toTrack() -> Track {
        Track(
            id: self.id,
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

    static func from(_ track: Track, sortOrder: Int) -> StoredTrack {
        StoredTrack(
            id: track.id,
            mediaSourceId: track.mediaSourceId,
            title: track.title,
            subtitle: track.subtitle,
            duration: track.duration,
            artworkUrl: track.artworkUrl,
            url: track.url,
            metadata: track.metadata,
            artists: track.artists,
            albums: track.albums,
            sortOrder: sortOrder
        )
    }

    func identityMatches(_ track: Track) -> Bool {
        self.title == track.title
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

    func updateContent(from track: Track) {
        self.duration = track.duration
        self.artworkUrl = track.artworkUrl
        self.metadataJSON = (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
        self.artistsJSON = StoredTrack.encodeArtists(track.artists)
        self.albumsJSON = StoredTrack.encodeAlbums(track.albums)
    }

    private static func encodeArtists(_ artists: [Artist]) -> Data {
        guard !artists.isEmpty else { return Data() }
        let raw: [[String: Any]] = artists.map { artist in
            var data: [String: Any] = ["id": artist.id, "name": artist.name]
            if let artworkUrl = artist.artworkUrl { data["artworkUrl"] = artworkUrl }
            if !artist.metadata.isEmpty { data["metadata"] = artist.metadata }
            return data
        }
        return (try? JSONSerialization.data(withJSONObject: raw)) ?? Data()
    }

    private static func encodeAlbums(_ albums: [Tracklist]) -> Data {
        guard !albums.isEmpty else { return Data() }
        let raw: [[String: Any]] = albums.map { album in
            var data: [String: Any] = ["id": album.id, "title": album.title]
            if let subtitle = album.subtitle { data["subtitle"] = subtitle }
            if let artworkUrl = album.artworkUrl { data["artworkUrl"] = artworkUrl }
            if !album.metadata.isEmpty { data["metadata"] = album.metadata }
            return data
        }
        return (try? JSONSerialization.data(withJSONObject: raw)) ?? Data()
    }
}
