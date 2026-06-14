import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "PaginatedScriptExecutor"
)

class PaginatedScriptExecutor {
    static let shared = PaginatedScriptExecutor()

    private init() {}

    func executeRaw(
        script: String,
        params: [String: Any],
        previousResult: [String: Any]? = nil,
        customUserAgent: String?,
        domain: String,
        context: [String: String] = [:]
    ) async throws -> [String: Any] {
        var jsParams: [String: Any] = params
        if let previousResult {
            jsParams["previousResult"] = previousResult
        }
        return try await JSExecutionEngine.shared.execute(
            script: script,
            params: jsParams,
            customUserAgent: customUserAgent,
            domain: domain,
            context: context
        )
    }

    func mapToTrack(_ script: ScriptTrack, mediaSourceId: String) -> Track {
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

    func mapToTracklist(_ script: ScriptTracklist, mediaSourceId: String, tracklistType: Tracklist.TracklistType) -> Tracklist {
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

    func mapToArtist(_ script: ScriptArtist, mediaSourceId: String) -> Artist {
        Artist(
            mediaId: script.id,
            mediaSourceId: mediaSourceId,
            name: script.name,
            artworkUrl: script.artworkUrl,
            url: script.url
        )
    }
}
