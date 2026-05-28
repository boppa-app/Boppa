import Foundation
import SQLiteData

@Table("tracklists")
nonisolated struct StoredTracklist: Identifiable {
    let id: Int
    var mediaId: String
    var mediaSourceId: String
    var title: String
    var subtitle: String?
    var artworkUrl: String?
    var tracklistType: String
    var metadataJSON: Data
    var artistsJSON: Data
    var fromArtistJSON: Data
    var isPinned: Bool
    var prevId: Int?
    var nextId: Int?
}

extension StoredTracklist {
    func toTracklist() -> Tracklist {
        Tracklist(storedTracklist: self)
    }

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

    var fromArtist: Artist? {
        guard !self.fromArtistJSON.isEmpty,
              let data = try? JSONSerialization.jsonObject(with: self.fromArtistJSON) as? [String: Any],
              let id = data["id"] as? String,
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

    static func encodeArtist(_ artist: Artist?) -> Data {
        guard let artist else { return Data() }
        var data: [String: Any] = ["id": artist.mediaId, "name": artist.name]
        if let artworkUrl = artist.artworkUrl { data["artworkUrl"] = artworkUrl }
        if !artist.metadata.isEmpty { data["metadata"] = artist.metadata }
        return (try? JSONSerialization.data(withJSONObject: data)) ?? Data()
    }
}
