import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "TracklistFetchService")

struct TracklistResponse {
    let tracks: [Track]
    let paginationContext: [String: Any]?
}

class TracklistFetchService {
    static let shared = TracklistFetchService()

    private init() {}

    func fetchAllTracks(for tracklist: Tracklist, onPageFetched: (([Track]) -> Void)? = nil) async throws -> [Track] {
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: tracklist.mediaSourceId) else {
            throw NSError(domain: "TracklistFetchService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No media source found for tracklist"])
        }
        let config = mediaSource.config
        let mediaSourceId = tracklist.mediaSourceId

        logger.info("Fetching all tracks for '\(tracklist.title)' on '\(mediaSourceId)'...")

        switch tracklist.tracklistType {
        case .album:
            guard let script = config.list?.album else { throw self.missingScriptError("list.album") }
            return try await self.fetchAllTrackPages(
                script: script, params: ["id": tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                parseResponse: { dict in let r = ListAlbumResponse(dict); return (r.items, r.paginationContext) },
                onPageFetched: onPageFetched
            )
        case .playlist:
            guard let script = config.list?.playlist else { throw self.missingScriptError("list.playlist") }
            return try await self.fetchAllTrackPages(
                script: script, params: ["id": tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                parseResponse: { dict in let r = ListPlaylistResponse(dict); return (r.items, r.paginationContext) },
                onPageFetched: onPageFetched
            )
        case .artistSongs:
            guard let script = config.list?.artistSongs else { throw self.missingScriptError("list.artistSongs") }
            return try await self.fetchAllTrackPages(
                script: script, params: ["id": tracklist.fromArtist?.mediaId ?? tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                parseResponse: { dict in let r = ListArtistSongsResponse(dict); return (r.items, r.paginationContext) },
                onPageFetched: onPageFetched
            )
        case .artistVideos:
            guard let script = config.list?.artistVideos else { throw self.missingScriptError("list.artistVideos") }
            return try await self.fetchAllTrackPages(
                script: script, params: ["id": tracklist.fromArtist?.mediaId ?? tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                parseResponse: { dict in let r = ListArtistVideosResponse(dict); return (r.items, r.paginationContext) },
                onPageFetched: onPageFetched
            )
        default:
            throw NSError(domain: "TracklistFetchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot fetch tracks for this tracklist type"])
        }
    }

    func fetchTracklist(tracklist: Tracklist, previousResult: [String: Any]? = nil) async throws -> TracklistResponse {
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: tracklist.mediaSourceId) else {
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
        let config = mediaSource.config
        let mediaSourceId = tracklist.mediaSourceId

        switch tracklist.tracklistType {
        case .album:
            guard let script = config.list?.album else { return TracklistResponse(tracks: [], paginationContext: nil) }
            let response = try ListAlbumResponse(await JSExecutionEngine.shared.execute(script: script, params: scriptParams(["id": tracklist.mediaId], previousResult: previousResult), customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues))
            logger.info("Fetched \(response.items.count) track(s) via list.album")
            return TracklistResponse(tracks: response.items.map { $0.toTrack(mediaSourceId: mediaSourceId) }, paginationContext: response.paginationContext)

        case .playlist:
            guard let script = config.list?.playlist else { return TracklistResponse(tracks: [], paginationContext: nil) }
            let response = try ListPlaylistResponse(await JSExecutionEngine.shared.execute(script: script, params: scriptParams(["id": tracklist.mediaId], previousResult: previousResult), customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues))
            logger.info("Fetched \(response.items.count) track(s) via list.playlist")
            return TracklistResponse(tracks: response.items.map { $0.toTrack(mediaSourceId: mediaSourceId) }, paginationContext: response.paginationContext)

        case .artistSongs:
            guard let script = config.list?.artistSongs else { return TracklistResponse(tracks: [], paginationContext: nil) }
            let response = try ListArtistSongsResponse(await JSExecutionEngine.shared.execute(script: script, params: scriptParams(["id": tracklist.fromArtist?.mediaId ?? ""], previousResult: previousResult), customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues))
            logger.info("Fetched \(response.items.count) track(s) via list.artistSongs")
            return TracklistResponse(tracks: response.items.map { $0.toTrack(mediaSourceId: mediaSourceId) }, paginationContext: response.paginationContext)

        case .artistVideos:
            guard let script = config.list?.artistVideos else { return TracklistResponse(tracks: [], paginationContext: nil) }
            let response = try ListArtistVideosResponse(await JSExecutionEngine.shared.execute(script: script, params: scriptParams(["id": tracklist.fromArtist?.mediaId ?? ""], previousResult: previousResult), customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues))
            logger.info("Fetched \(response.items.count) track(s) via list.artistVideos")
            return TracklistResponse(tracks: response.items.map { $0.toTrack(mediaSourceId: mediaSourceId) }, paginationContext: response.paginationContext)

        case .likes:
            return TracklistResponse(tracks: [], paginationContext: nil)
        }
    }

    func fetchTracklistMetadata(tracklist: Tracklist) async throws -> GetTracklistResponse? {
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
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: ["id": tracklist.mediaId],
            customUserAgent: config.customUserAgent,
            domain: config.url,
            context: mediaSource.contextValues
        )
        return GetTracklistResponse(jsResult)
    }

    func fetchArtist(artist: Artist, mediaSource: MediaSource) async throws -> ArtistDetail {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.get?.artist else {
            logger.warning("No get.artist script for '\(mediaSourceId)'")
            return ArtistDetail()
        }

        logger.info("Fetching artist '\(artist.name)' for '\(mediaSourceId)'...")
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: ["id": artist.mediaId],
            customUserAgent: config.customUserAgent,
            domain: config.url,
            context: mediaSource.contextValues
        )

        let result = GetArtistResponse(jsResult)
        let songs = result.songs?.map { $0.toTrack(mediaSourceId: mediaSourceId) }
        let albums = result.albums?.map { $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .album) }
        let videos = result.videos?.map { $0.toTrack(mediaSourceId: mediaSourceId) }
        let playlists = result.playlists?.map { $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .playlist) }
        let sectionOrder = result.sectionOrder.compactMap { ArtistDetailSection(rawValue: $0) }

        logger.info("Fetched artist '\(artist.name)': \(songs?.count ?? 0) song(s), \(albums?.count ?? 0) album(s), \(videos?.count ?? 0) video(s), \(playlists?.count ?? 0) playlist(s)")
        return ArtistDetail(songs: songs, albums: albums, videos: videos, playlists: playlists, sectionOrder: sectionOrder)
    }

    func fetchAlbumsForArtist(artist: Artist, mediaSource: MediaSource) async throws -> [Tracklist] {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.list?.artistAlbums else {
            logger.warning("No list.artistAlbums script for '\(mediaSourceId)'")
            return []
        }
        logger.info("Fetching all albums for artist '\(artist.name)' on '\(mediaSourceId)'...")
        let response = try ListArtistAlbumsResponse(await JSExecutionEngine.shared.execute(
            script: script, params: ["id": artist.mediaId],
            customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues
        ))
        logger.info("Fetched \(response.items.count) album(s) for artist '\(artist.name)'")
        return response.items.map { $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .album) }
    }

    func fetchPlaylistsForArtist(artist: Artist, mediaSource: MediaSource) async throws -> [Tracklist] {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.list?.artistPlaylists else {
            logger.warning("No list.artistPlaylists script for '\(mediaSourceId)'")
            return []
        }
        logger.info("Fetching all playlists for artist '\(artist.name)' on '\(mediaSourceId)'...")
        let response = try ListArtistPlaylistsResponse(await JSExecutionEngine.shared.execute(
            script: script, params: ["id": artist.mediaId],
            customUserAgent: config.customUserAgent, domain: config.url, context: mediaSource.contextValues
        ))
        logger.info("Fetched \(response.items.count) playlist(s) for artist '\(artist.name)'")
        return response.items.map { $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .playlist) }
    }

    // MARK: - Private

    private func fetchAllTrackPages(
        script: String,
        params: [String: Any],
        config: MediaSourceConfig,
        mediaSourceId: String,
        context: [String: String],
        parseResponse: ([String: Any]) -> ([ScriptTrack], [String: Any]?),
        onPageFetched: (([Track]) -> Void)?
    ) async throws -> [Track] {
        var allTracks: [Track] = []
        var previousResult: [String: Any]? = nil

        while true {
            let jsResult = try await JSExecutionEngine.shared.execute(
                script: script, params: scriptParams(params, previousResult: previousResult),
                customUserAgent: config.customUserAgent, domain: config.url, context: context
            )
            let (items, paginationContext) = parseResponse(jsResult)
            let tracks = items.map { $0.toTrack(mediaSourceId: mediaSourceId) }
            allTracks.append(contentsOf: tracks)
            logger.info("Fetched page with \(tracks.count) track(s), total: \(allTracks.count)")
            onPageFetched?(allTracks)
            guard let nextContext = paginationContext else { break }
            previousResult = nextContext
        }

        logger.info("All pages fetched: \(allTracks.count) total track(s)")
        return allTracks
    }

    private func missingScriptError(_ name: String) -> NSError {
        NSError(domain: "TracklistFetchService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No \(name) script available"])
    }
}
