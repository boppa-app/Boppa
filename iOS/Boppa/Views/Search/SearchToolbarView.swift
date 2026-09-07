import SwiftUI
import UIKit

struct SearchToolbarView: View {
    @Bindable var viewModel: SearchViewModel
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var onSearch: (() -> Void)?

    @State private var isMediaSourcePickerVisible = false

    private static let searchBarHeight: CGFloat = 44

    private var searchPrompt: String {
        guard let mediaSource = self.viewModel.selectedMediaSource else {
            return "Search"
        }

        return "Search for media on \"\(mediaSource.config.name)\""
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                self.mediaSourcePickerButton

                HStack(spacing: 8) {
                    TextField(
                        "",
                        text: self.$viewModel.searchQuery,
                        prompt: Text(self.searchPrompt).foregroundColor(Color(.systemGray4))
                    )
                    .tint(Color.purp)
                    .textFieldStyle(.plain)
                    .foregroundColor(self.isSearchFieldFocused.wrappedValue ? Color
                        .white : Color(.systemGray))
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused(self.isSearchFieldFocused)
                    .onSubmit {
                        self.viewModel.search()
                        self.onSearch?()
                        self.isSearchFieldFocused.wrappedValue = false
                    }
                    .accessibilityLabel(self.searchPrompt)

                    if self.viewModel.isQueryActive {
                        Button {
                            self.viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16))
                                .foregroundColor(Color(.systemGray))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear Search")
                        .accessibilityHint("Clear the current search query")
                    }
                }
                .padding(.trailing, 12)
                .padding(.vertical, 10)
            }
            .frame(height: Self.searchBarHeight)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            if self.isSearchFieldFocused.wrappedValue {
                Button("Cancel") {
                    self.viewModel.cancelMediaSourceSwitchIfNeeded()
                    self.isSearchFieldFocused.wrappedValue = false
                }
                .buttonStyle(.plain)
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
            self.viewModel
                .beginMediaSourceSwitch(isEditingSearch: self.isSearchFieldFocused.wrappedValue)
            self.viewModel.showMediaSourcePicker = true
        } label: {
            HStack(spacing: 8) {
                if self.viewModel.isSearching {
                    SpinnerView(
                        tint: self.isSearchFieldFocused
                            .wrappedValue ? .white : Color(.systemGray),
                        lineWidth: 2.5
                    )
                    .frame(width: 16, height: 16)
                    .frame(width: 24, height: 24)
                } else if let mediaSource = self.viewModel.selectedMediaSource,
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

                Image(systemName: self.isMediaSourcePickerVisible
                    ? "circle.grid.2x2.fill" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.purp)
                    .contentTransition(.symbolEffect(.replace, options: .speed(3)))
                    .animation(.easeInOut(duration: 0.1), value: self.isMediaSourcePickerVisible)
            }
            .padding(.horizontal, 8)
            .frame(height: Self.searchBarHeight)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(Color(.systemGray5).opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(self.viewModel.selectedMediaSource
            .map { "Selected source: \($0.config.name)" } ?? "Select Media Source")
        .accessibilityHint("Choose which media source to search")
        .onChange(of: self.viewModel.showMediaSourcePicker) { _, isPresented in
            self.isMediaSourcePickerVisible = isPresented
        }
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
            .background(
                SheetDismissDelegateBridge(
                    onWillDismiss: { self.isMediaSourcePickerVisible = false },
                    onDidDismiss: { self.viewModel.showMediaSourcePicker = false }
                )
            )
        }
    }
}

private struct SheetDismissDelegateBridge: UIViewControllerRepresentable {
    var onWillDismiss: () -> Void
    var onDidDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            var candidate = uiViewController.parent
            while let current = candidate, current.presentingViewController == nil {
                candidate = current.parent
            }
            candidate?.presentationController?.delegate = context.coordinator
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onWillDismiss: self.onWillDismiss, onDidDismiss: self.onDidDismiss)
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        private let onWillDismiss: () -> Void
        private let onDidDismiss: () -> Void

        init(onWillDismiss: @escaping () -> Void, onDidDismiss: @escaping () -> Void) {
            self.onWillDismiss = onWillDismiss
            self.onDidDismiss = onDidDismiss
        }

        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            self.onWillDismiss()
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            self.onDidDismiss()
        }
    }
}
