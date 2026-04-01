import Foundation
import SwiftData

@Model
final class StoredTrack {
    var title: String
    var subtitle: String?
    var duration: Int?
    var artworkUrl: String?
    var url: String?
    var mediaSourceName: String?
    var metadataJSON: Data
    var sortOrder: Int

    @Relationship(inverse: \StoredTracklist.tracks)
    var tracklist: StoredTracklist?

    var metadata: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: self.metadataJSON)) ?? [:]
    }

    init(
        title: String,
        subtitle: String? = nil,
        duration: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        mediaSourceName: String? = nil,
        metadata: [String: String] = [:],
        sortOrder: Int = 0
    ) {
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.url = url
        self.mediaSourceName = mediaSourceName
        self.metadataJSON = (try? JSONEncoder().encode(metadata)) ?? Data()
        self.sortOrder = sortOrder
    }

    func toTrack() -> Track {
        Track(
            title: self.title,
            subtitle: self.subtitle,
            duration: self.duration,
            artworkUrl: self.artworkUrl,
            url: self.url,
            mediaSourceName: self.mediaSourceName,
            metadata: self.metadata
        )
    }

    static func from(_ track: Track, sortOrder: Int) -> StoredTrack {
        StoredTrack(
            title: track.title,
            subtitle: track.subtitle,
            duration: track.duration,
            artworkUrl: track.artworkUrl,
            url: track.url,
            mediaSourceName: track.mediaSourceName,
            metadata: track.metadata,
            sortOrder: sortOrder
        )
    }

    func contentMatches(_ track: Track) -> Bool {
        self.title == track.title
            && self.subtitle == track.subtitle
            && self.duration == track.duration
            && self.artworkUrl == track.artworkUrl
            && self.url == track.url
            && self.mediaSourceName == track.mediaSourceName
            && self.metadata == track.metadata
    }
}
