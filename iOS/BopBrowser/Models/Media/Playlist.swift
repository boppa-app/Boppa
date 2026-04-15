import Foundation

struct Playlist: Identifiable, Equatable {
    let id: String
    let mediaSourceId: String
    let title: String
    let user: String?
    let trackCount: Int?
    let artworkUrl: String?
    let url: String?
    let metadata: [String: Any]

    init(
        id: String,
        mediaSourceId: String,
        title: String,
        user: String? = nil,
        trackCount: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        metadata: [String: Any] = [:]
    ) {
        self.id = id
        self.mediaSourceId = mediaSourceId
        self.title = title
        self.user = user
        self.trackCount = trackCount
        self.artworkUrl = artworkUrl
        self.url = url
        self.metadata = metadata
    }

    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
            && lhs.mediaSourceId == rhs.mediaSourceId
            && lhs.title == rhs.title
            && lhs.user == rhs.user
            && lhs.trackCount == rhs.trackCount
            && lhs.artworkUrl == rhs.artworkUrl
            && lhs.url == rhs.url
    }

    var formattedTrackCount: String? {
        guard let trackCount else { return nil }
        return "\(trackCount) track\(trackCount == 1 ? "" : "s")"
    }
}
