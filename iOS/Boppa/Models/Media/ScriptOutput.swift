import Foundation

// MARK: - Helpers

func scriptString(_ value: Any?) -> String? {
    if let s = value as? String { return s }
    if let i = value as? Int { return String(i) }
    if let d = value as? Double { return String(Int(d)) }
    return nil
}

func scriptInt(_ value: Any?) -> Int? {
    if let i = value as? Int { return i }
    if let d = value as? Double { return Int(d) }
    if let s = value as? String { return Int(s) }
    return nil
}

func scriptParams(_ params: [String: Any], previousResult: [String: Any]? = nil) -> [String: Any] {
    guard let previousResult else { return params }
    var merged = params
    merged["previousResult"] = previousResult
    return merged
}

// MARK: - Embedded Ref Types (Nested Within ScriptTrack)

struct ScriptArtistRef {
    let id: String
    let name: String
    let artworkUrl: String?

    init?(_ dict: [String: Any]) {
        guard let id = scriptString(dict["id"]),
              let name = dict["name"] as? String
        else { return nil }
        self.id = id
        self.name = name
        self.artworkUrl = dict["artworkUrl"] as? String
    }
}

struct ScriptAlbumRef {
    let id: String
    let title: String
    let subtitle: String?
    let artworkUrl: String?

    init?(_ dict: [String: Any]) {
        guard let id = scriptString(dict["id"]),
              let title = dict["title"] as? String
        else { return nil }
        self.id = id
        self.title = title
        self.subtitle = dict["subtitle"] as? String
        self.artworkUrl = dict["artworkUrl"] as? String
    }
}

// MARK: - Script Item Types (List / Search Page Items)

struct ScriptTrack {
    let id: String
    let title: String
    let subtitle: String?
    let duration: Int?
    let artworkUrl: String?
    let url: String?
    let artists: [ScriptArtistRef]
    let albums: [ScriptAlbumRef]

    init?(_ dict: [String: Any]) {
        guard let id = scriptString(dict["id"]),
              let title = dict["title"] as? String
        else { return nil }
        self.id = id
        self.title = title
        self.subtitle = dict["subtitle"] as? String
        self.duration = scriptInt(dict["duration"])
        self.artworkUrl = dict["artworkUrl"] as? String
        self.url = dict["url"] as? String
        self.artists = (dict["artists"] as? [[String: Any]] ?? []).compactMap { ScriptArtistRef($0) }
        self.albums = (dict["albums"] as? [[String: Any]] ?? []).compactMap { ScriptAlbumRef($0) }
    }
}

struct ScriptTracklist {
    let id: String
    let title: String
    let subtitle: String?
    let year: Int?
    let trackCount: Int?
    let artworkUrl: String?
    let url: String?

    init?(_ dict: [String: Any]) {
        guard let id = scriptString(dict["id"]),
              let title = dict["title"] as? String
        else { return nil }
        self.id = id
        self.title = title
        self.subtitle = dict["subtitle"] as? String
        self.year = scriptInt(dict["year"])
        self.trackCount = scriptInt(dict["trackCount"])
        self.artworkUrl = dict["artworkUrl"] as? String
        self.url = dict["url"] as? String
    }
}

struct ScriptArtist {
    let id: String
    let name: String
    let artworkUrl: String?
    let url: String?

    init?(_ dict: [String: Any]) {
        guard let id = scriptString(dict["id"]),
              let name = dict["name"] as? String
        else { return nil }
        self.id = id
        self.name = name
        self.artworkUrl = dict["artworkUrl"] as? String
        self.url = dict["url"] as? String
    }
}

// MARK: - Get Responses

// TODO: Add GetTrackResponse

struct GetArtistResponse {
    let songs: [ScriptTrack]?
    let albums: [ScriptTracklist]?
    let videos: [ScriptTrack]?
    let playlists: [ScriptTracklist]?
    let sectionOrder: [String]

    init(_ dict: [String: Any]) {
        self.songs = (dict["songs"] as? [[String: Any]]).map { $0.compactMap { ScriptTrack($0) } }
        self.albums = (dict["albums"] as? [[String: Any]]).map { $0.compactMap { ScriptTracklist($0) } }
        self.videos = (dict["videos"] as? [[String: Any]]).map { $0.compactMap { ScriptTrack($0) } }
        self.playlists = (dict["playlists"] as? [[String: Any]]).map { $0.compactMap { ScriptTracklist($0) } }
        self.sectionOrder = dict["__keyOrder"] as? [String] ?? []
    }
}

protocol TracklistMetadata {
    var id: String { get }
    var title: String { get }
    var subtitle: String? { get }
    var year: Int? { get }
    var trackCount: Int? { get }
    var artworkUrl: String? { get }
    var url: String? { get }
}

struct GetAlbumResponse: TracklistMetadata {
    let id: String
    let title: String
    let subtitle: String?
    let year: Int?
    let trackCount: Int?
    let artworkUrl: String?
    let url: String?

    init?(_ dict: [String: Any]) {
        guard let id = scriptString(dict["id"]),
              let title = dict["title"] as? String
        else { return nil }
        self.id = id
        self.title = title
        self.subtitle = dict["subtitle"] as? String
        self.year = scriptInt(dict["year"])
        self.trackCount = scriptInt(dict["trackCount"])
        self.artworkUrl = dict["artworkUrl"] as? String
        self.url = dict["url"] as? String
    }
}

struct GetPlaylistResponse: TracklistMetadata {
    let id: String
    let title: String
    let subtitle: String?
    let year: Int? = nil
    let trackCount: Int?
    let artworkUrl: String?
    let url: String?

    init?(_ dict: [String: Any]) {
        guard let id = scriptString(dict["id"]),
              let title = dict["title"] as? String
        else { return nil }
        self.id = id
        self.title = title
        self.subtitle = dict["subtitle"] as? String
        self.trackCount = scriptInt(dict["trackCount"])
        self.artworkUrl = dict["artworkUrl"] as? String
        self.url = dict["url"] as? String
    }
}

// MARK: - List Responses

private func extractContinuation(_ dict: [String: Any]) -> [String: Any]? {
    var ctx = dict
    ctx.removeValue(forKey: "items")
    ctx.removeValue(forKey: "__keyOrder")
    return ctx.values.contains { !($0 is NSNull) } ? ctx : nil
}

struct ListAlbumResponse {
    let items: [ScriptTrack]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTrack($0) }
        self.continuation = extractContinuation(dict)
    }
}

struct ListPlaylistResponse {
    let items: [ScriptTrack]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTrack($0) }
        self.continuation = extractContinuation(dict)
    }
}

struct ListArtistSongsResponse {
    let items: [ScriptTrack]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTrack($0) }
        self.continuation = extractContinuation(dict)
    }
}

struct ListArtistVideosResponse {
    let items: [ScriptTrack]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTrack($0) }
        self.continuation = extractContinuation(dict)
    }
}

struct ListArtistAlbumsResponse {
    let items: [ScriptTracklist]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTracklist($0) }
        self.continuation = extractContinuation(dict)
    }
}

struct ListArtistPlaylistsResponse {
    let items: [ScriptTracklist]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTracklist($0) }
        self.continuation = extractContinuation(dict)
    }
}

// MARK: - Search Responses

struct SearchSongsResponse {
    let items: [ScriptTrack]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTrack($0) }
        self.continuation = extractContinuation(dict)
    }
}

struct SearchVideosResponse {
    let items: [ScriptTrack]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTrack($0) }
        self.continuation = extractContinuation(dict)
    }
}

struct SearchAlbumsResponse {
    let items: [ScriptTracklist]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTracklist($0) }
        self.continuation = extractContinuation(dict)
    }
}

struct SearchPlaylistsResponse {
    let items: [ScriptTracklist]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptTracklist($0) }
        self.continuation = extractContinuation(dict)
    }
}

struct SearchArtistsResponse {
    let items: [ScriptArtist]
    let continuation: [String: Any]?
    init(_ dict: [String: Any]) {
        self.items = (dict["items"] as? [[String: Any]] ?? []).compactMap { ScriptArtist($0) }
        self.continuation = extractContinuation(dict)
    }
}

// MARK: - Domain Mapping

extension ScriptTrack {
    func toTrack(mediaSourceId: String) -> Track {
        Track(
            mediaId: self.id,
            mediaSourceId: mediaSourceId,
            title: self.title,
            subtitle: self.subtitle,
            duration: self.duration,
            artworkUrl: self.artworkUrl,
            url: self.url,
            artists: self.artists.map { Artist(mediaId: $0.id, mediaSourceId: mediaSourceId, name: $0.name, artworkUrl: $0.artworkUrl) },
            albums: self.albums.map { Tracklist(mediaId: $0.id, mediaSourceId: mediaSourceId, title: $0.title, subtitle: $0.subtitle, artworkUrl: $0.artworkUrl, tracklistType: .album) }
        )
    }
}

extension ScriptTracklist {
    func toTracklist(mediaSourceId: String, tracklistType: Tracklist.TracklistType) -> Tracklist {
        Tracklist(
            mediaId: self.id,
            mediaSourceId: mediaSourceId,
            title: self.title,
            subtitle: self.subtitle,
            year: self.year,
            trackCount: self.trackCount,
            artworkUrl: self.artworkUrl,
            url: self.url,
            tracklistType: tracklistType
        )
    }
}

extension ScriptArtist {
    func toArtist(mediaSourceId: String) -> Artist {
        Artist(
            mediaId: self.id,
            mediaSourceId: mediaSourceId,
            name: self.name,
            artworkUrl: self.artworkUrl,
            url: self.url
        )
    }
}
