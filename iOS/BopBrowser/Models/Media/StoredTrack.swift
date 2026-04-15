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

    var artists: [String: Artist] {
        guard !self.artistsJSON.isEmpty,
              let raw = try? JSONSerialization.jsonObject(with: self.artistsJSON) as? [String: [String: Any]]
        else { return [:] }
        var result: [String: Artist] = [:]
        for (name, data) in raw {
            guard let id = data["id"] as? String else { continue }
            result[name] = Artist(
                id: id,
                mediaSourceId: self.mediaSourceId,
                name: name,
                artworkUrl: data["artworkUrl"] as? String,
                metadata: data["metadata"] as? [String: Any] ?? [:]
            )
        }
        return result
    }

    var albums: [String: Tracklist] {
        guard !self.albumsJSON.isEmpty,
              let raw = try? JSONSerialization.jsonObject(with: self.albumsJSON) as? [String: [String: Any]]
        else { return [:] }
        var result: [String: Tracklist] = [:]
        for (name, data) in raw {
            guard let id = data["id"] as? String else { continue }
            result[name] = Tracklist(
                id: id,
                mediaSourceId: self.mediaSourceId,
                title: name,
                subtitle: data["subtitle"] as? String,
                artworkUrl: data["artworkUrl"] as? String,
                metadata: data["metadata"] as? [String: Any] ?? [:],
                tracklistType: .album
            )
        }
        return result
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
        artists: [String: Artist] = [:],
        albums: [String: Tracklist] = [:],
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

    private static func encodeArtists(_ artists: [String: Artist]) -> Data {
        guard !artists.isEmpty else { return Data() }
        var raw: [String: [String: Any]] = [:]
        for (name, artist) in artists {
            var data: [String: Any] = ["id": artist.id]
            if let artworkUrl = artist.artworkUrl { data["artworkUrl"] = artworkUrl }
            if !artist.metadata.isEmpty { data["metadata"] = artist.metadata }
            raw[name] = data
        }
        return (try? JSONSerialization.data(withJSONObject: raw)) ?? Data()
    }

    private static func encodeAlbums(_ albums: [String: Tracklist]) -> Data {
        guard !albums.isEmpty else { return Data() }
        var raw: [String: [String: Any]] = [:]
        for (name, album) in albums {
            var data: [String: Any] = ["id": album.id]
            if let subtitle = album.subtitle { data["subtitle"] = subtitle }
            if let artworkUrl = album.artworkUrl { data["artworkUrl"] = artworkUrl }
            if !album.metadata.isEmpty { data["metadata"] = album.metadata }
            raw[name] = data
        }
        return (try? JSONSerialization.data(withJSONObject: raw)) ?? Data()
    }
}
