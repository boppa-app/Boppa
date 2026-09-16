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

    func findStoredTracklists(
        _ tracklists: [Tracklist],
        db: Database? = nil
    ) -> [String: StoredTracklist] {
        guard !tracklists.isEmpty else { return [:] }
        return (try? self.withReadDB(db) { db in
            let mediaIds = Array(Set(tracklists.map(\.mediaId)))
            let rows = try StoredTracklist.where { $0.mediaId.in(mediaIds) }.fetchAll(db)
            return Dictionary(
                rows.map { (Self.key($0.mediaId, $0.mediaSourceId), $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }) ?? [:]
    }

    /// Called directly via UI with only one tracklist at a time for now so keep single
    /// StoredTracklist param instead of array
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
                tracks.map { ("\($0.mediaId)|\($0.mediaSourceId)", $0) },
                uniquingKeysWith: { first, _ in first }
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

    /// Called directly via UI with only one tracklist at a time for now so keep single Tracklist
    /// param instead of array
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
            return try self.updateExistingLibraryTracklist(existing, with: tracklist, db: db)
        }
        let inserted = try self.insertTracklistStubs([tracklist], isSavedToLibrary: true, db: db)
        return inserted[0]
    }

    private func updateExistingLibraryTracklist(
        _ existing: StoredTracklist,
        with tracklist: Tracklist,
        db: Database
    ) throws -> StoredTracklist {
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

    private func persistTracks(
        _ tracks: [Track],
        into tracklist: StoredTracklist,
        db: Database,
        pruneStale: Bool
    ) throws {
        let existingTracks = pruneStale
            ? TrackStorageManager.shared.fetchStoredTracksForTracklist(tracklist, db: db)
            : []

        try TrackStorageManager.shared.upsertTracks(tracks, db: db)

        let newKeys = FractionalIndex.generateNKeysBetween(nil, nil, n: tracks.count)
        try self.upsertTrackJoins(tracks, newKeys: newKeys, into: tracklist, db: db)

        try TrackStorageManager.shared.markSavedToLibrary(tracks, db: db)

        if pruneStale {
            try self.pruneStaleJoins(
                existingTracks: existingTracks,
                newTracks: tracks,
                from: tracklist,
                db: db
            )
        }
    }

    private func upsertTrackJoins(
        _ tracks: [Track],
        newKeys: [String],
        into tracklist: StoredTracklist,
        db: Database
    ) throws {
        guard !tracks.isEmpty else { return }
        try StoredTracklistTrack.insert {
            zip(tracks, newKeys).map { track, key in
                StoredTracklistTrack.Draft(
                    tracklistMediaId: tracklist.mediaId,
                    tracklistMediaSourceId: tracklist.mediaSourceId,
                    trackMediaId: track.mediaId,
                    trackMediaSourceId: track.mediaSourceId,
                    sortOrder: key
                )
            }
        } onConflictDoUpdate: { $0.sortOrder = $1.sortOrder }
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

    /// Called directly via UI with only one tracklist at a time for now so keep single
    /// StoredTracklist param instead of array
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

    /// Called directly via UI with only one tracklist at a time for now so keep single
    /// StoredTracklist param instead of array
    func moveTracklist(
        _ tracklist: StoredTracklist,
        after previousTracklist: StoredTracklist?,
        before nextTracklist: StoredTracklist?,
        db: Database? = nil
    ) throws {
        try self.withWriteDB(db) { db in
            let keys = try self.sortOrderKeys(for: [previousTracklist, nextTracklist], db: db)
            let newKey = FractionalIndex.generateKeyBetween(keys[0], keys[1])

            try StoredTracklist.update { $0.sortOrder = newKey }
                .where {
                    $0.mediaId.eq(tracklist.mediaId)
                        .and($0.mediaSourceId.eq(tracklist.mediaSourceId))
                }
                .execute(db)
        }
    }

    private func sortOrderKeys(
        for storedTracklists: [StoredTracklist?],
        db: Database
    ) throws -> [String?] {
        let mediaIds = storedTracklists.compactMap { $0?.mediaId }
        guard !mediaIds.isEmpty else { return storedTracklists.map { _ in nil } }

        let sortOrderByKey = try Dictionary(
            StoredTracklist
                .where { $0.mediaId.in(mediaIds) }
                .fetchAll(db)
                .map { (Self.key($0.mediaId, $0.mediaSourceId), $0.sortOrder) },
            uniquingKeysWith: { first, _ in first }
        )

        return storedTracklists.map { stored in
            guard let stored else { return nil }
            return sortOrderByKey[Self.key(stored.mediaId, stored.mediaSourceId)]
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

    /// Called directly via UI with only one tracklist at a time for now so keep single
    /// StoredTracklist param instead of array
    func deleteStoredTracklist(_ storedTracklist: StoredTracklist, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            let tracks = TrackStorageManager.shared
                .fetchStoredTracksForTracklist(storedTracklist, db: db)
                .map { $0.toTrack() }

            try StoredTracklistTrack
                .where {
                    $0.tracklistMediaId.eq(storedTracklist.mediaId)
                        .and($0.tracklistMediaSourceId.eq(storedTracklist.mediaSourceId))
                }
                .delete()
                .execute(db)
            try StoredTracklist.update { $0.isSavedToLibrary = false }
                .where {
                    $0.mediaId.eq(storedTracklist.mediaId)
                        .and($0.mediaSourceId.eq(storedTracklist.mediaSourceId))
                }
                .execute(db)

            try self.deleteAlbumStubsIfOrphaned(
                [Tracklist(storedTracklist: storedTracklist)],
                db: db
            )
            try TrackStorageManager.shared.deleteTrackStubsIfOrphaned(tracks, db: db)
        }
        logger.info("Deleted stored tracklist '\(storedTracklist.title)'")
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

    // MARK: - Tracklist Stubs

    func upsertTracklistStubs(_ tracklists: [Tracklist], db: Database? = nil) throws {
        let tracklists = tracklists.filter(\.tracklistType.isPersistable)
        guard !tracklists.isEmpty else { return }
        try self.withWriteDB(db) { db in
            let existingByKey = self.findStoredTracklists(tracklists, db: db)

            var toInsert: [Tracklist] = []
            var seenNewKeys = Set<String>()
            for tracklist in tracklists {
                let key = Self.key(tracklist.mediaId, tracklist.mediaSourceId)
                if existingByKey[key] != nil {
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

    @discardableResult
    private func insertTracklistStubs(
        _ tracklists: [Tracklist],
        isSavedToLibrary: Bool = false,
        db: Database
    ) throws -> [StoredTracklist] {
        guard !tracklists.isEmpty else { return [] }
        if let invalid = tracklists.first(where: { !$0.tracklistType.isPersistable }) {
            throw NSError(
                domain: "TracklistStorageManager", code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Cannot save a '\(invalid.tracklistType.rawValue)' tracklist to the library",
                ]
            )
        }
        var inserted: [StoredTracklist] = []
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
            let rows = zip(group, newKeys).map { tracklist, sortOrder in
                StoredTracklist(
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
                    isSavedToLibrary: isSavedToLibrary,
                    sortOrder: sortOrder
                )
            }

            try StoredTracklist.insert {
                rows.map { StoredTracklist.Draft($0) }
            }.execute(db)

            inserted.append(contentsOf: rows)
        }
        return inserted
    }
}
