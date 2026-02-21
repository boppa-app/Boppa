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
    let search: [MediaSourceDataEntry]?
    let listLikes: [MediaSourceDataEntry]?
}

struct MediaSourceDataEntry: Codable {
    let baseUrl: String?
    let type: String?
    let queryParameters: [String: String]?
    let extraction: [ExtractionItem]?
    let priority: Int?
}

struct ExtractionItem: Codable {
    let type: String?
    let reMatch: String?
    let selector: String?
    let itemMapping: SongMapping?
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
