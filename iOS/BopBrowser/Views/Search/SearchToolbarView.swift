import SwiftData
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
                .frame(width: 20, height: 20)

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

                if self.isSearchFieldFocused.wrappedValue && self.viewModel.isQueryActive {
                    Button {
                        self.viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(Color(.systemGray))
                    }
                }

                self.mediaSourcePickerButton
                    .opacity(self.isSearchFieldFocused.wrappedValue ? 1.0 : 0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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
                    .clipShape(Circle())
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(Color.purp)
                    .frame(width: 24, height: 24)
            }
        }
        .sheet(isPresented: self.$viewModel.showMediaSourcePicker) {
            MediaSourcePickerSheet(
                mediaSources: self.viewModel.mediaSources,
                mediaSourcePickerMode: .single(
                    selectedID: self.viewModel.selectedMediaSource?.persistentModelID,
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
