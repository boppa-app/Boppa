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
                    isLoading: self.viewModel.isLoading,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.viewModel.clearPage()
                        }
                    }
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
        .ignoresSafeArea(edges: self.viewModel.barsHidden ? [.bottom] : [])
    }
}

private struct WebViewWrapper: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.addSubview(self.webView)
        self.webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.webView.topAnchor.constraint(equalTo: container.topAnchor),
            self.webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            self.webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            self.webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard self.webView.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        container.addSubview(self.webView)
        self.webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.webView.topAnchor.constraint(equalTo: container.topAnchor),
            self.webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            self.webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            self.webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        container.layoutIfNeeded()
    }
}

#Preview {
    BrowserView(viewModel: BrowserViewModel())
}
