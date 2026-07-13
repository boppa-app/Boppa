import Foundation

@MainActor
@Observable
class AddMediaSourceViewModel {
    var configUrl: String
    var isLoading = false
    var isGatheringContext = false
    var errorMessage: String?

    init(configUrl: String = "") {
        self.configUrl = configUrl
    }

    var isAddDisabled: Bool {
        self.configUrl.isEmpty || self.isLoading
    }

    func addMediaSource() async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

        let formattedUrl = self.configUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let mediaSource = try await MediaSourceImportService.shared.fetchMediaSource(configUrl: formattedUrl)

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
}
