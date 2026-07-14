import Foundation

enum JSExecutionError: LocalizedError {
    case timeout
    case scriptError(detail: String)
    case invalidResult(detail: String)

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Execution timed out"
        case let .scriptError(detail):
            return "Error: \(detail)"
        case let .invalidResult(detail):
            return "Invalid result: \(detail)"
        }
    }
}
