import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "SearchCacheManager"
)

@MainActor
@Observable
class SearchCacheManager {
    var cachedQueries: [CachedSearchQuery] = []

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    private static let maxCachedQueries = 25

    func load() {
        self.cachedQueries = (try? database.read { db in
            try CachedSearchQuery
                .order { $0.timestamp.desc() }
                .limit(Self.maxCachedQueries)
                .fetchAll(db)
        }) ?? []
    }

    func saveQuery(_ query: String, category: SearchCategory) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try? database.write { db in
            try CachedSearchQuery
                .where { $0.query.eq(trimmed).and($0.categoryRaw.eq(category.rawValue)) }
                .delete()
                .execute(db)

            try CachedSearchQuery.insert {
                CachedSearchQuery.Draft(
                    query: trimmed,
                    categoryRaw: category.rawValue,
                    timestamp: Date().timeIntervalSince1970
                )
            }.execute(db)

            let allSorted = try CachedSearchQuery
                .order { $0.timestamp.desc() }
                .fetchAll(db)

            if allSorted.count > Self.maxCachedQueries {
                let overflowIds = allSorted[Self.maxCachedQueries...].map(\.id)
                try CachedSearchQuery
                    .where { $0.id.in(overflowIds) }
                    .delete()
                    .execute(db)
            }
        }

        self.load()
        logger.info("Cached search query: \"\(trimmed)\" [\(category.rawValue)]")
    }

    func removeQuery(_ query: CachedSearchQuery) {
        try? database.write { db in
            try CachedSearchQuery.where { $0.id.eq(query.id) }.delete().execute(db)
        }
        self.load()
    }

    func clearAll() {
        try? database.write { db in
            try CachedSearchQuery.delete().execute(db)
        }
        self.cachedQueries = []
    }
}
