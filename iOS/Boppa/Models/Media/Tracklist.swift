import Foundation

struct Tracklist: Identifiable, Equatable, Hashable {
    let id: UUID
    let mediaId: String
    let mediaSourceId: String
    let title: String
    let subtitle: String?
    let year: Int?
    let trackCount: Int?
    let artworkUrl: String?
    let url: String?
    let tracklistType: TracklistType
    let fromArtist: Artist?
    let artistDetail: ArtistDetail?
    let storedTracklist: StoredTracklist?

    enum TracklistType: String, Equatable, Hashable {
        case album
        case playlist
        case artistSongs
        case artistVideos
        case likes
    }

    init(
        mediaId: String,
        mediaSourceId: String,
        title: String,
        subtitle: String? = nil,
        year: Int? = nil,
        trackCount: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        tracklistType: TracklistType,
        fromArtist: Artist? = nil,
        artistDetail: ArtistDetail? = nil,
        storedTracklist: StoredTracklist? = nil
    ) {
        self.id = UUID()
        self.mediaId = mediaId
        self.mediaSourceId = mediaSourceId
        self.title = title
        self.subtitle = subtitle
        self.year = year
        self.trackCount = trackCount
        self.artworkUrl = artworkUrl
        self.url = url
        self.tracklistType = tracklistType
        self.fromArtist = fromArtist
        self.artistDetail = artistDetail
        self.storedTracklist = storedTracklist
    }

    init(storedTracklist: StoredTracklist, fromArtist: Artist? = nil) {
        self.id = UUID()
        self.mediaId = storedTracklist.mediaId
        self.mediaSourceId = storedTracklist.mediaSourceId
        self.title = storedTracklist.title
        self.subtitle = storedTracklist.subtitle
        self.year = storedTracklist.year
        self.trackCount = nil
        self.artworkUrl = storedTracklist.artworkUrl
        self.url = nil
        self.tracklistType = TracklistType(rawValue: storedTracklist.tracklistType) ?? .playlist
        self.fromArtist = fromArtist
        self.artistDetail = nil
        self.storedTracklist = storedTracklist
    }

    static func == (lhs: Tracklist, rhs: Tracklist) -> Bool {
        lhs.mediaId == rhs.mediaId
            && lhs.mediaSourceId == rhs.mediaSourceId
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.trackCount == rhs.trackCount
            && lhs.artworkUrl == rhs.artworkUrl
            && lhs.url == rhs.url
            && lhs.tracklistType == rhs.tracklistType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.mediaId)
    }

    var isPersisted: Bool {
        self.storedTracklist?.isSavedToLibrary == true
    }

    var formattedTrackCount: String? {
        guard let trackCount else { return nil }
        return "\(trackCount) track\(trackCount == 1 ? "" : "s")"
    }
}

extension Tracklist: FuzzySearchable {
    var fuzzyTitle: String {
        self.title
    }

    var fuzzySubtitle: String? {
        self.subtitle
    }
}
