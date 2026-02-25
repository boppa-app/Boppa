import Foundation

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

struct PaginationConfig: Codable {
    let baseUrl: String?
    let queryParameters: [String: String]?
}

struct MediaSourceData: Codable {
    let searchSongs: [DataEntry<SongExtractionItem>]?
    let searchArtists: [DataEntry<ArtistExtractionItem>]?
    let searchAlbums: [DataEntry<AlbumExtractionItem>]?
    let searchPlaylists: [DataEntry<PlaylistExtractionItem>]?
    let listLikes: [DataEntry<SongExtractionItem>]?
}

struct DataEntry<Extraction: Codable>: Codable {
    let baseUrl: String?
    let type: String?
    let queryParameters: [String: String]?
    let extraction: [Extraction]?
    let priority: Int?
    let pagination: PaginationConfig?
}

protocol ExtractionSource {
    associatedtype Mapping: Codable
    var type: String? { get }
    var reMatch: String? { get }
    var selector: String? { get }
    var itemMapping: Mapping? { get }
}

struct SongExtractionItem: Codable, ExtractionSource {
    let type: String?
    let reMatch: String?
    let selector: String?
    let itemMapping: SongMapping?
}

struct AlbumExtractionItem: Codable, ExtractionSource {
    let type: String?
    let reMatch: String?
    let selector: String?
    let itemMapping: AlbumMapping?
}

struct ArtistExtractionItem: Codable, ExtractionSource {
    let type: String?
    let reMatch: String?
    let selector: String?
    let itemMapping: ArtistMapping?
}

struct PlaylistExtractionItem: Codable, ExtractionSource {
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
    let title: [String]
    let artist: [String]
    let duration: [String]
    let artworkUrl: [String]
    let url: [String]
}

struct AlbumMapping: Codable {
    let title: [String]
    let artist: [String]
    let trackCount: [String]
    let artworkUrl: [String]
    let url: [String]
}

struct ArtistMapping: Codable {
    let artist: [String]
    let artworkUrl: [String]
    let url: [String]
}

struct PlaylistMapping: Codable {
    let title: [String]
    let user: [String]
    let trackCount: [String]
    let artworkUrl: [String]
    let url: [String]
}
