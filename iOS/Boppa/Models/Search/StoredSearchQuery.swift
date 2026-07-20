import Foundation
import Ifrit
import SQLiteData

@Table("cachedSearchQueries")
nonisolated struct StoredSearchQuery: Identifiable {
    let id: Int
    var query: String
    var timestamp: Double
}

extension StoredSearchQuery: FuzzySearchable {
    var fuzzyTitle: String {
        self.query
    }

    var fuzzySubtitle: String? {
        nil
    }
}

extension StoredSearchQuery {
    init(query: String) {
        self.id = 0
        self.query = query
        self.timestamp = Date().timeIntervalSince1970
    }
}
