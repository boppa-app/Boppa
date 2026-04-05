import Foundation
import os
import SwiftData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "TracklistService"
)

struct TracklistResponse {
    let tracks: [Track]
    let paginationContext: [String: Any]?
}

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

    func fetchTracklist(
        tracklist: Tracklist,
        config: MediaSourceConfig,
        previousResult: [String: Any]? = nil
    ) async throws -> TracklistResponse {
        switch tracklist.tracklistType {
        case let .album(album):
            return try await self.fetchAlbumPage(
                album: album,
                config: config,
                mediaSourceName: tracklist.mediaSourceName,
                previousResult: previousResult
            )
        case let .playlist(playlist):
            return try await self.fetchPlaylistPage(
                playlist: playlist,
                config: config,
                mediaSourceName: tracklist.mediaSourceName,
                previousResult: previousResult
            )
        case .likes:
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
    }

    private func fetchAlbumPage(
        album: Album,
        config: MediaSourceConfig,
        mediaSourceName: String,
        previousResult: [String: Any]?
    ) async throws -> TracklistResponse {
        guard let script = config.data?.getAlbum?.script else {
            logger.warning("No getAlbum script for '\(mediaSourceName)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }

        logger.info("Fetching album '\(album.title)' for '\(mediaSourceName)'...")

        var itemParams: [String: Any] = [:]
        itemParams["subtitle"] = album.subtitle ?? ""
        itemParams["artworkUrl"] = album.artworkUrl ?? ""
        for (key, value) in album.metadata {
            itemParams[key] = value
        }

        let page = try await self.paginated.executePage(
            script: script,
            params: ["item": itemParams],
            previousResult: previousResult,
            customUserAgent: config.customUserAgent,
            domain: config.url
        )

        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceName: mediaSourceName) }
        logger.info("Fetched \(tracks.count) track(s) for album '\(album.title)'")

        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
    }

    private func fetchPlaylistPage(
        playlist: Playlist,
        config: MediaSourceConfig,
        mediaSourceName: String,
        previousResult: [String: Any]?
    ) async throws -> TracklistResponse {
        guard let script = config.data?.getPlaylist?.script else {
            logger.warning("No getPlaylist script for '\(mediaSourceName)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }

        logger.info("Fetching playlist '\(playlist.title)' for '\(mediaSourceName)'...")

        var itemParams: [String: Any] = [:]
        itemParams["user"] = playlist.user ?? ""
        itemParams["artworkUrl"] = playlist.artworkUrl ?? ""
        for (key, value) in playlist.metadata {
            itemParams[key] = value
        }

        let page = try await self.paginated.executePage(
            script: script,
            params: ["item": itemParams],
            previousResult: previousResult,
            customUserAgent: config.customUserAgent,
            domain: config.url
        )

        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceName: mediaSourceName) }
        logger.info("Fetched \(tracks.count) track(s) for playlist '\(playlist.title)'")

        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
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
