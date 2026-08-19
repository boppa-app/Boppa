import SQLiteData

extension DatabaseMigrator {
    mutating func register20260818172551_DropTrackCount() {
        self.registerMigration("20260818172551_dropTrackCount") { db in
            try #sql(
                """
                ALTER TABLE "tracklists" DROP COLUMN "trackCount"
                """
            ).execute(db)
        }
    }
}
