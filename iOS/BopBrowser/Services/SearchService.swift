import Foundation
import os

// TODO: If switching media source configs dont execute search unless user clicks, instead clear search results

@MainActor
class SearchService {
    static let shared = SearchService()

    private let paginated = PaginatedScriptExecutor.shared

    private init() {}

    @MainActor
    func search(
        query: String,
        config: MediaSourceConfig,
        category: SearchCategory,
        contextService: MediaSourceContextProvider
    ) async throws -> SearchResponse {
        guard let data = config.data else {
            throw SearchError.noSearchConfig
        }

        guard let script = category.script(from: data) else {
            throw SearchError.noSearchConfig
        }

        let page = try await self.paginated.executePage(
            script: script,
            params: ["query": query],
            previousResult: nil,
            contextService: contextService
        )

        return self.buildResponse(page: page, category: category, mediaSourceName: config.name)
    }

    @MainActor
    func searchNextPage(
        paginationContext: [String: Any],
        config: MediaSourceConfig,
        category: SearchCategory,
        query: String,
        contextService: MediaSourceContextProvider
    ) async throws -> SearchResponse {
        guard let data = config.data else {
            throw SearchError.noSearchConfig
        }

        guard let script = category.script(from: data) else {
            throw SearchError.noSearchConfig
        }

        let page = try await self.paginated.executePage(
            script: script,
            params: ["query": query],
            previousResult: paginationContext,
            contextService: contextService
        )

        return self.buildResponse(page: page, category: category, mediaSourceName: config.name)
    }

    private func buildResponse(page: PageResult, category: SearchCategory, mediaSourceName: String) -> SearchResponse {
        let result: SearchResult
        switch category {
        case .songs:
            result = .songs(page.items.compactMap { self.paginated.mapToSong($0, mediaSourceName: mediaSourceName) })
        case .albums:
            result = .albums(page.items.compactMap(self.paginated.mapToAlbum))
        case .artists:
            result = .artists(page.items.compactMap(self.paginated.mapToArtist))
        case .playlists:
            result = .playlists(page.items.compactMap(self.paginated.mapToPlaylist))
        }

        return SearchResponse(result: result, paginationContext: page.paginationContext)
    }
}
