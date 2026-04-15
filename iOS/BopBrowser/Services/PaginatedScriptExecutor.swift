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
        domain: String,
        mediaSourceContext: [String: String] = [:]
    ) async throws -> PageResult {
        let context = self.buildJSContext(params: params, previousResult: previousResult)
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            context: context,
            customUserAgent: customUserAgent,
            domain: domain,
            mediaSourceContext: mediaSourceContext
        )
        return self.parsePageResult(jsResult)
    }

    func executeAllPages(
        script: String,
        params: [String: Any],
        customUserAgent: String?,
        domain: String,
        mediaSourceId: String,
        mediaSourceContext: [String: String] = [:],
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
                domain: domain,
                mediaSourceContext: mediaSourceContext
            )

            let tracks = page.items.compactMap { self.mapToTrack($0, mediaSourceId: mediaSourceId) }
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
        paginationData.removeValue(forKey: "__keyOrder")
        let hasPaginationContext = paginationData.values.contains { !($0 is NSNull) }
        let paginationContext: [String: Any]? = hasPaginationContext ? paginationData : nil

        return PageResult(items: items, paginationContext: paginationContext)
    }

    func mapToTrack(_ item: [String: Any], mediaSourceId: String) -> Track? {
        guard let title = item["title"] as? String,
              let id = self.resolveString(item["id"])
        else { return nil }

        var artists: [String: Artist] = [:]
        if let rawArtists = item["artists"] as? [String: [String: Any]] {
            for (name, data) in rawArtists {
                guard let artistId = self.resolveString(data["id"]) else { continue }
                artists[name] = Artist(
                    id: artistId,
                    mediaSourceId: mediaSourceId,
                    name: name,
                    artworkUrl: data["artworkUrl"] as? String,
                    metadata: data["metadata"] as? [String: Any] ?? [:]
                )
            }
        }

        var albums: [String: Tracklist] = [:]
        if let rawAlbums = item["albums"] as? [String: [String: Any]] {
            for (name, data) in rawAlbums {
                guard let albumId = self.resolveString(data["id"]) else { continue }
                albums[name] = Tracklist(
                    id: albumId,
                    mediaSourceId: mediaSourceId,
                    title: name,
                    subtitle: data["subtitle"] as? String,
                    artworkUrl: data["artworkUrl"] as? String,
                    metadata: data["metadata"] as? [String: Any] ?? [:],
                    tracklistType: .album
                )
            }
        }

        return Track(
            id: id,
            mediaSourceId: mediaSourceId,
            title: title,
            subtitle: item["subtitle"] as? String,
            duration: self.resolveInt(item["duration"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            artists: artists,
            albums: albums,
            metadata: item["metadata"] as? [String: Any] ?? [:]
        )
    }

    func mapToTracklist(_ item: [String: Any], mediaSourceId: String, tracklistType: Tracklist.TracklistType) -> Tracklist? {
        guard let title = item["title"] as? String,
              let id = self.resolveString(item["id"])
        else { return nil }
        return Tracklist(
            id: id,
            mediaSourceId: mediaSourceId,
            title: title,
            subtitle: item["subtitle"] as? String ?? item["user"] as? String,
            trackCount: self.resolveInt(item["trackCount"]),
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            metadata: item["metadata"] as? [String: Any] ?? [:],
            tracklistType: tracklistType
        )
    }

    func mapToArtist(_ item: [String: Any], mediaSourceId: String) -> Artist? {
        guard let name = (item["name"] as? String),
              let id = self.resolveString(item["id"])
        else { return nil }
        return Artist(
            id: id,
            mediaSourceId: mediaSourceId,
            name: name,
            artworkUrl: item["artworkUrl"] as? String,
            url: item["url"] as? String,
            metadata: item["metadata"] as? [String: Any] ?? [:]
        )
    }

    func resolveString(_ value: Any?) -> String? {
        if let stringValue = value as? String { return stringValue }
        if let intValue = value as? Int { return String(intValue) }
        if let doubleValue = value as? Double { return String(Int(doubleValue)) }
        return nil
    }

    func resolveInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }
}
