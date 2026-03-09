import SwiftUI
import WebKit

struct LoginWebView: View {
    let url: URL
    let customUserAgent: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LoginWebViewRepresentable(url: self.url, customUserAgent: self.customUserAgent)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Login")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            WebDataStore.shared.forceSyncCookies()
                            self.dismiss()
                        }
                        .foregroundColor(Color.purp)
                    }
                    .sharedBackgroundVisibilityIfAvailable(.hidden)
                }
        }
    }
}

private struct LoginWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let customUserAgent: String?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WebViewFactory.makeWebView(
            customUserAgent: self.customUserAgent,
            isHidden: false
        )
        webView.scrollView.isScrollEnabled = true
        webView.allowsBackForwardNavigationGestures = true
        webView.transform = .identity
        webView.frame = .zero
        webView.load(URLRequest(url: self.url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
