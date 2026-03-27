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
        onPageFetched: (([Song]) -> Void)? = nil
    ) async throws {
        guard let script = config.data?.listLikes?.script else {
            logger.warning("No listLikes script for '\(mediaSourceName)'")
            return
        }

        logger.info("Fetching likes for '\(mediaSourceName)'...")

        let songs = try await self.paginated.executeAllPages(
            script: script,
            params: [:],
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceName: mediaSourceName,
            onPageFetched: { allSongsSoFar in
                onPageFetched?(allSongsSoFar)
            }
        )

        self.persistSongs(songs, into: tracklist, modelContext: modelContext, pruneStale: true)
        onPageFetched?(songs)
        logger.info("Persisted \(songs.count) liked song(s) for '\(mediaSourceName)'")
    }

    func fetchAlbum(
        album: Album,
        config: MediaSourceConfig,
        mediaSourceName: String,
        onPageFetched: (([Song]) -> Void)? = nil
    ) async throws -> [Song] {
        guard let script = config.data?.getAlbum?.script else {
            logger.warning("No getAlbum script for '\(mediaSourceName)'")
            return []
        }

        logger.info("Fetching album '\(album.title)' for '\(mediaSourceName)'...")

        var itemParams: [String: Any] = [:]
        itemParams["artist"] = album.artist ?? ""
        itemParams["artworkUrl"] = album.artworkUrl ?? ""
        for (key, value) in album.metadata {
            itemParams[key] = value
        }

        let songs = try await self.paginated.executeAllPages(
            script: script,
            params: ["item": itemParams],
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceName: mediaSourceName,
            onPageFetched: { allSongsSoFar in
                onPageFetched?(allSongsSoFar)
            }
        )

        logger.info("Fetched \(songs.count) song(s) for album '\(album.title)'")
        return songs
    }

    func persistSongs(_ songs: [Song], into tracklist: StoredTracklist, modelContext: ModelContext, pruneStale: Bool) {
        let existingSongs = tracklist.songs

        for (index, song) in songs.enumerated() {
            if let match = existingSongs.first(where: { $0.contentMatches(song) }) {
                match.sortOrder = index
            } else {
                let stored = StoredSong.from(song, sortOrder: index)
                stored.tracklist = tracklist
                modelContext.insert(stored)
            }
        }

        if pruneStale {
            for existing in existingSongs {
                if !songs.contains(where: { existing.contentMatches($0) }) {
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
