import SwiftUI

struct MinifiedBrowserToolbarView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { self.viewModel.goBack() }) {
                Image(systemName: "arrow.backward")
                    .font(.caption)
            }
            .foregroundColor(self.viewModel.canGoBack ? Color.purp : Color(.systemGray))
            .disabled(!self.viewModel.canGoBack)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.viewModel.showBars()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color(.systemGray))

                    Text(self.viewModel.displayHost)
                        .font(.caption2)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)

                    if self.viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            Button(action: { self.viewModel.goForward() }) {
                Image(systemName: "arrow.forward")
                    .font(.caption)
            }
            .foregroundColor(self.viewModel.canGoForward ? Color.purp : Color(.systemGray))
            .disabled(!self.viewModel.canGoForward)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

#Preview {
    MinifiedBrowserToolbarView(viewModel: BrowserViewModel())
}
