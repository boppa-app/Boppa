import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
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
        context: [String: String] = [:]
    ) async throws -> PageResult {
        let jsParams = self.buildJSParams(params: params, previousResult: previousResult)
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: jsParams,
            customUserAgent: customUserAgent,
            domain: domain,
            context: context
        )
        return self.parsePageResult(jsResult)
    }

    func executeAllPages(
        script: String,
        params: [String: Any],
        customUserAgent: String?,
        domain: String,
        mediaSourceId: String,
        context: [String: String] = [:],
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
                context: context
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

    func buildJSParams(
        params: [String: Any],
        previousResult: [String: Any]?
    ) -> [String: Any] {
        var jsParams: [String: Any] = params

        if let previousResult {
            jsParams["previousResult"] = previousResult
        }

        return jsParams
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
        guard let script = ScriptTrackItem(item) else { return nil }
        return self.mapToTrack(script, mediaSourceId: mediaSourceId)
    }

    func mapToTrack(_ script: ScriptTrackItem, mediaSourceId: String) -> Track {
        Track(
            mediaId: script.id,
            mediaSourceId: mediaSourceId,
            title: script.title,
            subtitle: script.subtitle,
            duration: script.duration,
            artworkUrl: script.artworkUrl,
            url: script.url,
            artists: script.artists.map {
                Artist(mediaId: $0.id, mediaSourceId: mediaSourceId, name: $0.name, artworkUrl: $0.artworkUrl)
            },
            albums: script.albums.map {
                Tracklist(mediaId: $0.id, mediaSourceId: mediaSourceId, title: $0.title, subtitle: $0.subtitle, artworkUrl: $0.artworkUrl, tracklistType: .album)
            }
        )
    }

    func mapToTracklist(_ item: [String: Any], mediaSourceId: String, tracklistType: Tracklist.TracklistType) -> Tracklist? {
        guard let script = ScriptTracklistItem(item) else { return nil }
        return self.mapToTracklist(script, mediaSourceId: mediaSourceId, tracklistType: tracklistType)
    }

    func mapToTracklist(_ script: ScriptTracklistItem, mediaSourceId: String, tracklistType: Tracklist.TracklistType) -> Tracklist {
        Tracklist(
            mediaId: script.id,
            mediaSourceId: mediaSourceId,
            title: script.title,
            subtitle: script.subtitle,
            year: script.year,
            trackCount: script.trackCount,
            artworkUrl: script.artworkUrl,
            url: script.url,
            tracklistType: tracklistType
        )
    }

    func mapToArtist(_ item: [String: Any], mediaSourceId: String) -> Artist? {
        guard let script = ScriptArtistItem(item) else { return nil }
        return self.mapToArtist(script, mediaSourceId: mediaSourceId)
    }

    func mapToArtist(_ script: ScriptArtistItem, mediaSourceId: String) -> Artist {
        Artist(
            mediaId: script.id,
            mediaSourceId: mediaSourceId,
            name: script.name,
            artworkUrl: script.artworkUrl,
            url: script.url
        )
    }
}
