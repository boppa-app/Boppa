import Foundation

struct MediaSourceConfig: Codable {
    let name: String
    let url: String
    let login: String?
    let loginRequired: Bool?
    let data: MediaSourceData?
    let actions: MediaSourceActions?
}

struct MediaSourceData: Codable {
    let search: MediaSourceDataEntry?
    let listLikes: MediaSourceDataEntry?
}

struct MediaSourceDataEntry: Codable {
    let baseUrl: String?
    let queryParameters: [String: String]?
    let type: String?
    let networkRequestParser: NetworkRequestParser?
    let priority: Int?
}

struct MediaSourceActions: Codable {
    let searchNextPage: MediaSourceAction?
    let likesNextPage: MediaSourceAction?
    let addToLikes: MediaSourceAction?
}

struct MediaSourceAction: Codable {}

struct NetworkRequestParser: Codable {
    let reMatch: String?
    let extract: ExtractionConfig?
}

struct ExtractionConfig: Codable {
    let type: String?
    let strategy: String?
    let sources: [ExtractionSource]?
}

struct ExtractionSource: Codable {
    let type: String?
    let path: String?
    let forEach: Song?
}

struct Song: Codable {
    let title: String
    let artist: String
    let duration: String
    let artworkUrl: String
    let url: String
}
