import Foundation

@MainActor
@Observable
class AddMediaSourceViewModel {
    var configUrl: String
    var selectedFileURL: URL?
    var isLoading = false
    var isGatheringContext = false
    var errorMessage: String?

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
            let mediaSource: StoredMediaSource
            if let fileURL = self.selectedFileURL {
                mediaSource = try Self.loadMediaSource(fromFile: fileURL)
            } else {
                let formattedUrl = self.configUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                mediaSource = try await MediaSourceImportService.shared.fetchMediaSource(configUrl: formattedUrl)
            }

            if MediaSourceStorageManager.shared.fetchOne(id: mediaSource.id) != nil {
                throw MediaSourceImportError.alreadyExists(id: mediaSource.id)
            }

            try MediaSourceStorageManager.shared.insert([mediaSource])

            let hasContextConfigs = !(mediaSource.config.context ?? []).isEmpty
            if hasContextConfigs {
                self.isGatheringContext = true
                MediaSourceContextProvider.shared.refresh()
                do {
                    try await MediaSourceContextProvider.shared.waitForFirstContextGather(mediaSourceId: mediaSource.id)
                } catch {
                    self.isGatheringContext = false
                    try? MediaSourceStorageManager.shared.delete(id: mediaSource.id)
                    throw error
                }
                self.isGatheringContext = false
            }

            NotificationCenter.default.post(name: .mediaSourceAdded, object: nil, userInfo: ["id": mediaSource.id])
            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            return false
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
