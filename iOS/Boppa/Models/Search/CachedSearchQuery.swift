import Foundation
import Ifrit
import SQLiteData

// TODO: rename this one and all other SQLite table structs to prefix with "Stored"

@Table("cachedSearchQueries")
nonisolated struct CachedSearchQuery: Identifiable {
    let id: Int
    var query: String
    var timestamp: Double
}

extension CachedSearchQuery: FuzzySearchable {
    var fuzzyTitle: String {
        self.query
    }

    var fuzzySubtitle: String? {
        nil
    }
}

extension CachedSearchQuery {
    init(query: String) {
        self.id = 0
        self.query = query
        self.timestamp = Date().timeIntervalSince1970
    }
}
