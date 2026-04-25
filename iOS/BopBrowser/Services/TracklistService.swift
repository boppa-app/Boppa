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

    func resolveMediaSource(mediaSourceId: String, modelContext: ModelContext) -> MediaSource? {
        let descriptor = FetchDescriptor<MediaSource>(
            predicate: #Predicate { $0.id == mediaSourceId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func fetchTracklist(
        tracklist: Tracklist,
        modelContext: ModelContext,
        previousResult: [String: Any]? = nil
    ) async throws -> TracklistResponse {
        guard let mediaSource = self.resolveMediaSource(mediaSourceId: tracklist.mediaSourceId, modelContext: modelContext)
        else {
            return TracklistResponse(tracks: [], paginationContext: nil)
        }

        let config = mediaSource.config
        let mediaSourceId = tracklist.mediaSourceId

        switch tracklist.tracklistType {
        case .album:
            return try await self.fetchAlbumPage(
                tracklist: tracklist,
                config: config,
                mediaSourceId: mediaSourceId,
                mediaSourceContext: mediaSource.contextValues,
                previousResult: previousResult
            )
        case .playlist:
            return try await self.fetchPlaylistPage(
                tracklist: tracklist,
                config: config,
                mediaSourceId: mediaSourceId,
                mediaSourceContext: mediaSource.contextValues,
                previousResult: previousResult
            )
        case .artistSongs:
            return try await self.fetchArtistTracksPage(
                tracklist: tracklist,
                script: config.data?.getSongsForArtist?.script,
                scriptName: "getSongsForArtist",
                config: config,
                mediaSourceId: mediaSourceId,
                mediaSourceContext: mediaSource.contextValues,
                previousResult: previousResult
            )
        case .artistVideos:
            return try await self.fetchArtistTracksPage(
                tracklist: tracklist,
                script: config.data?.getVideosForArtist?.script,
                scriptName: "getVideosForArtist",
                config: config,
                mediaSourceId: mediaSourceId,
                mediaSourceContext: mediaSource.contextValues,
                previousResult: previousResult
            )
        case .likes:
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
    }

    func fetchArtist(
        artist: Artist,
        mediaSource: MediaSource
    ) async throws -> ArtistDetail {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.data?.getArtist?.script else {
            logger.warning("No getArtist script for '\(mediaSourceId)'")
            return ArtistDetail()
        }

        logger.info("Fetching artist '\(artist.name)' for '\(mediaSourceId)'...")

        var itemParams: [String: Any] = [:]
        itemParams["name"] = artist.name
        itemParams["artworkUrl"] = artist.artworkUrl ?? ""
        for (key, value) in artist.metadata {
            itemParams[key] = value
        }

        let context = self.paginated.buildJSContext(
            params: ["item": itemParams],
            previousResult: nil
        )

        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            context: context,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceContext: mediaSource.contextValues
        )

        let songs = (jsResult["songs"] as? [[String: Any]])?.compactMap {
            self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId)
        }

        let albums = (jsResult["albums"] as? [[String: Any]])?.compactMap {
            self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .album)
        }

        let videos = (jsResult["videos"] as? [[String: Any]])?.compactMap {
            self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId)
        }

        let playlists = (jsResult["playlists"] as? [[String: Any]])?.compactMap {
            self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .playlist)
        }

        let metadata = jsResult["metadata"] as? [String: Any] ?? [:]

        let sectionOrder: [ArtistDetailSection] = (jsResult["__keyOrder"] as? [String] ?? [])
            .compactMap { ArtistDetailSection(rawValue: $0) }

        logger.info("Fetched artist '\(artist.name)': \(songs?.count ?? 0) song(s), \(albums?.count ?? 0) album(s), \(videos?.count ?? 0) video(s), \(playlists?.count ?? 0) playlist(s)")

        return ArtistDetail(songs: songs, albums: albums, videos: videos, playlists: playlists, metadata: metadata, sectionOrder: sectionOrder)
    }

    func fetchAlbumsForArtist(
        artist: Artist,
        artistDetail: ArtistDetail,
        mediaSource: MediaSource
    ) async throws -> [Tracklist] {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.data?.getAlbumsForArtist?.script else {
            logger.warning("No getAlbumsForArtist script for '\(mediaSourceId)'")
            return []
        }

        logger.info("Fetching all albums for artist '\(artist.name)' on '\(mediaSourceId)'...")

        var itemParams: [String: Any] = [:]
        itemParams["name"] = artist.name
        itemParams["artworkUrl"] = artist.artworkUrl ?? ""
        for (key, value) in artist.metadata {
            itemParams[key] = value
        }
        for (key, value) in artistDetail.metadata {
            itemParams[key] = value
        }

        let context = self.paginated.buildJSContext(
            params: ["item": itemParams],
            previousResult: nil
        )

        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            context: context,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceContext: mediaSource.contextValues
        )

        let albums = (jsResult["items"] as? [[String: Any]] ?? [])
            .compactMap { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .album) }

        logger.info("Fetched \(albums.count) album(s) for artist '\(artist.name)'")
        return albums
    }

    func fetchPlaylistsForArtist(
        artist: Artist,
        artistDetail: ArtistDetail,
        mediaSource: MediaSource
    ) async throws -> [Tracklist] {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.data?.getPlaylistsForArtist?.script else {
            logger.warning("No getPlaylistsForArtist script for '\(mediaSourceId)'")
            return []
        }

        logger.info("Fetching all playlists for artist '\(artist.name)' on '\(mediaSourceId)'...")

        var itemParams: [String: Any] = [:]
        itemParams["name"] = artist.name
        itemParams["artworkUrl"] = artist.artworkUrl ?? ""
        for (key, value) in artist.metadata {
            itemParams[key] = value
        }
        for (key, value) in artistDetail.metadata {
            itemParams[key] = value
        }

        let context = self.paginated.buildJSContext(
            params: ["item": itemParams],
            previousResult: nil
        )

        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            context: context,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceContext: mediaSource.contextValues
        )

        let playlists = (jsResult["items"] as? [[String: Any]] ?? [])
            .compactMap { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .playlist) }

        logger.info("Fetched \(playlists.count) playlist(s) for artist '\(artist.name)'")
        return playlists
    }

    private func fetchArtistTracksPage(
        tracklist: Tracklist,
        script: String?,
        scriptName: String,
        config: MediaSourceConfig,
        mediaSourceId: String,
        mediaSourceContext: [String: String],
        previousResult: [String: Any]?
    ) async throws -> TracklistResponse {
        guard let script else {
            logger.warning("No \(scriptName) script for '\(mediaSourceId)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }

        guard let artist = tracklist.fromArtist else {
            logger.warning("No artist for \(scriptName) on '\(mediaSourceId)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }

        logger.info("Fetching \(scriptName) for artist '\(artist.name)' on '\(mediaSourceId)'...")

        var itemParams: [String: Any] = [:]
        itemParams["name"] = artist.name
        itemParams["artworkUrl"] = artist.artworkUrl ?? ""
        for (key, value) in artist.metadata {
            itemParams[key] = value
        }
        if let artistDetail = tracklist.artistDetail {
            for (key, value) in artistDetail.metadata {
                itemParams[key] = value
            }
        }

        let page = try await self.paginated.executePage(
            script: script,
            params: ["item": itemParams],
            previousResult: previousResult,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceContext: mediaSourceContext
        )

        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        logger.info("Fetched \(tracks.count) track(s) via \(scriptName) for artist '\(artist.name)'")

        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
    }

    private func fetchAlbumPage(
        tracklist: Tracklist,
        config: MediaSourceConfig,
        mediaSourceId: String,
        mediaSourceContext: [String: String],
        previousResult: [String: Any]?
    ) async throws -> TracklistResponse {
        guard let script = config.data?.getAlbum?.script else {
            logger.warning("No getAlbum script for '\(mediaSourceId)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }

        logger.info("Fetching album '\(tracklist.title)' for '\(mediaSourceId)'...")

        var itemParams: [String: Any] = [:]
        itemParams["subtitle"] = tracklist.subtitle ?? ""
        itemParams["artworkUrl"] = tracklist.artworkUrl ?? ""
        for (key, value) in tracklist.metadata {
            itemParams[key] = value
        }

        let page = try await self.paginated.executePage(
            script: script,
            params: ["item": itemParams],
            previousResult: previousResult,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceContext: mediaSourceContext
        )

        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        logger.info("Fetched \(tracks.count) track(s) for album '\(tracklist.title)'")

        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
    }

    private func fetchPlaylistPage(
        tracklist: Tracklist,
        config: MediaSourceConfig,
        mediaSourceId: String,
        mediaSourceContext: [String: String],
        previousResult: [String: Any]?
    ) async throws -> TracklistResponse {
        guard let script = config.data?.getPlaylist?.script else {
            logger.warning("No getPlaylist script for '\(mediaSourceId)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }

        logger.info("Fetching playlist '\(tracklist.title)' for '\(mediaSourceId)'...")

        var itemParams: [String: Any] = [:]
        itemParams["user"] = tracklist.subtitle ?? ""
        itemParams["artworkUrl"] = tracklist.artworkUrl ?? ""
        for (key, value) in tracklist.metadata {
            itemParams[key] = value
        }

        let page = try await self.paginated.executePage(
            script: script,
            params: ["item": itemParams],
            previousResult: previousResult,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceContext: mediaSourceContext
        )

        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        logger.info("Fetched \(tracks.count) track(s) for playlist '\(tracklist.title)'")

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

    @MainActor func saveTracklistToLibrary(
        tracklist: Tracklist,
        modelContext: ModelContext,
        onPageFetched: (([Track]) -> Void)? = nil
    ) async throws -> StoredTracklist {
        guard let mediaSource = self.resolveMediaSource(mediaSourceId: tracklist.mediaSourceId, modelContext: modelContext)
        else {
            throw NSError(domain: "TracklistService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No media source found for tracklist"])
        }

        let (script, itemParams) = try self.buildFetchParams(tracklist: tracklist, config: mediaSource.config)

        logger.info("Saving tracklist '\(tracklist.title)' to library for '\(tracklist.mediaSourceId)'...")

        let tracks = try await self.paginated.executeAllPages(
            script: script,
            params: ["item": itemParams],
            customUserAgent: mediaSource.config.customUserAgent,
            domain: mediaSource.config.url,
            mediaSourceId: tracklist.mediaSourceId,
            mediaSourceContext: mediaSource.contextValues,
            onPageFetched: { allTracksSoFar in
                onPageFetched?(allTracksSoFar)
            }
        )

        let stored = self.upsertStoredTracklist(
            tracklist: tracklist,
            modelContext: modelContext
        )

        self.persistTracks(tracks, into: stored, modelContext: modelContext, pruneStale: true)

        logger.info("Saved tracklist '\(tracklist.title)' with \(tracks.count) track(s) to library")

        return stored
    }

    private func buildFetchParams(tracklist: Tracklist, config: MediaSourceConfig) throws -> (script: String, params: [String: Any]) {
        let script: String?
        var itemParams: [String: Any] = [:]

        switch tracklist.tracklistType {
        case .playlist:
            script = config.data?.getPlaylist?.script
            itemParams["user"] = tracklist.subtitle ?? ""
            itemParams["artworkUrl"] = tracklist.artworkUrl ?? ""
            for (key, value) in tracklist.metadata {
                itemParams[key] = value
            }
        case .album:
            script = config.data?.getAlbum?.script
            itemParams["subtitle"] = tracklist.subtitle ?? ""
            itemParams["artworkUrl"] = tracklist.artworkUrl ?? ""
            for (key, value) in tracklist.metadata {
                itemParams[key] = value
            }
        default:
            throw NSError(domain: "TracklistService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot save this tracklist type to library"])
        }

        guard let script else {
            throw NSError(domain: "TracklistService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No script available for this tracklist type"])
        }

        return (script, itemParams)
    }

    @MainActor private func upsertStoredTracklist(
        tracklist: Tracklist,
        modelContext: ModelContext
    ) -> StoredTracklist {
        if let existing = self.findStoredTracklist(id: tracklist.id, modelContext: modelContext) {
            existing.name = tracklist.title
            existing.subtitle = tracklist.subtitle
            existing.artworkUrl = tracklist.artworkUrl
            existing.metadataJSON = (try? JSONSerialization.data(withJSONObject: tracklist.metadata)) ?? Data()
            existing.artistsJSON = StoredTracklist.encodeArtists(tracklist.artists)
            existing.fromArtistJSON = StoredTracklist.encodeArtist(tracklist.fromArtist)
            return existing
        }

        let typeString = tracklist.tracklistType.rawValue
        let descriptor = FetchDescriptor<StoredTracklist>(
            predicate: #Predicate { $0.tracklistType == typeString && $0.nextId == nil }
        )
        let currentTail = (try? modelContext.fetch(descriptor))?.first

        let stored = StoredTracklist(
            id: tracklist.id,
            name: tracklist.title,
            subtitle: tracklist.subtitle,
            mediaSourceId: tracklist.mediaSourceId,
            artworkUrl: tracklist.artworkUrl,
            tracklistType: typeString,
            metadata: tracklist.metadata,
            artists: tracklist.artists,
            fromArtist: tracklist.fromArtist
        )
        stored.prevId = currentTail?.id
        stored.nextId = nil
        modelContext.insert(stored)

        if let tail = currentTail {
            tail.nextId = stored.id
        }

        try? modelContext.save()
        return stored
    }

    @MainActor func deleteStoredTracklist(_ storedTracklist: StoredTracklist, modelContext: ModelContext) {
        modelContext.delete(storedTracklist)
        try? modelContext.save()
        logger.info("Deleted stored tracklist '\(storedTracklist.name)'")
    }

    func findStoredTracklist(id: String, modelContext: ModelContext) -> StoredTracklist? {
        let descriptor = FetchDescriptor<StoredTracklist>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
