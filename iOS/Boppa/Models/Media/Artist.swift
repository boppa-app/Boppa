import Foundation

struct Artist: Identifiable, Equatable, Hashable {
    let id: UUID
    let mediaId: String
    let mediaSourceId: String
    let name: String
    let artworkUrl: String?
    let url: String?
    let metadata: [String: Any]

    init(
        mediaId: String,
        mediaSourceId: String,
        name: String,
        artworkUrl: String? = nil,
        url: String? = nil,
        metadata: [String: Any] = [:]
    ) {
        self.id = UUID()
        self.mediaId = mediaId
        self.mediaSourceId = mediaSourceId
        self.name = name
        self.artworkUrl = artworkUrl
        self.url = url
        self.metadata = metadata
    }

    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.mediaId == rhs.mediaId
            && lhs.mediaSourceId == rhs.mediaSourceId
            && lhs.name == rhs.name
            && lhs.artworkUrl == rhs.artworkUrl
            && lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.mediaId)
    }
}
