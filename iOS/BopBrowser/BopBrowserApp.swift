import os
import SwiftUI

@main
struct BopBrowserApp: App {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BopBrowser", category: "BopBrowserApp")

    @State private var adBlockService = AdBlockService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if adBlockService.isReady {
                    ContentView()
                        .preferredColorScheme(.dark)
                        .background(Color.black.ignoresSafeArea())
                        .tint(Color.accentColor)
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .task {
                await AdBlockService.shared.loadContentRuleList()
            }
        }
    }
}
