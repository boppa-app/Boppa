import Foundation
import SQLiteData

extension DatabaseWriter where Self == DatabasePool {
    static func appDatabase() throws -> Self {
        let fileManager = FileManager.default
        let folder = try fileManager
            .url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("Boppa", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("app.db")

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let database = try DatabasePool(path: url.path, configuration: configuration)
        var migrator = DatabaseMigrator()
        migrator.registerV1InitialSchema()
        migrator.register20260818172551_DropTrackCount()
        try migrator.migrate(database)
        return database
    }
}
