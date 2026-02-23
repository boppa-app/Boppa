import Foundation

struct Artist: Identifiable, Equatable {
    let id: UUID
    let name: String
    let artworkUrl: String?
    let url: String

    init(
        id: UUID = UUID(),
        name: String,
        artworkUrl: String?,
        url: String
    ) {
        self.id = id
        self.name = name
        self.artworkUrl = artworkUrl
        self.url = url
    }
}
