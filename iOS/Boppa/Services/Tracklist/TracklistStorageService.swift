import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Boppa", category: "TracklistStorageService")

class TracklistStorageService {
    static let shared = TracklistStorageService()

    @Dependency(\.defaultDatabase) var database

    private let paginated = PaginatedScriptExecutor.shared

    private init() {}

    // MARK: - Reads

    func resolveMediaSource(mediaSourceId: String) -> MediaSource? {
        try? self.database.read { db in
            try MediaSource.where { $0.id.eq(mediaSourceId) }.fetchOne(db)
        }
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
            storedTracks = try query.order { tt, _ in tt.addedAt.desc() }.select { _, t in t }.fetchAll(db)
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
        let fromArtist: Artist?
        if let artistMediaId = stored.fromArtistMediaId {
            fromArtist = try StoredArtist
                .where { $0.mediaId.eq(artistMediaId).and($0.mediaSourceId.eq(stored.mediaSourceId)) }
                .fetchOne(db)?
                .toArtist()
        } else {
            fromArtist = nil
        }
        return Tracklist(storedTracklist: stored, artists: artists, fromArtist: fromArtist)
    }

    func tracklistWithRelations(from stored: StoredTracklist) -> Tracklist {
        (try? self.database.read { db in try self.tracklist(from: stored, db: db) })
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
        try self.database.write { db in
            try StoredTracklist
                .where { $0.mediaId.eq(storedTracklist.mediaId).and($0.mediaSourceId.eq(storedTracklist.mediaSourceId)) }
                .delete()
                .execute(db)
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
        let fromArtistMediaId = try tracklist.fromArtist.map { try self.upsertArtist($0, db: db) }

        let existing = try StoredTracklist
            .where { $0.mediaId.eq(tracklist.mediaId).and($0.mediaSourceId.eq(tracklist.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
            try StoredTracklist.update {
                $0.title = tracklist.title
                $0.subtitle = tracklist.subtitle
                $0.artworkUrl = tracklist.artworkUrl
                $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: tracklist.metadata)) ?? Data()
                $0.fromArtistMediaId = fromArtistMediaId
            }
            .where { $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId)) }
            .execute(db)
            try self.replaceTracklistArtists(tracklist: existing, artists: tracklist.artists, db: db)
            return try StoredTracklist
                .where { $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId)) }
                .fetchOne(db) ?? existing
        }

        let typeString = tracklist.tracklistType.rawValue
        let tail = try StoredTracklist
            .where { $0.tracklistType.eq(typeString).and($0.nextMediaId.is(nil)) }
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
                fromArtistMediaId: fromArtistMediaId,
                isPinned: false,
                prevMediaId: tail?.mediaId,
                prevMediaSourceId: tail?.mediaSourceId,
                nextMediaId: nil,
                nextMediaSourceId: nil
            )
        }.execute(db)

        let inserted = try StoredTracklist
            .where { $0.mediaId.eq(tracklist.mediaId).and($0.mediaSourceId.eq(tracklist.mediaSourceId)) }
            .fetchOne(db)!

        try self.replaceTracklistArtists(tracklist: inserted, artists: tracklist.artists, db: db)

        if let tail {
            try StoredTracklist.update {
                $0.nextMediaId = #bind(Optional(tracklist.mediaId))
                $0.nextMediaSourceId = #bind(Optional(tracklist.mediaSourceId))
            }
            .where { $0.mediaId.eq(tail.mediaId).and($0.mediaSourceId.eq(tail.mediaSourceId)) }
            .execute(db)
        }

        return inserted
    }

    private func persistTracks(_ tracks: [Track], into tracklist: StoredTracklist, db: Database, pruneStale: Bool) throws {
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
            if let match = existingTracks.first(where: { $0.identityMatches(track) }) {
                if let join = existingJoins.first(where: { $0.trackMediaId == match.mediaId && $0.trackMediaSourceId == match.mediaSourceId }),
                   join.sortOrder != index
                {
                    try StoredTracklistTrack.update { $0.sortOrder = index }
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
                        sortOrder: index,
                        addedAt: Date().timeIntervalSince1970
                    )
                } onConflictDoUpdate: { $0.sortOrder = index }
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

                let usageCount = try StoredTracklistTrack
                    .where { $0.trackMediaId.eq(existing.mediaId).and($0.trackMediaSourceId.eq(existing.mediaSourceId)) }
                    .fetchAll(db)
                    .count
                if usageCount == 0 {
                    try StoredTrack
                        .where { $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId)) }
                        .delete()
                        .execute(db)
                }
            }
        }
    }

    private func buildFetchParams(tracklist: Tracklist, config: MediaSourceConfig) throws -> (script: String, params: [String: Any]) {
        let script: String?
        var itemParams: [String: Any] = ["artworkUrl": tracklist.artworkUrl ?? ""]
        for (key, value) in tracklist.metadata {
            itemParams[key] = value
        }

        switch tracklist.tracklistType {
        case .playlist:
            script = config.data?.getPlaylist
            itemParams["user"] = tracklist.subtitle ?? ""
        case .album:
            script = config.data?.getAlbum
            itemParams["subtitle"] = tracklist.subtitle ?? ""
        default:
            throw NSError(domain: "TracklistStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot save this tracklist type to library"])
        }

        guard let script else {
            throw NSError(domain: "TracklistStorageService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No script available for this tracklist type"])
        }
        return (script, itemParams)
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
                    url: track.url,
                    metadataJSON: (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
                )
            }.execute(db)
            let inserted = StoredTrack(
                mediaId: track.mediaId,
                mediaSourceId: track.mediaSourceId,
                title: track.title,
                subtitle: track.subtitle,
                duration: track.duration,
                artworkUrl: track.artworkUrl,
                url: track.url,
                metadataJSON: (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
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
            $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: track.metadata)) ?? Data()
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
        for (index, artist) in artists.enumerated() {
            try self.upsertArtist(artist, db: db)
            try StoredTrackArtist.insert {
                StoredTrackArtist.Draft(
                    trackMediaId: track.mediaId,
                    trackMediaSourceId: track.mediaSourceId,
                    artistMediaId: artist.mediaId,
                    artistMediaSourceId: artist.mediaSourceId,
                    sortOrder: index
                )
            }.execute(db)
        }
    }

    private func replaceTrackAlbums(track: StoredTrack, albums: [Tracklist], db: Database) throws {
        try StoredTrackAlbum
            .where { $0.trackMediaId.eq(track.mediaId).and($0.trackMediaSourceId.eq(track.mediaSourceId)) }
            .delete()
            .execute(db)
        for (index, album) in albums.enumerated() {
            try self.upsertAlbumTracklist(album, db: db)
            try StoredTrackAlbum.insert {
                StoredTrackAlbum.Draft(
                    trackMediaId: track.mediaId,
                    trackMediaSourceId: track.mediaSourceId,
                    tracklistMediaId: album.mediaId,
                    tracklistMediaSourceId: album.mediaSourceId,
                    sortOrder: index
                )
            }.execute(db)
        }
    }

    private func replaceTracklistArtists(tracklist: StoredTracklist, artists: [Artist], db: Database) throws {
        try StoredTracklistArtist
            .where { $0.tracklistMediaId.eq(tracklist.mediaId).and($0.tracklistMediaSourceId.eq(tracklist.mediaSourceId)) }
            .delete()
            .execute(db)
        for (index, artist) in artists.enumerated() {
            try self.upsertArtist(artist, db: db)
            try StoredTracklistArtist.insert {
                StoredTracklistArtist.Draft(
                    tracklistMediaId: tracklist.mediaId,
                    tracklistMediaSourceId: tracklist.mediaSourceId,
                    artistMediaId: artist.mediaId,
                    artistMediaSourceId: artist.mediaSourceId,
                    sortOrder: index
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
            let mergedMetadata = self.deepMerge(existing.metadata, artist.metadata)
            try StoredArtist.update {
                if !artist.name.isEmpty { $0.name = artist.name }
                if artist.artworkUrl != nil { $0.artworkUrl = artist.artworkUrl }
                $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: mergedMetadata)) ?? Data()
            }
            .where { $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId)) }
            .execute(db)
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
        }
        return artist.mediaId
    }

    private func upsertAlbumTracklist(_ album: Tracklist, db: Database) throws {
        let existing = try StoredTracklist
            .where { $0.mediaId.eq(album.mediaId).and($0.mediaSourceId.eq(album.mediaSourceId)) }
            .fetchOne(db)
        if let existing {
            let mergedMetadata = self.deepMerge(existing.metadata, album.metadata)
            try StoredTracklist.update {
                if !album.title.isEmpty { $0.title = album.title }
                if album.subtitle != nil { $0.subtitle = album.subtitle }
                if album.artworkUrl != nil { $0.artworkUrl = album.artworkUrl }
                $0.metadataJSON = (try? JSONSerialization.data(withJSONObject: mergedMetadata)) ?? Data()
            }
            .where { $0.mediaId.eq(existing.mediaId).and($0.mediaSourceId.eq(existing.mediaSourceId)) }
            .execute(db)
        } else {
            let typeString = Tracklist.TracklistType.album.rawValue
            let tail = try StoredTracklist
                .where { $0.tracklistType.eq(typeString).and($0.nextMediaId.is(nil)) }
                .fetchOne(db)
            try StoredTracklist.insert {
                StoredTracklist.Draft(
                    mediaId: album.mediaId,
                    mediaSourceId: album.mediaSourceId,
                    title: album.title,
                    subtitle: album.subtitle,
                    artworkUrl: album.artworkUrl,
                    tracklistType: typeString,
                    metadataJSON: (try? JSONSerialization.data(withJSONObject: album.metadata)) ?? Data(),
                    fromArtistMediaId: nil,
                    isPinned: false,
                    prevMediaId: tail?.mediaId,
                    prevMediaSourceId: tail?.mediaSourceId,
                    nextMediaId: nil,
                    nextMediaSourceId: nil
                )
            }.execute(db)
            if let tail {
                try StoredTracklist.update {
                    $0.nextMediaId = #bind(Optional(album.mediaId))
                    $0.nextMediaSourceId = #bind(Optional(album.mediaSourceId))
                }
                .where { $0.mediaId.eq(tail.mediaId).and($0.mediaSourceId.eq(tail.mediaSourceId)) }
                .execute(db)
            }
        }
    }

    private func deepMerge(_ base: [String: Any], _ override: [String: Any]) -> [String: Any] {
        var result = base
        for (key, newValue) in override {
            if let existingDict = result[key] as? [String: Any],
               let newDict = newValue as? [String: Any]
            {
                result[key] = self.deepMerge(existingDict, newDict)
            } else {
                result[key] = newValue
            }
        }
        return result
    }
}
