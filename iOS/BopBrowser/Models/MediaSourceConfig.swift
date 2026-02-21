import Foundation

struct MediaSourceConfig: Codable {
    let name: String
    let url: String
    let iconSvg: String?
    let login: LoginConfig?
    let data: MediaSourceData?
    let actions: MediaSourceActions?
}

struct LoginConfig: Codable {
    let url: String
    let required: Bool?
}

struct MediaSourceData: Codable {
    let search: [MediaSourceDataEntry]?
    let listLikes: [MediaSourceDataEntry]?
}

struct MediaSourceDataEntry: Codable {
    let baseUrl: String?
    let type: String?
    let queryParameters: [String: QueryParameter]?
    let extraction: [ExtractionItem]?
    let priority: Int?
}

struct QueryParameter: Codable {
    let type: String
    let field: String?
    let pattern: String?
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
