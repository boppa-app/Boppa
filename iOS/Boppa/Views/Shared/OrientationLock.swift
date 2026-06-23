import SwiftUI
import UIKit

final class OrientationLock {
    static let shared = OrientationLock()

    private(set) var mask: UIInterfaceOrientationMask = .portrait

    private init() {}

    func setAllowsLandscape(_ allowsLandscape: Bool) {
        self.mask = allowsLandscape ? .allButUpsideDown : .portrait

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

extension View {
    func allowsLandscape() -> some View {
        self
            .onAppear { OrientationLock.shared.setAllowsLandscape(true) }
            .onDisappear { OrientationLock.shared.setAllowsLandscape(false) }
    }
}
