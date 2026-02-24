import SwiftUI
import WebKit

struct LoginWebView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LoginWebViewRepresentable(url: self.url)
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

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WebDataStore.shared.getDataStore()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: self.url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
