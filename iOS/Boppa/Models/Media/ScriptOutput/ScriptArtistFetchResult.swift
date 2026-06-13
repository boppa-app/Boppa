import Foundation

struct ScriptArtistFetchResult {
    let songs: [ScriptTrackItem]?
    let albums: [ScriptTracklistItem]?
    let videos: [ScriptTrackItem]?
    let playlists: [ScriptTracklistItem]?
    let metadata: [String: Any]
    let sectionOrder: [String]

    init(_ dict: [String: Any]) {
        self.songs = (dict["songs"] as? [[String: Any]]).map { $0.compactMap { ScriptTrackItem($0) } }
        self.albums = (dict["albums"] as? [[String: Any]]).map { $0.compactMap { ScriptTracklistItem($0) } }
        self.videos = (dict["videos"] as? [[String: Any]]).map { $0.compactMap { ScriptTrackItem($0) } }
        self.playlists = (dict["playlists"] as? [[String: Any]]).map { $0.compactMap { ScriptTracklistItem($0) } }
        self.metadata = dict["metadata"] as? [String: Any] ?? [:]
        self.sectionOrder = dict["__keyOrder"] as? [String] ?? []
    }
}
