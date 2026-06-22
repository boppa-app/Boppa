import Foundation
import SwiftUI

@MainActor
@Observable
class SettingsViewModel {
    var mediaSources: [MediaSource] = []

    func loadSources() {
        self.mediaSources = MediaSourceStorageManager.shared.fetchAll()
    }

    func moveMediaSources(from source: IndexSet, to destination: Int) {
        var reordered = self.mediaSources
        reordered.move(fromOffsets: source, toOffset: destination)
        self.mediaSources = (try? MediaSourceStorageManager.shared.updateSortOrders(reordered)) ?? reordered
    }

    func deleteMediaSource(at offsets: IndexSet) {
        for index in offsets.sorted().reversed() {
            let mediaSource = self.mediaSources[index]
            try? MediaSourceStorageManager.shared.delete(id: mediaSource.id)
            self.mediaSources.remove(at: index)
            NotificationCenter.default.post(name: .mediaSourceRemoved, object: nil, userInfo: ["id": mediaSource.id])
        }
    }
}
