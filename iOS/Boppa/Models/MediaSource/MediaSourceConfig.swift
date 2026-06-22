import Foundation
import WebKit

// TODO: Add version, updateUrl (URL to check for config updates), and downloadUrl (URL to download config) fields
struct MediaSourceConfig: Codable {
    let id: String
    let name: String
    let url: String
    let iconSvg: String?
    let highlightColor: String?
    let customUserAgent: String?
    let login: LoginConfig?
    let context: [ContextConfig]?
    let data: DataScripts
    let playback: PlaybackConfig
    let lastUpdated: Date

    private enum CodingKeys: String, CodingKey {
        case id, name, url, iconSvg, highlightColor, customUserAgent, login, context, data, playback, lastUpdated
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(String.self, forKey: .url)
        self.iconSvg = try container.decodeIfPresent(String.self, forKey: .iconSvg)
        self.highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
        self.customUserAgent = try container.decodeIfPresent(String.self, forKey: .customUserAgent)
        self.login = try container.decodeIfPresent(LoginConfig.self, forKey: .login)
        self.context = try container.decodeIfPresent([ContextConfig].self, forKey: .context)
        self.data = try container.decode(DataScripts.self, forKey: .data)
        self.playback = try container.decode(PlaybackConfig.self, forKey: .playback)
        self.lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.url, forKey: .url)
        try container.encodeIfPresent(self.iconSvg, forKey: .iconSvg)
        try container.encodeIfPresent(self.highlightColor, forKey: .highlightColor)
        try container.encodeIfPresent(self.customUserAgent, forKey: .customUserAgent)
        try container.encodeIfPresent(self.login, forKey: .login)
        try container.encodeIfPresent(self.context, forKey: .context)
        try container.encode(self.data, forKey: .data)
        try container.encode(self.playback, forKey: .playback)
        try container.encode(self.lastUpdated, forKey: .lastUpdated)
    }
}

struct DataScripts: Codable {
    let search: SearchScripts?
    let list: ListScripts?
    let get: GetScripts?
}

struct LoginConfig: Codable {
    let url: String
    let required: Bool?
    let cookies: [String]?
}

struct ContextConfig: Codable {
    let title: String
    let url: String
    let intervalSeconds: Int
    let userScripts: [Script]
}

struct Script: Codable {
    let title: String
    let content: String
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

struct SearchScripts: Codable {
    let songs: String?
    let videos: String?
    let albums: String?
    let artists: String?
    let playlists: String?
}

struct ListScripts: Codable {
    let album: String?
    let playlist: String?
    let artistSongs: String?
    let artistVideos: String?
    let artistAlbums: String?
    let artistPlaylists: String?
}

struct GetScripts: Codable {
    let artist: String?
    let song: String?
    let video: String?
    let album: String?
    let playlist: String?
}
