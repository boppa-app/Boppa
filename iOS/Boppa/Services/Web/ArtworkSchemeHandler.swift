import Foundation
import Kingfisher
import os
import WebKit

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "ArtworkSchemeHandler"
)

enum ArtworkURLBridge {
    static let scheme = "boppa-artwork"

    static func localURLString(for original: String?) -> String {
        guard let original, !original.isEmpty else { return "" }

        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = "cache"
        components.queryItems = [URLQueryItem(name: "url", value: original)]
        return components.url?.absoluteString ?? ""
    }

    static func originalURLString(from request: URLRequest) -> String? {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        return components.queryItems?.first(where: { $0.name == "url" })?.value
    }

    static func cacheKey(for originalURLString: String) -> String {
        URL(string: originalURLString)?.absoluteString ?? originalURLString
    }
}

final class ArtworkSchemeHandler: NSObject, WKURLSchemeHandler {
    static let shared = ArtworkSchemeHandler()

    private let lock = NSLock()
    private var activeTasks: Set<ObjectIdentifier> = []

    override private init() {}

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskId = ObjectIdentifier(urlSchemeTask)
        self.lock.withLock { _ = self.activeTasks.insert(taskId) }

        guard let originalURLString = ArtworkURLBridge.originalURLString(from: urlSchemeTask.request),
              let requestURL = urlSchemeTask.request.url
        else {
            self.fail(urlSchemeTask, taskId: taskId, error: URLError(.badURL))
            return
        }

        let cacheKey = ArtworkURLBridge.cacheKey(for: originalURLString)

        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? ImageCache.default.diskStorage.value(forKey: cacheKey) {
                self.respond(urlSchemeTask, taskId: taskId, requestURL: requestURL, data: data)
                return
            }

            guard let originalURL = URL(string: originalURLString) else {
                self.fail(urlSchemeTask, taskId: taskId, error: URLError(.badURL))
                return
            }

            logger.info("Artwork cache miss, fetching from origin: \(originalURLString)")
            KingfisherManager.shared.retrieveImage(with: originalURL) { result in
                switch result {
                case .success:
                    if let data = try? ImageCache.default.diskStorage.value(forKey: cacheKey) {
                        self.respond(urlSchemeTask, taskId: taskId, requestURL: requestURL, data: data)
                    } else {
                        self.fail(urlSchemeTask, taskId: taskId, error: URLError(.cannotDecodeContentData))
                    }
                case let .failure(error):
                    self.fail(urlSchemeTask, taskId: taskId, error: error)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        self.lock.withLock { _ = self.activeTasks.remove(ObjectIdentifier(urlSchemeTask)) }
    }

    private func isActive(_ taskId: ObjectIdentifier) -> Bool {
        self.lock.withLock { self.activeTasks.contains(taskId) }
    }

    private func respond(_ urlSchemeTask: WKURLSchemeTask, taskId: ObjectIdentifier, requestURL: URL, data: Data) {
        guard self.isActive(taskId) else { return }
        let response = URLResponse(
            url: requestURL,
            mimeType: Self.mimeType(for: data),
            expectedContentLength: data.count,
            textEncodingName: nil
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
        self.lock.withLock { _ = self.activeTasks.remove(taskId) }
    }

    private func fail(_ urlSchemeTask: WKURLSchemeTask, taskId: ObjectIdentifier, error: Error) {
        guard self.isActive(taskId) else { return }
        logger.error("Failed to serve artwork: \(error.localizedDescription)")
        urlSchemeTask.didFailWithError(error)
        self.lock.withLock { _ = self.activeTasks.remove(taskId) }
    }

    private static func mimeType(for data: Data) -> String {
        var bytes = [UInt8](repeating: 0, count: min(data.count, 12))
        data.copyBytes(to: &bytes, count: bytes.count)

        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
        if bytes.count >= 12, bytes[0 ... 3] == [0x52, 0x49, 0x46, 0x46], bytes[8 ... 11] == [0x57, 0x45, 0x42, 0x50] {
            return "image/webp"
        }
        return "application/octet-stream"
    }
}
