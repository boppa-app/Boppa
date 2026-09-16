import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "TracklistStorageManager"
)

class TracklistStorageManager {
    static let shared = TracklistStorageManager()

    @Dependency(\.defaultDatabase) var database

    private init() {}

    // MARK: - DB Access

    private func withReadDB<T>(_ db: Database?, _ body: (Database) throws -> T) throws -> T {
        if let db { return try body(db) }
        return try self.database.read(body)
    }

    private func withWriteDB<T>(_ db: Database?, _ body: (Database) throws -> T) throws -> T {
        if let db { return try body(db) }
        return try self.database.write(body)
    }

    // MARK: - Reads

    func fetchPinnedTracklists(db: Database? = nil) -> [StoredTracklist] {
        (try? self.withReadDB(db) { db in
            try StoredTracklist.where(\.isPinned).fetchAll(db)
        }) ?? []
    }

    func fetchLibraryTracklists(db: Database? = nil) -> [StoredTracklist] {
        (try? self.withReadDB(db) { db in
            try StoredTracklist.where(\.isSavedToLibrary).fetchAll(db)
        }) ?? []
    }

    func findStoredTracklist(_ tracklist: Tracklist, db: Database? = nil) -> StoredTracklist? {
        try? self.withReadDB(db) { db in
            try StoredTracklist
                .where {
                    $0.mediaId.eq(tracklist.mediaId)
                        .and($0.mediaSourceId.eq(tracklist.mediaSourceId))
                }
                .fetchOne(db)
        }
    }

    func isTracklistEmpty(_ tracklist: Tracklist, db: Database? = nil) -> Bool {
        let match: StoredTracklistTrack? = try? self.withReadDB(db) { db in
            try StoredTracklistTrack
                .where {
                    $0.tracklistMediaId.eq(tracklist.mediaId)
                        .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
                }
                .fetchOne(db)
        }
        return match == nil
    }

    func fetchStoredAlbumsForTracks(
        _ tracks: [Track],
        db: Database? = nil
    ) throws -> [(Track, StoredTracklist)] {
        guard !tracks.isEmpty else { return [] }
        return try self.withReadDB(db) { db in
            let tracksByKey = Dictionary(
                uniqueKeysWithValues: tracks.map { ("\($0.mediaId)|\($0.mediaSourceId)", $0) }
            )
            let rows = try StoredTrackAlbum
                .where { $0.trackMediaId.in(tracks.map(\.mediaId)) }
                .join(StoredTracklist.all) { ta, tl in
                    ta.tracklistMediaId.eq(tl.mediaId).and(
                        ta.tracklistMediaSourceId.eq(tl.mediaSourceId)
                    )
                }
                .order { ta, _ in ta.sortOrder }
                .fetchAll(db)
            return rows.compactMap { trackAlbum, tracklist in
                guard let track = tracksByKey[
                    "\(trackAlbum.trackMediaId)|\(trackAlbum.trackMediaSourceId)"
                ] else { return nil }
                return (track, tracklist)
            }
        }
    }

    // MARK: - Writes

    func storeTracklist(
        _ tracklist: Tracklist,
        tracks: [Track],
        db: Database? = nil
    ) async throws -> StoredTracklist {
        let stored: StoredTracklist
        if let db {
            stored = try self.performStoreTracklist(tracklist, tracks: tracks, db: db)
        } else {
            stored = try await self.database.write { db in
                try self.performStoreTracklist(tracklist, tracks: tracks, db: db)
            }
        }
        logger
            .info("Stored tracklist '\(tracklist.title)' with \(tracks.count) track(s) to library")
        return stored
    }

    private func performStoreTracklist(
        _ tracklist: Tracklist,
        tracks: [Track],
        db: Database
    ) throws -> StoredTracklist {
        let stored = try self.upsertLibraryTracklist(tracklist: tracklist, db: db)
        try self.persistTracks(tracks, into: stored, db: db, pruneStale: true)
        return try StoredTracklist
            .where {
                $0.mediaId.eq(stored.mediaId).and($0.mediaSourceId.eq(stored.mediaSourceId))
            }
            .fetchOne(db) ?? stored
    }

    func setPin(_ storedTracklist: StoredTracklist, isPinned: Bool, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            try StoredTracklist.update { $0.isPinned = isPinned }
                .where {
                    $0.mediaId.eq(storedTracklist.mediaId)
                        .and($0.mediaSourceId.eq(storedTracklist.mediaSourceId))
                }
                .execute(db)
        }
    }

    func moveTracklist(
        _ tracklist: Tracklist,
        after previousTracklist: Tracklist?,
        before nextTracklist: Tracklist?,
        db: Database? = nil
    ) throws {
        guard let stored = tracklist.storedTracklist else { return }
        try self.withWriteDB(db) { db in
            func sortOrderKey(for tracklist: Tracklist?) throws -> String? {
                guard let stored = tracklist?.storedTracklist else { return nil }
                return try StoredTracklist
                    .where {
                        $0.mediaId.eq(stored.mediaId).and($0.mediaSourceId.eq(stored.mediaSourceId))
                    }
                    .fetchOne(db)?.sortOrder
            }

            let prevKey = try sortOrderKey(for: previousTracklist)
            let nextKey = try sortOrderKey(for: nextTracklist)
            let newKey = FractionalIndex.generateKeyBetween(prevKey, nextKey)

            try StoredTracklist.update { $0.sortOrder = newKey }
                .where {
                    $0.mediaId.eq(stored.mediaId)
                        .and($0.mediaSourceId.eq(stored.mediaSourceId))
                }
                .execute(db)
        }
    }

    func fetchLibraryTracklists(type: String, db: Database? = nil) -> [Tracklist] {
        (try? self.withReadDB(db) { db in
            try StoredTracklist
                .where { $0.tracklistType.eq(type).and($0.isSavedToLibrary.eq(true)) }
                .order { $0.sortOrder }
                .fetchAll(db)
        })?.map { Tracklist(storedTracklist: $0) } ?? []
    }

    func deleteStoredTracklist(_ storedTracklist: StoredTracklist, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            let tracks = try StoredTracklistTrack
                .where {
                    $0.tracklistMediaId.eq(storedTracklist.mediaId)
                        .and($0.tracklistMediaSourceId.eq(storedTracklist.mediaSourceId))
                }
                .join(StoredTrack.all) { tt, t in
                    tt.trackMediaId.eq(t.mediaId).and(tt.trackMediaSourceId.eq(t.mediaSourceId))
                }
                .select { _, t in t }
                .fetchAll(db)

            let albumRefCount = try StoredTrackAlbum
                .where {
                    $0.tracklistMediaId.eq(storedTracklist.mediaId)
                        .and($0.tracklistMediaSourceId.eq(storedTracklist.mediaSourceId))
                }
                .fetchCount(db)

            if albumRefCount > 0 {
                try StoredTracklist.update { $0.isSavedToLibrary = false }
                    .where {
                        $0.mediaId.eq(storedTracklist.mediaId)
                            .and($0.mediaSourceId.eq(storedTracklist.mediaSourceId))
                    }
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
                    .where {
                        $0.mediaId.eq(storedTracklist.mediaId)
                            .and($0.mediaSourceId.eq(storedTracklist.mediaSourceId))
                    }
                    .delete()
                    .execute(db)
            }

            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned(
                tracks.map { $0.toTrack() },
                db: db
            )
        }
        logger.info("Deleted stored tracklist '\(storedTracklist.title)'")
    }

    private func upsertLibraryTracklist(
        tracklist: Tracklist,
        db: Database
    ) throws -> StoredTracklist {
        let existing = try StoredTracklist
            .where {
                $0.mediaId.eq(tracklist.mediaId).and($0.mediaSourceId.eq(tracklist.mediaSourceId))
            }
            .fetchOne(db)
        if let existing {
            try StoredTracklist.update {
                $0.title = tracklist.title
                $0.subtitle = tracklist.subtitle
                $0.year = tracklist.year
                $0.lowResArtworkUrl = tracklist.lowResArtworkUrl
                $0.highResArtworkUrl = tracklist.highResArtworkUrl
                $0.url = tracklist.url
                $0.isSavedToLibrary = true
            }
            .where {
                $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId))
            }
            .execute(db)
            return try StoredTracklist
                .where {
                    $0.mediaId.eq(existing.mediaId)
                        .and($0.mediaSourceId.eq(existing.mediaSourceId))
                }
                .fetchOne(db) ?? existing
        }

        guard tracklist.tracklistType.isPersistable else {
            throw NSError(
                domain: "TracklistStorageManager", code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Cannot save a '\(tracklist.tracklistType.rawValue)' tracklist to the library",
                ]
            )
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
                year: tracklist.year,
                lowResArtworkUrl: tracklist.lowResArtworkUrl,
                highResArtworkUrl: tracklist.highResArtworkUrl,
                url: tracklist.url,
                tracklistType: typeString,
                isPinned: false,
                isSavedToLibrary: true,
                sortOrder: newSortOrder
            )
        }.execute(db)

        return StoredTracklist(
            mediaId: tracklist.mediaId,
            mediaSourceId: tracklist.mediaSourceId,
            title: tracklist.title,
            subtitle: tracklist.subtitle,
            year: tracklist.year,
            lowResArtworkUrl: tracklist.lowResArtworkUrl,
            highResArtworkUrl: tracklist.highResArtworkUrl,
            url: tracklist.url,
            tracklistType: typeString,
            isPinned: false,
            isSavedToLibrary: true,
            sortOrder: newSortOrder
        )
    }

    private func persistTracks(
        _ tracks: [Track],
        into tracklist: StoredTracklist,
        db: Database,
        pruneStale: Bool
    ) throws {
        let newKeys = FractionalIndex.generateNKeysBetween(nil, nil, n: tracks.count)
        let (existingJoins, existingTracks) = try fetchExistingTrackData(for: tracklist, db: db)
        let relationCache = try buildRelationCache(for: existingTracks, db: db)

        for (index, track) in tracks.enumerated() {
            let newKey = newKeys[index]
            if let match = existingTracks.first(where: { $0.identityMatches(track) }) {
                try self.syncExistingTrack(
                    track,
                    match: match,
                    newKey: newKey,
                    existingJoins: existingJoins,
                    relationCache: relationCache,
                    db: db
                )
            } else {
                try self.insertNewTrackJoin(track, newKey: newKey, into: tracklist, db: db)
            }
        }

        if pruneStale {
            try self.pruneStaleJoins(
                existingTracks: existingTracks,
                newTracks: tracks,
                from: tracklist,
                db: db
            )
        }
    }

    private func fetchExistingTrackData(
        for tracklist: StoredTracklist,
        db: Database
    ) throws -> ([StoredTracklistTrack], [StoredTrack]) {
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

    private func buildRelationCache(
        for tracks: [StoredTrack],
        db: Database
    ) throws -> [(Track, [StoredArtist], [StoredTracklist])] {
        let domainTracks = tracks.map { $0.toTrack() }

        var artistsByKey: [String: [StoredArtist]] = [:]
        for (track, artist) in try ArtistStorageManager.shared.fetchStoredArtistsForTracks(
            domainTracks,
            db: db
        ) {
            artistsByKey[Self.key(track.mediaId, track.mediaSourceId), default: []].append(artist)
        }
        var albumsByKey: [String: [StoredTracklist]] = [:]
        for (track, album) in try self.fetchStoredAlbumsForTracks(
            domainTracks,
            db: db
        ) {
            albumsByKey[Self.key(track.mediaId, track.mediaSourceId), default: []].append(album)
        }

        return domainTracks.map { track in
            let key = Self.key(track.mediaId, track.mediaSourceId)
            return (track, artistsByKey[key] ?? [], albumsByKey[key] ?? [])
        }
    }

    private func syncExistingTrack(
        _ track: Track,
        match: StoredTrack,
        newKey: String,
        existingJoins: [StoredTracklistTrack],
        relationCache: [(Track, [StoredArtist], [StoredTracklist])],
        db: Database
    ) throws {
        if let join = existingJoins
            .first(where: {
                $0.trackMediaId == match.mediaId && $0.trackMediaSourceId == match.mediaSourceId
            }),
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
        let relations = relationCache.first {
            $0.0.mediaId == match.mediaId && $0.0.mediaSourceId == match.mediaSourceId
        }
        let existingArtists = relations?.1 ?? []
        let existingAlbums = relations?.2 ?? []
        if !match.contentMatches(track, artists: existingArtists, albums: existingAlbums) {
            try TrackStorageManager.shared.updateTrackScalars(track, stored: match, db: db)
            try TrackStorageManager.shared.replaceTrackArtists(
                track: match,
                artists: track.artists,
                db: db
            )
            try TrackStorageManager.shared.replaceTrackAlbums(
                track: match,
                albums: track.albums,
                db: db
            )
        }
        try TrackStorageManager.shared.markSavedToLibrary(track, db: db)
    }

    private func insertNewTrackJoin(
        _ track: Track,
        newKey: String,
        into tracklist: StoredTracklist,
        db: Database
    ) throws {
        try TrackStorageManager.shared.upsertTrack(track, db: db)
        try TrackStorageManager.shared.markSavedToLibrary(track, db: db)
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

    private func pruneStaleJoins(
        existingTracks: [StoredTrack],
        newTracks: [Track],
        from tracklist: StoredTracklist,
        db: Database
    ) throws {
        let staleTracks = existingTracks.filter { existing in
            !newTracks.contains(where: { existing.identityMatches($0) })
        }
        guard !staleTracks.isEmpty else { return }

        for (mediaSourceId, group) in Dictionary(grouping: staleTracks, by: \.mediaSourceId) {
            try StoredTracklistTrack.where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
                    .and($0.trackMediaId.in(group.map(\.mediaId)))
                    .and($0.trackMediaSourceId.eq(mediaSourceId))
            }.delete().execute(db)
        }

        try TrackStorageManager.shared.deleteTrackStubsIfOrphaned(
            staleTracks.map { $0.toTrack() },
            db: db
        )
    }

    // MARK: - Orphan Cleanup

    func deleteAlbumStubsIfOrphaned(_ tracklists: [Tracklist], db: Database? = nil) throws {
        guard !tracklists.isEmpty else { return }
        try self.withWriteDB(db) { db in
            let candidates = try self.fetchUnreferencedAlbumStubs(tracklists, db: db)
            guard !candidates.isEmpty else { return }
            try self.deleteOrphanedAlbumStubs(candidates, db: db)
        }
    }

    private func fetchUnreferencedAlbumStubs(
        _ tracklists: [Tracklist],
        db: Database
    ) throws -> [StoredTracklist] {
        let mediaIds = Array(Set(tracklists.map(\.mediaId)))
        let referencedKeys =
            try StoredTrackAlbum
                .where { $0.tracklistMediaId.in(mediaIds) }
                .fetchAll(db)
                .reduce(into: Set<String>()) {
                    $0.insert(Self.key($1.tracklistMediaId, $1.tracklistMediaSourceId))
                }
        let unreferenced = tracklists.filter {
            !referencedKeys.contains(Self.key($0.mediaId, $0.mediaSourceId))
        }
        guard !unreferenced.isEmpty else { return [] }

        let unreferencedKeys = Set(unreferenced.map { Self.key($0.mediaId, $0.mediaSourceId) })
        return try StoredTracklist
            .where { $0.mediaId.in(unreferenced.map(\.mediaId)) }
            .fetchAll(db)
            .filter { unreferencedKeys.contains(Self.key($0.mediaId, $0.mediaSourceId)) }
    }

    private func deleteOrphanedAlbumStubs(_ candidates: [StoredTracklist], db: Database) throws {
        let toDelete = candidates.filter { !$0.isSavedToLibrary && !$0.isRecent }
        guard !toDelete.isEmpty else { return }
        for (mediaSourceId, group) in Dictionary(grouping: toDelete, by: \.mediaSourceId) {
            let mediaIds = group.map(\.mediaId)
            try StoredTracklist
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(mediaIds)) }
                .delete()
                .execute(db)
        }
        for tracklist in toDelete {
            logger.info("Deleted orphaned album stub '\(tracklist.mediaId)'")
        }
    }

    private static func key(_ mediaId: String, _ mediaSourceId: String) -> String {
        "\(mediaId)|\(mediaSourceId)"
    }

    // MARK: - Composed Artwork

    private static let composedArtworkTargetCount = 4
    private static let composedArtworkInitialBatchSize = 8
    private static let composedArtworkMaxBatchSize = 64

    func resolveComposedArtwork(
        mediaId: String,
        mediaSourceId: String,
        db: Database? = nil
    ) -> [TrackArtworkURLs] {
        var collected: [TrackArtworkURLs] = []
        var seenKeys = Set<String>()
        var offset = 0
        var batchSize = Self.composedArtworkInitialBatchSize

        while collected.count < Self.composedArtworkTargetCount {
            let batch: [StoredTrack] = (try? self.withReadDB(db) { db in
                try StoredTracklistTrack
                    .where {
                        $0.tracklistMediaId.eq(mediaId)
                            .and($0.tracklistMediaSourceId.eq(mediaSourceId))
                    }
                    .join(StoredTrack.all) { tt, t in
                        tt.trackMediaId.eq(t.mediaId).and(tt.trackMediaSourceId.eq(t.mediaSourceId))
                    }
                    .order { tt, _ in tt.sortOrder }
                    .select { _, t in t }
                    .limit(batchSize, offset: offset)
                    .fetchAll(db)
            }) ?? []

            guard !batch.isEmpty else { break }

            for track in batch {
                guard let key = track.highResArtworkUrl ?? track.lowResArtworkUrl,
                      !key.isEmpty
                else {
                    continue
                }
                guard seenKeys.insert(key).inserted else { continue }
                collected.append(
                    TrackArtworkURLs(
                        lowResUrl: track.lowResArtworkUrl,
                        highResUrl: track.highResArtworkUrl
                    )
                )
                if collected.count >= Self.composedArtworkTargetCount { break }
            }

            offset += batch.count
            if batch.count < batchSize { break }
            batchSize = min(batchSize * 2, Self.composedArtworkMaxBatchSize)
        }

        return collected
    }

    // MARK: - Tracklist Stubs

    func upsertTracklistStubs(_ tracklists: [Tracklist], db: Database? = nil) throws {
        let tracklists = tracklists.filter(\.tracklistType.isPersistable)
        guard !tracklists.isEmpty else { return }
        try self.withWriteDB(db) { db in
            let mediaIds = Array(Set(tracklists.map(\.mediaId)))
            let existingKeys = try Set(
                StoredTracklist
                    .where { $0.mediaId.in(mediaIds) }
                    .fetchAll(db)
                    .map { Self.key($0.mediaId, $0.mediaSourceId) }
            )

            var toInsert: [Tracklist] = []
            var seenNewKeys = Set<String>()
            for tracklist in tracklists {
                let key = Self.key(tracklist.mediaId, tracklist.mediaSourceId)
                if existingKeys.contains(key) {
                    try StoredTracklist.update {
                        if !tracklist.title.isEmpty { $0.title = tracklist.title }
                        if tracklist.subtitle != nil { $0.subtitle = tracklist.subtitle }
                        if tracklist
                            .lowResArtworkUrl != nil
                        {
                            $0.lowResArtworkUrl = tracklist.lowResArtworkUrl
                        }
                        if tracklist
                            .highResArtworkUrl != nil
                        {
                            $0.highResArtworkUrl = tracklist.highResArtworkUrl
                        }
                        if tracklist.url != nil { $0.url = tracklist.url }
                    }
                    .where {
                        $0.mediaId.eq(tracklist.mediaId)
                            .and($0.mediaSourceId.eq(tracklist.mediaSourceId))
                    }
                    .execute(db)
                } else if seenNewKeys.insert(key).inserted {
                    toInsert.append(tracklist)
                }
            }

            try self.insertTracklistStubs(toInsert, db: db)
        }
    }

    private func insertTracklistStubs(_ tracklists: [Tracklist], db: Database) throws {
        guard !tracklists.isEmpty else { return }
        for (typeString, group) in Dictionary(
            grouping: tracklists,
            by: { $0.tracklistType.rawValue }
        ) {
            let maxKey = try StoredTracklist
                .where { $0.tracklistType.eq(typeString) }
                .order { $0.sortOrder.desc() }
                .fetchOne(db)?
                .sortOrder
            let newKeys = FractionalIndex.generateNKeysBetween(maxKey, nil, n: group.count)
            try StoredTracklist.insert {
                zip(group, newKeys).map { tracklist, sortOrder in
                    StoredTracklist.Draft(
                        mediaId: tracklist.mediaId,
                        mediaSourceId: tracklist.mediaSourceId,
                        title: tracklist.title,
                        subtitle: tracklist.subtitle,
                        lowResArtworkUrl: tracklist.lowResArtworkUrl,
                        highResArtworkUrl: tracklist.highResArtworkUrl,
                        url: tracklist.url,
                        tracklistType: typeString,
                        isPinned: false,
                        isSavedToLibrary: false,
                        sortOrder: sortOrder
                    )
                }
            }.execute(db)
        }
    }
}
