import Foundation

enum SearchError: LocalizedError {
    case noSearchConfig
    case invalidURL
    case requestFailed(statusCode: Int)
    case parsingFailed
    case missingKeyMapping(String)

    var errorDescription: String? {
        switch self {
        case .noSearchConfig:
            return "No search configuration available for this source"
        case .invalidURL:
            return "Could not construct a valid search URL"
        case let .requestFailed(statusCode):
            return "Search request failed (HTTP \(statusCode))"
        case .parsingFailed:
            return "Failed to parse search results"
        case let .missingKeyMapping(key):
            return "Missing required value for \(key), try refreshing the source"
        }
    }
}
