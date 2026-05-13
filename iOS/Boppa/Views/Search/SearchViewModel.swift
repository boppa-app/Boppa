import Foundation
import os
import SwiftData

@MainActor
@Observable
class SearchViewModel {
    var searchQuery = ""
    var results: SearchResult = .songs([])
    var isSearching = false
    var isLoadingNextPage = false
    var hasMorePages = false
    var errorMessage: String?
    var selectedMediaSource: MediaSource?
    var mediaSources: [MediaSource] = []
    var showMediaSourcePicker = false
    var selectedCategory: SearchCategory = .songs
    var availableCategories: [SearchCategory] = []

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
        category: "SearchViewModel"
    )

    private var searchTask: Task<Void, Never>?
    private var nextPageTask: Task<Void, Never>?
    private var paginationContext: [String: Any]?

    var isQueryActive: Bool {
        !self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static let selectedMediaSourceKey = "search.selectedMediaSourceId"

    func loadSources(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<MediaSource>(
            predicate: #Predicate { $0.isEnabled }
        )
        descriptor.sortBy = [SortDescriptor(\MediaSource.order)]
        self.mediaSources = (try? modelContext.fetch(descriptor)) ?? []

        if let current = self.selectedMediaSource,
           let match = self.mediaSources.first(where: { $0.persistentModelID == current.persistentModelID })
        {
            self.selectedMediaSource = match
        } else if let savedId = UserDefaults.standard.string(forKey: Self.selectedMediaSourceKey),
                  let match = self.mediaSources.first(where: { $0.id == savedId })
        {
            self.selectedMediaSource = match
        } else {
            self.selectedMediaSource = self.mediaSources.first
        }

        self.updateAvailableCategories()
    }

    func selectMediaSource(_ mediaSource: MediaSource) {
        self.selectedMediaSource = mediaSource
        self.showMediaSourcePicker = false
        UserDefaults.standard.set(mediaSource.id, forKey: Self.selectedMediaSourceKey)
        self.updateAvailableCategories()

        if self.isQueryActive {
            self.search()
        }
    }

    func selectCategory(_ category: SearchCategory) {
        self.selectedCategory = category

        if self.isQueryActive {
            self.search()
        }
    }

    func search() {
        self.searchTask?.cancel()
        self.nextPageTask?.cancel()
        self.paginationContext = nil
        self.hasMorePages = false

        let trimmed = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.results = .songs([])
            self.errorMessage = nil
            return
        }

        guard let mediaSource = self.selectedMediaSource else {
            self.errorMessage = "No media source selected"
            return
        }

        self.isSearching = true
        self.errorMessage = nil

        self.searchTask = Task {
            do {
                let response = try await SearchService.shared.search(
                    query: trimmed,
                    mediaSource: mediaSource,
                    category: self.selectedCategory
                )

                guard !Task.isCancelled else { return }

                self.results = response.result
                self.paginationContext = response.paginationContext
                self.hasMorePages = response.paginationContext != nil
                self.isSearching = false

                self.logger.info("Search returned \(response.result.count) result(s)")
            } catch {
                guard !Task.isCancelled else { return }

                self.results = .songs([])
                self.isSearching = false
                self.errorMessage = error.localizedDescription
                self.logger.error("Search failed: \(error.localizedDescription)")
            }
        }
    }

    func loadNextPage() {
        guard !self.isLoadingNextPage,
              self.hasMorePages,
              let paginationContext = self.paginationContext,
              let mediaSource = self.selectedMediaSource
        else { return }

        let trimmed = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        self.isLoadingNextPage = true

        self.nextPageTask = Task {
            do {
                let response = try await SearchService.shared.searchNextPage(
                    paginationContext: paginationContext,
                    mediaSource: mediaSource,
                    category: self.selectedCategory,
                    query: trimmed
                )

                guard !Task.isCancelled else { return }

                self.results.append(response.result)
                self.paginationContext = response.paginationContext
                self.hasMorePages = response.paginationContext != nil
                self.isLoadingNextPage = false

                self.logger.info("Next page returned \(response.result.count) result(s)")
            } catch {
                guard !Task.isCancelled else { return }

                self.isLoadingNextPage = false
                self.hasMorePages = false
                self.logger.error("Next page failed: \(error.localizedDescription)")
            }
        }
    }

    func clearSearch() {
        self.searchTask?.cancel()
        self.nextPageTask?.cancel()
        self.searchQuery = ""
        self.results = .songs([])
        self.errorMessage = nil
        self.isSearching = false
        self.isLoadingNextPage = false
        self.hasMorePages = false
        self.paginationContext = nil
        self.selectedCategory = .songs
    }

    private func updateAvailableCategories() {
        guard let data = self.selectedMediaSource?.config.data else {
            self.availableCategories = []
            return
        }

        self.availableCategories = SearchCategory.allCases.filter { $0.isAvailable(in: data) }

        if !self.availableCategories.contains(self.selectedCategory),
           let first = self.availableCategories.first
        {
            self.selectedCategory = first
        }
    }
}
