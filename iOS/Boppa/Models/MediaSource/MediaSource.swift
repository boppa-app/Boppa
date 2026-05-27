import Foundation
import SQLiteData

@Table("mediaSources")
nonisolated struct MediaSource: Identifiable, Hashable {
    @Column(primaryKey: true)
    var id: String
    var name: String
    var url: String
    var configData: Data
    var sortOrder: Int
    var isEnabled: Bool
    var contextValuesJSON: String
}

extension MediaSource {
    var config: MediaSourceConfig {
        try! JSONDecoder().decode(MediaSourceConfig.self, from: self.configData)
    }

    var contextValues: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(self.contextValuesJSON.utf8))) ?? [:]
    }

    init(id: String, name: String, url: String, config: MediaSourceConfig, sortOrder: Int = 0, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.configData = (try? JSONEncoder().encode(config)) ?? Data()
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.contextValuesJSON = "{}"
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
            throw MediaSourceImportError.malformedConfig(detail: "Config array is empty")
        }

        return configs.map { config in
            MediaSource(id: config.id, name: config.name, url: config.url, config: config)
        }
    }

    private static func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case let .keyNotFound(key, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            let location = path.isEmpty ? "" : " at \"\(path)\""
            return "Missing key \"\(key.stringValue)\"\(location)"
        case let .typeMismatch(type, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Type mismatch for \"\(path)\": expected \(type)"
        case let .valueNotFound(type, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Missing value for \"\(path)\": expected \(type)"
        case let .dataCorrupted(context):
            return "Data corrupted: \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
