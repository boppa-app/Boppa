import Foundation
import SwiftData

@Model
final class MediaSource {
    var mediaSourceUrl: String
    var configProviderUrl: String
    var iconSystemName: String
    var createdAt: Date

    init(mediaSourceUrl: String, configProviderUrl: String, iconSystemName: String = "music.note", createdAt: Date = .now) {
        self.mediaSourceUrl = mediaSourceUrl
        self.configProviderUrl = configProviderUrl
        self.iconSystemName = iconSystemName
        self.createdAt = createdAt
    }
}
