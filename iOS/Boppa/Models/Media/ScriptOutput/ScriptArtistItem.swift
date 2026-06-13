import Foundation

struct ScriptArtistItem {
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
