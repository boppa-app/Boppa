import SwiftUI

private struct HorizontalFadeModifier: ViewModifier {
    @Binding var leftFade: CGFloat
    @Binding var rightFade: CGFloat
    let fadeWidth: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGPoint.self) { geometry in
                    CGPoint(x: geometry.contentOffset.x, y: geometry.contentSize.width - geometry.visibleRect.width)
                } action: { _, new in
                    let offsetX = new.x
                    let overflow = new.y
                    self.leftFade = min(offsetX / self.fadeWidth, 1)
                    self.rightFade = overflow > 0 ? min(max(overflow - offsetX, 0) / self.fadeWidth, 1) : 0
                }
        } else {
            content
        }
    }
}

struct SearchToolbarView: View {
    @Bindable var viewModel: SearchViewModel
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var onSearch: (() -> Void)?

    @State private var bubblesLeftFade: CGFloat = 0
    @State private var bubblesRightFade: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
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

            if self.viewModel.isQueryActive && !self.viewModel.availableCategories.isEmpty {
                self.categoryBubbles
            }
        }
    }

    private var categoryBubbles: some View {
        let fadeWidth: CGFloat = 40
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(self.viewModel.availableCategories, id: \.self) { category in
                        Button {
                            self.viewModel.selectCategory(category)
                            self.isSearchFieldFocused.wrappedValue = false
                            withAnimation {
                                proxy.scrollTo(category, anchor: .center)
                            }
                        } label: {
                            let isSelected = self.viewModel.selectedCategory == category
                            HStack(spacing: 5) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 13))
                                Text(category.rawValue.prefix(1).uppercased() + category.rawValue.dropFirst())
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(isSelected ? .purp : Color(.systemGray))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(Color(.systemGray6).opacity(0.6))
                                    .overlay(Capsule().fill(Color.purp.opacity(isSelected ? 0.1 : 0)))
                                    .overlay(Capsule().strokeBorder(isSelected ? Color.purp.opacity(0.5) : Color(.systemGray3), lineWidth: 2))
                            )
                        }
                        .buttonStyle(.plain)
                        .id(category)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 16)
        .modifier(HorizontalFadeModifier(
            leftFade: self.$bubblesLeftFade,
            rightFade: self.$bubblesRightFade,
            fadeWidth: fadeWidth
        ))
        .mask(
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(1 - self.bubblesLeftFade), .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
                Color.black
                LinearGradient(
                    colors: [.black, .black.opacity(1 - self.bubblesRightFade)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
            }
        )
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
