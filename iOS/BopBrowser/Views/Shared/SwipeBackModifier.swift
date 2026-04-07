import SwiftUI
import UIKit

private struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class SwipeBackController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            self.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

extension View {
    func enableSwipeBack() -> some View {
        self.background(SwipeBackGestureEnabler())
    }
}
