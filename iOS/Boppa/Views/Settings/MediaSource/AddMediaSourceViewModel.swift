import Foundation

@MainActor
@Observable
class AddMediaSourceViewModel {
    var mediaSourceUrl = ""
    var configProviderUrl = "localhost:8788"
    var isLoading = false
    var errorMessage: String?

    var isAddDisabled: Bool {
        self.mediaSourceUrl.isEmpty || self.configProviderUrl.isEmpty || self.isLoading
    }

    func addMediaSource() async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

        let formattedSourceUrl = self.mediaSourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let formattedProviderUrl = self.configProviderUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let mediaSource = try await MediaSourceImportService.shared.fetchMediaSource(
                configProviderUrl: formattedProviderUrl,
                mediaSourceUrl: formattedSourceUrl
            )

            try MediaSourceStorageManager.shared.insert([mediaSource])

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
