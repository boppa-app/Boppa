import SwiftUI
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
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
            await AdBlockService.shared.loadContentRuleList()

            let rootView = ContentView()
                .preferredColorScheme(.dark)
                .background(Color.black.ignoresSafeArea())
                .tint(Color.accentColor)

            let hostingController = UIHostingController(rootView: rootView)
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
            self.window = window
        }
    }
}
