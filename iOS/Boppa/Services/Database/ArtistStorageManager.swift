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

    // MARK: - Reads

    func fetchLibraryArtists() -> [StoredArtist] {
        (try? self.database.read { db in
            try StoredArtist.where(\.isSavedToLibrary).fetchAll(db)
        }) ?? []
    }

    func isArtistSaved(mediaId: String, mediaSourceId: String) -> Bool {
        (try? self.database.read { db in
            try StoredArtist
                .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
                .fetchOne(db)?.isSavedToLibrary
        }) ?? false
    }

    // MARK: - Writes

    func saveArtistToLibrary(_ artist: Artist) throws {
        try self.database.write { db in
            try self.upsertArtist(artist, db: db)
            try StoredArtist.update { $0.isSavedToLibrary = true }
                .where {
                    $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId))
                }
                .execute(db)
        }
        logger.info("Saved artist '\(artist.mediaId)' to library")
    }

    func removeArtistFromLibrary(mediaId: String, mediaSourceId: String) throws {
        try self.database.write { db in
            try StoredArtist.update { $0.isSavedToLibrary = false }
                .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
                .execute(db)
            try self.deleteArtistIfOrphaned(mediaId: mediaId, mediaSourceId: mediaSourceId, db: db)
        }
        logger.info("Removed artist '\(mediaId)' from library")
    }

    // MARK: - Recents

    func markArtistRecentlyViewed(_ artist: Artist, viewedAt: Double, db: Database) throws {
        try self.upsertArtist(artist, db: db)
        try StoredArtist.update {
            $0.isRecent = true
            $0.lastViewedTimestamp = #bind(viewedAt)
        }
        .where { $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId)) }
        .execute(db)
    }

    func unmarkArtistRecentlyViewed(mediaId: String, mediaSourceId: String, db: Database) throws {
        try StoredArtist.update { $0.isRecent = false }
            .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
            .execute(db)
        try self.deleteArtistIfOrphaned(mediaId: mediaId, mediaSourceId: mediaSourceId, db: db)
    }

    // MARK: - Track Relation Support

    @discardableResult
    func upsertArtist(_ artist: Artist, db: Database) throws -> String {
        let existing =
            try StoredArtist
                .where {
                    $0.mediaId.eq(artist.mediaId).and($0.mediaSourceId.eq(artist.mediaSourceId))
                }
                .fetchOne(db)
        if let existing {
            try StoredArtist.update {
                if !artist.name.isEmpty { $0.name = artist.name }
                if artist.lowResArtworkUrl != nil { $0.lowResArtworkUrl = artist.lowResArtworkUrl }
                if artist
                    .highResArtworkUrl != nil { $0.highResArtworkUrl = artist.highResArtworkUrl }
                if artist.url != nil { $0.url = artist.url }
            }
            .where {
                $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId))
            }
            .execute(db)
        } else {
            try StoredArtist.insert {
                StoredArtist.Draft(
                    mediaId: artist.mediaId,
                    mediaSourceId: artist.mediaSourceId,
                    name: artist.name,
                    lowResArtworkUrl: artist.lowResArtworkUrl,
                    highResArtworkUrl: artist.highResArtworkUrl,
                    url: artist.url
                )
            }.execute(db)
        }
        return artist.mediaId
    }

    func deleteArtistIfOrphaned(_ ref: StoredTrackArtist, db: Database) throws {
        try self.deleteArtistIfOrphaned(
            mediaId: ref.artistMediaId, mediaSourceId: ref.artistMediaSourceId, db: db
        )
    }

    func deleteArtistIfOrphaned(
        mediaId: String,
        mediaSourceId: String,
        db: Database
    ) throws {
        let inTracks =
            try StoredTrackArtist
                .where { $0.artistMediaId.eq(mediaId).and($0.artistMediaSourceId.eq(mediaSourceId))
                }
                .fetchCount(db)
        guard inTracks == 0 else { return }
        let artist =
            try StoredArtist
                .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
                .fetchOne(db)
        guard let artist, !artist.isRecent, !artist.isSavedToLibrary else { return }
        try StoredArtist
            .where { $0.mediaId.eq(mediaId).and($0.mediaSourceId.eq(mediaSourceId)) }
            .delete()
            .execute(db)
        logger.info("Deleted orphaned artist '\(mediaId)'")
    }
}
