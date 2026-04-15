import Foundation

struct Album: Identifiable, Equatable, Hashable {
    let id: String
    let mediaSourceName: String
    let title: String
    let subtitle: String?
    let trackCount: Int?
    let artworkUrl: String?
    let url: String?
    let metadata: [String: Any]

    init(
        id: String,
        mediaSourceName: String,
        title: String,
        subtitle: String? = nil,
        trackCount: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        metadata: [String: Any] = [:]
    ) {
        self.id = id
        self.mediaSourceName = mediaSourceName
        self.title = title
        self.subtitle = subtitle
        self.trackCount = trackCount
        self.artworkUrl = artworkUrl
        self.url = url
        self.metadata = metadata
    }

    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
            && lhs.mediaSourceName == rhs.mediaSourceName
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.trackCount == rhs.trackCount
            && lhs.artworkUrl == rhs.artworkUrl
            && lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    var formattedTrackCount: String? {
        guard let trackCount else { return nil }
        return "\(trackCount) track\(trackCount == 1 ? "" : "s")"
    }
}
