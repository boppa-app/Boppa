import Foundation
import SwiftData

@MainActor
@Observable
class AddMediaSourceViewModel {
    var mediaSourceUrl = ""
    var configProviderUrl = "localhost:8080"
    var isLoading = false
    var errorMessage: String?

    var isAddDisabled: Bool {
        mediaSourceUrl.isEmpty || configProviderUrl.isEmpty || isLoading
    }

    func addMediaSource(modelContext: ModelContext) async -> Bool {
        isLoading = true
        errorMessage = nil

        let formattedSourceUrl = mediaSourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let formattedProviderUrl = configProviderUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let mediaSources = try await MediaSourceImportService.shared.fetchMediaSources(
                configProviderUrl: formattedProviderUrl,
                mediaSourceUrl: formattedSourceUrl
            )
            mediaSources.forEach { modelContext.insert($0) }

            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
}
