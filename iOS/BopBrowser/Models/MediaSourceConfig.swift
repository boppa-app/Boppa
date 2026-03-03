import Foundation
import WebKit

struct MediaSourceConfig: Codable {
    let name: String
    let url: String
    let iconSvg: String?
    let login: LoginConfig?
    let refreshUrls: [RefreshUrl]?
    let data: MediaSourceData?
    let actions: MediaSourceActions?
    let playback: PlaybackConfig?
}

struct LoginConfig: Codable {
    let url: String
    let required: Bool?
}

struct RefreshUrl: Codable {
    let url: String
    let intervalSeconds: Int
    let scripts: [RefreshScript]
}

struct RefreshScript: Codable {
    let content: ScriptContent
    let injectionTime: ScriptInjectionTime
}

enum ScriptInjectionTime: String, Codable {
    case atDocumentStart
    case atDocumentEnd

    var wkUserScriptInjectionTime: WKUserScriptInjectionTime {
        switch self {
        case .atDocumentStart: return .atDocumentStart
        case .atDocumentEnd: return .atDocumentEnd
        }
    }
}

struct ScriptContent: Codable {
    let script: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let lines = try? container.decode([String].self) {
            self.script = lines.joined(separator: "\n")
        } else {
            self.script = try container.decode(String.self)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.script)
    }
}

struct MediaSourceData: Codable {
    let searchSongs: ScriptContent?
    let searchArtists: ScriptContent?
    let searchAlbums: ScriptContent?
    let searchPlaylists: ScriptContent?
    let listLikes: ScriptContent?
}

struct MediaSourceActions: Codable {
    let searchNextPage: MediaSourceAction?
    let likesNextPage: MediaSourceAction?
    let addToLikes: MediaSourceAction?
}

struct MediaSourceAction: Codable {}
