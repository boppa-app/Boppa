import SwiftUI

struct SearchToolbarView: View {
    @Bindable var viewModel: SearchViewModel
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var onSearch: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Group {
                    if self.viewModel.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !self.viewModel.results.isEmpty {
                        Image(systemName: self.viewModel.selectedCategory.icon)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .foregroundColor(self.isSearchFieldFocused.wrappedValue ? Color.white : Color(.systemGray))
                .frame(width: 20, height: 24)

                TextField(
                    "",
                    text: self.$viewModel.searchQuery,
                    prompt: Text("Search for music").foregroundColor(Color(.systemGray4))
                )
                .tint(Color.purp)
                .textFieldStyle(.plain)
                .foregroundColor(self.isSearchFieldFocused.wrappedValue ? Color.white : Color(.systemGray))
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(self.isSearchFieldFocused)
                .onSubmit {
                    self.viewModel.search()
                    self.onSearch?()
                    self.isSearchFieldFocused.wrappedValue = false
                }
                .accessibilityLabel("Search for music")

                if self.isSearchFieldFocused.wrappedValue && self.viewModel.isQueryActive {
                    Button {
                        self.viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(Color(.systemGray))
                    }
                    .accessibilityLabel("Clear Search")
                    .accessibilityHint("Clear the current search query")
                }

                if !self.isSearchFieldFocused.wrappedValue {
                    self.mediaSourcePickerButton
                        .opacity(0.5)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            if self.isSearchFieldFocused.wrappedValue {
                Button("Cancel") {
                    self.isSearchFieldFocused.wrappedValue = false
                }
                .foregroundColor(Color.purp)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .accessibilityLabel("Cancel")
                .accessibilityHint("Dismiss search")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: self.isSearchFieldFocused.wrappedValue)
        .padding(.horizontal, 16)
    }

    private var mediaSourcePickerButton: some View {
        Button {
            self.viewModel.showMediaSourcePicker = true
        } label: {
            if let mediaSource = self.viewModel.selectedMediaSource,
               let iconSvg = mediaSource.config.iconSvg
            {
                SVGImageView(svgString: iconSvg, size: 24)
                    .frame(width: 24, height: 24)
                    .clipShape(Rectangle())
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(Color.purp)
                    .frame(width: 24, height: 24)
            }
        }
        .accessibilityLabel(self.viewModel.selectedMediaSource.map { "Selected source: \($0.config.name)" } ?? "Select Media Source")
        .accessibilityHint("Choose which media source to search")
        .sheet(isPresented: self.$viewModel.showMediaSourcePicker) {
            MediaSourcePickerSheet(
                mediaSourcePickerMode: .single(
                    selectedID: self.viewModel.selectedMediaSource?.id,
                    onSelect: { mediaSource in
                        self.viewModel.selectMediaSource(mediaSource)
                    }
                )
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemGray6))
        }
    }
}
