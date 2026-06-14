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

struct GetTracklistResponse {
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
