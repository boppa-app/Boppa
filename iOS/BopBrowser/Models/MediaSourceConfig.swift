import Foundation

struct MediaSourceConfig: Codable {
    let name: String
    let url: String
    let iconSvg: String?
    let login: LoginConfig?
    let refreshUrls: [RefreshUrl]?
    let data: MediaSourceData?
    let actions: MediaSourceActions?
}

struct LoginConfig: Codable {
    let url: String
    let required: Bool?
}

struct RefreshUrl: Codable {
    let url: String
    let intervalSeconds: Int
    let capture: [QueryParameterCapture]
}

enum KeyMappingPattern: RegexPattern {
    static let regex = /^<<[A-Z0-9_]+>>$/
    static let description = "<<UPPER_CASE_OR_NUMBERS>>"
}

typealias KeyMapping = RegexValidated<KeyMappingPattern>

struct QueryParameterCapture: Codable {
    let type: String = "queryParameter"
    let value: String
    let pattern: String
    let keyMapping: KeyMapping
}

struct MediaSourceData: Codable {
    let searchSongs: [SongDataEntry]?
    let searchArtists: [ArtistDataEntry]?
    let searchAlbums: [AlbumDataEntry]?
    let searchPlaylists: [PlaylistDataEntry]?
    let listLikes: [SongDataEntry]?
}

struct SongDataEntry: Codable {
    let baseUrl: String?
    let type: String?
    let queryParameters: [String: String]?
    let extraction: [SongExtractionItem]?
    let priority: Int?
}

struct AlbumDataEntry: Codable {
    let baseUrl: String?
    let type: String?
    let queryParameters: [String: String]?
    let extraction: [AlbumExtractionItem]?
    let priority: Int?
}

struct ArtistDataEntry: Codable {
    let baseUrl: String?
    let type: String?
    let queryParameters: [String: String]?
    let extraction: [ArtistExtractionItem]?
    let priority: Int?
}

struct PlaylistDataEntry: Codable {
    let baseUrl: String?
    let type: String?
    let queryParameters: [String: String]?
    let extraction: [PlaylistExtractionItem]?
    let priority: Int?
}

struct SongExtractionItem: Codable {
    let type: String?
    let reMatch: String?
    let selector: String?
    let itemMapping: SongMapping?
}

struct AlbumExtractionItem: Codable {
    let type: String?
    let reMatch: String?
    let selector: String?
    let itemMapping: AlbumMapping?
}

struct ArtistExtractionItem: Codable {
    let type: String?
    let reMatch: String?
    let selector: String?
    let itemMapping: ArtistMapping?
}

struct PlaylistExtractionItem: Codable {
    let type: String?
    let reMatch: String?
    let selector: String?
    let itemMapping: PlaylistMapping?
}

struct MediaSourceActions: Codable {
    let searchNextPage: MediaSourceAction?
    let likesNextPage: MediaSourceAction?
    let addToLikes: MediaSourceAction?
}

struct MediaSourceAction: Codable {}

struct SongMapping: Codable {
    let title: String
    let artist: String
    let duration: String
    let artworkUrl: String
    let url: String
}

struct AlbumMapping: Codable {
    let title: String
    let artist: String
    let trackCount: String
    let artworkUrl: String
    let url: String
}

struct ArtistMapping: Codable {
    let artist: String
    let artworkUrl: String
    let url: String
}

struct PlaylistMapping: Codable {
    let title: String
    let user: String
    let trackCount: String
    let artworkUrl: String
    let url: String
}
