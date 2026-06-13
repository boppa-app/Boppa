import Foundation

struct ScriptTrackItem {
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
