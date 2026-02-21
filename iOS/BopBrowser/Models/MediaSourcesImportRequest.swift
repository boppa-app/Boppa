import Foundation
import SwiftData

@Model
final class MediaSourcesImportRequest {
    var mediaSourceUrl: String
    var configProviderUrl: String
    var createdAt: Date

    init(mediaSourceUrl: String, configProviderUrl: String) {
        self.mediaSourceUrl = mediaSourceUrl
        self.configProviderUrl = configProviderUrl
        createdAt = .now
    }
}
