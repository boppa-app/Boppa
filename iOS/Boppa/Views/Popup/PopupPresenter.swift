import SwiftUI

private struct PopupPresenterModifier: ViewModifier {
    private let popupManager = PopupManager.shared

    func body(content: Content) -> some View {
        content
            .sheet(item: Binding(
                get: { self.popupManager.activePopup },
                set: { newValue in
                    if newValue == nil {
                        self.popupManager.dismiss()
                    }
                }
            )) { popup in
                PopupSheetView(title: popup.title, webView: popup.webView) {
                    self.popupManager.dismiss()
                }
            }
    }
}

extension View {
    func popupPresenter() -> some View {
        self.modifier(PopupPresenterModifier())
    }
}
