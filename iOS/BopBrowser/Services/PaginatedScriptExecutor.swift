import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "PaginatedScriptExecutor"
)

struct PageResult {
    let items: [[String: Any]]
    let paginationContext: [String: Any]?
}

class PaginatedScriptExecutor {
    static let shared = PaginatedScriptExecutor()

    private init() {}

    func executePage(
        script: String,
        params: [String: Any],
        previousResult: [String: Any]?,
        contextService: MediaSourceContextService
    ) async throws -> PageResult {
        let context = self.buildJSContext(params: params, previousResult: previousResult, contextService: contextService)
        let jsResult = try await JSExecutionEngine.shared.execute(script: script, context: context)
        return self.parsePageResult(jsResult)
    }

    func executeAllPages(
        script: String,
        params: [String: Any],
        contextService: MediaSourceContextService,
        mediaSourceName: String,
        onPageFetched: (([Song]) -> Void)? = nil
    ) async throws -> [Song] {
        var allSongs: [Song] = []
        var previousResult: [String: Any]? = nil

        while true {
            let page = try await self.executePage(
                script: script,
                params: params,
                previousResult: previousResult,
                contextService: contextService
            )

            let songs = page.items.compactMap { self.mapToSong($0, mediaSourceName: mediaSourceName) }
            allSongs.append(contentsOf: songs)

            logger.info("Fetched page with \(songs.count) song(s), total: \(allSongs.count)")

            onPageFetched?(allSongs)

            guard let nextContext = page.paginationContext else {
                break
            }
            previousResult = nextContext
        }

        logger.info("All pages fetched: \(allSongs.count) total song(s)")
        return allSongs
    }

    func buildJSContext(
        params: [String: Any],
        previousResult: [String: Any]?,
        contextService: MediaSourceContextService
    ) -> [String: Any] {
        var context: [String: Any] = params
        context["capturedValues"] = contextService.allContextData()

        if let previousResult {
            context["previousResult"] = previousResult
        }

        return context
    }

    func parsePageResult(_ jsResult: [String: Any]) -> PageResult {
        let items: [[String: Any]]
        if let itemsArray = jsResult["items"] as? [[String: Any]] {
            items = itemsArray
        } else {
            items = []
        }

        var paginationData = jsResult
        paginationData.removeValue(forKey: "items")
        let hasPaginationContext = paginationData.values.contains { !($0 is NSNull) }
        let paginationContext: [String: Any]? = hasPaginationContext ? jsResult : nil

        return PageResult(items: items, paginationContext: paginationContext)
    }

    func mapToSong(_ item: [String: Any], mediaSourceName: String) -> Song? {
        guard let title = item["title"] as? String else { return nil }
        return Song(
            title: title,
            artist: item["artist"] as? String,
            duration: self.resolveInt(item["duration"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            mediaSourceName: mediaSourceName,
            metadata: self.resolveMetadata(item["metadata"])
        )
    }

    func mapToAlbum(_ item: [String: Any]) -> Album? {
        guard let title = item["title"] as? String else { return nil }
        return Album(
            title: title,
            artist: item["artist"] as? String,
            trackCount: self.resolveInt(item["trackCount"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            metadata: self.resolveMetadata(item["metadata"])
        )
    }

    func mapToArtist(_ item: [String: Any]) -> Artist? {
        guard let name = (item["name"] as? String) ?? (item["artist"] as? String) else { return nil }
        return Artist(
            name: name,
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            metadata: self.resolveMetadata(item["metadata"])
        )
    }

    func mapToPlaylist(_ item: [String: Any]) -> Playlist? {
        guard let title = item["title"] as? String else { return nil }
        return Playlist(
            title: title,
            user: item["user"] as? String,
            trackCount: self.resolveInt(item["trackCount"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            metadata: self.resolveMetadata(item["metadata"])
        )
    }

    func resolveMetadata(_ value: Any?) -> [String: String] {
        guard let rawMetadata = value as? [String: Any] else { return [:] }
        var metadata: [String: String] = [:]
        for (key, value) in rawMetadata {
            if let stringValue = value as? String {
                metadata[key] = stringValue
            } else {
                metadata[key] = String(describing: value)
            }
        }
        return metadata
    }

    func resolveInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }
}
