import SwiftUI
import WebKit

// TODO: Bottom menu bar:
//         * Add picture-in-picture enable/disable button (enabled: pip, greyed out. disabled: pip.fill, accent color)
//         * Add mobile/desktop mode which rotates view content 90 degrees (sf symbol: desktopcomputer / iphone.gen1)
// TODO: Central config for greyed out (unavailable) color
// TODO: URL bar extension when selected for input
// TODO: Add settings page for browser whether to keep menu bars or hide them based on interaction.

struct BrowserView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            if !self.viewModel.barsHidden {
                BrowserToolbarView(viewModel: self.viewModel)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if self.viewModel.barsHidden {
                MinifiedBrowserToolbarView(
                    host: self.viewModel.displayHost,
                    isLoading: self.viewModel.isLoading
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.viewModel.showBars()
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            WebViewWrapper(webView: self.viewModel.webView)
                .allowsHitTesting(self.viewModel.currentURL != nil)
        }
        .animation(.easeInOut(duration: 0.3), value: self.viewModel.barsHidden)
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
    BrowserView(viewModel: BrowserViewModel())
}
