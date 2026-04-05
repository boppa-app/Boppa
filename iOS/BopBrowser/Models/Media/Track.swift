import Foundation

struct Track: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String?
    let duration: Int?
    let artworkUrl: String?
    let url: String?
    let mediaSourceName: String?
    let artists: [String: [String: String]]
    let album: [String: [String: String]]
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        duration: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        mediaSourceName: String? = nil,
        artists: [String: [String: String]] = [:],
        album: [String: [String: String]] = [:],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.url = url
        self.mediaSourceName = mediaSourceName
        self.artists = artists
        self.album = album
        self.metadata = metadata
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
