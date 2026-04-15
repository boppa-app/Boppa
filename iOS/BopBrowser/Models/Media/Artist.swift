import Foundation

struct Artist: Identifiable, Equatable, Hashable {
    let id: String
    let mediaSourceName: String
    let name: String
    let artworkUrl: String?
    let url: String?
    let metadata: [String: Any]

    init(
        id: String,
        mediaSourceName: String,
        name: String,
        artworkUrl: String? = nil,
        url: String? = nil,
        metadata: [String: Any] = [:]
    ) {
        self.id = id
        self.mediaSourceName = mediaSourceName
        self.name = name
        self.artworkUrl = artworkUrl
        self.url = url
        self.metadata = metadata
    }

    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.id == rhs.id
            && lhs.mediaSourceName == rhs.mediaSourceName
            && lhs.name == rhs.name
            && lhs.artworkUrl == rhs.artworkUrl
            && lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}
