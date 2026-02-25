import Foundation

struct PlaybackConfig: Codable {
    let type: PlaybackType
    let widget: WidgetPlaybackConfig?
}

enum PlaybackType: String, Codable {
    case widget
    case directStream
}

struct WidgetPlaybackConfig: Codable {
    let scriptUrl: String
    let embedUrl: String
    let widgetInit: WidgetInit
    let eventBinding: EventBinding
    let events: [WidgetEvent]
    let commands: WidgetCommands
    let callbackMapping: [String: CallbackFieldMapping]

    enum CodingKeys: String, CodingKey {
        case scriptUrl
        case embedUrl
        case widgetInit
        case eventBinding
        case events
        case commands
        case callbackMapping
    }
}

struct WidgetInit: Codable {
    let constructor: String
}

struct EventBinding: Codable {
    let method: String
    let constantPrefix: String
}

struct WidgetEvent: Codable {
    let widgetEvent: String
    let callbackArg: String?
    let post: PostMessage?
    let actions: [ReadyAction]?
}

struct PostMessage: Codable {
    let type: String
    let fields: [String: PostMessageValue]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        self.type = try container.decode(String.self, forKey: DynamicCodingKey(stringValue: "type")!)

        var extractedFields: [String: PostMessageValue] = [:]
        for key in container.allKeys where key.stringValue != "type" {
            let value = try container.decode(PostMessageValue.self, forKey: key)
            extractedFields[key.stringValue] = value
        }
        self.fields = extractedFields.isEmpty ? nil : extractedFields
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encode(self.type, forKey: DynamicCodingKey(stringValue: "type")!)
        if let fields {
            for (key, value) in fields {
                try container.encode(value, forKey: DynamicCodingKey(stringValue: key)!)
            }
        }
    }
}

enum PostMessageValue: Codable {
    case fieldExtraction(field: String, transform: [ValueTransform]?)
    case callbackArgRef(index: Int, transform: [ValueTransform]?)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let field = try container.decodeIfPresent(String.self, forKey: .field) {
            let transform = try container.decodeIfPresent([ValueTransform].self, forKey: .transform)
            self = .fieldExtraction(field: field, transform: transform)
        } else if let index = try container.decodeIfPresent(Int.self, forKey: .callbackArg) {
            let transform = try container.decodeIfPresent([ValueTransform].self, forKey: .transform)
            self = .callbackArgRef(index: index, transform: transform)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "PostMessageValue must have 'field' or 'callbackArg'")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .fieldExtraction(field, transform):
            try container.encode(field, forKey: .field)
            try container.encodeIfPresent(transform, forKey: .transform)
        case let .callbackArgRef(index, transform):
            try container.encode(index, forKey: .callbackArg)
            try container.encodeIfPresent(transform, forKey: .transform)
        }
    }

    enum CodingKeys: String, CodingKey {
        case field
        case callbackArg
        case transform
    }
}

enum ValueTransform: Codable {
    case divide(Double)
    case multiply(Double)
    case divideByField(String)
    case round

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let divisor = try container.decodeIfPresent(Double.self, forKey: .divide) {
            self = .divide(divisor)
        } else if let multiplier = try container.decodeIfPresent(Double.self, forKey: .multiply) {
            self = .multiply(multiplier)
        } else if let field = try container.decodeIfPresent(String.self, forKey: .divideByField) {
            self = .divideByField(field)
        } else if let shouldRound = try container.decodeIfPresent(Bool.self, forKey: .round), shouldRound {
            self = .round
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown transform type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .divide(value):
            try container.encode(value, forKey: .divide)
        case let .multiply(value):
            try container.encode(value, forKey: .multiply)
        case let .divideByField(field):
            try container.encode(field, forKey: .divideByField)
        case .round:
            try container.encode(true, forKey: .round)
        }
    }

    enum CodingKeys: String, CodingKey {
        case divide
        case multiply
        case divideByField
        case round
    }
}

enum ReadyAction: Codable {
    case command(String)
    case asyncMethod(method: String, post: PostMessage)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let command = try container.decodeIfPresent(String.self, forKey: .command) {
            self = .command(command)
        } else if let method = try container.decodeIfPresent(String.self, forKey: .asyncMethod) {
            let post = try container.decode(PostMessage.self, forKey: .post)
            self = .asyncMethod(method: method, post: post)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "ReadyAction must have 'command' or 'asyncMethod'")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .command(name):
            try container.encode(name, forKey: .command)
        case let .asyncMethod(method, post):
            try container.encode(method, forKey: .asyncMethod)
            try container.encode(post, forKey: .post)
        }
    }

    enum CodingKeys: String, CodingKey {
        case command
        case asyncMethod
        case post
    }
}

struct WidgetCommands: Codable {
    let play: WidgetCommand
    let pause: WidgetCommand
    let seek: WidgetCommand
}

struct WidgetCommand: Codable {
    let method: String
    let argTransform: String?
}

struct CallbackFieldMapping: Codable {
    let type: String
    let currentTime: String?
    let duration: String?
    let value: String?
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
