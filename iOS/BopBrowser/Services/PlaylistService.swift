import Foundation
import os
import SwiftData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "PlaylistService"
)

class PlaylistService {
    static let shared = PlaylistService()

    private let paginated = PaginatedScriptExecutor.shared

    private init() {}

    func fetchLikes(
        config: MediaSourceConfig,
        mediaSourceName: String,
        playlist: StoredPlaylist,
        modelContext: ModelContext,
        contextService: MediaSourceContextProvider,
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
            contextService: contextService,
            mediaSourceName: mediaSourceName,
            onPageFetched: { allSongsSoFar in
                onPageFetched?(allSongsSoFar)
            }
        )

        self.persistSongs(songs, into: playlist, modelContext: modelContext, pruneStale: true)
        onPageFetched?(songs)
        logger.info("Persisted \(songs.count) liked song(s) for '\(mediaSourceName)'")
    }

    func persistSongs(_ songs: [Song], into playlist: StoredPlaylist, modelContext: ModelContext, pruneStale: Bool) {
        let existingSongs = playlist.songs

        for (index, song) in songs.enumerated() {
            if let match = existingSongs.first(where: { $0.contentMatches(song) }) {
                match.sortOrder = index
            } else {
                let stored = StoredSong.from(song, sortOrder: index)
                stored.playlist = playlist
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

    func ensureLikesPlaylist(mediaSourceName: String, modelContext: ModelContext) -> StoredPlaylist? {
        let descriptor = FetchDescriptor<StoredPlaylist>(
            predicate: #Predicate { $0.mediaSourceName == mediaSourceName && $0.playlistType == "likes" }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let playlist = StoredPlaylist(
            name: "Likes",
            mediaSourceName: mediaSourceName,
            playlistType: "likes"
        )
        modelContext.insert(playlist)
        try? modelContext.save()
        return playlist
    }
}
