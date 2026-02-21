import Foundation
import SwiftData

@Model
final class MediaSource {
    var name: String
    var url: String
    var configData: Data

    var config: MediaSourceConfig? {
        try? JSONDecoder().decode(MediaSourceConfig.self, from: configData)
    }

    init(name: String, url: String, config: MediaSourceConfig) {
        self.name = name
        self.url = url
        configData = (try? JSONEncoder().encode(config)) ?? Data()
    }

    static func fromConfigData(_ data: Data) throws -> [MediaSource] {
        let configs: [MediaSourceConfig]
        do {
            configs = try JSONDecoder().decode([MediaSourceConfig].self, from: data)
        } catch let decodingError as DecodingError {
            throw MediaSourceImportError.malformedConfig(detail: describeDecodingError(decodingError))
        } catch {
            throw MediaSourceImportError.malformedConfig(detail: error.localizedDescription)
        }

        guard !configs.isEmpty else {
            throw MediaSourceImportError.malformedConfig(detail: "Config array is empty.")
        }

        return configs.map { config in
            MediaSource(name: config.name, url: config.url, config: config)
        }
    }

    private static func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case let .keyNotFound(key, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            let location = path.isEmpty ? "" : " at \"\(path)\""
            return "Missing key \"\(key.stringValue)\"\(location)."
        case let .typeMismatch(type, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Type mismatch for \"\(path)\": expected \(type)."
        case let .valueNotFound(type, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Missing value for \"\(path)\": expected \(type)."
        case let .dataCorrupted(context):
            return "Data corrupted: \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
