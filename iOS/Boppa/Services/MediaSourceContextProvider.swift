import Foundation
import os
import SwiftData
import WebKit

extension Notification.Name {
    static let mediaSourceAdded = Notification.Name("mediaSourceAdded")
    static let mediaSourceRemoved = Notification.Name("mediaSourceRemoved")
    static let mediaSourceUpdated = Notification.Name("mediaSourceUpdated")
    static let mediaSourceLoginCompleted = Notification.Name("mediaSourceLoginCompleted")
}

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "MediaSourceContextProvider"
)

@Observable
final class MediaSourceContextProvider: NSObject {
    static let shared = MediaSourceContextProvider()

    private static let refreshTimeoutSeconds: TimeInterval = 15
    private static let messageHandlerName = "contextCapture"

    private var refreshTimers: [String: Timer] = [:]
    private var isProcessing = false
    private var pendingWork: [RefreshWorkItem] = []
    private var activeWebView: WKWebView?
    private var timeoutTask: Task<Void, Never>?
    private var currentMediaSourceId: String?
    private var modelContext: ModelContext?
    private var mediaSourceAddedObserver: NSObjectProtocol?
    private var mediaSourceRemovedObserver: NSObjectProtocol?
    private var mediaSourceLoginObserver: NSObjectProtocol?

    override private init() {
        super.init()
        logger.info("MediaSourceContextProvider initialized")
    }

    @MainActor
    func startMonitoring(modelContainer: ModelContainer) {
        logger.info("MediaSourceContextProvider starting monitoring...")

        let context = ModelContext(modelContainer)
        self.modelContext = context
        self.refreshFromModelContext()

        self.mediaSourceAddedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceAdded,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                logger.info("Received mediaSourceAdded notification, refreshing...")
                MediaSourceContextProvider.shared.refreshFromModelContext()
            }
        }

        self.mediaSourceRemovedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceRemoved,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                logger.info("Received mediaSourceRemoved notification, refreshing...")
                MediaSourceContextProvider.shared.refreshFromModelContext()
            }
        }

        self.mediaSourceLoginObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceLoginCompleted,
            object: nil,
            queue: .main
        ) { notification in
            guard let mediaSourceId = notification.userInfo?["mediaSourceId"] as? String else { return }
            MainActor.assumeIsolated {
                logger.info("Received mediaSourceLoginCompleted for '\(mediaSourceId)', triggering refresh...")
                MediaSourceContextProvider.shared.refreshSource(id: mediaSourceId)
            }
        }
    }

    func stopAllTimers() {
        let count = self.refreshTimers.count
        logger.info("Stopping all timers (\(count) active)")
        for (key, timer) in self.refreshTimers {
            timer.invalidate()
            logger.debug("Invalidated timer: \(key)")
        }
        self.refreshTimers.removeAll()
    }

    @MainActor
    private func refreshFromModelContext() {
        guard let modelContext else {
            logger.warning("refreshFromModelContext called but no modelContext set")
            return
        }
        let descriptor = FetchDescriptor<MediaSource>()
        let mediaSources = (try? modelContext.fetch(descriptor)) ?? []
        logger.info("Fetched \(mediaSources.count) media mediaSource(s) from ModelContext")
        self.startMonitoring(mediaSources: mediaSources)
    }

    @MainActor
    private func refreshSource(id mediaSourceId: String) {
        guard let modelContext else {
            logger.warning("refreshSource called but no modelContext set")
            return
        }
        let descriptor = FetchDescriptor<MediaSource>()
        let mediaSources = (try? modelContext.fetch(descriptor)) ?? []
        guard let mediaSource = mediaSources.first(where: { $0.id == mediaSourceId }) else {
            logger.warning("refreshSource: no mediaSource found with id '\(mediaSourceId)'")
            return
        }

        let config = mediaSource.config
        guard let parses = config.parse, !parses.isEmpty else {
            logger.debug("refreshSource: mediaSource '\(mediaSourceId)' has no parses configured")
            return
        }

        logger.info("Refreshing mediaSource '\(mediaSourceId)' with \(parses.count) parse(s) after login")
        for parse in parses {
            self.enqueueRefresh(mediaSourceId: config.id, parse: parse, customUserAgent: config.customUserAgent)
        }
    }

    @MainActor
    private func startMonitoring(mediaSources: [MediaSource]) {
        logger.info("startMonitoring called with \(mediaSources.count) mediaSource(s)")

        self.stopAllTimers()
        self.pendingWork.removeAll()
        self.tearDownWebView()
        self.isProcessing = false

        for mediaSource in mediaSources {
            let config = mediaSource.config
            guard let parses = config.parse, !parses.isEmpty else {
                logger.debug("Skipping mediaSource '\(config.name)': no parses configured")
                continue
            }

            logger.info("Source '\(config.name)' has \(parses.count) parse(s)")

            for parse in parses {
                let timerKey = "\(config.id)|\(parse.url)"

                logger.info("Enqueueing immediate refresh for '\(config.id)' -> \(parse.url) with \(parse.userScripts.count) script(s)")
                self.enqueueRefresh(mediaSourceId: config.id, parse: parse, customUserAgent: config.customUserAgent)

                let interval = TimeInterval(parse.intervalSeconds)
                let mediaSourceId = config.id
                let customUserAgent = config.customUserAgent
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    MainActor.assumeIsolated {
                        logger.info("Timer fired: recurring refresh for '\(mediaSourceId)' -> \(parse.url)")
                        MediaSourceContextProvider.shared.enqueueRefresh(mediaSourceId: mediaSourceId, parse: parse, customUserAgent: customUserAgent)
                    }
                }
                self.refreshTimers[timerKey] = timer
                logger.info("Scheduled recurring refresh for '\(config.id)' at \(parse.url) every \(parse.intervalSeconds)s")
            }
        }

        let queueCount = self.pendingWork.count
        let timerCount = self.refreshTimers.count
        logger.info("Monitoring setup complete. \(queueCount) item(s) in queue, \(timerCount) timer(s) active")
    }

    @MainActor
    private func enqueueRefresh(mediaSourceId: String, parse: Parse, customUserAgent: String?) {
        let workItem = RefreshWorkItem(mediaSourceId: mediaSourceId, parse: parse, customUserAgent: customUserAgent)
        self.pendingWork.append(workItem)
        let queueSize = self.pendingWork.count
        let processing = self.isProcessing
        logger.debug("Enqueued refresh for '\(mediaSourceId)'. Queue size: \(queueSize), isProcessing: \(processing)")
        self.processNextIfIdle()
    }

    @MainActor
    private func processNextIfIdle() {
        guard !self.isProcessing else {
            let waiting = self.pendingWork.count
            logger.debug("Queue processor busy, \(waiting) item(s) waiting")
            return
        }
        guard let workItem = pendingWork.first else {
            logger.debug("Queue empty, nothing to process")
            return
        }
        self.pendingWork.removeFirst()
        self.isProcessing = true
        self.currentMediaSourceId = workItem.mediaSourceId

        guard let url = URL(string: workItem.parse.url) else {
            logger.error("Invalid refresh URL: '\(workItem.parse.url)' for '\(workItem.mediaSourceId)'")
            self.completeCurrentWork()
            return
        }

        logger.info("Processing: '\(workItem.mediaSourceId)' -> \(url.absoluteString) with \(workItem.parse.userScripts.count) script(s)")
        self.loadRefreshURL(url: url, scripts: workItem.parse.userScripts, mediaSourceId: workItem.mediaSourceId, customUserAgent: workItem.customUserAgent)
    }

    @MainActor
    private func completeCurrentWork() {
        self.timeoutTask?.cancel()
        self.timeoutTask = nil
        self.tearDownWebView()
        self.isProcessing = false
        self.currentMediaSourceId = nil
        let remaining = self.pendingWork.count
        logger.debug("Work item complete. \(remaining) item(s) remaining.")
        self.processNextIfIdle()
    }

    @MainActor
    private func loadRefreshURL(url: URL, scripts: [Script], mediaSourceId: String, customUserAgent: String?) {
        let webView = WebViewFactory.makeWebView(
            scripts: scripts,
            contractScript: self.buildContractScript(),
            messageHandler: self,
            messageHandlerName: Self.messageHandlerName,
            customUserAgent: customUserAgent
        )

        self.activeWebView = webView

        let timeout = Self.refreshTimeoutSeconds
        self.timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            logger.warning("Timeout (\(timeout)s) for '\(mediaSourceId)'. Moving on.")
            MediaSourceContextProvider.shared.completeCurrentWork()
        }

        let urlStr = url.absoluteString
        logger.info("Loading: \(urlStr) (timeout: \(timeout)s)")
        webView.load(URLRequest(url: url))
    }

    private func buildContractScript() -> String {
        """
        (function() {
            window.boppaMediaSourceContextDone = function() {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({
                    type: 'done'
                });
            };
            window.boppaSetMediaSourceContextValues = function(values) {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({
                    type: 'contextValues',
                    values: values
                });
            };
        })();
        """
    }

    private func tearDownWebView() {
        if let webView = activeWebView {
            logger.debug("Tearing down WebView")
            webView.stopLoading()
            webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
        }
        self.activeWebView = nil
    }

    @MainActor
    private func handleDoneMessage() {
        logger.info("boppaMediaSourceContextDone signaled. Completing work item.")
        self.completeCurrentWork()
    }

    @MainActor
    private func handleContextValues(_ values: [String: Any]) {
        guard let mediaSourceId = self.currentMediaSourceId else {
            logger.warning("Received contextValues but no current mediaSource id")
            return
        }
        guard let modelContext else {
            logger.warning("Received contextValues but no modelContext")
            return
        }

        let descriptor = FetchDescriptor<MediaSource>()
        guard let mediaSources = try? modelContext.fetch(descriptor),
              let mediaSource = mediaSources.first(where: { $0.id == mediaSourceId })
        else {
            logger.warning("Could not find MediaSource '\(mediaSourceId)' to store context values")
            return
        }

        for (key, value) in values {
            if let stringValue = value as? String {
                mediaSource.contextValues[key] = stringValue
            } else {
                mediaSource.contextValues[key] = String(describing: value)
            }
        }

        try? modelContext.save()
        logger.info("Stored \(values.count) context value(s) for '\(mediaSourceId)'")
    }
}

extension MediaSourceContextProvider: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        MainActor.assumeIsolated {
            guard message.name == Self.messageHandlerName else { return }

            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else {
                let bodyDesc = String(describing: message.body)
                logger.warning("Received message with unexpected body format: \(bodyDesc)")
                return
            }

            switch type {
            case "done":
                self.handleDoneMessage()

            case "contextValues":
                if let values = body["values"] as? [String: Any] {
                    self.handleContextValues(values)
                } else {
                    logger.warning("contextValues message missing 'values' dictionary")
                }

            default:
                logger.warning("Unknown message type: \(type)")
            }
        }
    }
}

private struct RefreshWorkItem {
    let mediaSourceId: String
    let parse: Parse
    let customUserAgent: String?
}
