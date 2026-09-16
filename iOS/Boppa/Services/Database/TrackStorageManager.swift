import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "TrackStorageManager"
)

class TrackStorageManager {
    static let shared = TrackStorageManager()

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

    func fetchLibraryTracks(db: Database? = nil) -> [StoredTrack] {
        (try? self.withReadDB(db) { db in
            try StoredTrack.where(\.isSavedToLibrary).fetchAll(db)
        }) ?? []
    }

    func fetchStoredTracksForTracklist(
        _ tracklist: StoredTracklist,
        db: Database? = nil
    ) -> [StoredTrack] {
        let isLikes = tracklist.tracklistType == Tracklist.TracklistType.likes.rawValue
        return (try? self.withReadDB(db) { db in
            try self.fetchStoredTracks(for: tracklist, isLikes: isLikes, db: db)
        }) ?? []
    }

    private func fetchStoredTracks(
        for tracklist: StoredTracklist,
        isLikes: Bool,
        db: Database
    ) throws -> [StoredTrack] {
        let query = StoredTracklistTrack
            .where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
            }
            .join(StoredTrack.all) { tt, t in
                tt.trackMediaId.eq(t.mediaId).and(tt.trackMediaSourceId.eq(t.mediaSourceId))
            }
        if isLikes {
            return try query.order { tt, _ in tt.sortOrder.desc() }.select { _, t in t }
                .fetchAll(db)
        } else {
            return try query.order { tt, _ in tt.sortOrder }.select { _, t in t }
                .fetchAll(db)
        }
    }

    // MARK: - Writes

    func upsertTracks(_ tracks: [Track], db: Database? = nil) throws {
        guard !tracks.isEmpty else { return }
        try self.withWriteDB(db) { db in
            let existingByKey = try self.fetchExistingTracksByKey(tracks, db: db)
            let newTracks = try self.syncExistingTracks(
                tracks,
                existingByKey: existingByKey,
                db: db
            )
            try self.insertNewTracks(newTracks, db: db)
        }
    }

    private func fetchExistingTracksByKey(
        _ tracks: [Track],
        db: Database
    ) throws -> [String: StoredTrack] {
        let mediaIds = Array(Set(tracks.map(\.mediaId)))
        let existingRows = try StoredTrack.where { $0.mediaId.in(mediaIds) }.fetchAll(db)
        return Dictionary(
            existingRows.map { (Self.key($0.mediaId, $0.mediaSourceId), $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func syncExistingTracks(
        _ tracks: [Track],
        existingByKey: [String: StoredTrack],
        db: Database
    ) throws -> [Track] {
        var toInsert: [Track] = []
        var seenNewKeys = Set<String>()
        for track in tracks {
            let key = Self.key(track.mediaId, track.mediaSourceId)
            if let stored = existingByKey[key] {
                try self.updateTrackScalars(track, stored: stored, db: db)
                try self.replaceTrackArtists(track: stored, artists: track.artists, db: db)
                try self.replaceTrackAlbums(track: stored, albums: track.albums, db: db)
            } else if seenNewKeys.insert(key).inserted {
                toInsert.append(track)
            }
        }
        return toInsert
    }

    private func insertNewTracks(_ tracks: [Track], db: Database) throws {
        guard !tracks.isEmpty else { return }
        try StoredTrack.insert {
            tracks.map { track in
                StoredTrack.Draft(
                    mediaId: track.mediaId,
                    mediaSourceId: track.mediaSourceId,
                    title: track.title,
                    subtitle: track.subtitle,
                    duration: track.duration,
                    lowResArtworkUrl: track.lowResArtworkUrl,
                    highResArtworkUrl: track.highResArtworkUrl,
                    url: track.url,
                    type: track.type.rawValue,
                    metadata: track.metadata
                )
            }
        }.execute(db)

        for track in tracks {
            let inserted = StoredTrack(
                mediaId: track.mediaId,
                mediaSourceId: track.mediaSourceId,
                title: track.title,
                subtitle: track.subtitle,
                duration: track.duration,
                lowResArtworkUrl: track.lowResArtworkUrl,
                highResArtworkUrl: track.highResArtworkUrl,
                url: track.url,
                type: track.type.rawValue,
                metadata: track.metadata
            )
            try self.replaceTrackArtists(track: inserted, artists: track.artists, db: db)
            try self.replaceTrackAlbums(track: inserted, albums: track.albums, db: db)
        }
    }

    func markSavedToLibrary(_ tracks: [Track], db: Database? = nil) throws {
        guard !tracks.isEmpty else { return }
        try self.withWriteDB(db) { db in
            for (mediaSourceId, group) in Dictionary(grouping: tracks, by: \.mediaSourceId) {
                try StoredTrack.update { $0.isSavedToLibrary = true }
                    .where {
                        $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(group.map(\.mediaId)))
                    }
                    .execute(db)
            }
        }
    }

    func updateTrackScalars(_ track: Track, stored: StoredTrack, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            try StoredTrack.update {
                $0.title = track.title
                $0.subtitle = track.subtitle
                $0.duration = track.duration
                $0.lowResArtworkUrl = track.lowResArtworkUrl
                $0.highResArtworkUrl = track.highResArtworkUrl
                $0.type = track.type.rawValue
                $0.metadata = track.metadata
            }
            .where { $0.mediaId.eq(stored.mediaId).and($0.mediaSourceId.eq(stored.mediaSourceId)) }
            .execute(db)
        }
    }

    func replaceTrackArtists(
        track: StoredTrack,
        artists: [Artist],
        db: Database? = nil
    ) throws {
        try self.withWriteDB(db) { db in
            let oldArtists =
                try StoredTrackArtist
                    .where {
                        $0.trackMediaId.eq(track.mediaId)
                            .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                    }
                    .join(StoredArtist.all) { ta, a in
                        ta.artistMediaId.eq(a.mediaId)
                            .and(ta.artistMediaSourceId.eq(a.mediaSourceId))
                    }
                    .select { _, a in a }
                    .fetchAll(db)
            try StoredTrackArtist
                .where {
                    $0.trackMediaId.eq(track.mediaId)
                        .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                }
                .delete()
                .execute(db)
            try ArtistStorageManager.shared.upsertArtists(artists, db: db)
            if !artists.isEmpty {
                let keys = FractionalIndex.generateNKeysBetween(nil, nil, n: artists.count)
                try StoredTrackArtist.insert {
                    zip(artists, keys).map { artist, key in
                        StoredTrackArtist.Draft(
                            trackMediaId: track.mediaId,
                            trackMediaSourceId: track.mediaSourceId,
                            artistMediaId: artist.mediaId,
                            artistMediaSourceId: artist.mediaSourceId,
                            sortOrder: key
                        )
                    }
                }.execute(db)
            }
            try ArtistStorageManager.shared.deleteArtistStubsIfOrphaned(
                oldArtists.map { $0.toArtist() },
                db: db
            )
        }
    }

    func replaceTrackAlbums(
        track: StoredTrack,
        albums: [Tracklist],
        db: Database? = nil
    ) throws {
        try self.withWriteDB(db) { db in
            let oldAlbums =
                try StoredTrackAlbum
                    .where {
                        $0.trackMediaId.eq(track.mediaId)
                            .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                    }
                    .join(StoredTracklist.all) { ta, tl in
                        ta.tracklistMediaId.eq(tl.mediaId)
                            .and(ta.tracklistMediaSourceId.eq(tl.mediaSourceId))
                    }
                    .select { _, tl in tl }
                    .fetchAll(db)
            try StoredTrackAlbum
                .where {
                    $0.trackMediaId.eq(track.mediaId)
                        .and($0.trackMediaSourceId.eq(track.mediaSourceId))
                }
                .delete()
                .execute(db)
            try TracklistStorageManager.shared.upsertTracklistStubs(albums, db: db)
            if !albums.isEmpty {
                let keys = FractionalIndex.generateNKeysBetween(nil, nil, n: albums.count)
                try StoredTrackAlbum.insert {
                    zip(albums, keys).map { album, key in
                        StoredTrackAlbum.Draft(
                            trackMediaId: track.mediaId,
                            trackMediaSourceId: track.mediaSourceId,
                            tracklistMediaId: album.mediaId,
                            tracklistMediaSourceId: album.mediaSourceId,
                            sortOrder: key
                        )
                    }
                }.execute(db)
            }
            try TracklistStorageManager.shared.deleteAlbumStubsIfOrphaned(
                oldAlbums.map { Tracklist(storedTracklist: $0) },
                db: db
            )
        }
    }

    // MARK: - Orphan Cleanup

    func deleteTrackStubsIfOrphaned(_ tracks: [Track], db: Database? = nil) throws {
        guard !tracks.isEmpty else { return }
        try self.withWriteDB(db) { db in
            let candidates = try self.fetchUnreferencedTrackStubs(tracks, db: db)
            guard !candidates.isEmpty else { return }

            let recentTracks = candidates.filter(\.isRecent)
            let nonRecentTracks = candidates.filter { !$0.isRecent }

            try self.demoteRecentTrackStubs(recentTracks, db: db)
            try self.deleteNonRecentTrackStubs(nonRecentTracks, db: db)
        }
    }

    private func fetchUnreferencedTrackStubs(
        _ tracks: [Track],
        db: Database
    ) throws -> [StoredTrack] {
        let mediaIds = Array(Set(tracks.map(\.mediaId)))
        let referencedKeys =
            try StoredTracklistTrack
                .where { $0.trackMediaId.in(mediaIds) }
                .fetchAll(db)
                .reduce(into: Set<String>()) {
                    $0.insert(Self.key($1.trackMediaId, $1.trackMediaSourceId))
                }
        let unreferenced = tracks.filter {
            !referencedKeys.contains(Self.key($0.mediaId, $0.mediaSourceId))
        }
        guard !unreferenced.isEmpty else { return [] }

        let unreferencedKeys = Set(unreferenced.map { Self.key($0.mediaId, $0.mediaSourceId) })
        return try StoredTrack
            .where { $0.mediaId.in(unreferenced.map(\.mediaId)) }
            .fetchAll(db)
            .filter { unreferencedKeys.contains(Self.key($0.mediaId, $0.mediaSourceId)) }
    }

    private func demoteRecentTrackStubs(_ tracks: [StoredTrack], db: Database) throws {
        let toDemote = tracks.filter(\.isSavedToLibrary)
        guard !toDemote.isEmpty else { return }
        for (mediaSourceId, group) in Dictionary(grouping: toDemote, by: \.mediaSourceId) {
            let mediaIds = group.map(\.mediaId)
            try StoredTrack.update { $0.isSavedToLibrary = false }
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(mediaIds)) }
                .execute(db)
        }
    }

    private func deleteNonRecentTrackStubs(_ tracks: [StoredTrack], db: Database) throws {
        guard !tracks.isEmpty else { return }
        let domainTracks = tracks.map { $0.toTrack() }
        let orphanArtists = try ArtistStorageManager.shared
            .fetchStoredArtistsForTracks(domainTracks, db: db).map(\.1)
        let orphanAlbums = try TracklistStorageManager.shared
            .fetchStoredAlbumsForTracks(domainTracks, db: db).map(\.1)

        for (mediaSourceId, group) in Dictionary(grouping: tracks, by: \.mediaSourceId) {
            let mediaIds = group.map(\.mediaId)
            try StoredTrack
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(mediaIds)) }
                .delete()
                .execute(db)
        }
        for track in tracks {
            logger.info("Deleted orphaned track '\(track.mediaId)' from '\(track.mediaSourceId)'")
        }

        let uniqueArtists = Dictionary(
            grouping: orphanArtists,
            by: { Self.key($0.mediaId, $0.mediaSourceId) }
        ).values.compactMap(\.first)
        try ArtistStorageManager.shared.deleteArtistStubsIfOrphaned(
            uniqueArtists.map { $0.toArtist() },
            db: db
        )

        let uniqueAlbums = Dictionary(
            grouping: orphanAlbums,
            by: { Self.key($0.mediaId, $0.mediaSourceId) }
        ).values.compactMap(\.first)
        try TracklistStorageManager.shared.deleteAlbumStubsIfOrphaned(
            uniqueAlbums.map { Tracklist(storedTracklist: $0) },
            db: db
        )
    }

    private static func key(_ mediaId: String, _ mediaSourceId: String) -> String {
        "\(mediaId)|\(mediaSourceId)"
    }
}
