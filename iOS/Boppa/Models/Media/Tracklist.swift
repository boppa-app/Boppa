import Foundation

struct Tracklist: Identifiable, Equatable, Hashable {
    let id: UUID
    let mediaId: String
    let mediaSourceId: String
    let title: String
    let subtitle: String?
    let year: Int?
    let lowResArtworkUrl: String?
    let highResArtworkUrl: String?
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
        id: UUID = UUID(),
        mediaId: String,
        mediaSourceId: String,
        title: String,
        subtitle: String? = nil,
        year: Int? = nil,
        lowResArtworkUrl: String? = nil,
        highResArtworkUrl: String? = nil,
        url: String? = nil,
        tracklistType: TracklistType,
        fromArtist: Artist? = nil,
        artistDetail: ArtistDetail? = nil,
        storedTracklist: StoredTracklist? = nil
    ) {
        self.id = id
        self.mediaId = mediaId
        self.mediaSourceId = mediaSourceId
        self.title = title
        self.subtitle = subtitle
        self.year = year
        self.lowResArtworkUrl = lowResArtworkUrl
        self.highResArtworkUrl = highResArtworkUrl
        self.url = url
        self.tracklistType = tracklistType
        self.fromArtist = fromArtist
        self.artistDetail = artistDetail
        self.storedTracklist = storedTracklist
    }

    init(storedTracklist: StoredTracklist, fromArtist: Artist? = nil, id: UUID = UUID()) {
        self.init(
            id: id,
            mediaId: storedTracklist.mediaId,
            mediaSourceId: storedTracklist.mediaSourceId,
            title: storedTracklist.title,
            subtitle: storedTracklist.subtitle,
            year: storedTracklist.year,
            lowResArtworkUrl: storedTracklist.lowResArtworkUrl,
            highResArtworkUrl: storedTracklist.highResArtworkUrl,
            url: storedTracklist.url,
            tracklistType: TracklistType(rawValue: storedTracklist.tracklistType) ?? .playlist,
            fromArtist: fromArtist,
            artistDetail: nil,
            storedTracklist: storedTracklist
        )
    }

    static func == (lhs: Tracklist, rhs: Tracklist) -> Bool {
        lhs.mediaId == rhs.mediaId
            && lhs.mediaSourceId == rhs.mediaSourceId
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.lowResArtworkUrl == rhs.lowResArtworkUrl
            && lhs.highResArtworkUrl == rhs.highResArtworkUrl
            && lhs.url == rhs.url
            && lhs.tracklistType == rhs.tracklistType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.mediaId)
    }

    var isPersisted: Bool {
        self.storedTracklist?.isSavedToLibrary == true
    }

    var tracklistKey: String {
        "\(self.mediaId)|\(self.mediaSourceId)"
    }

    var isMediaSourceEnabled: Bool {
        guard self.mediaSourceId != "boppa.app" else { return true }
        guard let source = MediaSourceStorageManager.shared.fetchOne(id: self.mediaSourceId) else {
            return false
        }
        return source.isEnabled
    }

    func merging(fetched: any TracklistMetadata) -> Tracklist {
        Tracklist(
            id: self.id,
            mediaId: self.mediaId,
            mediaSourceId: self.mediaSourceId,
            title: fetched.title.isEmpty ? self.title : fetched.title,
            subtitle: fetched.subtitle ?? self.subtitle,
            year: fetched.year ?? self.year,
            lowResArtworkUrl: fetched.lowResArtworkUrl ?? self.lowResArtworkUrl,
            highResArtworkUrl: fetched.highResArtworkUrl ?? self.highResArtworkUrl,
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
