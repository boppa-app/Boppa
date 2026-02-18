import SwiftUI

// TODO: Add picture-in-picture enable/disable button, potentially in the toolbar (enabled: pip, greyed out. disabled: pip.fill, accent color)
// TODO: Add mobile/desktop mode which rotates toolbar 90 degrees
// TODO: Central config for greyed out (unavailable) color

struct BrowserView: View {
    @State private var viewModel = BrowserViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbarView(viewModel: viewModel)
            
            MusicWebView(
                url: viewModel.currentURL,
                delegate: viewModel
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    BrowserView()
}
