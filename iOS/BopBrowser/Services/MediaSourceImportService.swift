import Foundation
import os

class MediaSourceImportService {
    static let shared = MediaSourceImportService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser", category: "MediaSourceImportService")
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        session = URLSession(configuration: configuration)
    }

    func buildConfigURL(configProviderUrl: String, mediaSourceUrl: String) -> URL? {
        let host = configProviderUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheme = host.hasPrefix("localhost") || host.hasPrefix("127.0.0.1") ? "http" : "https"
        let urlString = "\(scheme)://\(host)/mediaSourceConfigs/\(mediaSourceUrl).json"
        return URL(string: urlString)
    }

    func fetchMediaSources(configProviderUrl: String, mediaSourceUrl: String) async throws -> [MediaSource] {
        guard let url = buildConfigURL(configProviderUrl: configProviderUrl, mediaSourceUrl: mediaSourceUrl) else {
            logger.error("Invalid config URL for provider: \(configProviderUrl), source: \(mediaSourceUrl)")
            throw MediaSourceImportError.invalidURL
        }

        logger.info("Fetching config from: \(url.absoluteString)")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MediaSourceImportError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            logger.error("Server returned status \(httpResponse.statusCode) for \(url.absoluteString)")
            throw MediaSourceImportError.serverError(statusCode: httpResponse.statusCode, mediaSourceUrl: mediaSourceUrl)
        }

        let mediaSources = try MediaSource.fromConfigData(data)
        logger.info("Successfully created \(mediaSources.count) media source(s) for \(mediaSourceUrl)")

        return mediaSources
    }
}
