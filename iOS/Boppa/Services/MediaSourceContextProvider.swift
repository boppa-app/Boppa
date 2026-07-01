import Foundation
import os
import WebKit

extension Notification.Name {
    static let mediaSourceAdded = Notification.Name("mediaSourceAdded")
    static let mediaSourceRemoved = Notification.Name("mediaSourceRemoved")
    static let mediaSourceEnabled = Notification.Name("mediaSourceEnabled")
    static let mediaSourceDisabled = Notification.Name("mediaSourceDisabled")
}

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Boppa",
    category: "MediaSourceContextProvider"
)

@Observable
final class MediaSourceContextProvider: NSObject {
    static let shared = MediaSourceContextProvider()

    private static let refreshTimeoutSeconds: TimeInterval = 60
    private static let messageHandlerName = "contextCapture"

    private var refreshTimers: [String: Timer] = [:]
    private var isProcessing = false
    private var pendingWork: [RefreshWorkItem] = []
    private var activeWebView: WKWebView?
    private var timeoutTask: Task<Void, Never>?
    private var currentMediaSourceId: String?
    private var mediaSourceAddedObserver: NSObjectProtocol?
    private var mediaSourceRemovedObserver: NSObjectProtocol?

    override private init() {
        super.init()
        logger.info("MediaSourceContextProvider initialized")
    }

    @MainActor
    func startMonitoring() {
        logger.info("MediaSourceContextProvider starting monitoring...")

        self.refreshFromDatabase()

        self.mediaSourceAddedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceAdded,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                logger.info("Received mediaSourceAdded notification, refreshing...")
                MediaSourceContextProvider.shared.refreshFromDatabase()
            }
        }

        self.mediaSourceRemovedObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourceRemoved,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                logger.info("Received mediaSourceRemoved notification, refreshing...")
                MediaSourceContextProvider.shared.refreshFromDatabase()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .mediaSourceEnabled,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                logger.info("Received mediaSourceEnabled notification, refreshing...")
                MediaSourceContextProvider.shared.refreshFromDatabase()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .mediaSourceDisabled,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                logger.info("Received mediaSourceDisabled notification, refreshing...")
                MediaSourceContextProvider.shared.refreshFromDatabase()
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
    private func refreshFromDatabase() {
        let mediaSources = MediaSourceStorageManager.shared.fetchAll()
        logger.info("Fetched \(mediaSources.count) media source(s) from database")
        self.startMonitoring(mediaSources: mediaSources)
    }

    @MainActor
    private func startMonitoring(mediaSources: [MediaSource]) {
        logger.info("startMonitoring called with \(mediaSources.count) mediaSource(s)")

        self.timeoutTask?.cancel()
        self.timeoutTask = nil
        self.stopAllTimers()
        self.pendingWork.removeAll()
        self.tearDownWebView()
        self.isProcessing = false

        for mediaSource in mediaSources {
            let config = mediaSource.config
            guard let entries = config.context, !entries.isEmpty else {
                logger.debug("Skipping mediaSource '\(config.name)': no parses configured")
                continue
            }

            logger.info("Source '\(config.name)' has \(entries.count) parse(s)")

            for entry in entries {
                let timerKey = "\(config.id)|\(entry.url)"

                logger.info("Enqueueing immediate refresh for '\(config.id)' -> \(entry.url) with \(entry.userScripts.count) script(s)")
                self.enqueueRefresh(mediaSourceId: config.id, context: entry, customUserAgent: config.customUserAgent)

                let interval = TimeInterval(entry.intervalSeconds)
                let mediaSourceId = config.id
                let customUserAgent = config.customUserAgent
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    MainActor.assumeIsolated {
                        logger.info("Timer fired: recurring refresh for '\(mediaSourceId)' -> \(entry.url)")
                        MediaSourceContextProvider.shared.enqueueRefresh(mediaSourceId: mediaSourceId, context: entry, customUserAgent: customUserAgent)
                    }
                }
                self.refreshTimers[timerKey] = timer
                logger.info("Scheduled recurring refresh for '\(config.id)' at \(entry.url) every \(entry.intervalSeconds)s")
            }
        }

        let queueCount = self.pendingWork.count
        let timerCount = self.refreshTimers.count
        logger.info("Monitoring setup complete. \(queueCount) item(s) in queue, \(timerCount) timer(s) active")
    }

    @MainActor
    private func enqueueRefresh(mediaSourceId: String, context: ContextConfig, customUserAgent: String?) {
        let workItem = RefreshWorkItem(mediaSourceId: mediaSourceId, context: context, customUserAgent: customUserAgent)
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

        guard let url = URL(string: workItem.context.url) else {
            logger.error("Invalid refresh URL: '\(workItem.context.url)' for '\(workItem.mediaSourceId)'")
            self.completeCurrentWork()
            return
        }

        logger.info("Processing: '\(workItem.mediaSourceId)' -> \(url.absoluteString) with \(workItem.context.userScripts.count) script(s)")
        self.loadRefreshURL(url: url, scripts: workItem.context.userScripts, mediaSourceId: workItem.mediaSourceId, customUserAgent: workItem.customUserAgent)
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
        self.startTimeout(for: mediaSourceId)

        logger.info("Loading: \(url.absoluteString) (timeout: \(Self.refreshTimeoutSeconds)s)")
        webView.load(URLRequest(url: url))
    }

    @MainActor
    private func startTimeout(for mediaSourceId: String) {
        let timeout = Self.refreshTimeoutSeconds
        self.timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            logger.warning("Timeout (\(timeout)s) for '\(mediaSourceId)'. Moving on.")
            MediaSourceContextProvider.shared.completeCurrentWork()
        }
    }

    @MainActor
    private func handlePopupRequest(id: String) {
        guard let mediaSourceId = self.currentMediaSourceId else {
            logger.warning("Popup requested but no current mediaSource id")
            return
        }

        let mediaSources = MediaSourceStorageManager.shared.fetchAll()
        guard let mediaSource = mediaSources.first(where: { $0.id == mediaSourceId }),
              let popupConfig = mediaSource.config.popup?[id]
        else {
            logger.warning("No popup config '\(id)' found for mediaSource '\(mediaSourceId)'")
            return
        }

        self.timeoutTask?.cancel()
        self.timeoutTask = nil

        PopupManager.shared.showPopup(
            config: popupConfig,
            customUserAgent: mediaSource.config.customUserAgent,
            onDismiss: { [weak self] in
                guard let self else { return }
                self.activeWebView?.reload()
                self.startTimeout(for: mediaSourceId)
            }
        )
    }

    private func buildContractScript() -> String {
        """
        (function() {
            window.boppaMediaSourceContextDone = function() {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({ type: 'done' });
            };
            window.boppaSetMediaSourceContextValues = function(values) {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({ type: 'contextValues', values: values });
            };
            window.boppaPopup = function(id) {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({ type: 'popup', id: id });
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

        try? MediaSourceStorageManager.shared.mergeContextValues(id: mediaSourceId, newValues: values)
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

            case "popup":
                let id = body["id"] as? String ?? ""
                self.handlePopupRequest(id: id)

            default:
                logger.warning("Unknown message type: \(type)")
            }
        }
    }
}

private struct RefreshWorkItem {
    let mediaSourceId: String
    let context: ContextConfig
    let customUserAgent: String?
}
