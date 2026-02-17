import SwiftUI

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
