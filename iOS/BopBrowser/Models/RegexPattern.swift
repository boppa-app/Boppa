import Foundation

struct RegexValidated<Pattern: RegexPattern>: Codable, Equatable {
    let rawValue: String

    init(_ value: String) throws {
        guard value.wholeMatch(of: Pattern.regex) != nil else {
            throw ValidationError.invalidFormat(value, pattern: Pattern.description)
        }
        rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        try self.init(value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    enum ValidationError: Error, LocalizedError {
        case invalidFormat(String, pattern: String)

        var errorDescription: String? {
            switch self {
            case let .invalidFormat(value, pattern):
                return "Invalid value: '\(value)'. Must match pattern: \(pattern)"
            }
        }
    }
}

protocol RegexPattern {
    static var regex: Regex<Substring> { get }
    static var description: String { get }
}
