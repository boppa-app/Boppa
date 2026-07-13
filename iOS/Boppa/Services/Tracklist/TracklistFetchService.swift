import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "TracklistFetchService"
)

struct TracklistResponse {
    let tracks: [Track]
    let continuation: [String: Any]?
}

struct TracklistListResponse {
    let tracklists: [Tracklist]
    let continuation: [String: Any]?
}

class TracklistFetchService {
    static let shared = TracklistFetchService()

    private init() {}

    func fetchAllTracks(for tracklist: Tracklist, onPageFetched: (([Track]) -> Void)? = nil)
        async throws -> [Track]
    {
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: tracklist.mediaSourceId)
        else {
            throw NSError(
                domain: "TracklistFetchService", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "No media source found for tracklist"]
            )
        }
        let config = mediaSource.config
        let mediaSourceId = tracklist.mediaSourceId

        logger.info("Fetching all tracks for '\(tracklist.title)' on '\(mediaSourceId)'...")

        switch tracklist.tracklistType {
        case .album:
            guard let script = config.data.list?.album else {
                throw self.missingScriptError("list.album")
            }
            return try await self.fetchAllTrackPages(
                script: script, params: ["id": tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                parseResponse: { dict in
                    let r = ListAlbumResponse(dict)
                    return (r.items, r.continuation)
                },
                onPageFetched: onPageFetched
            )
        case .playlist:
            guard let script = config.data.list?.playlist else {
                throw self.missingScriptError("list.playlist")
            }
            return try await self.fetchAllTrackPages(
                script: script, params: ["id": tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                parseResponse: { dict in
                    let r = ListPlaylistResponse(dict)
                    return (r.items, r.continuation)
                },
                onPageFetched: onPageFetched
            )
        case .artistSongs:
            guard let script = config.data.list?.artistSongs else {
                throw self.missingScriptError("list.artistSongs")
            }
            return try await self.fetchAllTrackPages(
                script: script, params: ["id": tracklist.fromArtist?.mediaId ?? tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                parseResponse: { dict in
                    let r = ListArtistSongsResponse(dict)
                    return (r.items, r.continuation)
                },
                onPageFetched: onPageFetched
            )
        case .artistVideos:
            guard let script = config.data.list?.artistVideos else {
                throw self.missingScriptError("list.artistVideos")
            }
            return try await self.fetchAllTrackPages(
                script: script, params: ["id": tracklist.fromArtist?.mediaId ?? tracklist.mediaId],
                config: config, mediaSourceId: mediaSourceId, context: mediaSource.contextValues,
                trackType: .video,
                parseResponse: { dict in
                    let r = ListArtistVideosResponse(dict)
                    return (r.items, r.continuation)
                },
                onPageFetched: onPageFetched
            )
        default:
            throw NSError(
                domain: "TracklistFetchService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot fetch tracks for this tracklist type"]
            )
        }
    }

    func fetchTracklist(tracklist: Tracklist, previousResult: [String: Any]? = nil) async throws
        -> TracklistResponse
    {
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: tracklist.mediaSourceId)
        else {
            return TracklistResponse(tracks: [], continuation: nil)
        }
        let config = mediaSource.config
        let mediaSourceId = tracklist.mediaSourceId

        switch tracklist.tracklistType {
        case .album:
            guard let script = config.data.list?.album else {
                return TracklistResponse(tracks: [], continuation: nil)
            }
            let response = try ListAlbumResponse(
                await JSExecutionEngine.shared.execute(
                    script: script,
                    params: scriptParams(["id": tracklist.mediaId], previousResult: previousResult),
                    domain: config.url,
                    context: mediaSource.contextValues,
                    allowedUrls: config.effectiveAllowedUrls
                )
            )
            logger.info("Fetched \(response.items.count) track(s) via list.album")
            return TracklistResponse(
                tracks: response.items.map { $0.toTrack(mediaSourceId: mediaSourceId) },
                continuation: response.continuation
            )

        case .playlist:
            guard let script = config.data.list?.playlist else {
                return TracklistResponse(tracks: [], continuation: nil)
            }
            let response = try ListPlaylistResponse(
                await JSExecutionEngine.shared.execute(
                    script: script,
                    params: scriptParams(["id": tracklist.mediaId], previousResult: previousResult),
                    domain: config.url,
                    context: mediaSource.contextValues,
                    allowedUrls: config.effectiveAllowedUrls
                )
            )
            logger.info("Fetched \(response.items.count) track(s) via list.playlist")
            return TracklistResponse(
                tracks: response.items.map { $0.toTrack(mediaSourceId: mediaSourceId) },
                continuation: response.continuation
            )

        case .artistSongs:
            guard let script = config.data.list?.artistSongs else {
                return TracklistResponse(tracks: [], continuation: nil)
            }
            let response = try ListArtistSongsResponse(
                await JSExecutionEngine.shared.execute(
                    script: script,
                    params: scriptParams(
                        ["id": tracklist.fromArtist?.mediaId ?? ""], previousResult: previousResult
                    ),
                    domain: config.url,
                    context: mediaSource.contextValues,
                    allowedUrls: config.effectiveAllowedUrls
                )
            )
            logger.info("Fetched \(response.items.count) track(s) via list.artistSongs")
            return TracklistResponse(
                tracks: response.items.map { $0.toTrack(mediaSourceId: mediaSourceId) },
                continuation: response.continuation
            )

        case .artistVideos:
            guard let script = config.data.list?.artistVideos else {
                return TracklistResponse(tracks: [], continuation: nil)
            }
            let response = try ListArtistVideosResponse(
                await JSExecutionEngine.shared.execute(
                    script: script,
                    params: scriptParams(
                        ["id": tracklist.fromArtist?.mediaId ?? ""], previousResult: previousResult
                    ),
                    domain: config.url,
                    context: mediaSource.contextValues,
                    allowedUrls: config.effectiveAllowedUrls
                )
            )
            logger.info("Fetched \(response.items.count) track(s) via list.artistVideos")
            return TracklistResponse(
                tracks: response.items.map {
                    $0.toTrack(mediaSourceId: mediaSourceId, type: .video)
                }, continuation: response.continuation
            )

        case .likes:
            return TracklistResponse(tracks: [], continuation: nil)
        }
    }

    func fetchTracklistMetadata(tracklist: Tracklist) async throws -> (any TracklistMetadata)? {
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: tracklist.mediaSourceId)
        else { return nil }
        let config = mediaSource.config
        logger.info("Fetching metadata for '\(tracklist.title)' on '\(tracklist.mediaSourceId)'...")
        switch tracklist.tracklistType {
        case .album:
            guard let script = config.data.get?.album else { return nil }
            let jsResult = try await JSExecutionEngine.shared.execute(
                script: script, params: ["id": tracklist.mediaId],
                domain: config.url,
                context: mediaSource.contextValues,
                allowedUrls: config.effectiveAllowedUrls
            )
            return GetAlbumResponse(jsResult)
        case .playlist:
            guard let script = config.data.get?.playlist else { return nil }
            let jsResult = try await JSExecutionEngine.shared.execute(
                script: script, params: ["id": tracklist.mediaId],
                domain: config.url,
                context: mediaSource.contextValues,
                allowedUrls: config.effectiveAllowedUrls
            )
            return GetPlaylistResponse(jsResult)
        default:
            return nil
        }
    }

    func fetchArtist(artist: Artist, mediaSource: MediaSource) async throws -> ArtistDetail {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.data.get?.artist else {
            logger.warning("No get.artist script for '\(mediaSourceId)'")
            return ArtistDetail()
        }

        logger.info("Fetching artist '\(artist.name)' for '\(mediaSourceId)'...")
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: ["id": artist.mediaId],
            domain: config.url,
            context: mediaSource.contextValues,
            allowedUrls: config.effectiveAllowedUrls
        )

        let result = GetArtistResponse(jsResult)
        let songs = result.songs?.map { $0.toTrack(mediaSourceId: mediaSourceId) }
        let albums = result.albums?.map {
            $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .album)
        }
        let videos = result.videos?.map { $0.toTrack(mediaSourceId: mediaSourceId, type: .video) }
        let playlists = result.playlists?.map {
            $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .playlist)
        }
        let sectionOrder = result.sectionOrder.compactMap { ArtistDetailSection(rawValue: $0) }

        logger.info(
            "Fetched artist '\(artist.name)': \(songs?.count ?? 0) song(s), \(albums?.count ?? 0) album(s), \(videos?.count ?? 0) video(s), \(playlists?.count ?? 0) playlist(s)"
        )
        return ArtistDetail(
            lowResArtworkUrl: result.lowResArtworkUrl,
            highResArtworkUrl: result.highResArtworkUrl,
            songs: songs, albums: albums, videos: videos, playlists: playlists,
            sectionOrder: sectionOrder
        )
    }

    func fetchSong(mediaId: String, mediaSourceId: String) async throws -> Track? {
        try await self.fetchTrackMetadata(
            mediaId: mediaId, mediaSourceId: mediaSourceId, type: .song
        )
    }

    func fetchVideo(mediaId: String, mediaSourceId: String) async throws -> Track? {
        try await self.fetchTrackMetadata(
            mediaId: mediaId, mediaSourceId: mediaSourceId, type: .video
        )
    }

    func fetchAlbumsForArtist(
        artist: Artist, mediaSource: MediaSource, previousResult: [String: Any]? = nil
    ) async throws -> TracklistListResponse {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.data.list?.artistAlbums else {
            logger.warning("No list.artistAlbums script for '\(mediaSourceId)'")
            return TracklistListResponse(tracklists: [], continuation: nil)
        }
        logger.info("Fetching albums page for artist '\(artist.name)' on '\(mediaSourceId)'...")
        let response = try ListArtistAlbumsResponse(
            await JSExecutionEngine.shared.execute(
                script: script,
                params: scriptParams(["id": artist.mediaId], previousResult: previousResult),
                domain: config.url,
                context: mediaSource.contextValues,
                allowedUrls: config.effectiveAllowedUrls
            )
        )
        logger.info("Fetched \(response.items.count) album(s) for artist '\(artist.name)'")
        return TracklistListResponse(
            tracklists: response.items.map {
                $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .album)
            },
            continuation: response.continuation
        )
    }

    func fetchPlaylistsForArtist(
        artist: Artist, mediaSource: MediaSource, previousResult: [String: Any]? = nil
    ) async throws -> TracklistListResponse {
        let config = mediaSource.config
        let mediaSourceId = mediaSource.id
        guard let script = config.data.list?.artistPlaylists else {
            logger.warning("No list.artistPlaylists script for '\(mediaSourceId)'")
            return TracklistListResponse(tracklists: [], continuation: nil)
        }
        logger.info("Fetching playlists page for artist '\(artist.name)' on '\(mediaSourceId)'...")
        let response = try ListArtistPlaylistsResponse(
            await JSExecutionEngine.shared.execute(
                script: script,
                params: scriptParams(["id": artist.mediaId], previousResult: previousResult),
                domain: config.url,
                context: mediaSource.contextValues,
                allowedUrls: config.effectiveAllowedUrls
            )
        )
        logger.info("Fetched \(response.items.count) playlist(s) for artist '\(artist.name)'")
        return TracklistListResponse(
            tracklists: response.items.map {
                $0.toTracklist(mediaSourceId: mediaSourceId, tracklistType: .playlist)
            },
            continuation: response.continuation
        )
    }

    // MARK: - Private

    private func fetchTrackMetadata(mediaId: String, mediaSourceId: String, type: Track.TrackType)
        async throws -> Track?
    {
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: mediaSourceId) else {
            return nil
        }
        let config = mediaSource.config
        guard let script = config.data.get?.script(for: type) else {
            logger.warning("No get.\(type.rawValue) script for '\(mediaSourceId)'")
            return nil
        }

        logger.info("Fetching get.\(type.rawValue) '\(mediaId)' for '\(mediaSourceId)'...")
        let jsResult = try await JSExecutionEngine.shared.execute(
            script: script,
            params: ["id": mediaId],
            domain: config.url,
            context: mediaSource.contextValues,
            allowedUrls: config.effectiveAllowedUrls
        )

        guard let response = GetTrackResponse(jsResult) else { return nil }
        return response.track.toTrack(mediaSourceId: mediaSourceId, type: type)
    }

    private func fetchAllTrackPages(
        script: String,
        params: [String: Any],
        config: MediaSourceConfig,
        mediaSourceId: String,
        context: [String: String],
        trackType: Track.TrackType = .song,
        parseResponse: ([String: Any]) -> ([ScriptTrack], [String: Any]?),
        onPageFetched: (([Track]) -> Void)?
    ) async throws -> [Track] {
        var allTracks: [Track] = []
        var previousResult: [String: Any]? = nil

        while true {
            let jsResult = try await JSExecutionEngine.shared.execute(
                script: script, params: scriptParams(params, previousResult: previousResult),
                domain: config.url, context: context, allowedUrls: config.effectiveAllowedUrls
            )
            let (items, continuation) = parseResponse(jsResult)
            let tracks = items.map { $0.toTrack(mediaSourceId: mediaSourceId, type: trackType) }
            allTracks.append(contentsOf: tracks)
            logger.info("Fetched page with \(tracks.count) track(s), total: \(allTracks.count)")
            onPageFetched?(allTracks)
            guard let nextContext = continuation else { break }
            previousResult = nextContext
        }

        logger.info("All pages fetched: \(allTracks.count) total track(s)")
        return allTracks
    }

    private func missingScriptError(_ name: String) -> NSError {
        NSError(
            domain: "TracklistFetchService", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "No \(name) script available"]
        )
    }
}
