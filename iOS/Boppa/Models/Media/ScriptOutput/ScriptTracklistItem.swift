import Foundation

struct ScriptTracklistItem {
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
