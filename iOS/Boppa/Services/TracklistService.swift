import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "TracklistService"
)

struct TracklistResponse {
    let tracks: [Track]
    let paginationContext: [String: Any]?
}

class TracklistService {
    static let shared = TracklistService()

    @Dependency(\.defaultDatabase) var database

    private let paginated = PaginatedScriptExecutor.shared

    private init() {}

    func resolveMediaSource(mediaSourceId: String) -> MediaSource? {
        try? database.read { db in
            try MediaSource.where { $0.id.eq(mediaSourceId) }.fetchOne(db)
        }
    }

    func fetchTracklist(
        tracklist: Tracklist,
        previousResult: [String: Any]? = nil
    ) async throws -> TracklistResponse {
        guard let mediaSource = resolveMediaSource(mediaSourceId: tracklist.mediaSourceId) else {
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
        for (key, value) in artist.metadata { itemParams[key] = value }
        for (key, value) in artistDetail.metadata { itemParams[key] = value }

        let context = self.paginated.buildJSContext(params: ["item": itemParams], previousResult: nil)
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
        for (key, value) in artist.metadata { itemParams[key] = value }
        for (key, value) in artistDetail.metadata { itemParams[key] = value }

        let context = self.paginated.buildJSContext(params: ["item": itemParams], previousResult: nil)
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
        for (key, value) in artist.metadata { itemParams[key] = value }
        if let artistDetail = tracklist.artistDetail {
            for (key, value) in artistDetail.metadata { itemParams[key] = value }
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
        for (key, value) in tracklist.metadata { itemParams[key] = value }

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
        for (key, value) in tracklist.metadata { itemParams[key] = value }

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

    func persistTracks(_ tracks: [Track], into tracklist: StoredTracklist, db: Database, pruneStale: Bool) throws {
        let existingJoins = try StoredTracklistTrack
            .where { $0.tracklistId.eq(tracklist.id) }
            .order { $0.sortOrder }
            .fetchAll(db)

        let existingTracks = try existingJoins.map { join -> StoredTrack in
            guard let track = try StoredTrack.where { $0.id.eq(join.trackId) }.fetchOne(db) else {
                throw NSError(domain: "TracklistService", code: 10, userInfo: [NSLocalizedDescriptionKey: "Track \(join.trackId) not found"])
            }
            return track
        }

        for (index, track) in tracks.enumerated() {
            if let match = existingTracks.first(where: { $0.identityMatches(track) }) {
                if let join = existingJoins.first(where: { $0.trackId == match.id }), join.sortOrder != index {
                    try StoredTracklistTrack.update { $0.sortOrder = index }
                        .where { $0.id.eq(join.id) }
                        .execute(db)
                }
                let existingArtists = try loadArtistsForTrack(match.id, db: db)
                let existingAlbums = try loadAlbumsForTrack(match.id, db: db)
                if !match.contentMatches(track, artists: existingArtists, albums: existingAlbums) {
                    try StoredTrack.update {
                        $0.title = track.title
                        $0.subtitle = track.subtitle
                        $0.duration = track.duration
                        $0.artworkUrl = track.artworkUrl
                        $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
                    }
                    .where { $0.id.eq(match.id) }
                    .execute(db)
                    try replaceTrackArtists(trackId: match.id, artists: track.artists, db: db)
                    try replaceTrackAlbums(trackId: match.id, albums: track.albums, db: db)
                }
            } else {
                let existingTrack = try StoredTrack
                    .where { $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId)) }
                    .fetchOne(db)

                let trackId: Int
                if let existing = existingTrack {
                    trackId = existing.id
                    let existingArtists = try loadArtistsForTrack(existing.id, db: db)
                    let existingAlbums = try loadAlbumsForTrack(existing.id, db: db)
                    if !existing.contentMatches(track, artists: existingArtists, albums: existingAlbums) {
                        try StoredTrack.update {
                            $0.title = track.title
                            $0.subtitle = track.subtitle
                            $0.duration = track.duration
                            $0.artworkUrl = track.artworkUrl
                            $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
                        }
                        .where { $0.id.eq(existing.id) }
                        .execute(db)
                        try replaceTrackArtists(trackId: existing.id, artists: track.artists, db: db)
                        try replaceTrackAlbums(trackId: existing.id, albums: track.albums, db: db)
                    }
                } else {
                    try StoredTrack.insert {
                        StoredTrack.Draft(
                            mediaId: track.mediaId,
                            mediaSourceId: track.mediaSourceId,
                            title: track.title,
                            subtitle: track.subtitle,
                            duration: track.duration,
                            artworkUrl: track.artworkUrl,
                            url: track.url,
                            metadataJSON: (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
                        )
                    }.execute(db)
                    trackId = Int(db.lastInsertedRowID)
                    try replaceTrackArtists(trackId: trackId, artists: track.artists, db: db)
                    try replaceTrackAlbums(trackId: trackId, albums: track.albums, db: db)
                }

                try StoredTracklistTrack.insert {
                    StoredTracklistTrack.Draft(tracklistId: tracklist.id, trackId: trackId, sortOrder: index)
                } onConflictDoUpdate: { $0.sortOrder = index }
                .execute(db)
            }
        }

        if pruneStale {
            for existing in existingTracks {
                if !tracks.contains(where: { existing.identityMatches($0) }) {
                    try StoredTracklistTrack.where {
                        $0.tracklistId.eq(tracklist.id).and($0.trackId.eq(existing.id))
                    }.delete().execute(db)

                    let usageCount = try StoredTracklistTrack.where { $0.trackId.eq(existing.id) }.fetchAll(db).count
                    if usageCount == 0 {
                        try StoredTrack.where { $0.id.eq(existing.id) }.delete().execute(db)
                    }
                }
            }
        }
    }

    @MainActor func saveTracklistToLibrary(
        tracklist: Tracklist,
        onPageFetched: (([Track]) -> Void)? = nil
    ) async throws -> StoredTracklist {
        guard let mediaSource = resolveMediaSource(mediaSourceId: tracklist.mediaSourceId) else {
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

        let stored = try await database.write { db in
            let stored = try self.upsertStoredTracklist(tracklist: tracklist, db: db)
            try self.persistTracks(tracks, into: stored, db: db, pruneStale: true)
            return stored
        }

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
            for (key, value) in tracklist.metadata { itemParams[key] = value }
        case .album:
            script = config.data?.getAlbum?.script
            itemParams["subtitle"] = tracklist.subtitle ?? ""
            itemParams["artworkUrl"] = tracklist.artworkUrl ?? ""
            for (key, value) in tracklist.metadata { itemParams[key] = value }
        default:
            throw NSError(domain: "TracklistService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot save this tracklist type to library"])
        }

        guard let script else {
            throw NSError(domain: "TracklistService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No script available for this tracklist type"])
        }

        return (script, itemParams)
    }

    private func upsertStoredTracklist(tracklist: Tracklist, db: Database) throws -> StoredTracklist {
        let fromArtistId = try tracklist.fromArtist.map { try upsertArtist($0, db: db) }

        let existingTracklist = try StoredTracklist
            .where { $0.mediaId.eq(tracklist.mediaId).and($0.mediaSourceId.eq(tracklist.mediaSourceId)) }
            .fetchOne(db)
        if let existing = existingTracklist {
            try StoredTracklist.update {
                $0.title = tracklist.title
                $0.subtitle = tracklist.subtitle
                $0.artworkUrl = tracklist.artworkUrl
                $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: tracklist.metadata)) ?? Data()
                $0.fromArtistId = fromArtistId
            }
            .where { $0.id.eq(existing.id) }
            .execute(db)

            try replaceTracklistArtists(tracklistId: existing.id, artists: tracklist.artists, db: db)

            return try StoredTracklist.where { $0.id.eq(existing.id) }.fetchOne(db) ?? existing
        }

        let typeString = tracklist.tracklistType.rawValue
        let currentTail = try StoredTracklist
            .where { $0.tracklistType.eq(typeString).and($0.nextId.is(nil)) }
            .fetchOne(db)

        try StoredTracklist.insert {
            StoredTracklist.Draft(
                mediaId: tracklist.mediaId,
                mediaSourceId: tracklist.mediaSourceId,
                title: tracklist.title,
                subtitle: tracklist.subtitle,
                artworkUrl: tracklist.artworkUrl,
                tracklistType: typeString,
                metadataJSON: (try? JSONSerialization.data(withJSONObject: tracklist.metadata)) ?? Data(),
                fromArtistId: fromArtistId,
                isPinned: false,
                prevId: currentTail?.id,
                nextId: nil
            )
        }.execute(db)

        let insertedId = Int(db.lastInsertedRowID)

        try replaceTracklistArtists(tracklistId: insertedId, artists: tracklist.artists, db: db)

        if let tail = currentTail {
            try StoredTracklist.update { $0.nextId = #bind(Optional(insertedId)) }
                .where { $0.id.eq(tail.id) }
                .execute(db)
        }

        return try StoredTracklist.where { $0.id.eq(insertedId) }.fetchOne(db)!
    }

    func deleteStoredTracklist(_ storedTracklist: StoredTracklist) throws {
        try database.write { db in
            try StoredTracklist.where { $0.id.eq(storedTracklist.id) }.delete().execute(db)
        }
        logger.info("Deleted stored tracklist '\(storedTracklist.title)'")
    }

    func loadTracksForTracklist(_ tracklist: StoredTracklist) -> [Track] {
        (try? database.read { db in
            let storedTracks = try StoredTracklistTrack
                .where { $0.tracklistId.eq(tracklist.id) }
                .join(StoredTrack.all) { tt, t in tt.trackId.eq(t.id) }
                .order { tt, _ in tt.sortOrder }
                .select { _, t in t }
                .fetchAll(db)
            return try storedTracks.map { stored in
                let artists = try self.loadArtistsForTrack(stored.id, db: db)
                let albums = try self.loadAlbumsForTrack(stored.id, db: db)
                return stored.toTrack(artists: artists, albums: albums)
            }
        }) ?? []
    }

    func tracklist(from stored: StoredTracklist, db: Database) throws -> Tracklist {
        let artists = try loadArtistsForTracklist(stored.id, db: db)
        let fromArtist = try stored.fromArtistId.flatMap { id in
            try StoredArtist.where { $0.id.eq(id) }.fetchOne(db)?.toArtist()
        }
        return Tracklist(storedTracklist: stored, artists: artists, fromArtist: fromArtist)
    }

    func tracklistWithRelations(from stored: StoredTracklist) -> Tracklist {
        (try? database.read { db in
            try self.tracklist(from: stored, db: db)
        }) ?? Tracklist(storedTracklist: stored)
    }

    func findStoredTracklist(mediaId: String, mediaSourceId: String) -> StoredTracklist? {
        try? database.read { db in
            try StoredTracklist
                .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
                .fetchOne(db)
        }
    }

    func findStoredTracklistById(_ id: Int) -> StoredTracklist? {
        try? database.read { db in
            try StoredTracklist.where { $0.id.eq(id) }.fetchOne(db)
        }
    }

    private func loadArtistsForTracklist(_ tracklistId: Int, db: Database) throws -> [Artist] {
        try StoredTracklistArtist
            .where { $0.tracklistId.eq(tracklistId) }
            .join(StoredArtist.all) { ta, a in ta.artistId.eq(a.id) }
            .order { ta, _ in ta.sortOrder }
            .select { _, a in a }
            .fetchAll(db)
            .map { $0.toArtist() }
    }

    private func loadArtistsForTrack(_ trackId: Int, db: Database) throws -> [Artist] {
        try StoredTrackArtist
            .where { $0.trackId.eq(trackId) }
            .join(StoredArtist.all) { ta, a in ta.artistId.eq(a.id) }
            .order { ta, _ in ta.sortOrder }
            .select { _, a in a }
            .fetchAll(db)
            .map { $0.toArtist() }
    }

    private func loadAlbumsForTrack(_ trackId: Int, db: Database) throws -> [Tracklist] {
        try StoredTrackAlbum
            .where { $0.trackId.eq(trackId) }
            .join(StoredTracklist.all) { ta, tl in ta.tracklistId.eq(tl.id) }
            .order { ta, _ in ta.sortOrder }
            .select { _, tl in tl }
            .fetchAll(db)
            .map { Tracklist(storedTracklist: $0) }
    }

    private func replaceTrackArtists(trackId: Int, artists: [Artist], db: Database) throws {
        try StoredTrackArtist.where { $0.trackId.eq(trackId) }.delete().execute(db)
        for (index, artist) in artists.enumerated() {
            let artistId = try upsertArtist(artist, db: db)
            try StoredTrackArtist.insert {
                StoredTrackArtist.Draft(trackId: trackId, artistId: artistId, sortOrder: index)
            }.execute(db)
        }
    }

    private func replaceTrackAlbums(trackId: Int, albums: [Tracklist], db: Database) throws {
        try StoredTrackAlbum.where { $0.trackId.eq(trackId) }.delete().execute(db)
        for (index, album) in albums.enumerated() {
            let tracklistId = try upsertAlbumTracklist(album, db: db)
            try StoredTrackAlbum.insert {
                StoredTrackAlbum.Draft(trackId: trackId, tracklistId: tracklistId, sortOrder: index)
            }.execute(db)
        }
    }

    private func replaceTracklistArtists(tracklistId: Int, artists: [Artist], db: Database) throws {
        try StoredTracklistArtist.where { $0.tracklistId.eq(tracklistId) }.delete().execute(db)
        for (index, artist) in artists.enumerated() {
            let artistId = try upsertArtist(artist, db: db)
            try StoredTracklistArtist.insert {
                StoredTracklistArtist.Draft(tracklistId: tracklistId, artistId: artistId, sortOrder: index)
            }.execute(db)
        }
    }

    private func upsertArtist(_ artist: Artist, db: Database) throws -> Int {
        let existing = try StoredArtist
            .where { $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
            let mergedMetadata = deepMerge(existing.metadata, artist.metadata)
            try StoredArtist.update {
                if !artist.name.isEmpty { $0.name = artist.name }
                if artist.artworkUrl != nil { $0.artworkUrl = artist.artworkUrl }
                $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: mergedMetadata)) ?? Data()
            }
            .where { $0.id.eq(existing.id) }
            .execute(db)
            return existing.id
        } else {
            try StoredArtist.insert {
                StoredArtist.Draft(
                    mediaId: artist.mediaId,
                    mediaSourceId: artist.mediaSourceId,
                    name: artist.name,
                    artworkUrl: artist.artworkUrl,
                    metadataJSON: (try? JSONSerialization.data(withJSONObject: artist.metadata)) ?? Data()
                )
            }.execute(db)
            return Int(db.lastInsertedRowID)
        }
    }

    private func upsertAlbumTracklist(_ album: Tracklist, db: Database) throws -> Int {
        let existing = try StoredTracklist
            .where { $0.mediaId.eq(album.mediaId).and($0.mediaSourceId.eq(album.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
            let mergedMetadata = deepMerge(existing.metadata, album.metadata)
            try StoredTracklist.update {
                if !album.title.isEmpty { $0.title = album.title }
                if album.subtitle != nil { $0.subtitle = album.subtitle }
                if album.artworkUrl != nil { $0.artworkUrl = album.artworkUrl }
                $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: mergedMetadata)) ?? Data()
            }
            .where { $0.id.eq(existing.id) }
            .execute(db)
            return existing.id
        } else {
            try StoredTracklist.insert {
                StoredTracklist.Draft(
                    mediaId: album.mediaId,
                    mediaSourceId: album.mediaSourceId,
                    title: album.title,
                    subtitle: album.subtitle,
                    artworkUrl: album.artworkUrl,
                    tracklistType: Tracklist.TracklistType.album.rawValue,
                    metadataJSON: (try? JSONSerialization.data(withJSONObject: album.metadata)) ?? Data(),
                    fromArtistId: nil,
                    isPinned: false,
                    prevId: nil,
                    nextId: nil
                )
            }.execute(db)
            return Int(db.lastInsertedRowID)
        }
    }

    private func deepMerge(_ base: [String: Any], _ override: [String: Any]) -> [String: Any] {
        var result = base
        for (key, newValue) in override {
            if let existingDict = result[key] as? [String: Any],
               let newDict = newValue as? [String: Any]
            {
                result[key] = deepMerge(existingDict, newDict)
            } else {
                result[key] = newValue
            }
        }
        return result
    }
}
