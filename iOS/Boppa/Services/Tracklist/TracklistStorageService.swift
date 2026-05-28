import Dependencies
import Foundation
import SQLiteData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "TracklistStorageService")

class TracklistStorageService {
    static let shared = TracklistStorageService()

    @Dependency(\.defaultDatabase) var database

    private let paginated = PaginatedScriptExecutor.shared

    private init() {}

    // MARK: - Reads

    func resolveMediaSource(mediaSourceId: String) -> MediaSource? {
        try? database.read { db in
            try MediaSource.where { $0.id.eq(mediaSourceId) }.fetchOne(db)
        }
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
        (try? database.read { db in try self.tracklist(from: stored, db: db) })
            ?? Tracklist(storedTracklist: stored)
    }

    // MARK: - Writes

    @MainActor func saveTracklistToLibrary(
        tracklist: Tracklist,
        onPageFetched: (([Track]) -> Void)? = nil
    ) async throws -> StoredTracklist {
        guard let mediaSource = resolveMediaSource(mediaSourceId: tracklist.mediaSourceId) else {
            throw NSError(domain: "TracklistStorageService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No media source found for tracklist"])
        }

        let (script, itemParams) = try buildFetchParams(tracklist: tracklist, config: mediaSource.config)
        logger.info("Saving tracklist '\(tracklist.title)' to library for '\(tracklist.mediaSourceId)'...")

        let tracks = try await paginated.executeAllPages(
            script: script,
            params: ["item": itemParams],
            customUserAgent: mediaSource.config.customUserAgent,
            domain: mediaSource.config.url,
            mediaSourceId: tracklist.mediaSourceId,
            mediaSourceContext: mediaSource.contextValues,
            onPageFetched: { onPageFetched?($0) }
        )

        let stored = try await database.write { db in
            let stored = try self.upsertStoredTracklist(tracklist: tracklist, db: db)
            try self.persistTracks(tracks, into: stored, db: db, pruneStale: true)
            return stored
        }

        logger.info("Saved tracklist '\(tracklist.title)' with \(tracks.count) track(s) to library")
        return stored
    }

    func deleteStoredTracklist(_ storedTracklist: StoredTracklist) throws {
        try database.write { db in
            try StoredTracklist.where { $0.id.eq(storedTracklist.id) }.delete().execute(db)
        }
        logger.info("Deleted stored tracklist '\(storedTracklist.title)'")
    }

    // MARK: - Private: reads

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

    private func loadArtistsForTracklist(_ tracklistId: Int, db: Database) throws -> [Artist] {
        try StoredTracklistArtist
            .where { $0.tracklistId.eq(tracklistId) }
            .join(StoredArtist.all) { ta, a in ta.artistId.eq(a.id) }
            .order { ta, _ in ta.sortOrder }
            .select { _, a in a }
            .fetchAll(db)
            .map { $0.toArtist() }
    }

    // MARK: - Private: tracklist persistence

    private func upsertStoredTracklist(tracklist: Tracklist, db: Database) throws -> StoredTracklist {
        let fromArtistId = try tracklist.fromArtist.map { try upsertArtist($0, db: db) }

        let existing = try StoredTracklist
            .where { $0.mediaId.eq(tracklist.mediaId).and($0.mediaSourceId.eq(tracklist.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
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
        let tail = try StoredTracklist
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
                prevId: tail?.id,
                nextId: nil
            )
        }.execute(db)

        let insertedId = Int(db.lastInsertedRowID)
        try replaceTracklistArtists(tracklistId: insertedId, artists: tracklist.artists, db: db)

        if let tail {
            try StoredTracklist.update { $0.nextId = #bind(Optional(insertedId)) }
                .where { $0.id.eq(tail.id) }
                .execute(db)
        }

        return try StoredTracklist.where { $0.id.eq(insertedId) }.fetchOne(db)!
    }

    private func persistTracks(_ tracks: [Track], into tracklist: StoredTracklist, db: Database, pruneStale: Bool) throws {
        let existingJoins = try StoredTracklistTrack
            .where { $0.tracklistId.eq(tracklist.id) }
            .order { $0.sortOrder }
            .fetchAll(db)

        let existingTracks = try existingJoins.map { join -> StoredTrack in
            guard let track = try StoredTrack.where { $0.id.eq(join.trackId) }.fetchOne(db) else {
                throw NSError(domain: "TracklistStorageService", code: 10, userInfo: [NSLocalizedDescriptionKey: "Track \(join.trackId) not found"])
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
                    try updateTrackScalars(track, id: match.id, db: db)
                    try replaceTrackArtists(trackId: match.id, artists: track.artists, db: db)
                    try replaceTrackAlbums(trackId: match.id, albums: track.albums, db: db)
                }
            } else {
                let trackId = try upsertTrack(track, db: db)
                try StoredTracklistTrack.insert {
                    StoredTracklistTrack.Draft(tracklistId: tracklist.id, trackId: trackId, sortOrder: index)
                } onConflictDoUpdate: { $0.sortOrder = index }
                .execute(db)
            }
        }

        if pruneStale {
            for existing in existingTracks where !tracks.contains(where: { existing.identityMatches($0) }) {
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

    private func buildFetchParams(tracklist: Tracklist, config: MediaSourceConfig) throws -> (script: String, params: [String: Any]) {
        let script: String?
        var itemParams: [String: Any] = ["artworkUrl": tracklist.artworkUrl ?? ""]
        for (key, value) in tracklist.metadata { itemParams[key] = value }

        switch tracklist.tracklistType {
        case .playlist:
            script = config.data?.getPlaylist?.script
            itemParams["user"] = tracklist.subtitle ?? ""
        case .album:
            script = config.data?.getAlbum?.script
            itemParams["subtitle"] = tracklist.subtitle ?? ""
        default:
            throw NSError(domain: "TracklistStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot save this tracklist type to library"])
        }

        guard let script else {
            throw NSError(domain: "TracklistStorageService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No script available for this tracklist type"])
        }
        return (script, itemParams)
    }

    private func upsertTrack(_ track: Track, db: Database) throws -> Int {
        let existing = try StoredTrack
            .where { $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
            let existingArtists = try loadArtistsForTrack(existing.id, db: db)
            let existingAlbums = try loadAlbumsForTrack(existing.id, db: db)
            if !existing.contentMatches(track, artists: existingArtists, albums: existingAlbums) {
                try updateTrackScalars(track, id: existing.id, db: db)
                try replaceTrackArtists(trackId: existing.id, artists: track.artists, db: db)
                try replaceTrackAlbums(trackId: existing.id, albums: track.albums, db: db)
            }
            return existing.id
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
            let trackId = Int(db.lastInsertedRowID)
            try replaceTrackArtists(trackId: trackId, artists: track.artists, db: db)
            try replaceTrackAlbums(trackId: trackId, albums: track.albums, db: db)
            return trackId
        }
    }

    private func updateTrackScalars(_ track: Track, id: Int, db: Database) throws {
        try StoredTrack.update {
            $0.title = track.title
            $0.subtitle = track.subtitle
            $0.duration = track.duration
            $0.artworkUrl = track.artworkUrl
            $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
        }
        .where { $0.id.eq(id) }
        .execute(db)
    }

    // MARK: - Private: relationship writes

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
