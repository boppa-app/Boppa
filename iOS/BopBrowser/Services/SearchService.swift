import Foundation
import os
import WebKit

class SearchService {
    static let shared = SearchService()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "SearchService"
    )

    private init() {}

    func search(
        query: String,
        config: MediaSourceConfig,
        category: SearchCategory,
        contextService: MediaSourceContextService
    ) async throws -> SearchResponse {
        guard let data = config.data else {
            throw SearchError.noSearchConfig
        }

        switch category {
        case .songs:
            let entries = try self.requireEntries(data.searchSongs)
            let (items, ctx) = try await self.executeSearch(query: query, entries: entries, contextService: contextService, mapItem: self.mapItemToSong)
            return SearchResponse(result: .songs(items), paginationContext: ctx)

        case .albums:
            let entries = try self.requireEntries(data.searchAlbums)
            let (items, ctx) = try await self.executeSearch(query: query, entries: entries, contextService: contextService, mapItem: self.mapItemToAlbum)
            return SearchResponse(result: .albums(items), paginationContext: ctx)

        case .artists:
            let entries = try self.requireEntries(data.searchArtists)
            let (items, ctx) = try await self.executeSearch(query: query, entries: entries, contextService: contextService, mapItem: self.mapItemToArtist)
            return SearchResponse(result: .artists(items), paginationContext: ctx)

        case .playlists:
            let entries = try self.requireEntries(data.searchPlaylists)
            let (items, ctx) = try await self.executeSearch(query: query, entries: entries, contextService: contextService, mapItem: self.mapItemToPlaylist)
            return SearchResponse(result: .playlists(items), paginationContext: ctx)
        }
    }

    func searchNextPage(
        paginationContext: [String: String],
        config: MediaSourceConfig,
        category: SearchCategory,
        contextService: MediaSourceContextService
    ) async throws -> SearchResponse {
        guard let data = config.data else {
            throw SearchError.noSearchConfig
        }

        switch category {
        case .songs:
            let entry = try self.requireTopEntry(self.requireEntries(data.searchSongs))
            let (items, ctx) = try await self.executeNextPage(paginationContext: paginationContext, entry: entry, contextService: contextService, mapItem: self.mapItemToSong)
            return SearchResponse(result: .songs(items), paginationContext: ctx)

        case .albums:
            let entry = try self.requireTopEntry(self.requireEntries(data.searchAlbums))
            let (items, ctx) = try await self.executeNextPage(paginationContext: paginationContext, entry: entry, contextService: contextService, mapItem: self.mapItemToAlbum)
            return SearchResponse(result: .albums(items), paginationContext: ctx)

        case .artists:
            let entry = try self.requireTopEntry(self.requireEntries(data.searchArtists))
            let (items, ctx) = try await self.executeNextPage(paginationContext: paginationContext, entry: entry, contextService: contextService, mapItem: self.mapItemToArtist)
            return SearchResponse(result: .artists(items), paginationContext: ctx)

        case .playlists:
            let entry = try self.requireTopEntry(self.requireEntries(data.searchPlaylists))
            let (items, ctx) = try await self.executeNextPage(paginationContext: paginationContext, entry: entry, contextService: contextService, mapItem: self.mapItemToPlaylist)
            return SearchResponse(result: .playlists(items), paginationContext: ctx)
        }
    }

    private func requireEntries<E>(_ entries: [DataEntry<E>]?) throws -> [DataEntry<E>] {
        guard let entries, !entries.isEmpty else { throw SearchError.noSearchConfig }
        return entries
    }

    private func requireTopEntry<E>(_ entries: [DataEntry<E>]) throws -> DataEntry<E> {
        let entry = entries.sorted { ($0.priority ?? Int.max) < ($1.priority ?? Int.max) }.first { $0.type == "fetch" }
        guard let entry else { throw SearchError.noSearchConfig }
        return entry
    }

    private func executeSearch<E: ExtractionSource, T>(
        query: String,
        entries: [DataEntry<E>],
        contextService: MediaSourceContextService,
        mapItem: ([String: Any], E.Mapping) -> T?
    ) async throws -> ([T], [String: String]?) {
        let sorted = entries.sorted { ($0.priority ?? Int.max) < ($1.priority ?? Int.max) }
        for entry in sorted where entry.type == "fetch" {
            do {
                let data = try await self.fetchData(baseUrl: entry.baseUrl, queryParameters: entry.queryParameters, query: query, contextService: contextService)
                return try self.parseResponse(data: data, entry: entry, mapItem: mapItem)
            } catch {
                self.logger.error("Search failed for entry: \(error.localizedDescription)")
                continue
            }
        }
        throw SearchError.noSearchConfig
    }

    private func executeNextPage<E: ExtractionSource, T>(
        paginationContext: [String: String],
        entry: DataEntry<E>,
        contextService: MediaSourceContextService,
        mapItem: ([String: Any], E.Mapping) -> T?
    ) async throws -> ([T], [String: String]?) {
        let data = try await self.fetchNextPage(paginationContext: paginationContext, pagination: entry.pagination, contextService: contextService)
        return try self.parseResponse(data: data, entry: entry, mapItem: mapItem)
    }

    private func parseResponse<E: ExtractionSource, T>(
        data: Data,
        entry: DataEntry<E>,
        mapItem: ([String: Any], E.Mapping) -> T?
    ) throws -> ([T], [String: String]?) {
        guard let extractions = entry.extraction, !extractions.isEmpty else { throw SearchError.parsingFailed }
        let paginationContext = self.extractPaginationContext(data: data, pagination: entry.pagination)
        for extraction in extractions where extraction.type == "direct" {
            let itemArray = try self.extractItemArray(data: data, selector: extraction.selector)
            guard let mapping = extraction.itemMapping else { throw SearchError.parsingFailed }
            let items = itemArray.compactMap { mapItem($0, mapping) }
            return (items, paginationContext)
        }
        throw SearchError.parsingFailed
    }

    private func fetchData(baseUrl: String?, queryParameters: [String: String]?, query: String, contextService: MediaSourceContextService) async throws -> Data {
        guard let baseUrl else { throw SearchError.invalidURL }
        guard var components = URLComponents(string: baseUrl) else { throw SearchError.invalidURL }

        if let queryParameters {
            components.queryItems = try queryParameters.map { key, value in
                let resolved = try self.resolveParameterValue(value, query: query, contextService: contextService)
                return URLQueryItem(name: key, value: resolved)
            }
        }

        guard let url = components.url else { throw SearchError.invalidURL }
        return try await self.executeRequest(url: url)
    }

    private func fetchNextPage(paginationContext: [String: String], pagination: PaginationConfig?, contextService: MediaSourceContextService) async throws -> Data {
        guard let baseUrlValue = pagination?.baseUrl,
              let baseUrl = self.resolvePaginationValue(baseUrlValue, context: paginationContext, contextService: contextService)
        else { throw SearchError.invalidURL }
        guard var components = URLComponents(string: baseUrl) else { throw SearchError.invalidURL }

        if let queryParameters = pagination?.queryParameters {
            var queryItems = components.queryItems ?? []
            for (key, value) in queryParameters {
                guard let resolved = self.resolvePaginationValue(value, context: paginationContext, contextService: contextService) else { continue }
                queryItems.removeAll { $0.name == key }
                queryItems.append(URLQueryItem(name: key, value: resolved))
            }
            components.queryItems = queryItems
        }

        guard let url = components.url else { throw SearchError.invalidURL }
        return try await self.executeRequest(url: url)
    }

    private func resolvePaginationValue(_ value: String, context: [String: String], contextService: MediaSourceContextService) -> String? {
        if value.hasPrefix(".") {
            return context[value]
        }
        return try? self.resolveParameterValue(value, query: "", contextService: contextService)
    }

    private func executeRequest(url: URL) async throws -> Data {
        self.logger.info("Executing search: \(url.absoluteString)")

        let cookies = await self.getCookies(for: url)
        var request = URLRequest(url: url)
        if let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SearchError.requestFailed(statusCode: 0) }
        guard httpResponse.statusCode == 200 else { throw SearchError.requestFailed(statusCode: httpResponse.statusCode) }
        return data
    }

    private func extractPaginationContext(data: Data, pagination: PaginationConfig?) -> [String: String]? {
        guard let pagination else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        var selectors: [String] = []
        if let baseUrl = pagination.baseUrl, baseUrl.hasPrefix(".") {
            selectors.append(baseUrl)
        }
        if let queryParameters = pagination.queryParameters {
            for value in queryParameters.values where value.hasPrefix(".") {
                selectors.append(value)
            }
        }

        var context: [String: String] = [:]
        for selector in selectors {
            if let extracted = self.extractValue(from: json, keyPath: selector) {
                if let stringValue = extracted as? String {
                    context[selector] = stringValue
                } else if let intValue = extracted as? Int {
                    context[selector] = String(intValue)
                } else if let doubleValue = extracted as? Double {
                    context[selector] = String(doubleValue)
                }
            }
        }

        return context.isEmpty ? nil : context
    }

    private func extractItemArray(data: Data, selector: String?) throws -> [[String: Any]] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw SearchError.parsingFailed }
        let items = self.navigateToSelector(json: json, selector: selector)
        guard let itemArray = items as? [[String: Any]] else { throw SearchError.parsingFailed }
        return itemArray
    }

    private func resolve(from item: [String: Any], selectors: [String]) -> Any? {
        for selector in selectors {
            if let value = self.extractValue(from: item, keyPath: selector) {
                if let str = value as? String, str.isEmpty { continue }
                return value
            }
        }
        return nil
    }

    private func resolveInt(from item: [String: Any], selectors: [String]) -> Int? {
        guard let value = self.resolve(from: item, selectors: selectors) else { return nil }
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }

    private func mapItemToSong(item: [String: Any], mapping: SongMapping) -> Song? {
        guard let title = self.resolve(from: item, selectors: mapping.title) as? String else { return nil }
        return Song(
            title: title,
            artist: self.resolve(from: item, selectors: mapping.artist) as? String,
            duration: self.resolveInt(from: item, selectors: mapping.duration),
            artworkUrl: self.resolve(from: item, selectors: mapping.artworkUrl) as? String,
            url: self.resolve(from: item, selectors: mapping.url) as? String
        )
    }

    private func mapItemToAlbum(item: [String: Any], mapping: AlbumMapping) -> Album? {
        guard let title = self.resolve(from: item, selectors: mapping.title) as? String else { return nil }
        return Album(
            title: title,
            artist: self.resolve(from: item, selectors: mapping.artist) as? String,
            trackCount: self.resolveInt(from: item, selectors: mapping.trackCount),
            artworkUrl: self.resolve(from: item, selectors: mapping.artworkUrl) as? String,
            url: self.resolve(from: item, selectors: mapping.url) as? String
        )
    }

    private func mapItemToArtist(item: [String: Any], mapping: ArtistMapping) -> Artist? {
        guard let name = self.resolve(from: item, selectors: mapping.artist) as? String else { return nil }
        return Artist(
            name: name,
            artworkUrl: self.resolve(from: item, selectors: mapping.artworkUrl) as? String,
            url: self.resolve(from: item, selectors: mapping.url) as? String
        )
    }

    private func mapItemToPlaylist(item: [String: Any], mapping: PlaylistMapping) -> Playlist? {
        guard let title = self.resolve(from: item, selectors: mapping.title) as? String else { return nil }
        return Playlist(
            title: title,
            user: self.resolve(from: item, selectors: mapping.user) as? String,
            trackCount: self.resolveInt(from: item, selectors: mapping.trackCount),
            artworkUrl: self.resolve(from: item, selectors: mapping.artworkUrl) as? String,
            url: self.resolve(from: item, selectors: mapping.url) as? String
        )
    }

    private func resolveParameterValue(_ value: String, query: String, contextService: MediaSourceContextService) throws -> String {
        if value == "<SEARCH_QUERY>" { return query }
        if value.wholeMatch(of: KeyMappingPattern.regex) != nil {
            let keyMapping = try KeyMapping(value)
            guard let resolved = contextService.resolveConfigValue(keyMapping: keyMapping) else { throw SearchError.missingKeyMapping(value) }
            return resolved
        }
        return value
    }

    private func stripLeadingDot(_ keyPath: String) -> String {
        keyPath.hasPrefix(".") ? String(keyPath.dropFirst()) : keyPath
    }

    private func navigateToSelector(json: Any, selector: String?) -> Any {
        guard let selector, !selector.isEmpty else { return json }
        let path = self.stripLeadingDot(selector).components(separatedBy: ".")
        var current: Any = json
        for component in path {
            if let dict = current as? [String: Any], let next = dict[component] {
                current = next
            } else {
                return json
            }
        }
        return current
    }

    private func extractValue(from dict: [String: Any], keyPath: String) -> Any? {
        let cleaned = self.stripLeadingDot(keyPath)
        let components = cleaned.components(separatedBy: ".")
        var current: Any = dict
        for component in components {
            if let currentDict = current as? [String: Any], let next = currentDict[component] {
                if next is NSNull { return nil }
                current = next
            } else {
                return nil
            }
        }
        return current
    }

    @MainActor
    private func getCookies(for url: URL) async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            WebDataStore.shared.getDataStore().httpCookieStore.getAllCookies { cookies in
                let matching = cookies.filter { cookie in
                    url.host?.contains(cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) ?? false
                }
                continuation.resume(returning: matching)
            }
        }
    }
}
