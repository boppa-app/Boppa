import Foundation
import os

class MediaSourceImportService {
    static let shared = MediaSourceImportService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "MediaSourceImportService")
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: configuration)
    }

    func fetchMediaSource(configUrl: String, isDefault: Bool = false) async throws -> MediaSource {
        guard let url = Self.normalizeConfigUrl(configUrl) else {
            self.logger.error("Invalid config URL: \(configUrl)")
            throw MediaSourceImportError.invalidURL
        }
        let urlString = url.absoluteString

        self.logger.info("Fetching config from: \(url.absoluteString)")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MediaSourceImportError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            self.logger.error("Server returned status \(httpResponse.statusCode) for \(url.absoluteString)")
            throw MediaSourceImportError.serverError(statusCode: httpResponse.statusCode, mediaSourceUrl: urlString)
        }

        let mediaSource = try MediaSource.fromConfigData(data, configUrl: urlString, isDefault: isDefault)
        self.logger.info("Successfully created media source '\(mediaSource.config.name)' from \(urlString)")

        return mediaSource
    }

    func updateAllMediaSources() async {
        let mediaSources = MediaSourceStorageManager.shared.fetchAll()
        let updatable = Self.sourcesToUpdate(mediaSources)
        guard !updatable.isEmpty else { return }

        self.logger.info("Updating \(updatable.count) media source config(s) from remote")

        await withTaskGroup(of: Void.self) { group in
            for source in updatable {
                group.addTask {
                    do {
                        let updated = try await self.fetchMediaSource(configUrl: source.configUrl!)
                        guard Self.shouldApplyUpdate(stored: source, fetched: updated) else {
                            if updated.id != source.id {
                                self.logger.warning("Config ID mismatch for '\(source.id)': remote returned '\(updated.id)', skipping")
                            } else {
                                self.logger.info("Config for '\(source.id)' is up to date (version \(source.config.version))")
                            }
                            return
                        }
                        try MediaSourceStorageManager.shared.updateConfig(
                            id: source.id,
                            configData: updated.configData
                        )
                        self.logger.info("Updated config for '\(source.id)' to version '\(updated.config.version)'")
                    } catch {
                        self.logger.error("Failed to update config for '\(source.id)': \(error)")
                    }
                }
            }
        }
    }

    static func normalizeConfigUrl(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let urlString = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed
            : "https://\(trimmed)"
        guard let url = URL(string: urlString), url.host != nil else { return nil }
        return url
    }

    static func sourcesToUpdate(_ sources: [MediaSource]) -> [MediaSource] {
        sources.filter { $0.configUrl != nil && $0.autoUpdate }
    }

    static func shouldApplyUpdate(stored: MediaSource, fetched: MediaSource) -> Bool {
        guard fetched.id == stored.id else { return false }
        return fetched.config.version != stored.config.version
    }
}
