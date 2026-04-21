import Foundation

struct Tracklist: Identifiable, Equatable, Hashable {
    let id: String
    let mediaSourceId: String
    let title: String
    let subtitle: String?
    let trackCount: Int?
    let artworkUrl: String?
    let url: String?
    let metadata: [String: Any]
    let tracklistType: TracklistType
    let artists: [Artist]
    let artist: Artist?
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
        id: String,
        mediaSourceId: String,
        title: String,
        subtitle: String? = nil,
        trackCount: Int? = nil,
        artworkUrl: String? = nil,
        url: String? = nil,
        metadata: [String: Any] = [:],
        tracklistType: TracklistType,
        artists: [Artist] = [],
        artist: Artist? = nil,
        artistDetail: ArtistDetail? = nil,
        storedTracklist: StoredTracklist? = nil
    ) {
        self.id = id
        self.mediaSourceId = mediaSourceId
        self.title = title
        self.subtitle = subtitle
        self.trackCount = trackCount
        self.artworkUrl = artworkUrl
        self.url = url
        self.metadata = metadata
        self.tracklistType = tracklistType
        self.artists = artists
        self.artist = artist
        self.artistDetail = artistDetail
        self.storedTracklist = storedTracklist
    }

    init(storedTracklist: StoredTracklist) {
        let mediaSourceId = storedTracklist.mediaSourceId
        self.id = storedTracklist.id
        self.mediaSourceId = mediaSourceId
        self.title = storedTracklist.name
        self.subtitle = storedTracklist.subtitle
        self.trackCount = nil
        self.artworkUrl = storedTracklist.artworkUrl
        self.url = nil
        self.metadata = storedTracklist.metadata
        self.tracklistType = TracklistType(rawValue: storedTracklist.tracklistType) ?? .playlist
        self.artists = storedTracklist.artists
        self.artist = nil
        self.artistDetail = nil
        self.storedTracklist = storedTracklist
    }

    static func == (lhs: Tracklist, rhs: Tracklist) -> Bool {
        lhs.id == rhs.id
            && lhs.mediaSourceId == rhs.mediaSourceId
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.trackCount == rhs.trackCount
            && lhs.artworkUrl == rhs.artworkUrl
            && lhs.url == rhs.url
            && lhs.tracklistType == rhs.tracklistType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    var isPersisted: Bool {
        self.storedTracklist != nil
    }

    var formattedTrackCount: String? {
        guard let trackCount else { return nil }
        return "\(trackCount) track\(trackCount == 1 ? "" : "s")"
    }
}
