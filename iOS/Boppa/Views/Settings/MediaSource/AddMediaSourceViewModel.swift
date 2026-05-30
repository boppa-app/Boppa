import Dependencies
import Foundation
import SQLiteData

@MainActor
@Observable
class AddMediaSourceViewModel {
    var mediaSourceUrl = ""
    var configProviderUrl = "localhost:8788"
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database

    var isAddDisabled: Bool {
        self.mediaSourceUrl.isEmpty || self.configProviderUrl.isEmpty || self.isLoading
    }

    func addMediaSource() async -> Bool {
        self.isLoading = true
        self.errorMessage = nil

        let formattedSourceUrl = self.mediaSourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let formattedProviderUrl = self.configProviderUrl.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let mediaSources = try await MediaSourceImportService.shared.fetchMediaSources(
                configProviderUrl: formattedProviderUrl,
                mediaSourceUrl: formattedSourceUrl
            )

            let startOrder: Int = {
                let existing = try? self.database.read { db in
                    try MediaSource.order { $0.sortOrder.desc() }.fetchOne(db)?.sortOrder
                }
                return (existing ?? nil ?? -1) + 1
            }()

            try await database.write { db in
                for (index, var mediaSource) in mediaSources.enumerated() {
                    mediaSource.sortOrder = startOrder + index
                    try MediaSource.insert { mediaSource }.execute(db)
                }
            }

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
