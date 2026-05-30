import Dependencies
import Foundation
import os
import SQLiteData

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "WebViewPlaybackEngineRegistry"
)

@MainActor
final class WebViewPlaybackEngineRegistry {
    static let shared = WebViewPlaybackEngineRegistry()

    private var engines: [String: WebViewPlaybackEngine] = [:]
    private var mediaSourceAddedObserver: NSObjectProtocol?
    private var mediaSourceRemovedObserver: NSObjectProtocol?
    private var mediaSourceEnabledObserver: NSObjectProtocol?
    private var mediaSourceDisabledObserver: NSObjectProtocol?

    @Dependency(\.defaultDatabase) var database

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
        let mediaSources = (try? self.database.read { db in
            try MediaSource.fetchAll(db)
        }) ?? []

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

        self.mediaSourceRemovedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceRemoved,
            object: nil,
            queue: .main
        ) { notification in
            MainActor.assumeIsolated {
                if let ids = notification.userInfo?["ids"] as? [String] {
                    self.handleMediaSourceRemoved(ids: ids)
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

        self.mediaSourceDisabledObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceDisabled,
            object: nil,
            queue: .main
        ) { notification in
            MainActor.assumeIsolated {
                if let id = notification.userInfo?["id"] as? String {
                    self.handleMediaSourceDisabled(id: id)
                }
            }
        }
    }

    private func handleMediaSourceAdded() {
        let mediaSources = (try? self.database.read { db in
            try MediaSource.fetchAll(db)
        }) ?? []

        for mediaSource in mediaSources where self.engines[mediaSource.id] == nil {
            self.createEngine(for: mediaSource)
            logger.info("Created engine for newly added source '\(mediaSource.name)'")
        }
    }

    private func handleMediaSourceRemoved(ids: [String]) {
        for id in ids {
            self.destroyEngine(for: id)
            logger.info("Destroyed engine for removed source '\(id)'")
        }
    }

    private func handleMediaSourceEnabled(id: String) {
        guard self.engines[id] == nil else { return }
        let mediaSources = (try? self.database.read { db in
            try MediaSource.fetchAll(db)
        }) ?? []
        guard let mediaSource = mediaSources.first(where: { $0.id == id }) else {
            logger.warning("Enabled source '\(id)' not found in database")
            return
        }
        self.createEngine(for: mediaSource)
        logger.info("Created engine for enabled source '\(mediaSource.name)'")
    }

    private func handleMediaSourceDisabled(id: String) {
        self.destroyEngine(for: id)
        logger.info("Destroyed engine for disabled source '\(id)'")
    }

    private func createEngine(for mediaSource: MediaSource) {
        let engine = WebViewPlaybackEngine(config: mediaSource.config)
        self.engines[mediaSource.id] = engine
    }

    private func destroyEngine(for mediaSourceId: String) {
        self.engines[mediaSourceId]?.tearDown()
        self.engines.removeValue(forKey: mediaSourceId)
    }
}
