import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "TracklistFetchService")

struct TracklistResponse {
    let tracks: [Track]
    let paginationContext: [String: Any]?
}

class TracklistFetchService {
    static let shared = TracklistFetchService()

    private let paginated = PaginatedScriptExecutor.shared

    private init() {}

    func fetchAllTracks(for tracklist: Tracklist, onPageFetched: (([Track]) -> Void)? = nil) async throws -> [Track] {
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: tracklist.mediaSourceId) else {
            throw NSError(domain: "TracklistFetchService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No media source found for tracklist"])
        }
        let config = mediaSource.config
        let mediaSourceId = tracklist.mediaSourceId

        let script: String?
        let params: [String: Any]

        switch tracklist.tracklistType {
        case .album:
            script = config.list?.album
            params = ["id": tracklist.mediaId]
        case .playlist:
            script = config.list?.playlist
            params = ["id": tracklist.mediaId]
        case .artistSongs:
            script = config.list?.artistSongs
            params = ["id": tracklist.fromArtist?.mediaId ?? tracklist.mediaId]
        case .artistVideos:
            script = config.list?.artistVideos
            params = ["id": tracklist.fromArtist?.mediaId ?? tracklist.mediaId]
        default:
            throw NSError(domain: "TracklistFetchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot fetch tracks for this tracklist type"])
        }

        guard let script else {
            throw NSError(domain: "TracklistFetchService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No script available for this tracklist type"])
        }

        logger.info("Fetching all tracks for '\(tracklist.title)' on '\(mediaSourceId)'...")
        return try await self.paginated.executeAllPages(
            script: script,
            params: params,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            mediaSourceId: mediaSourceId,
            context: mediaSource.contextValues,
            onPageFetched: { onPageFetched?($0) }
        )
    }

    func fetchTracklist(tracklist: Tracklist, previousResult: [String: Any]? = nil) async throws -> TracklistResponse {
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: tracklist.mediaSourceId) else {
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
        let config = mediaSource.config
        let mediaSourceId = tracklist.mediaSourceId

        switch tracklist.tracklistType {
        case .album:
            return try await self.fetchListPage(
                script: config.list?.album, scriptName: "list.album",
                params: ["id": tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                previousResult: previousResult
            )
        case .playlist:
            return try await self.fetchListPage(
                script: config.list?.playlist, scriptName: "list.playlist",
                params: ["id": tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                previousResult: previousResult
            )
        case .artistSongs:
            return try await self.fetchListPage(
                script: config.list?.artistSongs, scriptName: "list.artistSongs",
                params: ["id": tracklist.fromArtist?.mediaId ?? ""],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                previousResult: previousResult
            )
        case .artistVideos:
            return try await self.fetchListPage(
                script: config.list?.artistVideos, scriptName: "list.artistVideos",
                params: ["id": tracklist.fromArtist?.mediaId ?? ""],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                previousResult: previousResult
            )
        case .likes:
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
    }

    func fetchTracklistMetadata(tracklist: Tracklist) async throws -> ScriptTracklistItem? {
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: tracklist.mediaSourceId) else { return nil }
        let config = mediaSource.config
        let script: String?
        switch tracklist.tracklistType {
        case .album: script = config.get?.album
        case .playlist: script = config.get?.playlist
        default: return nil
        }
        guard let script else { return nil }

        logger.info("Fetching metadata for '\(tracklist.title)' on '\(tracklist.mediaSourceId)'...")
        let params: [String: Any] = ["id": tracklist.mediaId]
        let jsParams = self.paginated.buildJSParams(params: params, previousResult: nil)
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: jsParams,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            context: mediaSource.contextValues
        )
        return ScriptTracklistItem(jsResult)
    }

    func fetchArtist(artist: Artist, mediaSource: MediaSource) async throws -> ArtistDetail {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.get?.artist else {
            logger.warning("No get.artist script for '\(mediaSourceId)'")
            return ArtistDetail()
        }

        logger.info("Fetching artist '\(artist.name)' for '\(mediaSourceId)'...")

        let params: [String: Any] = ["id": artist.mediaId]
        let jsParams = self.paginated.buildJSParams(params: params, previousResult: nil)
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: jsParams,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            context: mediaSource.contextValues
        )

        let result = ScriptArtistFetchResult(jsResult)
        let songs = result.songs?.map { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        let albums = result.albums?.map { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .album) }
        let videos = result.videos?.map { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        let playlists = result.playlists?.map { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .playlist) }
        let sectionOrder = result.sectionOrder.compactMap { ArtistDetailSection(rawValue: $0) }

        logger.info("Fetched artist '\(artist.name)': \(songs?.count ?? 0) song(s), \(albums?.count ?? 0) album(s), \(videos?.count ?? 0) video(s), \(playlists?.count ?? 0) playlist(s)")
        return ArtistDetail(songs: songs, albums: albums, videos: videos, playlists: playlists, metadata: result.metadata, sectionOrder: sectionOrder)
    }

    func fetchAlbumsForArtist(artist: Artist, mediaSource: MediaSource) async throws -> [Tracklist] {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.list?.artistAlbums else {
            logger.warning("No list.artistAlbums script for '\(mediaSourceId)'")
            return []
        }

        logger.info("Fetching all albums for artist '\(artist.name)' on '\(mediaSourceId)'...")

        let params: [String: Any] = ["id": artist.mediaId]
        let jsParams = self.paginated.buildJSParams(params: params, previousResult: nil)
        let jsResult = try await JSExecutionEngine.shared.execute(script: script, params: jsParams, customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues)
        let albums = (jsResult["items"] as? [[String: Any]] ?? []).compactMap { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .album) }

        logger.info("Fetched \(albums.count) album(s) for artist '\(artist.name)'")
        return albums
    }

    func fetchPlaylistsForArtist(artist: Artist, mediaSource: MediaSource) async throws -> [Tracklist] {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.list?.artistPlaylists else {
            logger.warning("No list.artistPlaylists script for '\(mediaSourceId)'")
            return []
        }

        logger.info("Fetching all playlists for artist '\(artist.name)' on '\(mediaSourceId)'...")

        let params: [String: Any] = ["id": artist.mediaId]
        let jsParams = self.paginated.buildJSParams(params: params, previousResult: nil)
        let jsResult = try await JSExecutionEngine.shared.execute(script: script, params: jsParams, customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues)
        let playlists = (jsResult["items"] as? [[String: Any]] ?? []).compactMap { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .playlist) }

        logger.info("Fetched \(playlists.count) playlist(s) for artist '\(artist.name)'")
        return playlists
    }

    // MARK: - Private

    private func fetchListPage(
        script: String?,
        scriptName: String,
        params: [String: Any],
        config: MediaSourceConfig,
        mediaSourceId: String,
        context: [String: String],
        previousResult: [String: Any]?
    ) async throws -> TracklistResponse {
        guard let script else {
            logger.warning("No \(scriptName) script for '\(mediaSourceId)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
        logger.info("Executing \(scriptName) for '\(mediaSourceId)'...")
        let page = try await paginated.executePage(
            script: script,
            params: params,
            previousResult: previousResult,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            context: context
        )
        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        logger.info("Fetched \(tracks.count) track(s) via \(scriptName)")
        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
    }
}
