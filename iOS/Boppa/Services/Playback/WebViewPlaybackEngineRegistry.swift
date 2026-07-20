import Foundation
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "WebViewPlaybackEngineRegistry"
)

@MainActor
final class WebViewPlaybackEngineRegistry {
    static let shared = WebViewPlaybackEngineRegistry()

    private var engines: [String: WebViewPlaybackEngine] = [:]
    private var mediaSourceAddedObserver: NSObjectProtocol?
    private var mediaSourceDisabledOrRemovedObserver: NSObjectProtocol?
    private var mediaSourceEnabledObserver: NSObjectProtocol?

    private init() {}

    func start() {
        self.createEnginesForExistingSources()
        self.observeNotifications()
        logger.info("WebViewPlaybackEngineRegistry started")
    }

    func engine(for mediaSourceId: String) -> WebViewPlaybackEngine? {
        self.engines[mediaSourceId]
    }

    var allEngines: [WebViewPlaybackEngine] {
        Array(self.engines.values)
    }

    private func createEnginesForExistingSources() {
        let mediaSources = MediaSourceStorageManager.shared.fetchAll()

        for mediaSource in mediaSources {
            self.createEngine(for: mediaSource)
        }

        logger.info("Created \(mediaSources.count) playback engine(s) for existing sources")
    }

    private func observeNotifications() {
        self.mediaSourceAddedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceAdded,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                self.handleMediaSourceAdded()
            }
        }

        for name: Notification.Name in [.mediaSourceDisabled, .mediaSourceRemoved] {
            self.mediaSourceDisabledOrRemovedObserver = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { notification in
                MainActor.assumeIsolated {
                    if let id = notification.userInfo?["id"] as? String {
                        self.handleMediaSourceDisabledOrRemoved(id: id)
                    }
                }
            }
        }

        self.mediaSourceEnabledObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceEnabled,
            object: nil,
            queue: .main
        ) { notification in
            MainActor.assumeIsolated {
                if let id = notification.userInfo?["id"] as? String {
                    self.handleMediaSourceEnabled(id: id)
                }
            }
        }
    }

    private func handleMediaSourceAdded() {
        let mediaSources = MediaSourceStorageManager.shared.fetchAll()

        for mediaSource in mediaSources where self.engines[mediaSource.id] == nil {
            self.createEngine(for: mediaSource)
            logger.info("Created engine for newly added source '\(mediaSource.config.name)'")
        }
    }

    private func handleMediaSourceDisabledOrRemoved(id: String) {
        self.destroyEngine(for: id)
        logger.info("Destroyed engine for disabled/removed source '\(id)'")
    }

    private func handleMediaSourceEnabled(id: String) {
        guard self.engines[id] == nil else { return }
        guard let mediaSource = MediaSourceStorageManager.shared.fetchOne(id: id) else {
            logger.warning("Enabled source '\(id)' not found in database")
            return
        }
        self.createEngine(for: mediaSource)
        logger.info("Created engine for enabled source '\(mediaSource.config.name)'")
    }

    private func createEngine(for mediaSource: StoredMediaSource) {
        let engine = WebViewPlaybackEngine(config: mediaSource.config)
        self.engines[mediaSource.id] = engine
    }

    private func destroyEngine(for mediaSourceId: String) {
        self.engines[mediaSourceId]?.tearDown()
        self.engines.removeValue(forKey: mediaSourceId)
    }
}
