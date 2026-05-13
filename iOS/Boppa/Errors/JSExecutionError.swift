import Foundation

enum JSExecutionError: LocalizedError {
    case timeout
    case scriptError(detail: String)
    case invalidResult(detail: String)

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "JavaScript execution timed out"
        case let .scriptError(detail):
            return "JavaScript error: \(detail)"
        case let .invalidResult(detail):
            return "Invalid JavaScript result: \(detail)"
        }
    }
}
