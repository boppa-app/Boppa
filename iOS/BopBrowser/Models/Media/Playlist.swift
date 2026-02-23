import Foundation

struct Playlist: Identifiable, Equatable {
    let id: UUID
    let title: String
    let user: String
    let trackCount: Int
    let artworkUrl: String?
    let url: String

    init(
        id: UUID = UUID(),
        title: String,
        user: String,
        trackCount: Int,
        artworkUrl: String?,
        url: String
    ) {
        self.id = id
        self.title = title
        self.user = user
        self.trackCount = trackCount
        self.artworkUrl = artworkUrl
        self.url = url
    }

    var formattedTrackCount: String {
        "\(self.trackCount) track\(self.trackCount == 1 ? "" : "s")"
    }
}
