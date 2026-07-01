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

        let mediaSource = try MediaSource.fromConfigData(data)
        self.logger.info("Successfully created media source '\(mediaSource.name)' from \(urlString)")

        return mediaSource
    }
}
