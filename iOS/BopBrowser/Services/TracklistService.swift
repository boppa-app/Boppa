import Foundation
import os
import SwiftData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "TracklistService"
)

class TracklistService {
    static let shared = TracklistService()

    private let paginated = PaginatedScriptExecutor.shared

    private init() {}

    func fetchLikes(
        config: MediaSourceConfig,
        mediaSourceName: String,
        tracklist: StoredTracklist,
        modelContext: ModelContext,
        onPageFetched: (([Track]) -> Void)? = nil
    ) async throws {
        guard let script = config.data?.listLikes?.script else {
            logger.warning("No listLikes script for '\(mediaSourceName)'")
            return
        }

        logger.info("Fetching likes for '\(mediaSourceName)'...")

        let tracks = try await self.paginated.executeAllPages(
            script: script,
            params: [:],
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceName: mediaSourceName,
            onPageFetched: { allTracksSoFar in
                onPageFetched?(allTracksSoFar)
            }
        )

        self.persistTracks(tracks, into: tracklist, modelContext: modelContext, pruneStale: true)
        onPageFetched?(tracks)
        logger.info("Persisted \(tracks.count) liked track(s) for '\(mediaSourceName)'")
    }

    func fetchAlbum(
        album: Album,
        config: MediaSourceConfig,
        mediaSourceName: String,
        onPageFetched: (([Track]) -> Void)? = nil
    ) async throws -> [Track] {
        guard let script = config.data?.getAlbum?.script else {
            logger.warning("No getAlbum script for '\(mediaSourceName)'")
            return []
        }

        logger.info("Fetching album '\(album.title)' for '\(mediaSourceName)'...")

        var itemParams: [String: Any] = [:]
        itemParams["subtitle"] = album.subtitle ?? ""
        itemParams["artworkUrl"] = album.artworkUrl ?? ""
        for (key, value) in album.metadata {
            itemParams[key] = value
        }

        let tracks = try await self.paginated.executeAllPages(
            script: script,
            params: ["item": itemParams],
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceName: mediaSourceName,
            onPageFetched: { allTracksSoFar in
                onPageFetched?(allTracksSoFar)
            }
        )

        logger.info("Fetched \(tracks.count) track(s) for album '\(album.title)'")
        return tracks
    }

    func persistTracks(_ tracks: [Track], into tracklist: StoredTracklist, modelContext: ModelContext, pruneStale: Bool) {
        let existingTracks = tracklist.tracks

        for (index, track) in tracks.enumerated() {
            if let match = existingTracks.first(where: { $0.identityMatches(track) }) {
                match.sortOrder = index
                if !match.contentMatches(track) {
                    match.updateContent(from: track)
                }
            } else {
                let stored = StoredTrack.from(track, sortOrder: index)
                stored.tracklist = tracklist
                modelContext.insert(stored)
            }
        }

        if pruneStale {
            for existing in existingTracks {
                if !tracks.contains(where: { existing.identityMatches($0) }) {
                    modelContext.delete(existing)
                }
            }
        }

        try? modelContext.save()
    }

    func ensureLikesPlaylist(mediaSourceName: String, modelContext: ModelContext) -> StoredTracklist? {
        let descriptor = FetchDescriptor<StoredTracklist>(
            predicate: #Predicate { $0.mediaSourceName == mediaSourceName && $0.tracklistType == "likes" }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let tracklist = StoredTracklist(
            name: "Likes",
            mediaSourceName: mediaSourceName,
            tracklistType: "likes"
        )
        modelContext.insert(tracklist)
        try? modelContext.save()
        return tracklist
    }
}
