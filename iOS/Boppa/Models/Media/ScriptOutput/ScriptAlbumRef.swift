import Foundation

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
