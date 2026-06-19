import Foundation

struct PlaybackConfig: Codable {
    let url: String?
    let html: String?
    let userScripts: [Script]

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.html = try container.decodeIfPresent(String.self, forKey: .html)
        self.userScripts = try container.decode([Script].self, forKey: .userScripts)

        if self.url == nil, self.html == nil {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "playback config must have either 'url' or 'html'"
                )
            )
        }
        if self.url != nil, self.html != nil {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "playback config must have only one of 'url' or 'html', not both"
                )
            )
        }
    }
}
