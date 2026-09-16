import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "ArtistStorageManager"
)

class ArtistStorageManager {
    static let shared = ArtistStorageManager()

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

    func fetchLibraryArtists(db: Database? = nil) -> [StoredArtist] {
        (try? self.withReadDB(db) { db in
            try StoredArtist.where(\.isSavedToLibrary).fetchAll(db)
        }) ?? []
    }

    func isArtistSavedToLibrary(_ artist: Artist, db: Database? = nil) -> Bool {
        (try? self.withReadDB(db) { db in
            try StoredArtist
                .where {
                    $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId))
                }
                .fetchOne(db)?.isSavedToLibrary
        }) ?? false
    }

    func fetchStoredArtistsForTracks(
        _ tracks: [Track],
        db: Database? = nil
    ) throws -> [(Track, StoredArtist)] {
        guard !tracks.isEmpty else { return [] }
        return try self.withReadDB(db) { db in
            let tracksByKey = Dictionary(
                tracks.map { ("\($0.mediaId)|\($0.mediaSourceId)", $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let rows = try StoredTrackArtist
                .where { $0.trackMediaId.in(tracks.map(\.mediaId)) }
                .join(StoredArtist.all) { ta, a in
                    ta.artistMediaId.eq(a.mediaId).and(ta.artistMediaSourceId.eq(a.mediaSourceId))
                }
                .order { ta, _ in ta.sortOrder }
                .fetchAll(db)
            return rows.compactMap { trackArtist, artist in
                guard let track = tracksByKey[
                    "\(trackArtist.trackMediaId)|\(trackArtist.trackMediaSourceId)"
                ] else { return nil }
                return (track, artist)
            }
        }
    }

    // MARK: - Writes

    func saveArtistToLibrary(_ artist: Artist, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            try self.upsertArtists([artist], db: db)
            try StoredArtist.update { $0.isSavedToLibrary = true }
                .where {
                    $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId))
                }
                .execute(db)
        }
        logger.info("Saved artist '\(artist.mediaId)' to library")
    }

    func removeArtistFromLibrary(_ artist: Artist, db: Database? = nil) throws {
        try self.withWriteDB(db) { db in
            try StoredArtist.update { $0.isSavedToLibrary = false }
                .where {
                    $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId))
                }
                .execute(db)
            try self.deleteArtistStubsIfOrphaned([artist], db: db)
        }
        logger.info("Removed artist '\(artist.mediaId)' from library")
    }

    func upsertArtists(_ artists: [Artist], db: Database? = nil) throws {
        guard !artists.isEmpty else { return }
        try self.withWriteDB(db) { db in
            let mediaIds = Array(Set(artists.map(\.mediaId)))
            let existingKeys = try Set(
                StoredArtist
                    .where { $0.mediaId.in(mediaIds) }
                    .fetchAll(db)
                    .map(\.id)
            )

            var toInsert: [Artist] = []
            var seenNewKeys = Set<String>()
            for artist in artists {
                let key = artist.artistKey
                if existingKeys.contains(key) {
                    try StoredArtist.update {
                        if !artist.name.isEmpty { $0.name = artist.name }
                        if artist
                            .lowResArtworkUrl !=
                            nil { $0.lowResArtworkUrl = artist.lowResArtworkUrl }
                        if artist
                            .highResArtworkUrl != nil
                        {
                            $0.highResArtworkUrl = artist.highResArtworkUrl
                        }
                        if artist.url != nil { $0.url = artist.url }
                    }
                    .where {
                        $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId))
                    }
                    .execute(db)
                } else if seenNewKeys.insert(key).inserted {
                    toInsert.append(artist)
                }
            }

            guard !toInsert.isEmpty else { return }
            try StoredArtist.insert {
                toInsert.map { artist in
                    StoredArtist.Draft(
                        mediaId: artist.mediaId,
                        mediaSourceId: artist.mediaSourceId,
                        name: artist.name,
                        lowResArtworkUrl: artist.lowResArtworkUrl,
                        highResArtworkUrl: artist.highResArtworkUrl,
                        url: artist.url
                    )
                }
            }.execute(db)
        }
    }

    // MARK: - Orphan Cleanup

    func deleteArtistStubsIfOrphaned(_ artists: [Artist], db: Database? = nil) throws {
        guard !artists.isEmpty else { return }
        try self.withWriteDB(db) { db in
            let candidates = try self.fetchUnreferencedArtistStubs(artists, db: db)
            guard !candidates.isEmpty else { return }
            try self.deleteArtistStubs(candidates, db: db)
        }
    }

    private func fetchUnreferencedArtistStubs(
        _ artists: [Artist],
        db: Database
    ) throws -> [StoredArtist] {
        let mediaIds = Array(Set(artists.map(\.mediaId)))
        let referencedKeys =
            try StoredTrackArtist
                .where { $0.artistMediaId.in(mediaIds) }
                .fetchAll(db)
                .reduce(into: Set<String>()) {
                    $0.insert("\($1.artistMediaId)|\($1.artistMediaSourceId)")
                }
        let unreferenced = artists.filter { !referencedKeys.contains($0.artistKey) }
        guard !unreferenced.isEmpty else { return [] }

        let unreferencedKeys = Set(unreferenced.map(\.artistKey))
        return try StoredArtist
            .where { $0.mediaId.in(unreferenced.map(\.mediaId)) }
            .fetchAll(db)
            .filter { unreferencedKeys.contains($0.id) }
    }

    private func deleteArtistStubs(_ candidates: [StoredArtist], db: Database) throws {
        let toDelete = candidates.filter { !$0.isRecent && !$0.isSavedToLibrary }
        guard !toDelete.isEmpty else { return }
        for (mediaSourceId, group) in Dictionary(grouping: toDelete, by: \.mediaSourceId) {
            let mediaIds = group.map(\.mediaId)
            try StoredArtist
                .where { $0.mediaSourceId.eq(mediaSourceId).and($0.mediaId.in(mediaIds)) }
                .delete()
                .execute(db)
        }
        for artist in toDelete {
            logger.info("Deleted orphaned artist '\(artist.mediaId)'")
        }
    }
}
