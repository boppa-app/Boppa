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

            let existingDescriptor = FetchDescriptor<MediaSource>()
            let existingSources = (try? modelContext.fetch(existingDescriptor)) ?? []
            let maxOrder = existingSources.map(\.order).max() ?? -1

            for (index, mediaSource) in mediaSources.enumerated() {
                mediaSource.order = maxOrder + 1 + index
                modelContext.insert(mediaSource)
            }
            try modelContext.save()
            let addedNames = mediaSources.map(\.name)
            NotificationCenter.default.post(name: .mediaSourceAdded, object: nil, userInfo: ["names": addedNames])

            self.isLoading = false
            return true
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
