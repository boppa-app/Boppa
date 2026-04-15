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
    private var sourceCache: [String: MediaSource] = [:]

    private init() {}

    func resolveSource(name: String, modelContext: ModelContext) -> MediaSource? {
        if let cached = self.sourceCache[name] { return cached }
        let descriptor = FetchDescriptor<MediaSource>(
            predicate: #Predicate { $0.name == name }
        )
        if let source = try? modelContext.fetch(descriptor).first {
            self.sourceCache[name] = source
            return source
        }
        return nil
    }

    func fetchTracklist(
        tracklist: Tracklist,
        modelContext: ModelContext,
        previousResult: [String: Any]? = nil
    ) async throws -> TracklistResponse {
        guard let mediaSourceName = tracklist.mediaSourceName,
              let mediaSource = self.resolveSource(name: mediaSourceName, modelContext: modelContext)
        else {
            return TracklistResponse(tracks: [], paginationContext: nil)
        }

        let config = mediaSource.config
        switch tracklist.tracklistType {
        case let .album(album):
            return try await self.fetchAlbumPage(
                album: album,
                config: config,
                mediaSourceName: mediaSourceName,
                mediaSourceContext: mediaSource.contextValues,
                previousResult: previousResult
            )
        case let .playlist(playlist):
            return try await self.fetchPlaylistPage(
                playlist: playlist,
                config: config,
                mediaSourceName: mediaSourceName,
                mediaSourceContext: mediaSource.contextValues,
                previousResult: previousResult
            )
        case let .artistSongs(artist, artistDetail):
            return try await self.fetchArtistTracksPage(
                artist: artist,
                artistDetail: artistDetail,
                script: config.data?.getSongsForArtist?.script,
                scriptName: "getSongsForArtist",
                config: config,
                mediaSourceName: mediaSourceName,
                mediaSourceContext: mediaSource.contextValues,
                previousResult: previousResult
            )
        case let .artistVideos(artist, artistDetail):
            return try await self.fetchArtistTracksPage(
                artist: artist,
                artistDetail: artistDetail,
                script: config.data?.getVideosForArtist?.script,
                scriptName: "getVideosForArtist",
                config: config,
                mediaSourceName: mediaSourceName,
                mediaSourceContext: mediaSource.contextValues,
                previousResult: previousResult
            )
        }
    }

    func fetchArtist(
        artist: Artist,
        mediaSource: MediaSource
    ) async throws -> ArtistDetail {
        let config = mediaSource.config
        let mediaSourceName = mediaSource.name
        guard let script = config.data?.getArtist?.script else {
            logger.warning("No getArtist script for '\(mediaSourceName)'")
            return ArtistDetail()
        }

        logger.info("Fetching artist '\(artist.name)' for '\(mediaSourceName)'...")

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
            self.paginated.mapToTrack($0, mediaSourceName: mediaSourceName)
        }

        let albums = (jsResult["albums"] as? [[String: Any]])?.compactMap {
            self.paginated.mapToAlbum($0, mediaSourceName: mediaSourceName)
        }

        let videos = (jsResult["videos"] as? [[String: Any]])?.compactMap {
            self.paginated.mapToTrack($0, mediaSourceName: mediaSourceName)
        }

        let playlists = (jsResult["playlists"] as? [[String: Any]])?.compactMap {
            self.paginated.mapToPlaylist($0, mediaSourceName: mediaSourceName)
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
    ) async throws -> [Album] {
        let config = mediaSource.config
        let mediaSourceName = mediaSource.name
        guard let script = config.data?.getAlbumsForArtist?.script else {
            logger.warning("No getAlbumsForArtist script for '\(mediaSourceName)'")
            return []
        }

        logger.info("Fetching all albums for artist '\(artist.name)' on '\(mediaSourceName)'...")

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
            .compactMap { self.paginated.mapToAlbum($0, mediaSourceName: mediaSourceName) }

        logger.info("Fetched \(albums.count) album(s) for artist '\(artist.name)'")
        return albums
    }

    func fetchPlaylistsForArtist(
        artist: Artist,
        artistDetail: ArtistDetail,
        mediaSource: MediaSource
    ) async throws -> [Playlist] {
        let config = mediaSource.config
        let mediaSourceName = mediaSource.name
        guard let script = config.data?.getPlaylistsForArtist?.script else {
            logger.warning("No getPlaylistsForArtist script for '\(mediaSourceName)'")
            return []
        }

        logger.info("Fetching all playlists for artist '\(artist.name)' on '\(mediaSourceName)'...")

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
            .compactMap { self.paginated.mapToPlaylist($0, mediaSourceName: mediaSourceName) }

        logger.info("Fetched \(playlists.count) playlist(s) for artist '\(artist.name)'")
        return playlists
    }

    private func fetchArtistTracksPage(
        artist: Artist,
        artistDetail: ArtistDetail,
        script: String?,
        scriptName: String,
        config: MediaSourceConfig,
        mediaSourceName: String,
        mediaSourceContext: [String: String],
        previousResult: [String: Any]?
    ) async throws -> TracklistResponse {
        guard let script else {
            logger.warning("No \(scriptName) script for '\(mediaSourceName)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }

        logger.info("Fetching \(scriptName) for artist '\(artist.name)' on '\(mediaSourceName)'...")

        var itemParams: [String: Any] = [:]
        itemParams["name"] = artist.name
        itemParams["artworkUrl"] = artist.artworkUrl ?? ""
        for (key, value) in artist.metadata {
            itemParams[key] = value
        }
        for (key, value) in artistDetail.metadata {
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

        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceName: mediaSourceName) }
        logger.info("Fetched \(tracks.count) track(s) via \(scriptName) for artist '\(artist.name)'")

        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
    }

    private func fetchAlbumPage(
        album: Album,
        config: MediaSourceConfig,
        mediaSourceName: String,
        mediaSourceContext: [String: String],
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
            domain: config.url,
            mediaSourceContext: mediaSourceContext
        )

        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceName: mediaSourceName) }
        logger.info("Fetched \(tracks.count) track(s) for album '\(album.title)'")

        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
    }

    private func fetchPlaylistPage(
        playlist: Playlist,
        config: MediaSourceConfig,
        mediaSourceName: String,
        mediaSourceContext: [String: String],
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
            domain: config.url,
            mediaSourceContext: mediaSourceContext
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

    @MainActor func saveTracklistToLibrary(
        tracklist: Tracklist,
        modelContext: ModelContext,
        onPageFetched: (([Track]) -> Void)? = nil
    ) async throws -> StoredTracklist {
        guard let mediaSourceName = tracklist.mediaSourceName,
              let mediaSource = self.resolveSource(name: mediaSourceName, modelContext: modelContext)
        else {
            throw NSError(domain: "TracklistService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No media source found for tracklist"])
        }

        let (script, itemParams) = try self.buildFetchParams(tracklist: tracklist, config: mediaSource.config)

        logger.info("Saving tracklist '\(tracklist.name)' to library for '\(mediaSourceName)'...")

        let tracks = try await self.paginated.executeAllPages(
            script: script,
            params: ["item": itemParams],
            customUserAgent: mediaSource.config.customUserAgent,
            domain: mediaSource.config.url,
            mediaSourceName: mediaSourceName,
            mediaSourceContext: mediaSource.contextValues,
            onPageFetched: { allTracksSoFar in
                onPageFetched?(allTracksSoFar)
            }
        )

        let stored = self.upsertStoredTracklist(
            tracklist: tracklist,
            mediaSourceName: mediaSourceName,
            modelContext: modelContext
        )

        self.persistTracks(tracks, into: stored, modelContext: modelContext, pruneStale: true)

        logger.info("Saved tracklist '\(tracklist.name)' with \(tracks.count) track(s) to library")

        return stored
    }

    private func buildFetchParams(tracklist: Tracklist, config: MediaSourceConfig) throws -> (script: String, params: [String: Any]) {
        let script: String?
        var itemParams: [String: Any] = [:]

        switch tracklist.tracklistType {
        case let .playlist(playlist):
            script = config.data?.getPlaylist?.script
            itemParams["user"] = playlist.user ?? ""
            itemParams["artworkUrl"] = playlist.artworkUrl ?? ""
            for (key, value) in playlist.metadata {
                itemParams[key] = value
            }
        case let .album(album):
            script = config.data?.getAlbum?.script
            itemParams["subtitle"] = album.subtitle ?? ""
            itemParams["artworkUrl"] = album.artworkUrl ?? ""
            for (key, value) in album.metadata {
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
        mediaSourceName: String,
        modelContext: ModelContext
    ) -> StoredTracklist {
        let tracklistType: String
        let tracklistId: String
        let subtitle: String?
        let itemMetadata: [String: Any]

        switch tracklist.tracklistType {
        case let .playlist(playlist):
            tracklistType = "playlist"
            tracklistId = playlist.id
            subtitle = playlist.user
            itemMetadata = playlist.metadata
        case let .album(album):
            tracklistType = "album"
            tracklistId = album.id
            subtitle = album.subtitle
            itemMetadata = album.metadata
        default:
            tracklistType = "playlist"
            tracklistId = UUID().uuidString
            subtitle = nil
            itemMetadata = [:]
        }

        if let existing = self.findStoredTracklist(id: tracklistId, modelContext: modelContext) {
            existing.name = tracklist.name
            existing.subtitle = subtitle
            existing.artworkUrl = tracklist.artworkUrl
            existing.metadataJSON = (try? JSONSerialization.data(withJSONObject: itemMetadata)) ?? Data()
            return existing
        }

        let stored = StoredTracklist(
            id: tracklistId,
            name: tracklist.name,
            subtitle: subtitle,
            mediaSourceName: mediaSourceName,
            artworkUrl: tracklist.artworkUrl,
            tracklistType: tracklistType,
            metadata: itemMetadata
        )
        modelContext.insert(stored)
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
