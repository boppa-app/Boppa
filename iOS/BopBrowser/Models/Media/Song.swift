import Foundation

struct Song: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String?
    let duration: Int?
    let artworkUrl: String?
    let url: String?
    let mediaSourceName: String?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        title: String,
        artist: String? = nil,
        duration: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        mediaSourceName: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.url = url
        self.mediaSourceName = mediaSourceName
        self.metadata = metadata
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        return Song.formatTime(seconds: Double(duration) / 1000.0)
    }

    static func formatTime(seconds: Double) -> String {
        let totalSeconds = Int(max(seconds, 0))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
