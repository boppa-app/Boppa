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
            let artists = try self.loadArtistsForTrack(stored, db: db)
            let albums = try self.loadAlbumsForTrack(stored, db: db)
            return stored.toTrack(artists: artists, albums: albums)
        }
    }

    func tracklist(from stored: StoredTracklist, db: Database) throws -> Tracklist {
        let artists = try loadArtistsForTracklist(stored, db: db)
        return Tracklist(storedTracklist: stored, artists: artists)
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
                .fetchAll(db)
                .count

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
            let artists = try self.loadArtistsForTrack(stored, db: db)
            let albums = try self.loadAlbumsForTrack(stored, db: db)
            return stored.toTrack(artists: artists, albums: albums)
        }) ?? stored.toTrack()
    }

    // MARK: - Private: Reads

    private func loadArtistsForTrack(_ track: StoredTrack, db: Database) throws -> [Artist] {
        try StoredTrackArtist
            .where { $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId)) }
            .join(StoredArtist.all) { ta, a in
                ta.artistMediaId.eq(a.mediaId).and(ta.artistMediaSourceId.eq(a.mediaSourceId))
            }
            .order { ta, _ in ta.sortOrder }
            .select { _, a in a }
            .fetchAll(db)
            .map { $0.toArtist() }
    }

    private func loadAlbumsForTrack(_ track: StoredTrack, db: Database) throws -> [Tracklist] {
        try StoredTrackAlbum
            .where { $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId)) }
            .join(StoredTracklist.all) { ta, tl in
                ta.tracklistMediaId.eq(tl.mediaId).and(ta.tracklistMediaSourceId.eq(tl.mediaSourceId))
            }
            .order { ta, _ in ta.sortOrder }
            .select { _, tl in tl }
            .fetchAll(db)
            .map { Tracklist(storedTracklist: $0) }
    }

    private func loadArtistsForTracklist(_ tracklist: StoredTracklist, db: Database) throws -> [Artist] {
        try StoredTracklistArtist
            .where { $0.tracklistMediaId.eq(tracklist.mediaId).and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId)) }
            .join(StoredArtist.all) { ta, a in
                ta.artistMediaId.eq(a.mediaId).and(ta.artistMediaSourceId.eq(a.mediaSourceId))
            }
            .order { ta, _ in ta.sortOrder }
            .select { _, a in a }
            .fetchAll(db)
            .map { $0.toArtist() }
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
            try self.replaceTracklistArtists(tracklist: existing, artists: tracklist.artists, db: db)
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

        let inserted = try StoredTracklist
            .where { $0.mediaId.eq(tracklist.mediaId).and($0.mediaSourceId.eq(tracklist.mediaSourceId)) }
            .fetchOne(db)!

        try self.replaceTracklistArtists(tracklist: inserted, artists: tracklist.artists, db: db)
        return inserted
    }

    private func persistTracks(_ tracks: [Track], into tracklist: StoredTracklist, db: Database, pruneStale: Bool) throws {
        let newKeys = FractionalIndex.generateNKeysBetween(nil, nil, n: tracks.count)

        let existingJoins = try StoredTracklistTrack
            .where {
                $0.tracklistMediaId.eq(tracklist.mediaId)
                    .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
            }
            .order { $0.sortOrder }
            .fetchAll(db)

        let existingTracks: [StoredTrack] = try StoredTracklistTrack
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

        for (index, track) in tracks.enumerated() {
            let newKey = newKeys[index]
            if let match = existingTracks.first(where: { $0.identityMatches(track) }) {
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
                let existingArtists = try loadArtistsForTrack(match, db: db)
                let existingAlbums = try loadAlbumsForTrack(match, db: db)
                if !match.contentMatches(track, artists: existingArtists, albums: existingAlbums) {
                    try self.updateTrackScalars(track, stored: match, db: db)
                    try self.replaceTrackArtists(track: match, artists: track.artists, db: db)
                    try self.replaceTrackAlbums(track: match, albums: track.albums, db: db)
                }
            } else {
                try self.upsertTrack(track, db: db)
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
        }

        if pruneStale {
            for existing in existingTracks where !tracks.contains(where: { existing.identityMatches($0) }) {
                try StoredTracklistTrack.where {
                    $0.tracklistMediaId.eq(tracklist.mediaId)
                        .and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId))
                        .and($0.trackMediaId.eq(existing.mediaId))
                        .and($0.trackMediaSourceId.eq(existing.mediaSourceId))
                }.delete().execute(db)

                try TrackStorageManager.shared.deleteIfOrphaned(mediaId: existing.mediaId, mediaSourceId: existing.mediaSourceId, db: db)
            }
        }
    }

    func upsertTrack(_ track: Track, db: Database) throws {
        let existing = try StoredTrack
            .where { $0.mediaId.eq(track.mediaId).and($0.mediaSourceId.eq(track.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
            let existingArtists = try loadArtistsForTrack(existing, db: db)
            let existingAlbums = try loadAlbumsForTrack(existing, db: db)
            if !existing.contentMatches(track, artists: existingArtists, albums: existingAlbums) {
                try self.updateTrackScalars(track, stored: existing, db: db)
                try self.replaceTrackArtists(track: existing, artists: track.artists, db: db)
                try self.replaceTrackAlbums(track: existing, albums: track.albums, db: db)
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
                    url: track.url
                )
            }.execute(db)
            let inserted = StoredTrack(
                mediaId: track.mediaId,
                mediaSourceId: track.mediaSourceId,
                title: track.title,
                subtitle: track.subtitle,
                duration: track.duration,
                artworkUrl: track.artworkUrl,
                url: track.url
            )
            try self.replaceTrackArtists(track: inserted, artists: track.artists, db: db)
            try self.replaceTrackAlbums(track: inserted, albums: track.albums, db: db)
        }
    }

    private func updateTrackScalars(_ track: Track, stored: StoredTrack, db: Database) throws {
        try StoredTrack.update {
            $0.title = track.title
            $0.subtitle = track.subtitle
            $0.duration = track.duration
            $0.artworkUrl = track.artworkUrl
        }
        .where { $0.mediaId.eq(stored.mediaId).and($0.mediaSourceId.eq(stored.mediaSourceId)) }
        .execute(db)
    }

    // MARK: - Private: Relationship Writes

    private func replaceTrackArtists(track: StoredTrack, artists: [Artist], db: Database) throws {
        try StoredTrackArtist
            .where { $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId)) }
            .delete()
            .execute(db)
        let keys = FractionalIndex.generateNKeysBetween(nil, nil, n: artists.count)
        for (artist, key) in zip(artists, keys) {
            try self.upsertArtist(artist, db: db)
            try StoredTrackArtist.insert {
                StoredTrackArtist.Draft(
                    trackMediaId: track.mediaId,
                    trackMediaSourceId: track.mediaSourceId,
                    artistMediaId: artist.mediaId,
                    artistMediaSourceId: artist.mediaSourceId,
                    sortOrder: key
                )
            }.execute(db)
        }
    }

    private func replaceTrackAlbums(track: StoredTrack, albums: [Tracklist], db: Database) throws {
        try StoredTrackAlbum
            .where { $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId)) }
            .delete()
            .execute(db)
        let keys = FractionalIndex.generateNKeysBetween(nil, nil, n: albums.count)
        for (album, key) in zip(albums, keys) {
            try self.upsertAlbumTracklist(album, db: db)
            try StoredTrackAlbum.insert {
                StoredTrackAlbum.Draft(
                    trackMediaId: track.mediaId,
                    trackMediaSourceId: track.mediaSourceId,
                    tracklistMediaId: album.mediaId,
                    tracklistMediaSourceId: album.mediaSourceId,
                    sortOrder: key
                )
            }.execute(db)
        }
    }

    private func replaceTracklistArtists(tracklist: StoredTracklist, artists: [Artist], db: Database) throws {
        try StoredTracklistArtist
            .where { $0.tracklistMediaId.eq(tracklist.mediaId).and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId)) }
            .delete()
            .execute(db)
        let keys = FractionalIndex.generateNKeysBetween(nil, nil, n: artists.count)
        for (artist, key) in zip(artists, keys) {
            try self.upsertArtist(artist, db: db)
            try StoredTracklistArtist.insert {
                StoredTracklistArtist.Draft(
                    tracklistMediaId: tracklist.mediaId,
                    tracklistMediaSourceId: tracklist.mediaSourceId,
                    artistMediaId: artist.mediaId,
                    artistMediaSourceId: artist.mediaSourceId,
                    sortOrder: key
                )
            }.execute(db)
        }
    }

    @discardableResult
    private func upsertArtist(_ artist: Artist, db: Database) throws -> String {
        let existing = try StoredArtist
            .where { $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
            try StoredArtist.update {
                if !artist.name.isEmpty { $0.name = artist.name }
                if artist.artworkUrl != nil { $0.artworkUrl = artist.artworkUrl }
            }
            .where { $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId)) }
            .execute(db)
        } else {
            try StoredArtist.insert {
                StoredArtist.Draft(
                    mediaId: artist.mediaId,
                    mediaSourceId: artist.mediaSourceId,
                    name: artist.name,
                    artworkUrl: artist.artworkUrl
                )
            }.execute(db)
        }
        return artist.mediaId
    }

    private func upsertAlbumTracklist(_ album: Tracklist, db: Database) throws {
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
