import Foundation

struct Artist: Identifiable, Equatable, Hashable {
    let id: UUID
    let mediaId: String
    let mediaSourceId: String
    let name: String
    let artworkUrl: String?
    let url: String?

    init(
        mediaId: String,
        mediaSourceId: String,
        name: String,
        artworkUrl: String? = nil,
        url: String? = nil
    ) {
        self.id = UUID()
        self.mediaId = mediaId
        self.mediaSourceId = mediaSourceId
        self.name = name
        self.artworkUrl = artworkUrl
        self.url = url
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
