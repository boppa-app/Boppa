import Foundation
import SwiftData

@Model
final class StoredSong {
    var title: String
    var artist: String?
    var duration: Int?
    var artworkUrl: String?
    var url: String?
    var mediaSourceName: String?
    var metadataJSON: Data
    var sortOrder: Int

    @Relationship(inverse: \StoredTracklist.songs)
    var tracklist: StoredTracklist?

    var metadata: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: self.metadataJSON)) ?? [:]
    }

    init(
        title: String,
        artist: String? = nil,
        duration: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        mediaSourceName: String? = nil,
        metadata: [String: String] = [:],
        sortOrder: Int = 0
    ) {
        self.title = title
        self.artist = artist
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.url = url
        self.mediaSourceName = mediaSourceName
        self.metadataJSON = (try? JSONEncoder().encode(metadata)) ?? Data()
        self.sortOrder = sortOrder
    }

    func toSong() -> Song {
        Song(
            title: self.title,
            artist: self.artist,
            duration: self.duration,
            artworkUrl: self.artworkUrl,
            url: self.url,
            mediaSourceName: self.mediaSourceName,
            metadata: self.metadata
        )
    }

    static func from(_ song: Song, sortOrder: Int) -> StoredSong {
        StoredSong(
            title: song.title,
            artist: song.artist,
            duration: song.duration,
            artworkUrl: song.artworkUrl,
            url: song.url,
            mediaSourceName: song.mediaSourceName,
            metadata: song.metadata,
            sortOrder: sortOrder
        )
    }

    func contentMatches(_ song: Song) -> Bool {
        self.title == song.title
            && self.artist == song.artist
            && self.duration == song.duration
            && self.artworkUrl == song.artworkUrl
            && self.url == song.url
            && self.mediaSourceName == song.mediaSourceName
            && self.metadata == song.metadata
    }
}
