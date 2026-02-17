import SwiftUI

@main
struct BopBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .background(Color.black.ignoresSafeArea())
                .tint(Color.accentColor)
        }
    }
}
