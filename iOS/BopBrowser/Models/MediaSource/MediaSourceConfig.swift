import Foundation
import WebKit

// TODO: Add version, updateUrl (URL to check for config updates), and downloadUrl (URL to download config) fields
struct MediaSourceConfig: Codable, Sendable {
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

    private enum CodingKeys: String, CodingKey {
        case name, url, iconSvg, customUserAgent, login, parse, data, actions, playback, lastUpdated
    }

    nonisolated init(from decoder: Decoder) throws {
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

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.url, forKey: .url)
        try container.encodeIfPresent(self.iconSvg, forKey: .iconSvg)
        try container.encodeIfPresent(self.customUserAgent, forKey: .customUserAgent)
        try container.encodeIfPresent(self.login, forKey: .login)
        try container.encodeIfPresent(self.parse, forKey: .parse)
        try container.encodeIfPresent(self.data, forKey: .data)
        try container.encodeIfPresent(self.actions, forKey: .actions)
        try container.encode(self.playback, forKey: .playback)
        try container.encode(self.lastUpdated, forKey: .lastUpdated)
    }
}

struct LoginConfig: Codable, Sendable {
    let url: String
    let required: Bool?
    let cookies: [String]?
}

struct Parse: Codable, Sendable {
    let url: String
    let intervalSeconds: Int
    let userScripts: [Script]
}

struct Script: Codable, Sendable {
    let content: ScriptContent
    let injectionTime: ScriptInjectionTime
}

enum ScriptInjectionTime: String, Codable, Sendable {
    case atDocumentStart
    case atDocumentEnd

    var wkUserScriptInjectionTime: WKUserScriptInjectionTime {
        switch self {
        case .atDocumentStart: return .atDocumentStart
        case .atDocumentEnd: return .atDocumentEnd
        }
    }
}

struct ScriptContent: Codable, Sendable {
    let script: String

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let lines = try? container.decode([String].self) {
            self.script = lines.joined(separator: "\n")
        } else {
            self.script = try container.decode(String.self)
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.script)
    }
}

struct MediaSourceData: Codable, Sendable {
    let getTrack: ScriptContent?
    let searchSongs: ScriptContent?
    let searchVideos: ScriptContent?
    let searchArtists: ScriptContent?
    let searchAlbums: ScriptContent?
    let searchPlaylists: ScriptContent?
    let getAlbum: ScriptContent?
    let getArtist: ScriptContent?
    let getPlaylist: ScriptContent?
    let listLikes: ScriptContent?
    let listAlbumsForArtist: ScriptContent?
    let listSongsForArtist: ScriptContent?
    let listVideosForArtist: ScriptContent?
}

struct MediaSourceActions: Codable, Sendable {
    let searchNextPage: MediaSourceAction?
    let likesNextPage: MediaSourceAction?
    let addToLikes: MediaSourceAction?
}

struct MediaSourceAction: Codable, Sendable {}
