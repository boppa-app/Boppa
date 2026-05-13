import Foundation
import os
import SwiftData

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
    private var mediaSourceUpdatedObserver: NSObjectProtocol?
    private var modelContext: ModelContext?

    private init() {}

    func start(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
        self.createEnginesForExistingSources()
        self.observeNotifications()
        logger.info("WebViewPlaybackEngineRegistry started")
    }

    func engine(for mediaSourceId: String) -> WebViewPlaybackEngine? {
        self.engines[mediaSourceId]
    }

    private func createEnginesForExistingSources() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<MediaSource>()
        let mediaSources = (try? modelContext.fetch(descriptor)) ?? []

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

        self.mediaSourceUpdatedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceUpdated,
            object: nil,
            queue: .main
        ) { notification in
            MainActor.assumeIsolated {
                if let id = notification.userInfo?["id"] as? String {
                    self.handleMediaSourceUpdated(id: id)
                }
            }
        }
    }

    private func handleMediaSourceAdded() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<MediaSource>()
        let mediaSources = (try? modelContext.fetch(descriptor)) ?? []

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

    private func handleMediaSourceUpdated(id: String) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<MediaSource>()
        let mediaSources = (try? modelContext.fetch(descriptor)) ?? []

        guard let mediaSource = mediaSources.first(where: { $0.id == id }) else {
            logger.warning("Updated source '\(id)' not found in model context")
            return
        }

        self.destroyEngine(for: id)
        self.createEngine(for: mediaSource)
        logger.info("Recreated engine for updated source '\(mediaSource.name)'")
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
