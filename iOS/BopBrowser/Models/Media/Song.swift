import Foundation

struct Song: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let duration: Int
    let artworkUrl: String?
    let url: String

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        duration: Int,
        artworkUrl: String?,
        url: String
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.url = url
    }

    var formattedDuration: String {
        let totalSeconds = self.duration / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
