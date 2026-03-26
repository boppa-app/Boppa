import Foundation
import SwiftData

@Model
final class CachedSearchQuery {
    var query: String
    var categoryRaw: String
    var timestamp: Date

    var category: SearchCategory? {
        SearchCategory(rawValue: self.categoryRaw)
    }

    init(query: String, category: SearchCategory) {
        self.query = query
        self.categoryRaw = category.rawValue
        self.timestamp = Date()
    }
}
