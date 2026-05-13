import SwiftUI
import WebKit

struct LoginWebView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: LoginWebViewModel

    var body: some View {
        NavigationStack {
            LoginWebViewRepresentable(url: self.viewModel.url, customUserAgent: self.viewModel.customUserAgent)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Login")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            self.viewModel.dismiss()
                        }
                        .foregroundColor(Color.purp)
                    }
                    .sharedBackgroundVisibilityIfAvailable(.hidden)
                }
                .onAppear {
                    self.viewModel.startMonitoring()
                }
                .onDisappear {
                    self.viewModel.stopMonitoring()
                }
                .onChange(of: self.viewModel.shouldDismiss) {
                    if self.viewModel.shouldDismiss {
                        self.dismiss()
                    }
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
