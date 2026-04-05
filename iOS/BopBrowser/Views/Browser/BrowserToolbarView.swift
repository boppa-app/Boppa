import SwiftUI

struct BrowserToolbarView: View {
    @Bindable var viewModel: BrowserViewModel
    @FocusState.Binding var isURLFieldFocused: Bool
    @State private var urlText: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { self.viewModel.goBack() }) {
                Image(systemName: "arrow.backward")
                    .font(.title3)
            }
            .foregroundColor(self.viewModel.canGoBack ? Color.purp : Color(.systemGray))
            .disabled(!self.viewModel.canGoBack)

            Button(action: { self.viewModel.goForward() }) {
                Image(systemName: "arrow.forward")
                    .font(.title3)
            }
            .foregroundColor(self.viewModel.canGoForward ? Color.purp : Color(.systemGray))
            .disabled(!self.viewModel.canGoForward)

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: self.$urlText,
                    prompt: Text("Search or enter website name").foregroundColor(Color(.systemGray4))
                )
                .tint(Color.purp)
                .textFieldStyle(.plain)
                .foregroundColor(self.isURLFieldFocused ? Color.white : Color(.systemGray))
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused(self.$isURLFieldFocused)
                .onSubmit {
                    self.viewModel.loadURL(urlString: self.urlText)
                    self.isURLFieldFocused = false
                }
                .onChange(of: self.viewModel.currentURL) { _, newURL in
                    if !self.isURLFieldFocused {
                        self.urlText = newURL?.absoluteString ?? ""
                    }
                }
                .onAppear {
                    self.urlText = self.viewModel.currentURL?.absoluteString ?? ""
                }

                if self.isURLFieldFocused && !self.urlText.isEmpty {
                    Button {
                        self.urlText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(Color(.systemGray))
                    }
                }

                if self.viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            Button(action: {
                if self.viewModel.isLoading {
                    self.viewModel.stop()
                } else {
                    self.viewModel.refresh()
                }
            }) {
                Image(systemName: self.viewModel.isLoading ? "xmark" : "arrow.clockwise")
                    .font(.title3)
            }
            .foregroundColor(self.viewModel.currentURL != nil ? Color.purp : Color(.systemGray))
            .disabled(self.viewModel.currentURL == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // .background(Color(.systemBackground))
    }
}

#Preview {
    @Previewable @FocusState var isFocused: Bool
    BrowserToolbarView(viewModel: BrowserViewModel(), isURLFieldFocused: $isFocused)
}
