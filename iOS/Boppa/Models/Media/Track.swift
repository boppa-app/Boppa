import Foundation

struct Track: Identifiable, Equatable {
    let id: UUID
    let mediaId: String
    let mediaSourceId: String
    let title: String
    let subtitle: String?
    let duration: Int?
    let lowResArtworkUrl: String?
    let highResArtworkUrl: String?
    let url: String?
    let type: TrackType
    let artists: [Artist]
    let albums: [Tracklist]

    enum TrackType: String, Equatable, Hashable {
        case song
        case video
    }

    var trackKey: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }

    init(
        mediaId: String,
        mediaSourceId: String,
        title: String,
        subtitle: String? = nil,
        duration: Int? = nil,
        lowResArtworkUrl: String? = nil,
        highResArtworkUrl: String? = nil,
        url: String? = nil,
        type: TrackType = .song,
        artists: [Artist] = [],
        albums: [Tracklist] = []
    ) {
        self.init(
            id: UUID(),
            mediaId: mediaId,
            mediaSourceId: mediaSourceId,
            title: title,
            subtitle: subtitle,
            duration: duration,
            lowResArtworkUrl: lowResArtworkUrl,
            highResArtworkUrl: highResArtworkUrl,
            url: url,
            type: type,
            artists: artists,
            albums: albums
        )
    }

    private init(
        id: UUID,
        mediaId: String,
        mediaSourceId: String,
        title: String,
        subtitle: String?,
        duration: Int?,
        lowResArtworkUrl: String?,
        highResArtworkUrl: String?,
        url: String?,
        type: TrackType,
        artists: [Artist],
        albums: [Tracklist]
    ) {
        self.id = id
        self.mediaId = mediaId
        self.mediaSourceId = mediaSourceId
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.lowResArtworkUrl = lowResArtworkUrl
        self.highResArtworkUrl = highResArtworkUrl
        self.url = url
        self.type = type
        self.artists = artists
        self.albums = albums
    }

    /// Preserves `id` so SwiftUI identity is stable when enriching an
    /// already-playing track with fuller metadata from a get.song/get.video call.
    func merging(fetched: Track) -> Track {
        Track(
            id: self.id,
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            title: fetched.title,
            subtitle: fetched.subtitle ?? self.subtitle,
            duration: fetched.duration ?? self.duration,
            lowResArtworkUrl: fetched.lowResArtworkUrl ?? self.lowResArtworkUrl,
            highResArtworkUrl: fetched.highResArtworkUrl ?? self.highResArtworkUrl,
            url: fetched.url ?? self.url,
            type: self.type,
            artists: fetched.artists.isEmpty ? self.artists : fetched.artists,
            albums: fetched.albums.isEmpty ? self.albums : fetched.albums
        )
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.mediaId == rhs.mediaId
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.duration == rhs.duration
            && lhs.lowResArtworkUrl == rhs.lowResArtworkUrl
            && lhs.highResArtworkUrl == rhs.highResArtworkUrl
            && lhs.url == rhs.url
            && lhs.mediaSourceId == rhs.mediaSourceId
            && lhs.type == rhs.type
            && lhs.artists == rhs.artists
            && lhs.albums == rhs.albums
    }

    var isMediaSourceEnabled: Bool {
        guard let source = MediaSourceStorageManager.shared.fetchOne(id: self.mediaSourceId) else {
            return false
        }
        return source.isEnabled
    }

    var resolvedLowResArtworkUrl: String? {
        self.albums.compactMap(\.lowResArtworkUrl).first ?? self.lowResArtworkUrl
    }

    var resolvedHighResArtworkUrl: String? {
        self.albums.compactMap(\.highResArtworkUrl).first ?? self.highResArtworkUrl
    }

    var displayHighResArtworkUrl: String? {
        self.resolvedHighResArtworkUrl ?? self.resolvedLowResArtworkUrl
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        return Track.formatTime(seconds: Double(duration) / 1000.0)
    }

    static func formatTime(seconds: Double) -> String {
        let totalSeconds = Int(max(seconds, 0))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

extension Track: FuzzySearchable {
    var fuzzyTitle: String {
        self.title
    }

    var fuzzySubtitle: String? {
        self.subtitle
    }
}
