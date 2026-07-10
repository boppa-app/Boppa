import Foundation
import WebKit

// TODO: Add version, updateUrl (URL to check for config updates), and downloadUrl (URL to download config) fields
struct MediaSourceConfig: Codable {
    let id: String
    let version: String
    let name: String
    let url: String
    let iconSvg: String?
    let highlightColor: String?
    let context: [ContextConfig]?
    let data: DataScripts
    let playback: PlaybackConfig
    let popup: [String: PopupConfig]?

    private enum CodingKeys: String, CodingKey {
        case id, version, name, url, iconSvg, highlightColor, context, data, playback, popup
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.version = try container.decode(String.self, forKey: .version)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(String.self, forKey: .url)
        self.iconSvg = try container.decodeIfPresent(String.self, forKey: .iconSvg)
        self.highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
        self.context = try container.decodeIfPresent([ContextConfig].self, forKey: .context)
        self.data = try container.decode(DataScripts.self, forKey: .data)
        self.playback = try container.decode(PlaybackConfig.self, forKey: .playback)
        self.popup = try container.decodeIfPresent([String: PopupConfig].self, forKey: .popup)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.version, forKey: .version)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.url, forKey: .url)
        try container.encodeIfPresent(self.iconSvg, forKey: .iconSvg)
        try container.encodeIfPresent(self.highlightColor, forKey: .highlightColor)
        try container.encodeIfPresent(self.context, forKey: .context)
        try container.encode(self.data, forKey: .data)
        try container.encode(self.playback, forKey: .playback)
        try container.encodeIfPresent(self.popup, forKey: .popup)
    }
}

struct DataScripts: Codable {
    let search: SearchScripts?
    let list: ListScripts?
    let get: GetScripts?
}

struct ContextConfig: Codable {
    let title: String
    let url: String
    let intervalSeconds: Int
    let userScripts: [Script]
    let customUserAgent: String?
}

struct PopupConfig: Codable {
    let title: String
    let url: String
    let userScripts: [Script]
    let customUserAgent: String?
}

struct PlaybackConfig: Codable {
    let url: String?
    let html: String?
    let userScripts: [Script]
    let customUserAgent: String?

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.html = try container.decodeIfPresent(String.self, forKey: .html)
        self.userScripts = try container.decode([Script].self, forKey: .userScripts)
        self.customUserAgent = try container.decodeIfPresent(String.self, forKey: .customUserAgent)

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

    func script(for trackType: Track.TrackType) -> String? {
        switch trackType {
        case .song: self.song
        case .video: self.video
        }
    }
}
