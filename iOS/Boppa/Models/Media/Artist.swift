import Foundation

struct Artist: Identifiable, Equatable, Hashable {
    let id: UUID
    let mediaId: String
    let mediaSourceId: String
    let name: String
    let lowResArtworkUrl: String?
    let highResArtworkUrl: String?
    let url: String?

    init(
        mediaId: String,
        mediaSourceId: String,
        name: String,
        lowResArtworkUrl: String? = nil,
        highResArtworkUrl: String? = nil,
        url: String? = nil
    ) {
        self.id = UUID()
        self.mediaId = mediaId
        self.mediaSourceId = mediaSourceId
        self.name = name
        self.lowResArtworkUrl = lowResArtworkUrl
        self.highResArtworkUrl = highResArtworkUrl
        self.url = url
    }

    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.mediaId == rhs.mediaId
            && lhs.mediaSourceId == rhs.mediaSourceId
            && lhs.name == rhs.name
            && lhs.lowResArtworkUrl == rhs.lowResArtworkUrl
            && lhs.highResArtworkUrl == rhs.highResArtworkUrl
            && lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.mediaId)
    }

    func merging(detail: ArtistDetail) -> Artist {
        guard let artwork = detail.albums?.first(where: {
            $0.lowResArtworkUrl != nil || $0.highResArtworkUrl != nil
        })
        else { return self }

        return Artist(
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            name: self.name,
            lowResArtworkUrl: artwork.lowResArtworkUrl ?? self.lowResArtworkUrl,
            highResArtworkUrl: artwork.highResArtworkUrl ?? self.highResArtworkUrl,
            url: self.url
        )
    }
}
