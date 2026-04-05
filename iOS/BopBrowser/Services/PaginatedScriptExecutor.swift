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
        customUserAgent: String?,
        domain: String
    ) async throws -> PageResult {
        let context = self.buildJSContext(params: params, previousResult: previousResult)
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            context: context,
            customUserAgent: customUserAgent,
            domain: domain
        )
        return self.parsePageResult(jsResult)
    }

    func executeAllPages(
        script: String,
        params: [String: Any],
        customUserAgent: String?,
        domain: String,
        mediaSourceName: String,
        onPageFetched: (([Track]) -> Void)? = nil
    ) async throws -> [Track] {
        var allTracks: [Track] = []
        var previousResult: [String: Any]? = nil

        while true {
            let page = try await self.executePage(
                script: script,
                params: params,
                previousResult: previousResult,
                customUserAgent: customUserAgent,
                domain: domain
            )

            let tracks = page.items.compactMap { self.mapToTrack($0, mediaSourceName: mediaSourceName) }
            allTracks.append(contentsOf: tracks)

            logger.info("Fetched page with \(tracks.count) track(s), total: \(allTracks.count)")

            onPageFetched?(allTracks)

            guard let nextContext = page.paginationContext else {
                break
            }
            previousResult = nextContext
        }

        logger.info("All pages fetched: \(allTracks.count) total track(s)")
        return allTracks
    }

    func buildJSContext(
        params: [String: Any],
        previousResult: [String: Any]?
    ) -> [String: Any] {
        var context: [String: Any] = params

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

    func mapToTrack(_ item: [String: Any], mediaSourceName: String) -> Track? {
        guard let title = item["title"] as? String else { return nil }
        return Track(
            title: title,
            subtitle: item["subtitle"] as? String,
            duration: self.resolveInt(item["duration"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            mediaSourceName: mediaSourceName,
            artists: self.resolveDictOfFlatDicts(item["artists"]),
            album: self.resolveDictOfFlatDicts(item["album"]),
            metadata: self.resolveFlatDict(item["metadata"])
        )
    }

    func mapToAlbum(_ item: [String: Any]) -> Album? {
        guard let title = item["title"] as? String else { return nil }
        return Album(
            title: title,
            subtitle: item["subtitle"] as? String,
            trackCount: self.resolveInt(item["trackCount"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            metadata: self.resolveFlatDict(item["metadata"])
        )
    }

    func mapToArtist(_ item: [String: Any]) -> Artist? {
        guard let name = (item["name"] as? String) else { return nil }
        return Artist(
            name: name,
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            metadata: self.resolveFlatDict(item["metadata"])
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
            metadata: self.resolveFlatDict(item["metadata"])
        )
    }

    func resolveFlatDict(_ value: Any?) -> [String: String] {
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

    func resolveDictOfFlatDicts(_ value: Any?) -> [String: [String: String]] {
        guard let dict = value as? [String: [String: Any]] else { return [:] }
        var result: [String: [String: String]] = [:]
        for (key, value) in dict {
            result[key] = self.resolveFlatDict(value)
        }
        return result
    }

    func resolveInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }
}
