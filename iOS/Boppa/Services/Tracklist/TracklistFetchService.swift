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
        let (script, params) = try buildFetchParams(tracklist: tracklist, config: mediaSource.config)
        logger.info("Fetching all tracks for '\(tracklist.title)' on '\(tracklist.mediaSourceId)'...")
        return try await self.paginated.executeAllPages(
            script: script,
            params: params,
            customUserAgent: mediaSource.config.customUserAgent,
            domain: mediaSource.config.url,
            mediaSourceId: tracklist.mediaSourceId,
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
            return try await self.fetchAlbumPage(tracklist: tracklist, config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues, previousResult: previousResult)
        case .playlist:
            return try await self.fetchPlaylistPage(tracklist: tracklist, config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues, previousResult: previousResult)
        case .artistSongs:
            return try await self.fetchArtistTracksPage(tracklist: tracklist, script: config.get?.artist?.songs, scriptName: "getSongsForArtist", config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues, previousResult: previousResult)
        case .artistVideos:
            return try await self.fetchArtistTracksPage(tracklist: tracklist, script: config.get?.artist?.videos, scriptName: "getVideosForArtist", config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues, previousResult: previousResult)
        case .likes:
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
    }

    func fetchArtist(artist: Artist, mediaSource: MediaSource) async throws -> ArtistDetail {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.get?.artist?.fetch else {
            logger.warning("No getArtist script for '\(mediaSourceId)'")
            return ArtistDetail()
        }

        logger.info("Fetching artist '\(artist.name)' for '\(mediaSourceId)'...")

        let params: [String: Any] = ["name": artist.name, "artworkUrl": artist.artworkUrl ?? "", "id": artist.mediaId]

        let jsParams = self.paginated.buildJSParams(params: params, previousResult: nil)
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: jsParams,
            customUserAgent: config.customUserAgent,
            domain: config.url,
            context: mediaSource.contextValues
        )

        let songs = (jsResult["songs"] as? [[String: Any]])?.compactMap { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        let albums = (jsResult["albums"] as? [[String: Any]])?.compactMap { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .album) }
        let videos = (jsResult["videos"] as? [[String: Any]])?.compactMap { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        let playlists = (jsResult["playlists"] as? [[String: Any]])?.compactMap { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .playlist) }
        let metadata = jsResult["metadata"] as? [String: Any] ?? [:]
        let sectionOrder = (jsResult["__keyOrder"] as? [String] ?? []).compactMap { ArtistDetailSection(rawValue: $0) }

        logger.info("Fetched artist '\(artist.name)': \(songs?.count ?? 0) song(s), \(albums?.count ?? 0) album(s), \(videos?.count ?? 0) video(s), \(playlists?.count ?? 0) playlist(s)")
        return ArtistDetail(songs: songs, albums: albums, videos: videos, playlists: playlists, metadata: metadata, sectionOrder: sectionOrder)
    }

    func fetchAlbumsForArtist(artist: Artist, artistDetail: ArtistDetail, mediaSource: MediaSource) async throws -> [Tracklist] {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.get?.artist?.albums else {
            logger.warning("No getAlbumsForArtist script for '\(mediaSourceId)'")
            return []
        }

        logger.info("Fetching all albums for artist '\(artist.name)' on '\(mediaSourceId)'...")

        var params: [String: Any] = ["name": artist.name, "artworkUrl": artist.artworkUrl ?? "", "id": artist.mediaId]
        for (key, value) in artistDetail.metadata {
            params[key] = value
        }

        let jsParams = self.paginated.buildJSParams(params: params, previousResult: nil)
        let jsResult = try await JSExecutionEngine.shared.execute(script: script, params: jsParams, customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues)
        let albums = (jsResult["items"] as? [[String: Any]] ?? []).compactMap { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .album) }

        logger.info("Fetched \(albums.count) album(s) for artist '\(artist.name)'")
        return albums
    }

    func fetchPlaylistsForArtist(artist: Artist, artistDetail: ArtistDetail, mediaSource: MediaSource) async throws -> [Tracklist] {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.get?.artist?.playlists else {
            logger.warning("No getPlaylistsForArtist script for '\(mediaSourceId)'")
            return []
        }

        logger.info("Fetching all playlists for artist '\(artist.name)' on '\(mediaSourceId)'...")

        var params: [String: Any] = ["name": artist.name, "artworkUrl": artist.artworkUrl ?? "", "id": artist.mediaId]
        for (key, value) in artistDetail.metadata {
            params[key] = value
        }

        let jsParams = self.paginated.buildJSParams(params: params, previousResult: nil)
        let jsResult = try await JSExecutionEngine.shared.execute(script: script, params: jsParams, customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues)
        let playlists = (jsResult["items"] as? [[String: Any]] ?? []).compactMap { self.paginated.mapToTracklist($0, mediaSourceId: mediaSourceId, tracklistType: .playlist) }

        logger.info("Fetched \(playlists.count) playlist(s) for artist '\(artist.name)'")
        return playlists
    }

    // MARK: - Private

    private func buildFetchParams(tracklist: Tracklist, config: MediaSourceConfig) throws -> (script: String, params: [String: Any]) {
        let script: String?
        var params: [String: Any] = ["artworkUrl": tracklist.artworkUrl ?? "", "id": tracklist.mediaId]

        switch tracklist.tracklistType {
        case .playlist:
            script = config.get?.playlist
            params["user"] = tracklist.subtitle ?? ""
        case .album:
            script = config.get?.album
            params["subtitle"] = tracklist.subtitle ?? ""
        default:
            throw NSError(domain: "TracklistFetchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot fetch tracks for this tracklist type"])
        }

        guard let script else {
            throw NSError(domain: "TracklistFetchService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No script available for this tracklist type"])
        }
        return (script, params)
    }

    private func fetchArtistTracksPage(
        tracklist: Tracklist, script: String?, scriptName: String,
        config: MediaSourceConfig, mediaSourceId: String,
        context: [String: String], previousResult: [String: Any]?
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

        var params: [String: Any] = ["name": artist.name, "artworkUrl": artist.artworkUrl ?? ""]
        if let artistDetail = tracklist.artistDetail {
            for (key, value) in artistDetail.metadata {
                params[key] = value
            }
        }

        let page = try await paginated.executePage(script: script, params: params, previousResult: previousResult, customUserAgent: config.customUserAgent, domain: config.url, context: context)
        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        logger.info("Fetched \(tracks.count) track(s) via \(scriptName) for artist '\(artist.name)'")
        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
    }

    private func fetchAlbumPage(
        tracklist: Tracklist, config: MediaSourceConfig,
        mediaSourceId: String, context: [String: String], previousResult: [String: Any]?
    ) async throws -> TracklistResponse {
        guard let script = config.get?.album else {
            logger.warning("No getAlbum script for '\(mediaSourceId)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
        logger.info("Fetching album '\(tracklist.title)' for '\(mediaSourceId)'...")
        let params: [String: Any] = ["subtitle": tracklist.subtitle ?? "", "artworkUrl": tracklist.artworkUrl ?? "", "id": tracklist.mediaId]
        let page = try await paginated.executePage(script: script, params: params, previousResult: previousResult, customUserAgent: config.customUserAgent, domain: config.url, context: context)
        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        logger.info("Fetched \(tracks.count) track(s) for album '\(tracklist.title)'")
        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
    }

    private func fetchPlaylistPage(
        tracklist: Tracklist, config: MediaSourceConfig,
        mediaSourceId: String, context: [String: String], previousResult: [String: Any]?
    ) async throws -> TracklistResponse {
        guard let script = config.get?.playlist else {
            logger.warning("No getPlaylist script for '\(mediaSourceId)'")
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
        logger.info("Fetching playlist '\(tracklist.title)' for '\(mediaSourceId)'...")
        let params: [String: Any] = ["user": tracklist.subtitle ?? "", "artworkUrl": tracklist.artworkUrl ?? "", "id": tracklist.mediaId]
        let page = try await paginated.executePage(script: script, params: params, previousResult: previousResult, customUserAgent: config.customUserAgent, domain: config.url, context: context)
        let tracks = page.items.compactMap { self.paginated.mapToTrack($0, mediaSourceId: mediaSourceId) }
        logger.info("Fetched \(tracks.count) track(s) for playlist '\(tracklist.title)'")
        return TracklistResponse(tracks: tracks, paginationContext: page.paginationContext)
    }
}
