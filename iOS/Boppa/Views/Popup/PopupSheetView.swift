import SwiftUI
import WebKit

struct PopupSheetView: View {
    let title: String
    let webView: WKWebView
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            PopupWebViewRepresentable(webView: self.webView)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(self.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(self.title)
                            .fontWeight(.semibold)
                    }
                    .sharedBackgroundVisibilityIfAvailable(.hidden)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: self.onDone) {
                            Image(systemName: "door.left.hand.open")
                                .foregroundColor(Color.purp)
                        }
                        .buttonStyle(.plain)
                    }
                    .sharedBackgroundVisibilityIfAvailable(.hidden)
                }
        }
    }
}

private struct PopupWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        self.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
