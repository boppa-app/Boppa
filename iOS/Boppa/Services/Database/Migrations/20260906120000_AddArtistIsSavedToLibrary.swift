import SQLiteData

extension DatabaseMigrator {
    mutating func register20260906120000_AddArtistIsSavedToLibrary() {
        self.registerMigration("20260906120000_addArtistIsSavedToLibrary") { db in
            try #sql(
                """
                ALTER TABLE "artists" ADD COLUMN "isSavedToLibrary" INTEGER NOT NULL DEFAULT 0
                """
            ).execute(db)
            try #sql(
                "CREATE INDEX idx_artists_isSavedToLibrary ON artists (isSavedToLibrary)"
            ).execute(db)
        }
    }
}
