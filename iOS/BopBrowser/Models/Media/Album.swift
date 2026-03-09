import Foundation

struct Album: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String?
    let trackCount: Int?
    let artworkUrl: String?
    let url: String?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        title: String,
        artist: String? = nil,
        trackCount: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.artist = artist
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
