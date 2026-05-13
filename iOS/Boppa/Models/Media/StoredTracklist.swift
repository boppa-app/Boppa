import Foundation
import SwiftData

@Model
final class StoredTracklist {
    var id: String
    var name: String
    var subtitle: String?
    var mediaSourceId: String
    var artworkUrl: String?
    var tracklistType: String
    var metadataJSON: Data = Data()
    var artistsJSON: Data = Data()
    var fromArtistJSON: Data = Data()
    var isPinned: Bool = false
    var prevId: String?
    var nextId: String?

    @Relationship(deleteRule: .cascade)
    var tracks: [StoredTrack] = []

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

    var fromArtist: Artist? {
        guard !self.fromArtistJSON.isEmpty,
              let data = try? JSONSerialization.jsonObject(with: self.fromArtistJSON) as? [String: Any],
              let id = data["id"] as? String,
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

    init(
        id: String,
        name: String,
        subtitle: String? = nil,
        mediaSourceId: String,
        artworkUrl: String? = nil,
        tracklistType: String,
        metadata: [String: Any] = [:],
        artists: [Artist] = [],
        fromArtist: Artist? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.mediaSourceId = mediaSourceId
        self.artworkUrl = artworkUrl
        self.tracklistType = tracklistType
        self.metadataJSON = (try? JSONSerialization.data(withJSONObject: metadata)) ?? Data()
        self.artistsJSON = StoredTracklist.encodeArtists(artists)
        self.fromArtistJSON = StoredTracklist.encodeArtist(fromArtist)
    }

    var trackCount: Int {
        self.tracks.count
    }

    static func encodeArtists(_ artists: [Artist]) -> Data {
        guard !artists.isEmpty else { return Data() }
        let raw: [[String: Any]] = artists.map { artist in
            var data: [String: Any] = ["id": artist.id, "name": artist.name]
            if let artworkUrl = artist.artworkUrl { data["artworkUrl"] = artworkUrl }
            if !artist.metadata.isEmpty { data["metadata"] = artist.metadata }
            return data
        }
        return (try? JSONSerialization.data(withJSONObject: raw)) ?? Data()
    }

    static func encodeArtist(_ artist: Artist?) -> Data {
        guard let artist else { return Data() }
        var data: [String: Any] = ["id": artist.id, "name": artist.name]
        if let artworkUrl = artist.artworkUrl { data["artworkUrl"] = artworkUrl }
        if !artist.metadata.isEmpty { data["metadata"] = artist.metadata }
        return (try? JSONSerialization.data(withJSONObject: data)) ?? Data()
    }
}
