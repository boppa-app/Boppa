import Foundation
import SQLiteData

extension DatabaseWriter where Self == DatabasePool {
    static func appDatabase() throws -> Self {
        let fileManager = FileManager.default
        let folder = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Boppa", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("app.db")

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let database = try DatabasePool(path: url.path, configuration: configuration)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try #sql(
                """
                CREATE TABLE "mediaSources" (
                  "id" TEXT NOT NULL PRIMARY KEY,
                  "name" TEXT NOT NULL,
                  "url" TEXT NOT NULL,
                  "configData" BLOB NOT NULL,
                  "sortOrder" TEXT NOT NULL DEFAULT 'a0',
                  "isEnabled" INTEGER NOT NULL DEFAULT 1,
                  "contextValuesJSON" TEXT NOT NULL DEFAULT '{}'
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "artists" (
                  "mediaId" TEXT NOT NULL,
                  "mediaSourceId" TEXT NOT NULL,
                  "name" TEXT NOT NULL,
                  "artworkUrl" TEXT,
                  PRIMARY KEY ("mediaId", "mediaSourceId")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "tracklists" (
                  "mediaId" TEXT NOT NULL,
                  "mediaSourceId" TEXT NOT NULL,
                  "title" TEXT NOT NULL,
                  "subtitle" TEXT,
                  "artworkUrl" TEXT,
                  "tracklistType" TEXT NOT NULL CHECK (tracklistType IN ('album', 'playlist', 'likes')),
                  "isPinned" INTEGER NOT NULL DEFAULT 0,
                  "isSavedToLibrary" INTEGER NOT NULL DEFAULT 0,
                  "sortOrder" TEXT NOT NULL DEFAULT 'a0',
                  PRIMARY KEY ("mediaId", "mediaSourceId")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "tracks" (
                  "mediaId" TEXT NOT NULL,
                  "mediaSourceId" TEXT NOT NULL,
                  "title" TEXT NOT NULL,
                  "subtitle" TEXT,
                  "duration" INTEGER,
                  "artworkUrl" TEXT,
                  "url" TEXT,
                  PRIMARY KEY ("mediaId", "mediaSourceId")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "tracklistTracks" (
                  "tracklistMediaId" TEXT NOT NULL,
                  "tracklistMediaSourceId" TEXT NOT NULL,
                  "trackMediaId" TEXT NOT NULL,
                  "trackMediaSourceId" TEXT NOT NULL,
                  "sortOrder" TEXT NOT NULL DEFAULT 'a0',
                  PRIMARY KEY ("tracklistMediaId", "tracklistMediaSourceId", "trackMediaId", "trackMediaSourceId"),
                  FOREIGN KEY ("tracklistMediaId", "tracklistMediaSourceId") REFERENCES "tracklists"("mediaId", "mediaSourceId") ON DELETE CASCADE,
                  FOREIGN KEY ("trackMediaId", "trackMediaSourceId") REFERENCES "tracks"("mediaId", "mediaSourceId")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "trackArtists" (
                  "trackMediaId" TEXT NOT NULL,
                  "trackMediaSourceId" TEXT NOT NULL,
                  "artistMediaId" TEXT NOT NULL,
                  "artistMediaSourceId" TEXT NOT NULL,
                  "sortOrder" TEXT NOT NULL DEFAULT 'a0',
                  PRIMARY KEY ("trackMediaId", "trackMediaSourceId", "artistMediaId", "artistMediaSourceId"),
                  FOREIGN KEY ("trackMediaId", "trackMediaSourceId") REFERENCES "tracks"("mediaId", "mediaSourceId") ON DELETE CASCADE,
                  FOREIGN KEY ("artistMediaId", "artistMediaSourceId") REFERENCES "artists"("mediaId", "mediaSourceId")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "trackAlbums" (
                  "trackMediaId" TEXT NOT NULL,
                  "trackMediaSourceId" TEXT NOT NULL,
                  "tracklistMediaId" TEXT NOT NULL,
                  "tracklistMediaSourceId" TEXT NOT NULL,
                  "sortOrder" TEXT NOT NULL DEFAULT 'a0',
                  PRIMARY KEY ("trackMediaId", "trackMediaSourceId", "tracklistMediaId", "tracklistMediaSourceId"),
                  FOREIGN KEY ("trackMediaId", "trackMediaSourceId") REFERENCES "tracks"("mediaId", "mediaSourceId") ON DELETE CASCADE,
                  FOREIGN KEY ("tracklistMediaId", "tracklistMediaSourceId") REFERENCES "tracklists"("mediaId", "mediaSourceId") ON DELETE CASCADE
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "cachedSearchQueries" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "query" TEXT NOT NULL,
                  "timestamp" REAL NOT NULL
                ) STRICT
                """
            ).execute(db)

            try #sql("CREATE INDEX idx_tracklists_type_saved ON tracklists (tracklistType, isSavedToLibrary)").execute(db)
            try #sql("CREATE INDEX idx_tracklists_isPinned ON tracklists (isPinned)").execute(db)
            try #sql("CREATE INDEX idx_tracklistTracks_tracklist ON tracklistTracks (tracklistMediaId, tracklistMediaSourceId)").execute(db)
            try #sql("CREATE INDEX idx_tracklistTracks_track ON tracklistTracks (trackMediaId, trackMediaSourceId)").execute(db)
            try #sql("CREATE INDEX idx_trackArtists_artist ON trackArtists (artistMediaId, artistMediaSourceId)").execute(db)
            try #sql("CREATE INDEX idx_trackAlbums_tracklist ON trackAlbums (tracklistMediaId, tracklistMediaSourceId)").execute(db)
        }
        try migrator.migrate(database)
        return database
    }
}
