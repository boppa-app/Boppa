import Foundation

enum MediaSourceImportError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, mediaSourceUrl: String)
    case malformedConfig(detail: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The config URL could not be constructed."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .serverError(statusCode, mediaSourceUrl):
            if statusCode == 404 {
                return "No config found for media source URL: \(mediaSourceUrl)"
            }
            return "The server returned an error (HTTP \(statusCode))."
        case let .malformedConfig(detail):
            return "Malformed config: \(detail)"
        }
    }
}
