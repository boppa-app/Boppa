import Dependencies
import Foundation
import Ifrit
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
    var displayedQueries: [CachedSearchQuery] = []

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    @ObservationIgnored
    private let fuse = Fuse(threshold: 0.4, tokenize: true)

    @ObservationIgnored
    private var fuzzySearchTask: Task<Void, Never>?

    @ObservationIgnored
    private var currentFilter: String = ""

    private static let maxCachedQueries = 25

    func load() {
        self.cachedQueries =
            (try? self.database.read { db in
                try CachedSearchQuery
                    .order { $0.timestamp.desc() }
                    .limit(Self.maxCachedQueries)
                    .fetchAll(db)
            }) ?? []
        self.updateFilter(self.currentFilter)
    }

    func updateFilter(_ text: String) {
        self.fuzzySearchTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        self.currentFilter = trimmed
        guard !trimmed.isEmpty else {
            self.displayedQueries = self.cachedQueries
            return
        }

        let snapshot = self.cachedQueries
        let fuseInstance = self.fuse

        self.fuzzySearchTask = Task {
            let fuseProps: [[FuseProp]] = snapshot.map { [FuseProp($0.query, weight: 1.0)] }
            let results = await fuseInstance.search(trimmed, in: fuseProps)
            guard !Task.isCancelled else { return }
            self.displayedQueries = results.map { snapshot[$0.index] }
        }
    }

    func saveQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try? self.database.write { db in
            try CachedSearchQuery
                .where { $0.query.eq(trimmed) }
                .delete()
                .execute(db)

            try CachedSearchQuery.insert {
                CachedSearchQuery.Draft(
                    query: trimmed,
                    timestamp: Date().timeIntervalSince1970
                )
            }.execute(db)

            let allSorted =
                try CachedSearchQuery
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
        logger.info("Cached search query: \"\(trimmed)\"")
    }

    func popTopDisplayedQuery() {
        guard let top = self.displayedQueries.first else { return }
        try? self.database.write { db in
            try CachedSearchQuery.where { $0.id.eq(top.id) }.delete().execute(db)
        }
        self.load()
    }
}
