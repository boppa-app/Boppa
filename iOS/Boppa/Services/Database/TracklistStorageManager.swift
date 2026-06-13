import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "TracklistStorageManager")

class TracklistStorageManager {
    static let shared = TracklistStorageManager()

    @Dependency(\.defaultDatabase) var database

    private init() {}

    // MARK: - Reads

    func fetchPinnedTracklists() -> [StoredTracklist] {
        (try? self.database.read { db in
            try StoredTracklist.where(\.isPinned).fetchAll(db)
        }) ?? []
    }

    func fetchLibraryTracklists() -> [StoredTracklist] {
        (try? self.database.read { db in
            try StoredTracklist.where(\.isSavedToLibrary).fetchAll(db)
        }) ?? []
    }

    func findStoredTracklist(mediaId: String, mediaSourceId: String) -> StoredTracklist? {
        try? self.database.read { db in
            try StoredTracklist
                .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
                .fetchOne(db)
        }
    }

    func loadTracksForTracklist(_ tracklist: StoredTracklist) -> [Track] {
        let isLikes = tracklist.tracklistType == Tracklist.TracklistType.likes.rawValue
        return (try? self.database.read { db in
            try self.fetchStoredTracks(for: tracklist, isLikes: isLikes, db: db)
        }) ?? []
    }

    private func fetchStoredTracks(for tracklist: StoredTracklist, isLikes: Bool, db: Database) throws -> [Track] {
        let query = StoredTracklistTrack
            .where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
            }
            .join(StoredTrack.all) { tt, t in
                tt.trackMediaId.eq(t.mediaId).and(tt.trackMediaSourceId.eq(t.mediaSourceId))
            }
        let storedTracks: [StoredTrack]
        if isLikes {
            storedTracks = try query.order { tt, _ in tt.sortOrder.desc() }.select { _, t in t }.fetchAll(db)
        } else {
            storedTracks = try query.order { tt, _ in tt.sortOrder }.select { _, t in t }.fetchAll(db)
        }
        return try storedTracks.map { stored in
            let artists = try TrackStorageManager.shared.loadArtistsForTrack(stored, db: db)
            let albums = try TrackStorageManager.shared.loadAlbumsForTrack(stored, db: db)
            return stored.toTrack(artists: artists, albums: albums)
        }
    }

    func tracklist(from stored: StoredTracklist, db: Database) throws -> Tracklist {
        Tracklist(storedTracklist: stored)
    }

    func tracklistWithRelations(from stored: StoredTracklist) -> Tracklist {
        (try? self.database.read { db in try self.tracklist(from: stored, db: db) })
            ?? Tracklist(storedTracklist: stored)
    }

    // MARK: - Writes

    func storeTracklist(_ tracklist: Tracklist, tracks: [Track]) async throws -> StoredTracklist {
        let stored = try await database.write { db in
            let stored = try self.upsertStoredTracklist(tracklist: tracklist, db: db)
            try self.persistTracks(tracks, into: stored, db: db, pruneStale: true)
            return try StoredTracklist
                .where { $0.mediaId.eq(stored.mediaId).and($0.mediaSourceId.eq(stored.mediaSourceId)) }
                .fetchOne(db) ?? stored
        }
        logger.info("Stored tracklist '\(tracklist.title)' with \(tracks.count) track(s) to library")
        return stored
    }

    func setPin(_ storedTracklist: StoredTracklist, isPinned: Bool) throws {
        try self.database.write { db in
            try StoredTracklist.update { $0.isPinned = isPinned }
                .where { $0.mediaId.eq(storedTracklist.mediaId).and($0.mediaSourceId.eq(storedTracklist.mediaSourceId)) }
                .execute(db)
        }
    }

    func updateSortOrders(for tracklists: [Tracklist], reversed: Bool) throws {
        var keys = FractionalIndex.generateNKeysBetween(nil, nil, n: tracklists.count)
        if reversed { keys = keys.reversed() }
        try self.database.write { db in
            for (tracklist, key) in zip(tracklists, keys) {
                guard let stored = tracklist.storedTracklist else { continue }
                try StoredTracklist.update { $0.sortOrder = key }
                    .where { $0.mediaId.eq(stored.mediaId).and($0.mediaSourceId.eq(stored.mediaSourceId)) }
                    .execute(db)
            }
        }
    }

    func loadLibraryTracklists(type: String, visibleMediaSourceIds: Set<String>, reversed: Bool) -> [Tracklist] {
        (try? self.database.read { db in
            var allStored = try StoredTracklist
                .where { $0.tracklistType.eq(type).and($0.isSavedToLibrary.eq(true)) }
                .order { $0.sortOrder }
                .fetchAll(db)
            if reversed { allStored.reverse() }
            return try allStored
                .filter { visibleMediaSourceIds.contains($0.mediaSourceId) }
                .map { try self.tracklist(from: $0, db: db) }
        }) ?? []
    }

    func deleteStoredTracklist(_ storedTracklist: StoredTracklist) throws {
        try self.database.write { db in
            let joins = try StoredTracklistTrack
                .where {
                    $0.tracklistMediaId.eq(storedTracklist.mediaId)
                        .and($0.tracklistMediaSourceId.eq(storedTracklist.mediaSourceId))
                }
                .fetchAll(db)

            let albumRefCount = try StoredTrackAlbum
                .where {
                    $0.tracklistMediaId.eq(storedTracklist.mediaId)
                        .and($0.tracklistMediaSourceId.eq(storedTracklist.mediaSourceId))
                }
                .fetchCount(db)

            if albumRefCount > 0 {
                try StoredTracklist.update { $0.isSavedToLibrary = false }
                    .where { $0.mediaId.eq(storedTracklist.mediaId).and($0.mediaSourceId.eq(storedTracklist.mediaSourceId)) }
                    .execute(db)
                try StoredTracklistTrack
                    .where {
                        $0.tracklistMediaId.eq(storedTracklist.mediaId)
                            .and($0.tracklistMediaSourceId.eq(storedTracklist.mediaSourceId))
                    }
                    .delete()
                    .execute(db)
            } else {
                try StoredTracklist
                    .where { $0.mediaId.eq(storedTracklist.mediaId).and($0.mediaSourceId.eq(storedTracklist.mediaSourceId)) }
                    .delete()
                    .execute(db)
            }

            for join in joins {
                try TrackStorageManager.shared.deleteIfOrphaned(mediaId: join.trackMediaId, mediaSourceId: join.trackMediaSourceId, db: db)
            }
        }
        logger.info("Deleted stored tracklist '\(storedTracklist.title)'")
    }

    func loadTrackWithRelations(_ stored: StoredTrack) -> Track {
        (try? self.database.read { db in
            let artists = try TrackStorageManager.shared.loadArtistsForTrack(stored, db: db)
            let albums = try TrackStorageManager.shared.loadAlbumsForTrack(stored, db: db)
            return stored.toTrack(artists: artists, albums: albums)
        }) ?? stored.toTrack()
    }

    // MARK: - Private: Tracklist Persistence

    private func upsertStoredTracklist(tracklist: Tracklist, db: Database) throws -> StoredTracklist {
        let existing = try StoredTracklist
            .where { $0.mediaId.eq(tracklist.mediaId).and($0.mediaSourceId.eq(tracklist.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
            try StoredTracklist.update {
                $0.title = tracklist.title
                $0.subtitle = tracklist.subtitle
                $0.artworkUrl = tracklist.artworkUrl
                $0.isSavedToLibrary = true
            }
            .where { $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId)) }
            .execute(db)
            return try StoredTracklist
                .where { $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId)) }
                .fetchOne(db) ?? existing
        }

        let typeString = tracklist.tracklistType.rawValue
        let maxKey = try StoredTracklist
            .where { $0.tracklistType.eq(typeString) }
            .order { $0.sortOrder.desc() }
            .fetchOne(db)?
            .sortOrder
        let newSortOrder = FractionalIndex.generateKeyBetween(maxKey, nil)

        try StoredTracklist.insert {
            StoredTracklist.Draft(
                mediaId: tracklist.mediaId,
                mediaSourceId: tracklist.mediaSourceId,
                title: tracklist.title,
                subtitle: tracklist.subtitle,
                artworkUrl: tracklist.artworkUrl,
                tracklistType: typeString,
                isPinned: false,
                isSavedToLibrary: true,
                sortOrder: newSortOrder
            )
        }.execute(db)

        return try StoredTracklist
            .where { $0.mediaId.eq(tracklist.mediaId).and($0.mediaSourceId.eq(tracklist.mediaSourceId)) }
            .fetchOne(db)!
    }

    private func persistTracks(_ tracks: [Track], into tracklist: StoredTracklist, db: Database, pruneStale: Bool) throws {
        let newKeys = FractionalIndex.generateNKeysBetween(nil, nil, n: tracks.count)
        let (existingJoins, existingTracks) = try fetchExistingTrackData(for: tracklist, db: db)
        let (artistCache, albumCache) = try buildRelationCache(for: existingTracks, db: db)

        for (index, track) in tracks.enumerated() {
            let newKey = newKeys[index]
            if let match = existingTracks.first(where: { $0.identityMatches(track) }) {
                try self.syncExistingTrack(track, match: match, newKey: newKey, existingJoins: existingJoins, artistCache: artistCache, albumCache: albumCache, db: db)
            } else {
                try self.insertNewTrackJoin(track, newKey: newKey, into: tracklist, db: db)
            }
        }

        if pruneStale {
            try self.pruneStaleJoins(existingTracks: existingTracks, newTracks: tracks, from: tracklist, db: db)
        }
    }

    private func fetchExistingTrackData(for tracklist: StoredTracklist, db: Database) throws -> ([StoredTracklistTrack], [StoredTrack]) {
        let joins = try StoredTracklistTrack
            .where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
            }
            .order { $0.sortOrder }
            .fetchAll(db)

        let tracks: [StoredTrack] = try StoredTracklistTrack
            .where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
            }
            .join(StoredTrack.all) { tt, t in
                tt.trackMediaId.eq(t.mediaId).and(tt.trackMediaSourceId.eq(t.mediaSourceId))
            }
            .order { tt, _ in tt.sortOrder }
            .select { _, t in t }
            .fetchAll(db)

        return (joins, tracks)
    }

    private func buildRelationCache(for tracks: [StoredTrack], db: Database) throws -> ([String: [Artist]], [String: [Tracklist]]) {
        var artistCache: [String: [Artist]] = [:]
        var albumCache: [String: [Tracklist]] = [:]
        for track in tracks {
            let key = "\(track.mediaId)|\(track.mediaSourceId)"
            artistCache[key] = try TrackStorageManager.shared.loadArtistsForTrack(track, db: db)
            albumCache[key] = try TrackStorageManager.shared.loadAlbumsForTrack(track, db: db)
        }
        return (artistCache, albumCache)
    }

    private func syncExistingTrack(
        _ track: Track,
        match: StoredTrack,
        newKey: String,
        existingJoins: [StoredTracklistTrack],
        artistCache: [String: [Artist]],
        albumCache: [String: [Tracklist]],
        db: Database
    ) throws {
        if let join = existingJoins.first(where: { $0.trackMediaId == match.mediaId && $0.trackMediaSourceId == match.mediaSourceId }),
           join.sortOrder != newKey
        {
            try StoredTracklistTrack.update { $0.sortOrder = newKey }
                .where {
                    $0.tracklistMediaId.eq(join.tracklistMediaId)
                        .and($0.tracklistMediaSourceId.eq(join.tracklistMediaSourceId))
                        .and($0.trackMediaId.eq(join.trackMediaId))
                        .and($0.trackMediaSourceId.eq(join.trackMediaSourceId))
                }
                .execute(db)
        }
        let cacheKey = "\(match.mediaId)|\(match.mediaSourceId)"
        let existingArtists = artistCache[cacheKey] ?? []
        let existingAlbums = albumCache[cacheKey] ?? []
        if !match.contentMatches(track, artists: existingArtists, albums: existingAlbums) {
            try TrackStorageManager.shared.updateTrackScalars(track, stored: match, db: db)
            try TrackStorageManager.shared.replaceTrackArtists(track: match, artists: track.artists, db: db)
            try TrackStorageManager.shared.replaceTrackAlbums(track: match, albums: track.albums, db: db)
        }
    }

    private func insertNewTrackJoin(_ track: Track, newKey: String, into tracklist: StoredTracklist, db: Database) throws {
        try TrackStorageManager.shared.upsertTrack(track, db: db)
        try StoredTracklistTrack.insert {
            StoredTracklistTrack.Draft(
                tracklistMediaId: tracklist.mediaId,
                tracklistMediaSourceId: tracklist.mediaSourceId,
                trackMediaId: track.mediaId,
                trackMediaSourceId: track.mediaSourceId,
                sortOrder: newKey
            )
        } onConflictDoUpdate: { $0.sortOrder = newKey }
            .execute(db)
    }

    private func pruneStaleJoins(existingTracks: [StoredTrack], newTracks: [Track], from tracklist: StoredTracklist, db: Database) throws {
        for existing in existingTracks where !newTracks.contains(where: { existing.identityMatches($0) }) {
            try StoredTracklistTrack.where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
                    .and($0.trackMediaId.eq(existing.mediaId))
                    .and($0.trackMediaSourceId.eq(existing.mediaSourceId))
            }.delete().execute(db)

            try TrackStorageManager.shared.deleteIfOrphaned(mediaId: existing.mediaId, mediaSourceId: existing.mediaSourceId, db: db)
        }
    }

    // MARK: - Album Stubs

    func upsertAlbumTracklist(_ album: Tracklist, db: Database) throws {
        let existing = try StoredTracklist
            .where { $0.mediaId.eq(album.mediaId).and($0.mediaSourceId.eq(album.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
            try StoredTracklist.update {
                if !album.title.isEmpty { $0.title = album.title }
                if album.subtitle != nil { $0.subtitle = album.subtitle }
                if album.artworkUrl != nil { $0.artworkUrl = album.artworkUrl }
            }
            .where { $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId)) }
            .execute(db)
        } else {
            let typeString = Tracklist.TracklistType.album.rawValue
            let maxKey = try StoredTracklist
                .where { $0.tracklistType.eq(typeString) }
                .order { $0.sortOrder.desc() }
                .fetchOne(db)?
                .sortOrder
            let newSortOrder = FractionalIndex.generateKeyBetween(maxKey, nil)
            try StoredTracklist.insert {
                StoredTracklist.Draft(
                    mediaId: album.mediaId,
                    mediaSourceId: album.mediaSourceId,
                    title: album.title,
                    subtitle: album.subtitle,
                    artworkUrl: album.artworkUrl,
                    tracklistType: typeString,
                    isPinned: false,
                    isSavedToLibrary: false,
                    sortOrder: newSortOrder
                )
            }.execute(db)
        }
    }
}
