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
    subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
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
            guard let mediaSourceName = notification.userInfo?["mediaSourceName"] as? String else { return }
            MainActor.assumeIsolated {
                logger.info("Received mediaSourceLoginCompleted for '\(mediaSourceName)', triggering refresh...")
                MediaSourceContextProvider.shared.refreshSource(named: mediaSourceName)
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
        let sources = (try? modelContext.fetch(descriptor)) ?? []
        logger.info("Fetched \(sources.count) media source(s) from ModelContext")
        self.startMonitoring(sources: sources)
    }

    @MainActor
    private func refreshSource(named sourceName: String) {
        guard let modelContext else {
            logger.warning("refreshSource called but no modelContext set")
            return
        }
        let descriptor = FetchDescriptor<MediaSource>()
        let sources = (try? modelContext.fetch(descriptor)) ?? []
        guard let source = sources.first(where: { $0.name == sourceName }) else {
            logger.warning("refreshSource: no source found with name '\(sourceName)'")
            return
        }

        let config = source.config
        guard let parses = config.parse, !parses.isEmpty else {
            logger.debug("refreshSource: source '\(sourceName)' has no parses configured")
            return
        }

        logger.info("Refreshing source '\(sourceName)' with \(parses.count) parse(s) after login")
        for parse in parses {
            self.enqueueRefresh(sourceName: config.name, parse: parse, customUserAgent: config.customUserAgent)
        }
    }

    @MainActor
    private func startMonitoring(sources: [MediaSource]) {
        logger.info("startMonitoring called with \(sources.count) source(s)")

        self.stopAllTimers()
        self.pendingWork.removeAll()
        self.tearDownWebView()
        self.isProcessing = false

        for source in sources {
            let config = source.config
            guard let parses = config.parse, !parses.isEmpty else {
                logger.debug("Skipping source '\(config.name)': no parses configured")
                continue
            }

            logger.info("Source '\(config.name)' has \(parses.count) parse(s)")

            for parse in parses {
                let timerKey = "\(config.name)|\(parse.url)"

                logger.info("Enqueueing immediate refresh for '\(config.name)' -> \(parse.url) with \(parse.userScripts.count) script(s)")
                self.enqueueRefresh(sourceName: config.name, parse: parse, customUserAgent: config.customUserAgent)

                let interval = TimeInterval(parse.intervalSeconds)
                let sourceName = config.name
                let customUserAgent = config.customUserAgent
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    MainActor.assumeIsolated {
                        logger.info("Timer fired: recurring refresh for '\(sourceName)' -> \(parse.url)")
                        MediaSourceContextProvider.shared.enqueueRefresh(sourceName: sourceName, parse: parse, customUserAgent: customUserAgent)
                    }
                }
                self.refreshTimers[timerKey] = timer
                logger.info("Scheduled recurring refresh for '\(config.name)' at \(parse.url) every \(parse.intervalSeconds)s")
            }
        }

        let queueCount = self.pendingWork.count
        let timerCount = self.refreshTimers.count
        logger.info("Monitoring setup complete. \(queueCount) item(s) in queue, \(timerCount) timer(s) active")
    }

    @MainActor
    private func enqueueRefresh(sourceName: String, parse: Parse, customUserAgent: String?) {
        let workItem = RefreshWorkItem(sourceName: sourceName, parse: parse, customUserAgent: customUserAgent)
        self.pendingWork.append(workItem)
        let queueSize = self.pendingWork.count
        let processing = self.isProcessing
        logger.debug("Enqueued refresh for '\(sourceName)'. Queue size: \(queueSize), isProcessing: \(processing)")
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

        guard let url = URL(string: workItem.parse.url) else {
            logger.error("Invalid refresh URL: '\(workItem.parse.url)' for '\(workItem.sourceName)'")
            self.completeCurrentWork()
            return
        }

        logger.info("Processing: '\(workItem.sourceName)' -> \(url.absoluteString) with \(workItem.parse.userScripts.count) script(s)")
        self.loadRefreshURL(url: url, scripts: workItem.parse.userScripts, sourceName: workItem.sourceName, customUserAgent: workItem.customUserAgent)
    }

    @MainActor
    private func completeCurrentWork() {
        self.timeoutTask?.cancel()
        self.timeoutTask = nil
        self.tearDownWebView()
        self.isProcessing = false
        let remaining = self.pendingWork.count
        logger.debug("Work item complete. \(remaining) item(s) remaining.")
        self.processNextIfIdle()
    }

    @MainActor
    private func loadRefreshURL(url: URL, scripts: [Script], sourceName: String, customUserAgent: String?) {
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
            logger.warning("Timeout (\(timeout)s) for '\(sourceName)'. Moving on.")
            MediaSourceContextProvider.shared.completeCurrentWork()
        }

        let urlStr = url.absoluteString
        logger.info("Loading: \(urlStr) (timeout: \(timeout)s)")
        webView.load(URLRequest(url: url))
    }

    private func buildContractScript() -> String {
        """
        (function() {
            window.bopBrowserMediaContextDone = function() {
                window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({
                    type: 'done'
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
        logger.info("bopBrowserMediaContextDone signaled. Completing work item.")
        self.completeCurrentWork()
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

            default:
                logger.warning("Unknown message type: \(type)")
            }
        }
    }
}

private struct RefreshWorkItem {
    let sourceName: String
    let parse: Parse
    let customUserAgent: String?
}
