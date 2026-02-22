import SwiftUI
import WebKit

// TODO: Bottom menu bar:
//         * Add picture-in-picture enable/disable button (enabled: pip, greyed out. disabled: pip.fill, accent color)
//         * Add mobile/desktop mode which rotates view content 90 degrees (sf symbol: desktopcomputer / iphone.gen1)
// TODO: Central config for greyed out (unavailable) color
// TODO: URL bar extension when selected for input
// TODO: Hide menu bars when navigating in webview

struct BrowserView: View {
    @State private var viewModel = BrowserViewModel()

    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbarView(viewModel: self.viewModel)

            Rectangle().fill(Color(.systemGray6)).frame(height: 3)

            WebViewWrapper(webView: self.viewModel.webView)
        }
    }
}

private struct WebViewWrapper: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return self.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

#Preview {
    BrowserView()
}
