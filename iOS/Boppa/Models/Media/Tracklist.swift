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
        self.trackCount = storedTracklist.trackCount
        self.artworkUrl = storedTracklist.artworkUrl
        self.url = storedTracklist.url
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

    var isMediaSourceEnabled: Bool {
        guard let source = MediaSourceStorageManager.shared.fetchOne(id: self.mediaSourceId) else {
            return false
        }
        return source.isEnabled
    }

    var formattedTrackCount: String? {
        guard let trackCount else { return nil }
        return "\(trackCount) track\(trackCount == 1 ? "" : "s")"
    }

    func merging(fetched: any TracklistMetadata) -> Tracklist {
        Tracklist(
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            title: fetched.title.isEmpty ? self.title : fetched.title,
            subtitle: fetched.subtitle ?? self.subtitle,
            year: fetched.year ?? self.year,
            trackCount: fetched.trackCount ?? self.trackCount,
            artworkUrl: fetched.artworkUrl ?? self.artworkUrl,
            url: fetched.url ?? self.url,
            tracklistType: self.tracklistType,
            fromArtist: self.fromArtist,
            artistDetail: self.artistDetail,
            storedTracklist: self.storedTracklist
        )
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
