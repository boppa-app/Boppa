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

    func buildConfigURL(configProviderUrl: String, mediaSourceUrl: String) -> URL? {
        let host = configProviderUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheme = host.hasPrefix("localhost") || host.hasPrefix("127.0.0.1") ? "http" : "https"
        let urlString = "\(scheme)://\(host)/msc/\(mediaSourceUrl).json"
        return URL(string: urlString)
    }

    func fetchMediaSources(configProviderUrl: String, mediaSourceUrl: String) async throws -> [MediaSource] {
        guard let url = buildConfigURL(configProviderUrl: configProviderUrl, mediaSourceUrl: mediaSourceUrl) else {
            self.logger.error("Invalid config URL for provider: \(configProviderUrl), mediaSource: \(mediaSourceUrl)")
            throw MediaSourceImportError.invalidURL
        }

        self.logger.info("Fetching config from: \(url.absoluteString)")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MediaSourceImportError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            self.logger.error("Server returned status \(httpResponse.statusCode) for \(url.absoluteString)")
            throw MediaSourceImportError.serverError(statusCode: httpResponse.statusCode, mediaSourceUrl: mediaSourceUrl)
        }

        let mediaSources = try MediaSource.fromConfigData(data)
        self.logger.info("Successfully created \(mediaSources.count) media source(s) for \(mediaSourceUrl)")

        return mediaSources
    }
}
