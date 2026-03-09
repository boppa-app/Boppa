import Foundation

struct Playlist: Identifiable, Equatable {
    let id: UUID
    let title: String
    let user: String?
    let trackCount: Int?
    let artworkUrl: String?
    let url: String?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        title: String,
        user: String? = nil,
        trackCount: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.user = user
        self.trackCount = trackCount
        self.artworkUrl = artworkUrl
        self.url = url
        self.metadata = metadata
    }

    var formattedTrackCount: String? {
        guard let trackCount else { return nil }
        return "\(trackCount) track\(trackCount == 1 ? "" : "s")"
    }
}
