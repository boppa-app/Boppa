import Foundation
import SQLiteData
import Yams

@Table("mediaSources")
nonisolated struct MediaSource: Identifiable, Hashable {
    @Column(primaryKey: true)
    var id: String
    var configData: Data
    var configUrl: String?
    var autoUpdate: Bool
    var sortOrder: String
    var isEnabled: Bool
    var isDefault: Bool
    var lastUpdatedTimestamp: Double
    var contextValuesJSON: String
    var contextLastGatheredTimestamp: Double?
}

extension MediaSource {
    var config: MediaSourceConfig {
        try! YAMLDecoder().decode(MediaSourceConfig.self, from: self.configData)
    }

    var contextValues: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(self.contextValuesJSON.utf8))) ?? [:]
    }

    var lastUpdatedDate: Date {
        Date(timeIntervalSince1970: self.lastUpdatedTimestamp)
    }

    var contextLastGatheredDate: Date? {
        guard let ts = contextLastGatheredTimestamp else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    var isContextGathered: Bool {
        guard let contexts = config.context, !contexts.isEmpty else { return true }
        return self.contextLastGatheredTimestamp != nil
    }

    init(id: String, config: MediaSourceConfig, configUrl: String? = nil, sortOrder: String = "a0", isEnabled: Bool = true, isDefault: Bool = false) {
        self.id = id
        self.configData = (try? YAMLEncoder().encode(config)).flatMap { Data($0.utf8) } ?? Data()
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.lastUpdatedTimestamp = Date().timeIntervalSince1970
        self.contextValuesJSON = "{}"
        self.contextLastGatheredTimestamp = nil
        self.configUrl = configUrl
        self.autoUpdate = true
    }

    static func fromConfigData(_ data: Data, configUrl: String? = nil, isDefault: Bool = false) throws -> MediaSource {
        let config: MediaSourceConfig
        do {
            config = try YAMLDecoder().decode(MediaSourceConfig.self, from: data)
        } catch let decodingError as DecodingError {
            throw MediaSourceImportError.malformedConfig(detail: describeDecodingError(decodingError))
        } catch {
            throw MediaSourceImportError.malformedConfig(detail: error.localizedDescription)
        }

        return MediaSource(id: config.id, config: config, configUrl: configUrl, isDefault: isDefault)
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
