import Foundation
import WebKit

struct MediaSourceConfig: Codable {
    let name: String
    let url: String
    let iconSvg: String?
    let customUserAgent: String?
    let login: LoginConfig?
    let parse: [Parse]?
    let data: MediaSourceData?
    let actions: MediaSourceActions?
    let playback: PlaybackConfig
    let lastUpdated: Date

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(String.self, forKey: .url)
        self.iconSvg = try container.decodeIfPresent(String.self, forKey: .iconSvg)
        self.customUserAgent = try container.decodeIfPresent(String.self, forKey: .customUserAgent)
        self.login = try container.decodeIfPresent(LoginConfig.self, forKey: .login)
        self.parse = try container.decodeIfPresent([Parse].self, forKey: .parse)
        self.data = try container.decodeIfPresent(MediaSourceData.self, forKey: .data)
        self.actions = try container.decodeIfPresent(MediaSourceActions.self, forKey: .actions)
        self.playback = try container.decode(PlaybackConfig.self, forKey: .playback)
        self.lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
    }
}

struct LoginConfig: Codable {
    let url: String
    let required: Bool?
    let cookies: [String]?
}

struct Parse: Codable {
    let url: String
    let intervalSeconds: Int
    let userScripts: [Script]
}

struct Script: Codable {
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
