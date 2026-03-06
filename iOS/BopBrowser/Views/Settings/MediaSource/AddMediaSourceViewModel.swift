import Foundation
import SwiftData

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

    func addMediaSource(modelContext: ModelContext) async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

        let formattedSourceUrl = self.mediaSourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let formattedProviderUrl = self.configProviderUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let mediaSources = try await MediaSourceImportService.shared.fetchMediaSources(
                configProviderUrl: formattedProviderUrl,
                mediaSourceUrl: formattedSourceUrl
            )
            mediaSources.forEach { modelContext.insert($0) }
            try modelContext.save()
            NotificationCenter.default.post(name: .mediaSourcesDidChange, object: nil)

            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
