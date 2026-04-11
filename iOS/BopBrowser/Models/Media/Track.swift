import Foundation

struct Track: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let duration: Int?
    let artworkUrl: String?
    let url: String?
    let mediaSourceName: String?
    let artists: [String: Artist]
    let albums: [String: Album]
    let metadata: [String: Any]

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        duration: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        mediaSourceName: String? = nil,
        artists: [String: Artist] = [:],
        albums: [String: Album] = [:],
        metadata: [String: Any] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.url = url
        self.mediaSourceName = mediaSourceName
        self.artists = artists
        self.albums = albums
        self.metadata = metadata
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.duration == rhs.duration
            && lhs.artworkUrl == rhs.artworkUrl
            && lhs.url == rhs.url
            && lhs.mediaSourceName == rhs.mediaSourceName
            && lhs.artists == rhs.artists
            && lhs.albums == rhs.albums
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
