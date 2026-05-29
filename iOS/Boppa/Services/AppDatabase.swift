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
                  "sortOrder" INTEGER NOT NULL DEFAULT 0,
                  "isEnabled" INTEGER NOT NULL DEFAULT 1,
                  "contextValuesJSON" TEXT NOT NULL DEFAULT '{}'
                ) STRICT
                """
            ).execute(db)

            // TODO: Delete items from artists DB if no longer referenced anywhere
            try #sql(
                """
                CREATE TABLE "artists" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "mediaId" TEXT NOT NULL,
                  "mediaSourceId" TEXT NOT NULL,
                  "name" TEXT NOT NULL,
                  "artworkUrl" TEXT,
                  "metadataJSON" BLOB NOT NULL DEFAULT X'',
                  UNIQUE ("mediaId", "mediaSourceId")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "tracklists" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "mediaId" TEXT NOT NULL,
                  "mediaSourceId" TEXT NOT NULL,
                  "title" TEXT NOT NULL,
                  "subtitle" TEXT,
                  "artworkUrl" TEXT,
                  "tracklistType" TEXT NOT NULL,
                  "metadataJSON" BLOB NOT NULL DEFAULT X'',
                  "fromArtistId" INTEGER,
                  "isPinned" INTEGER NOT NULL DEFAULT 0,
                  "prevId" INTEGER,
                  "nextId" INTEGER,
                  UNIQUE ("mediaId", "mediaSourceId"),
                  FOREIGN KEY ("fromArtistId") REFERENCES "artists"("id")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "tracks" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "mediaId" TEXT NOT NULL,
                  "mediaSourceId" TEXT NOT NULL,
                  "title" TEXT NOT NULL,
                  "subtitle" TEXT,
                  "duration" INTEGER,
                  "artworkUrl" TEXT,
                  "url" TEXT,
                  "metadataJSON" BLOB NOT NULL DEFAULT X'',
                  UNIQUE ("mediaId", "mediaSourceId")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "tracklistTracks" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "tracklistId" INTEGER NOT NULL,
                  "trackId" INTEGER NOT NULL,
                  "sortOrder" INTEGER NOT NULL DEFAULT 0,
                  UNIQUE ("tracklistId", "trackId"),
                  FOREIGN KEY ("tracklistId") REFERENCES "tracklists"("id") ON DELETE CASCADE,
                  FOREIGN KEY ("trackId") REFERENCES "tracks"("id")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "trackArtists" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "trackId" INTEGER NOT NULL,
                  "artistId" INTEGER NOT NULL,
                  "sortOrder" INTEGER NOT NULL DEFAULT 0,
                  UNIQUE ("trackId", "artistId"),
                  FOREIGN KEY ("trackId") REFERENCES "tracks"("id") ON DELETE CASCADE,
                  FOREIGN KEY ("artistId") REFERENCES "artists"("id")
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "trackAlbums" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "trackId" INTEGER NOT NULL,
                  "tracklistId" INTEGER NOT NULL,
                  "sortOrder" INTEGER NOT NULL DEFAULT 0,
                  UNIQUE ("trackId", "tracklistId"),
                  FOREIGN KEY ("trackId") REFERENCES "tracks"("id") ON DELETE CASCADE,
                  FOREIGN KEY ("tracklistId") REFERENCES "tracklists"("id") ON DELETE CASCADE
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "tracklistArtists" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "tracklistId" INTEGER NOT NULL,
                  "artistId" INTEGER NOT NULL,
                  "sortOrder" INTEGER NOT NULL DEFAULT 0,
                  UNIQUE ("tracklistId", "artistId"),
                  FOREIGN KEY ("tracklistId") REFERENCES "tracklists"("id") ON DELETE CASCADE,
                  FOREIGN KEY ("artistId") REFERENCES "artists"("id")
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
        }
        try migrator.migrate(database)
        return database
    }
}
