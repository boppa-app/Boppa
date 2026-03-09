import Foundation

struct Artist: Identifiable, Equatable {
    let id: UUID
    let name: String
    let artworkUrl: String?
    let url: String?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        name: String,
        artworkUrl: String? = nil,
        url: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.artworkUrl = artworkUrl
        self.url = url
        self.metadata = metadata
    }
}
