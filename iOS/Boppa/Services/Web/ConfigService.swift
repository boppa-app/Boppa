import Foundation
import os
import Yams

struct AppConfig: Codable {
    let defaultMediaSourceConfigUrls: [String]
}

class ConfigService {
    static let shared = ConfigService()

    private static let remoteConfigUrl = URL(string: "https://cdn.boppa.app/config/iOS.yaml")!
    private static let deletedDefaultConfigUrlsKey = "deletedDefaultMediaSourceConfigUrls"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "ConfigService"
    )
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8
        self.session = URLSession(configuration: configuration)
    }

    func addDefaultMediaSourcesIfNeeded() async {
        let config: AppConfig
        do {
            config = try await self.fetchAppConfig()
        } catch {
            self.logger.error("Failed to load remote app config: \(error)")
            return
        }

        let deletedConfigUrls = Self.deletedDefaultConfigUrls

        await withTaskGroup(of: Void.self) { group in
            for configUrl in config.defaultMediaSourceConfigUrls {
                guard let normalizedUrl = MediaSourceImportService.normalizeConfigUrl(configUrl)?
                    .absoluteString,
                    !deletedConfigUrls.contains(normalizedUrl)
                else { continue }
                group.addTask {
                    await self.addDefaultMediaSource(configUrl: configUrl)
                }
            }
        }
    }

    private func fetchAppConfig() async throws -> AppConfig {
        let (data, response) = try await self.session.data(from: Self.remoteConfigUrl)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MediaSourceImportError.invalidResponse
        }
        return try YAMLDecoder().decode(AppConfig.self, from: data)
    }

    private func addDefaultMediaSource(configUrl: String) async {
        do {
            let mediaSource = try await MediaSourceImportService.shared.fetchMediaSource(
                configUrl: configUrl,
                isDefault: true
            )
            guard MediaSourceStorageManager.shared.fetchOne(id: mediaSource.id) == nil else {
                self.logger.info("Default media source '\(mediaSource.id)' already added, skipping")
                return
            }
            try MediaSourceStorageManager.shared.insert([mediaSource])
            self.logger.info("Added default media source '\(mediaSource.id)'")
        } catch {
            self.logger.error("Failed to add default media source from '\(configUrl)': \(error)")
        }
    }

    static func markDefaultConfigUrlDeleted(_ configUrl: String) {
        var urls = self.deletedDefaultConfigUrls
        urls.insert(configUrl)
        UserDefaults.standard.set(Array(urls), forKey: self.deletedDefaultConfigUrlsKey)
    }

    private static var deletedDefaultConfigUrls: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: self.deletedDefaultConfigUrlsKey) ?? [])
    }
}
