import SQLiteData
import SwiftUI
import UIKit

// TODO: Full JS errors for JS execution as well as capturing and emitting log statements

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        do {
            try prepareDependencies { dependencies in
                dependencies.defaultDatabase = try .appDatabase()
            }
        } catch {
            fatalError("Could not set up database: \(error)")
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        Task {
            // await AdBlockService.shared.loadContentRuleList()
            await ArtworkServer.shared.waitUntilReady()
            MediaSourceContextProvider.shared.startMonitoring()

            let rootView = ContentView()
                .preferredColorScheme(.dark)

            let hostingController = UIHostingController(rootView: rootView)
            let window = UIWindow(windowScene: windowScene)
            window.overrideUserInterfaceStyle = .dark
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
            self.window = window

            WebViewPlaybackEngineRegistry.shared.start()
        }
    }
}
