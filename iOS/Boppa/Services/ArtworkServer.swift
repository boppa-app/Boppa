import Foundation
import Network
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "ArtworkServer"
)

/// A lightweight localhost HTTP server that proxies and caches artwork images.
/// All artwork in the app is routed through this server to provide a unified
/// caching layer and localhost URLs for mediaSession artwork.
final class ArtworkServer: @unchecked Sendable {
    static let shared = ArtworkServer()

    private static let maxCacheBytes: Int = 10 * 1024 * 1024 // 10 MB
    private static let maxActiveConnections: Int = 128

    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    private let queue = DispatchQueue(label: "ArtworkServer")

    private let cacheLock = NSLock()
    private var cache: [String: CacheEntry] = [:]
    private var accessOrder: [String] = [] // LRU order, most recent at end
    private var currentCacheBytes: Int = 0

    private var isReady = false
    private var readyContinuations: [CheckedContinuation<Void, Never>] = []

    /// Tracks number of active connections to prevent resource exhaustion
    private let connectionLock = NSLock()
    private var activeConnectionCount: Int = 0

    /// Dedicated URLSession for artwork downloads with no caching (we manage our own cache)
    private let downloadSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    var baseURL: String {
        "http://127.0.0.1:\(self.port)"
    }

    /// Converts a remote artwork URL to a localhost proxy URL.
    /// Returns nil if the input is nil or empty.
    static func localURL(for remoteURL: String?) -> String? {
        guard let remoteURL, !remoteURL.isEmpty else { return nil }
        guard let encoded = remoteURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return "\(self.shared.baseURL)/artwork?url=\(encoded)"
    }

    private init() {
        self.start()
    }

    private func start() {
        do {
            let params = NWParameters.tcp
            let listener = try NWListener(using: params, on: .any)

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    if let port = self.listener?.port?.rawValue {
                        self.port = port
                        self.cacheLock.lock()
                        self.isReady = true
                        let continuations = self.readyContinuations
                        self.readyContinuations.removeAll()
                        self.cacheLock.unlock()
                        for continuation in continuations {
                            continuation.resume()
                        }
                        logger.info("ArtworkServer listening on port \(port)")
                    }
                case let .failed(error):
                    logger.error("ArtworkServer listener failed: \(error.localizedDescription)")
                    self.listener?.cancel()
                    self.queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.start()
                    }
                case .cancelled:
                    logger.warning("ArtworkServer listener cancelled unexpectedly, restarting...")
                    self.queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.start()
                    }
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener.start(queue: self.queue)
            self.listener = listener
        } catch {
            logger.error("Failed to create ArtworkServer listener: \(error.localizedDescription)")
        }
    }

    /// Waits until the server is ready and listening.
    func waitUntilReady() async {
        self.cacheLock.lock()
        if self.isReady {
            self.cacheLock.unlock()
            return
        }
        self.cacheLock.unlock()

        await withCheckedContinuation { continuation in
            self.cacheLock.lock()
            if self.isReady {
                self.cacheLock.unlock()
                continuation.resume()
            } else {
                self.readyContinuations.append(continuation)
                self.cacheLock.unlock()
            }
        }
    }

    /// Pre-fetches artwork into the cache. Returns the localhost URL.
    func prefetch(from remoteURL: String) async -> String? {
        guard !remoteURL.isEmpty else { return nil }

        // Check if already cached
        self.cacheLock.lock()
        if self.cache[remoteURL] != nil {
            self.touchEntry(remoteURL)
            self.cacheLock.unlock()
            return Self.localURL(for: remoteURL)
        }
        self.cacheLock.unlock()

        // Download
        guard let data = await self.downloadArtwork(from: remoteURL) else {
            return nil
        }

        self.storeInCache(url: remoteURL, entry: data)
        return Self.localURL(for: remoteURL)
    }

    // MARK: - Cache Management

    private struct CacheEntry {
        let data: Data
        let contentType: String
    }

    private func storeInCache(url: String, entry: CacheEntry) {
        self.cacheLock.lock()
        defer { self.cacheLock.unlock() }

        // If already exists, remove old size
        if let existing = self.cache[url] {
            self.currentCacheBytes -= existing.data.count
            self.accessOrder.removeAll { $0 == url }
        }

        // Evict until we have space
        while self.currentCacheBytes + entry.data.count > Self.maxCacheBytes, !self.accessOrder.isEmpty {
            let evictURL = self.accessOrder.removeFirst()
            if let evicted = self.cache.removeValue(forKey: evictURL) {
                self.currentCacheBytes -= evicted.data.count
                logger.debug("Evicted artwork from cache: \(evictURL.prefix(60))")
            }
        }

        self.cache[url] = entry
        self.accessOrder.append(url)
        self.currentCacheBytes += entry.data.count
    }

    private func touchEntry(_ url: String) {
        self.accessOrder.removeAll { $0 == url }
        self.accessOrder.append(url)
    }

    private func getCachedEntry(for url: String) -> CacheEntry? {
        self.cacheLock.lock()
        defer { self.cacheLock.unlock() }
        guard let entry = self.cache[url] else { return nil }
        self.touchEntry(url)
        return entry
    }

    // MARK: - Connection Tracking

    private func incrementConnections() {
        self.connectionLock.lock()
        self.activeConnectionCount += 1
        self.connectionLock.unlock()
    }

    private func decrementConnections() {
        self.connectionLock.lock()
        self.activeConnectionCount = max(0, self.activeConnectionCount - 1)
        self.connectionLock.unlock()
    }

    private func getActiveConnectionCount() -> Int {
        self.connectionLock.lock()
        defer { self.connectionLock.unlock() }
        return self.activeConnectionCount
    }

    // MARK: - Networking

    private func downloadArtwork(from urlString: String) async -> CacheEntry? {
        guard let url = URL(string: urlString) else {
            logger.error("Invalid artwork URL: \(urlString)")
            return nil
        }

        do {
            let (data, response) = try await self.downloadSession.data(from: url)

            let contentType: String
            if let httpResponse = response as? HTTPURLResponse,
               let mimeType = httpResponse.value(forHTTPHeaderField: "Content-Type")
            {
                contentType = mimeType
            } else if urlString.hasSuffix(".png") {
                contentType = "image/png"
            } else if urlString.hasSuffix(".webp") {
                contentType = "image/webp"
            } else {
                contentType = "image/jpeg"
            }

            return CacheEntry(data: data, contentType: contentType)
        } catch {
            logger.error("Failed to download artwork from \(urlString.prefix(80)): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - HTTP Server

    private func handleConnection(_ connection: NWConnection) {
        let count = self.getActiveConnectionCount()

        // Enforce connection limit to prevent resource exhaustion
        if count >= Self.maxActiveConnections {
            logger.warning("Connection limit reached (\(count)/\(Self.maxActiveConnections)), rejecting")
            connection.cancel()
            return
        }

        self.incrementConnections()
        connection.start(queue: self.queue)

        // Set a timeout to cancel stale connections that never send data
        let timeoutItem = DispatchWorkItem { [weak self] in
            logger.debug("Connection timed out waiting for request data, cancelling")
            connection.cancel()
            self?.decrementConnections()
        }
        self.queue.asyncAfter(deadline: .now() + 10, execute: timeoutItem)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            timeoutItem.cancel()

            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                logger.debug("Connection receive error: \(error.localizedDescription)")
                connection.cancel()
                self.decrementConnections()
                return
            }

            guard let data, let request = String(data: data, encoding: .utf8) else {
                self.sendResponse(connection: connection, status: "400 Bad Request", contentType: "text/plain", body: Data("Bad Request".utf8), cacheSuccess: false)
                return
            }

            // Parse the request line to extract the URL query parameter
            guard let remoteURL = self.parseArtworkURL(from: request) else {
                self.sendResponse(connection: connection, status: "400 Bad Request", contentType: "text/plain", body: Data("Missing url parameter".utf8), cacheSuccess: false)
                return
            }

            // Check cache first
            if let cached = self.getCachedEntry(for: remoteURL) {
                self.sendResponse(connection: connection, status: "200 OK", contentType: cached.contentType, body: cached.data, cacheSuccess: true)
                return
            }

            // Download and cache
            Task {
                if let entry = await self.downloadArtwork(from: remoteURL) {
                    self.storeInCache(url: remoteURL, entry: entry)
                    self.sendResponse(connection: connection, status: "200 OK", contentType: entry.contentType, body: entry.data, cacheSuccess: true)
                } else {
                    self.sendResponse(connection: connection, status: "502 Bad Gateway", contentType: "text/plain", body: Data("Failed to fetch artwork".utf8), cacheSuccess: false)
                }
            }
        }
    }

    private func parseArtworkURL(from request: String) -> String? {
        // Extract first line: "GET /artwork?url=... HTTP/1.1"
        guard let firstLine = request.components(separatedBy: "\r\n").first else { return nil }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }

        let path = parts[1]
        guard path.hasPrefix("/artwork?url=") else { return nil }

        let queryPart = String(path.dropFirst("/artwork?url=".count))
        return queryPart.removingPercentEncoding ?? queryPart
    }

    private func sendResponse(connection: NWConnection, status: String, contentType: String, body: Data, cacheSuccess: Bool) {
        // For successful image responses, allow URLSession/AsyncImage to cache them long-term
        // so they don't re-request from our server. For errors, prevent caching so retries work.
        let cacheControl = cacheSuccess ? "public, max-age=86400" : "no-store, no-cache"

        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nCache-Control: \(cacheControl)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"

        var responseData = Data(header.utf8)
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed { [weak self] error in
            if let error {
                logger.debug("Send error: \(error.localizedDescription)")
            }
            connection.cancel()
            self?.decrementConnections()
        })
    }
}
