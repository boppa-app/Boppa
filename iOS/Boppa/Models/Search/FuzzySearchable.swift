import Foundation
import Ifrit

protocol FuzzySearchable {
    var fuzzyTitle: String { get }
    var fuzzySubtitle: String? { get }
}

@MainActor
@Observable
class FuzzySearchHandler<T: FuzzySearchable> {
    var searchText = ""
    var isFuzzySearching = false
    var filteredItems: [T]?

    private var fuzzySearchTask: Task<Void, Never>?
    private let fuse = Fuse(threshold: 0.4, tokenize: true)

    func updateSearch(_ text: String, items: [T]) {
        self.searchText = text

        self.fuzzySearchTask?.cancel()

        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            self.filteredItems = nil
            self.isFuzzySearching = false
            return
        }

        self.isFuzzySearching = true

        let snapshot = items
        let query = text
        let fuseInstance = self.fuse

        self.fuzzySearchTask = Task {
            let fuseProps: [[FuseProp]] = snapshot.map { item in
                [
                    FuseProp(item.fuzzyTitle, weight: 0.6),
                    FuseProp(item.fuzzySubtitle ?? "", weight: 0.4),
                ]
            }

            let results = await fuseInstance.search(query, in: fuseProps)

            guard !Task.isCancelled else { return }

            self.filteredItems = results.map { snapshot[$0.index] }
            self.isFuzzySearching = false
        }
    }

    func displayItems(from allItems: [T]) -> [T] {
        if let filtered = self.filteredItems {
            return filtered
        }
        return allItems
    }
}
