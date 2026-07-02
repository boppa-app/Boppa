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

    func fetchMediaSource(configUrl: String) async throws -> MediaSource {
        let normalized = configUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = (normalized.hasPrefix("http://") || normalized.hasPrefix("https://")) ? normalized : "https://\(normalized)"
        guard let url = URL(string: urlString) else {
            self.logger.error("Invalid config URL: \(configUrl)")
            throw MediaSourceImportError.invalidURL
        }

        self.logger.info("Fetching config from: \(url.absoluteString)")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MediaSourceImportError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            self.logger.error("Server returned status \(httpResponse.statusCode) for \(url.absoluteString)")
            throw MediaSourceImportError.serverError(statusCode: httpResponse.statusCode, mediaSourceUrl: urlString)
        }

        let mediaSource = try MediaSource.fromConfigData(data, configUrl: urlString)
        self.logger.info("Successfully created media source '\(mediaSource.name)' from \(urlString)")

        return mediaSource
    }

    func updateAllMediaSources() async {
        let mediaSources = MediaSourceStorageManager.shared.fetchAll()
        let updatable = mediaSources.filter { $0.configUrl != nil && $0.autoUpdate }
        guard !updatable.isEmpty else { return }

        self.logger.info("Updating \(updatable.count) media source config(s) from remote")

        await withTaskGroup(of: Void.self) { group in
            for source in updatable {
                group.addTask {
                    do {
                        let updated = try await self.fetchMediaSource(configUrl: source.configUrl!)
                        guard updated.id == source.id else {
                            self.logger.warning("Config ID mismatch for '\(source.id)': remote returned '\(updated.id)', skipping")
                            return
                        }
                        guard updated.version != source.version else {
                            self.logger.info("Config for '\(source.id)' is up to date (version \(source.version))")
                            return
                        }
                        try MediaSourceStorageManager.shared.updateConfig(
                            id: source.id,
                            configData: updated.configData,
                            name: updated.name,
                            url: updated.url,
                            version: updated.version
                        )
                        self.logger.info("Updated config for '\(source.id)' to version '\(updated.version)'")
                    } catch {
                        self.logger.error("Failed to update config for '\(source.id)': \(error)")
                    }
                }
            }
        }
    }
}
