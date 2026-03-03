import Foundation

enum SearchError: LocalizedError {
    case noSearchConfig

    var errorDescription: String? {
        switch self {
        case .noSearchConfig:
            return "No search configuration available for this source"
        }
    }
}
