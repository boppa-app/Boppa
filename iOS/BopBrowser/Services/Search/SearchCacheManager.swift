import Foundation
import os
import SwiftData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
    category: "SearchCacheManager"
)

@MainActor
@Observable
class SearchCacheManager {
    var cachedQueries: [CachedSearchQuery] = []

    private static let maxCachedQueries = 25

    func load(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<CachedSearchQuery>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = Self.maxCachedQueries
        self.cachedQueries = (try? modelContext.fetch(descriptor)) ?? []
    }

    func saveQuery(_ query: String, category: SearchCategory, modelContext: ModelContext) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let existing = self.cachedQueries.filter {
            $0.query == trimmed && $0.categoryRaw == category.rawValue
        }
        for entry in existing {
            modelContext.delete(entry)
        }

        let newEntry = CachedSearchQuery(query: trimmed, category: category)
        modelContext.insert(newEntry)

        self.load(modelContext: modelContext)
        if self.cachedQueries.count > Self.maxCachedQueries {
            let overflow = self.cachedQueries[Self.maxCachedQueries...]
            for entry in overflow {
                modelContext.delete(entry)
            }
        }

        try? modelContext.save()
        self.load(modelContext: modelContext)

        logger.info("Cached search query: \"\(trimmed)\" [\(category.rawValue)]")
    }

    func removeQuery(_ query: CachedSearchQuery, modelContext: ModelContext) {
        modelContext.delete(query)
        try? modelContext.save()
        self.load(modelContext: modelContext)
    }

    func clearAll(modelContext: ModelContext) {
        for query in self.cachedQueries {
            modelContext.delete(query)
        }
        try? modelContext.save()
        self.cachedQueries = []
    }
}
