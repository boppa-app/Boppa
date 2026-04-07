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

    var metadata: [String: Any] {
        guard let dict = try? JSONSerialization.jsonObject(with: self.metadataJSON) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    init(
        title: String,
        subtitle: String? = nil,
        duration: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        mediaSourceName: String? = nil,
        metadata: [String: Any] = [:],
        sortOrder: Int = 0
    ) {
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.url = url
        self.mediaSourceName = mediaSourceName
        self.metadataJSON = (try? JSONSerialization.data(withJSONObject: metadata)) ?? Data()
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

    func identityMatches(_ track: Track) -> Bool {
        self.title == track.title
            && self.subtitle == track.subtitle
            && self.url == track.url
            && self.mediaSourceName == track.mediaSourceName
    }

    func contentMatches(_ track: Track) -> Bool {
        self.identityMatches(track)
            && self.duration == track.duration
            && self.artworkUrl == track.artworkUrl
            && NSDictionary(dictionary: self.metadata).isEqual(to: track.metadata)
    }

    func updateContent(from track: Track) {
        self.duration = track.duration
        self.artworkUrl = track.artworkUrl
        self.metadataJSON = (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
    }
}
