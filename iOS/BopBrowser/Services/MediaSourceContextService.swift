import Foundation
import os
import SwiftData
import WebKit

extension Notification.Name {
    static let mediaSourcesDidChange = Notification.Name("mediaSourcesDidChange")
}

@Observable
@MainActor
final class MediaSourceContextService: NSObject {
    static let shared = MediaSourceContextService()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser",
        category: "MediaSourceContextService"
    )

    private static let refreshTimeoutSeconds: TimeInterval = 15
    private static let messageHandlerName = "webViewCapture"

    private var capturedValues: [String: String] = [:]
    private var refreshTimers: [String: Timer] = [:]
    private var isProcessing = false
    private var pendingWork: [RefreshWorkItem] = []
    private var pendingKeyMappings: Set<String> = []
    private var activeWebView: WKWebView?
    private var timeoutTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private var mediaSourceObserver: NSObjectProtocol?

    override private init() {
        super.init()
        self.logger.info("MediaSourceContextService initialized")
    }

    func resolveConfigValue(keyMapping: KeyMapping) -> String? {
        return self.capturedValues[keyMapping.rawValue]
    }

    func startMonitoring(modelContainer: ModelContainer) {
        self.logger.info("MediaSourceContextService starting monitoring...")

        let context = ModelContext(modelContainer)
        self.modelContext = context
        self.refreshFromModelContext()

        self.mediaSourceObserver = NotificationCenter.default.addObserver(
            forName: .mediaSourcesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.info("Received mediaSourcesDidChange notification, refreshing...")
            self?.refreshFromModelContext()
        }
    }

    func stopAllTimers() {
        let count = self.refreshTimers.count
        self.logger.info("Stopping all timers (\(count) active)")
        for (key, timer) in self.refreshTimers {
            timer.invalidate()
            self.logger.debug("Invalidated timer: \(key)")
        }
        self.refreshTimers.removeAll()
    }

    private func refreshFromModelContext() {
        guard let modelContext else {
            self.logger.warning("refreshFromModelContext called but no modelContext set")
            return
        }
        let descriptor = FetchDescriptor<MediaSource>()
        let sources = (try? modelContext.fetch(descriptor)) ?? []
        self.logger.info("Fetched \(sources.count) media source(s) from ModelContext")
        self.startMonitoring(sources: sources)
    }

    private func startMonitoring(sources: [MediaSource]) {
        self.logger.info("startMonitoring called with \(sources.count) source(s)")

        self.stopAllTimers()
        self.capturedValues.removeAll()
        self.pendingWork.removeAll()
        self.tearDownWebView()
        self.isProcessing = false

        for source in sources {
            guard let config = source.config else {
                self.logger.debug("Skipping source '\(source.name)': unable to decode config")
                continue
            }
            guard let refreshUrls = config.refreshUrls, !refreshUrls.isEmpty else {
                self.logger.debug("Skipping source '\(config.name)': no refreshUrls configured")
                continue
            }

            self.logger.info("Source '\(config.name)' has \(refreshUrls.count) refreshUrl(s)")

            for refreshUrl in refreshUrls {
                let timerKey = "\(config.name)|\(refreshUrl.url)"

                self.logger.info("Enqueueing immediate refresh for '\(config.name)' -> \(refreshUrl.url) with \(refreshUrl.capture.count) capture rule(s)")
                self.enqueueRefresh(sourceName: config.name, refreshUrl: refreshUrl)

                let interval = TimeInterval(refreshUrl.intervalSeconds)
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.logger.info("Timer fired: recurring refresh for '\(config.name)' -> \(refreshUrl.url)")
                        self?.enqueueRefresh(sourceName: config.name, refreshUrl: refreshUrl)
                    }
                }
                self.refreshTimers[timerKey] = timer
                self.logger.info("Scheduled recurring refresh for '\(config.name)' at \(refreshUrl.url) every \(refreshUrl.intervalSeconds)s")
            }
        }

        let queueCount = self.pendingWork.count
        let timerCount = self.refreshTimers.count
        self.logger.info("Monitoring setup complete. \(queueCount) item(s) in queue, \(timerCount) timer(s) active")
    }

    private func enqueueRefresh(sourceName: String, refreshUrl: RefreshUrl) {
        let workItem = RefreshWorkItem(sourceName: sourceName, refreshUrl: refreshUrl)
        self.pendingWork.append(workItem)
        let queueSize = self.pendingWork.count
        let processing = self.isProcessing
        self.logger.debug("Enqueued refresh for '\(sourceName)'. Queue size: \(queueSize), isProcessing: \(processing)")
        self.processNextIfIdle()
    }

    private func processNextIfIdle() {
        guard !self.isProcessing else {
            let waiting = self.pendingWork.count
            self.logger.debug("Queue processor busy, \(waiting) item(s) waiting")
            return
        }
        guard let workItem = pendingWork.first else {
            self.logger.debug("Queue empty, nothing to process")
            return
        }
        self.pendingWork.removeFirst()
        self.isProcessing = true

        guard let url = URL(string: workItem.refreshUrl.url) else {
            self.logger.error("Invalid refresh URL: '\(workItem.refreshUrl.url)' for '\(workItem.sourceName)'")
            self.completeCurrentWork()
            return
        }

        self.pendingKeyMappings = Set(workItem.refreshUrl.capture.map(\.keyMapping.rawValue))
        let mappings = self.pendingKeyMappings.joined(separator: ", ")
        self.logger.info("Processing: '\(workItem.sourceName)' -> \(url.absoluteString). Expecting: [\(mappings)]")

        self.loadRefreshURL(url: url, captures: workItem.refreshUrl.capture, sourceName: workItem.sourceName)
    }

    private func completeCurrentWork() {
        self.timeoutTask?.cancel()
        self.timeoutTask = nil
        self.tearDownWebView()
        self.pendingKeyMappings.removeAll()
        self.isProcessing = false
        let remaining = self.pendingWork.count
        let allKeys = self.capturedValues.keys.joined(separator: ", ")
        self.logger.debug("Work item complete. \(remaining) item(s) remaining. All captured keys: [\(allKeys)]")
        self.processNextIfIdle()
    }

    private func loadRefreshURL(url: URL, captures: [QueryParameterCapture], sourceName: String) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WebDataStore.shared.getDataStore()

        let userContentController = WKUserContentController()
        userContentController.addUserScript(getNetworkCaptureScript(captures: captures, messageHandlerName: Self.messageHandlerName))
        userContentController.add(self, name: Self.messageHandlerName)
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
        webView.isHidden = true
        self.activeWebView = webView

        let timeout = Self.refreshTimeoutSeconds
        self.timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard let self, !Task.isCancelled else { return }
            let missing = self.pendingKeyMappings.joined(separator: ", ")
            self.logger.warning("Timeout (\(timeout)s) for '\(sourceName)'. Still missing: [\(missing)]. Moving on.")
            self.completeCurrentWork()
        }

        let urlStr = url.absoluteString
        self.logger.info("Loading: \(urlStr) (timeout: \(timeout)s)")
        webView.load(URLRequest(url: url))
    }

    private func tearDownWebView() {
        if let webView = activeWebView {
            self.logger.debug("Tearing down WebView")
            webView.stopLoading()
            webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
        }
        self.activeWebView = nil
    }

    private func handleCapture(keyMapping: String, value: String) {
        let previousValue = self.capturedValues[keyMapping]
        self.capturedValues[keyMapping] = value

        if previousValue == nil {
            self.logger.info("NEW capture: \(keyMapping) = \(value)")
        } else if previousValue != value {
            self.logger.info("UPDATED capture: \(keyMapping) = \(value) (was: \(previousValue ?? "nil"))")
        } else {
            self.logger.debug("Duplicate capture (unchanged): \(keyMapping) = \(value)")
        }

        self.pendingKeyMappings.remove(keyMapping)

        if self.pendingKeyMappings.isEmpty {
            self.logger.info("All expected captures received! Completing early.")
            self.completeCurrentWork()
        } else {
            let remaining = self.pendingKeyMappings.joined(separator: ", ")
            self.logger.debug("Still waiting for: \(remaining)")
        }
    }
}

extension MediaSourceContextService: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageHandlerName else { return }

        guard let body = message.body as? [String: String],
              let keyMapping = body["keyMapping"],
              let value = body["value"]
        else {
            let bodyDesc = String(describing: message.body)
            Task { @MainActor in
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser", category: "MediaSourceContextService")
                    .warning("Received message with unexpected body format: \(bodyDesc)")
            }
            return
        }

        Task { @MainActor [weak self] in
            self?.handleCapture(keyMapping: keyMapping, value: value)
        }
    }
}

private struct RefreshWorkItem {
    let sourceName: String
    let refreshUrl: RefreshUrl
}
