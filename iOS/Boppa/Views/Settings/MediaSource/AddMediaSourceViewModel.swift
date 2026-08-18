import Foundation

@MainActor
@Observable
class AddMediaSourceViewModel {
    var configUrl: String
    var selectedFileURL: URL?
    var isLoading = false
    var isGatheringContext = false
    var errorMessage: String?

    private var pendingMediaSourceId: String?

    init(configUrl: String = "") {
        self.configUrl = configUrl
    }

    var selectedFileName: String? {
        self.selectedFileURL?.lastPathComponent
    }

    var isAddDisabled: Bool {
        guard !self.isLoading else { return true }
        if self.selectedFileURL != nil { return false }
        return self.configUrl.isEmpty
    }

    func clearSelectedFile() {
        self.selectedFileURL = nil
    }

    func addMediaSource() async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

        do {
            let mediaSource = try await self.resolveMediaSource()
            try Task.checkCancellation()
            try self.insert(mediaSource)
            try await self.gatherContextIfNeeded(for: mediaSource)

            self.pendingMediaSourceId = nil
            NotificationCenter.default.post(
                name: .mediaSourceAdded,
                object: nil,
                userInfo: ["id": mediaSource.id]
            )
            self.isLoading = false
            return true
        } catch {
            self.rollback(after: error)
            return false
        }
    }

    func cancelAdd() {
        guard self.isLoading else { return }
        if let id = self.pendingMediaSourceId {
            MediaSourceContextProvider.shared.cancelWaiting(mediaSourceId: id)
        }
    }

    private func resolveMediaSource() async throws -> StoredMediaSource {
        if let fileURL = self.selectedFileURL {
            return try Self.loadMediaSource(fromFile: fileURL)
        }
        let formattedUrl = self.configUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await MediaSourceImportService.shared.fetchMediaSource(configUrl: formattedUrl)
    }

    private func insert(_ mediaSource: StoredMediaSource) throws {
        if MediaSourceStorageManager.shared.fetchOne(id: mediaSource.id) != nil {
            throw MediaSourceImportError.alreadyExists(id: mediaSource.id)
        }
        try MediaSourceStorageManager.shared.insert([mediaSource])
        self.pendingMediaSourceId = mediaSource.id
    }

    private func gatherContextIfNeeded(for mediaSource: StoredMediaSource) async throws {
        guard !(mediaSource.config.context ?? []).isEmpty else { return }

        self.isGatheringContext = true
        defer { self.isGatheringContext = false }

        MediaSourceContextProvider.shared.refresh()
        try await MediaSourceContextProvider.shared
            .waitForFirstContextGather(mediaSourceId: mediaSource.id)
    }

    private func rollback(after error: Error) {
        self.isLoading = false

        if let id = self.pendingMediaSourceId {
            self.pendingMediaSourceId = nil
            try? MediaSourceStorageManager.shared.delete(id: id)
            NotificationCenter.default.post(
                name: .mediaSourceRemoved,
                object: nil,
                userInfo: ["id": id]
            )
        }

        if !(error is CancellationError) {
            self.errorMessage = error.localizedDescription
        }
    }

    private static func loadMediaSource(fromFile url: URL) throws -> StoredMediaSource {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        return try StoredMediaSource.fromConfigData(data, configUrl: nil)
    }
}
