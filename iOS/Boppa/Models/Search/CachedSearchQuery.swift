import Foundation
import SQLiteData

@Table("cachedSearchQueries")
nonisolated struct CachedSearchQuery: Identifiable {
    let id: Int
    var query: String
    var categoryRaw: String
    var timestamp: Double
}

extension CachedSearchQuery {
    var category: SearchCategory? {
        SearchCategory(rawValue: self.categoryRaw)
    }

    init(query: String, category: SearchCategory) {
        self.id = 0
        self.query = query
        self.categoryRaw = category.rawValue
        self.timestamp = Date().timeIntervalSince1970
    }
}
