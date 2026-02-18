import SwiftUI

struct BrowserToolbarView: View {
    @Bindable var viewModel: BrowserViewModel
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.goBack() }) {
                Image(systemName: "arrow.backward")
                    .font(.title3)
            }
            .disabled(!viewModel.canGoBack)

            Button(action: { viewModel.goForward() }) {
                Image(systemName: "arrow.forward")
                    .font(.title3)
            }
            .disabled(!viewModel.canGoForward)

            HStack(spacing: 8) {
                TextField("Enter URL", text: $urlText)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($isURLFieldFocused)
                    .onSubmit {
                        viewModel.loadURL(urlString: urlText)
                        isURLFieldFocused = false
                    }
                    .onChange(of: viewModel.currentURL) { _, newURL in
                        if !isURLFieldFocused {
                            urlText = newURL?.absoluteString ?? ""
                        }
                    }
                    .onAppear {
                        urlText = viewModel.currentURL?.absoluteString ?? ""
                    }

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            Button(action: {
                if viewModel.isLoading {
                    viewModel.stop()
                } else {
                    viewModel.refresh()
                }
            }) {
                Image(systemName: viewModel.isLoading ? "xmark" : "arrow.clockwise")
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

#Preview {
    BrowserToolbarView(viewModel: BrowserViewModel())
}
