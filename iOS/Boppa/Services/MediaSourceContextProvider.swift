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

enum MediaSourceContextError: LocalizedError {
    case failed(message: String?)

    var errorDescription: String? {
        switch self {
        case let .failed(message):
            return message ?? "Failed to gather context."
        }
    }
}

@Observable
final class MediaSourceContextProvider: NSObject {
    static let shared = MediaSourceContextProvider()

    private static let refreshTimeoutSeconds: TimeInterval = 60
    private static let messageHandlerName = "contextCapture"

    private var refreshTimers: [String: Timer] = [:]
    private var isProcessing = false
    private var pendingWork: [(mediaSourceId: String, url: URL, scripts: [Script], customUserAgent: String?)] = []
    private var activeWebView: WKWebView?
    private var timeoutTask: Task<Void, Never>?
    private var currentMediaSourceId: String?
    private var currentContextURL: String?
    private var mediaSourceAddedObserver: NSObjectProtocol?
    private var mediaSourceRemovedObserver: NSObjectProtocol?
    private var pendingContextURLs: [String: Set<String>] = [:]
    private var contextGatheredContinuations: [String: CheckedContinuation<Void, Error>] = [:]

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
    func refresh() {
        self.refreshFromDatabase()
    }

    @MainActor
    func waitForFirstContextGather(mediaSourceId: String) async throws {
        if MediaSourceStorageManager.shared.fetchOne(id: mediaSourceId)?.contextLastGatheredTimestamp != nil {
            return
        }
        try await withCheckedThrowingContinuation { continuation in
            self.contextGatheredContinuations[mediaSourceId] = continuation
        }
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
        self.pendingContextURLs.removeAll()

        for mediaSource in mediaSources {
            let config = mediaSource.config
            guard let entries = config.context, !entries.isEmpty else {
                logger.debug("Skipping mediaSource '\(config.name)': no context configured")
                continue
            }

            logger.info("Source '\(config.name)' has \(entries.count) context config(s)")

            self.pendingContextURLs[config.id] = Set(entries.map { $0.url })

            for entry in entries {
                guard let url = URL(string: entry.url) else {
                    logger.error("Invalid context URL '\(entry.url)' for '\(config.id)'")
                    continue
                }

                let timerKey = "\(config.id)|\(entry.url)"

                logger.info("Enqueueing immediate refresh for '\(config.id)' -> \(entry.url) with \(entry.userScripts.count) script(s)")
                self.enqueueRefresh(mediaSourceId: config.id, url: url, scripts: entry.userScripts, customUserAgent: entry.customUserAgent)

                let interval = TimeInterval(entry.intervalSeconds)
                let mediaSourceId = config.id
                let customUserAgent = entry.customUserAgent
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    MainActor.assumeIsolated {
                        logger.info("Timer fired: recurring refresh for '\(mediaSourceId)' -> \(entry.url)")
                        MediaSourceContextProvider.shared.enqueueRefresh(mediaSourceId: mediaSourceId, url: url, scripts: entry.userScripts, customUserAgent: customUserAgent)
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
    private func enqueueRefresh(mediaSourceId: String, url: URL, scripts: [Script], customUserAgent: String?) {
        self.pendingWork.append((mediaSourceId: mediaSourceId, url: url, scripts: scripts, customUserAgent: customUserAgent))
        let queueSize = self.pendingWork.count
        logger.debug("Enqueued refresh for '\(mediaSourceId)'. Queue size: \(queueSize), isProcessing: \(self.isProcessing)")
        self.processNextIfIdle()
    }

    @MainActor
    private func processNextIfIdle() {
        guard !self.isProcessing else {
            logger.debug("Queue processor busy, \(self.pendingWork.count) item(s) waiting")
            return
        }
        guard let item = self.pendingWork.first else {
            logger.debug("Queue empty, nothing to process")
            return
        }
        self.pendingWork.removeFirst()
        self.isProcessing = true
        self.currentMediaSourceId = item.mediaSourceId
        self.currentContextURL = item.url.absoluteString

        logger.info("Processing: '\(item.mediaSourceId)' -> \(item.url.absoluteString) with \(item.scripts.count) script(s)")
        self.loadRefreshURL(url: item.url, scripts: item.scripts, customUserAgent: item.customUserAgent)
    }

    @MainActor
    private func completeCurrentWork() {
        self.timeoutTask?.cancel()
        self.timeoutTask = nil
        self.tearDownWebView()
        self.isProcessing = false
        self.currentMediaSourceId = nil
        self.currentContextURL = nil
        let remaining = self.pendingWork.count
        logger.debug("Work item complete. \(remaining) item(s) remaining.")
        self.processNextIfIdle()
    }

    @MainActor
    private func loadRefreshURL(url: URL, scripts: [Script], customUserAgent: String?) {
        let webView = WebViewFactory.makeWebView(
            scripts: scripts,
            contractScript: self.buildContractScript(),
            messageHandler: self,
            messageHandlerName: Self.messageHandlerName,
            customUserAgent: customUserAgent
        )

        self.activeWebView = webView
        self.startTimeout()

        logger.info("Loading: \(url.absoluteString) (timeout: \(Self.refreshTimeoutSeconds)s)")
        webView.load(URLRequest(url: url))
    }

    @MainActor
    private func startTimeout() {
        let timeout = Self.refreshTimeoutSeconds
        let mediaSourceId = self.currentMediaSourceId ?? "unknown"
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
            onDismiss: { [weak self] in
                guard let self else { return }
                self.activeWebView?.reload()
                self.startTimeout()
            }
        )
    }

    private func buildContractScript() -> String {
        """
        (function() {
            window.boppaContextDone = function() {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({ type: 'contextDone' });
            };
            window.boppaSetContextValues = function(values) {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({ type: 'contextValues', values: values });
            };
            window.boppaContextFailed = function(message) {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({ type: 'contextFailed', message: message });
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
    private func handleContextDoneMessage() {
        logger.info("boppaContextDone signaled.")

        if let mediaSourceId = self.currentMediaSourceId,
           let contextURL = self.currentContextURL
        {
            self.pendingContextURLs[mediaSourceId]?.remove(contextURL)

            if self.pendingContextURLs[mediaSourceId]?.isEmpty == true {
                self.pendingContextURLs.removeValue(forKey: mediaSourceId)
                let isFirstGather = (try? MediaSourceStorageManager.shared.setContextLastGatheredTimestamp(id: mediaSourceId)) ?? false
                if isFirstGather, let continuation = self.contextGatheredContinuations.removeValue(forKey: mediaSourceId) {
                    logger.info("All context gathered for '\(mediaSourceId)' for the first time. Resuming continuation.")
                    continuation.resume(returning: ())
                } else {
                    logger.info("All context gathered for '\(mediaSourceId)'. Timestamp updated.")
                }
            }
        }

        self.completeCurrentWork()
    }

    @MainActor
    private func handleContextFailedMessage(message: String?) {
        logger.warning("boppaContextFailed signaled: \(message ?? "no message")")

        if let mediaSourceId = self.currentMediaSourceId {
            self.pendingContextURLs.removeValue(forKey: mediaSourceId)

            if let continuation = self.contextGatheredContinuations.removeValue(forKey: mediaSourceId) {
                continuation.resume(throwing: MediaSourceContextError.failed(message: message))
            }
        }

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
            case "contextDone":
                self.handleContextDoneMessage()

            case "contextValues":
                if let values = body["values"] as? [String: Any] {
                    self.handleContextValues(values)
                } else {
                    logger.warning("contextValues message missing 'values' dictionary")
                }

            case "contextFailed":
                let message = body["message"] as? String
                self.handleContextFailedMessage(message: message)

            case "popup":
                let id = body["id"] as? String ?? ""
                self.handlePopupRequest(id: id)

            default:
                logger.warning("Unknown message type: \(type)")
            }
        }
    }
}
