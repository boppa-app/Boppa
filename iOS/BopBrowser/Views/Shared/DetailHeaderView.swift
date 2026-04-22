import SwiftUI

struct DetailHeaderView<CenterLeadingContent: View, TrailingContent: View, CenterContent: View>: View {
    let title: String
    let highlightedTitle: String?
    let onBack: () -> Void
    @ViewBuilder let centerLeading: () -> CenterLeadingContent
    @ViewBuilder let trailing: () -> TrailingContent
    @ViewBuilder let centerTrailing: () -> CenterContent

    private var searchText: Binding<String>?
    private var showSearchBar: Binding<Bool>?
    private var searchPlaceholder: String
    private var isSearchFieldFocused: FocusState<Bool>.Binding?

    init(
        title: String,
        highlightedTitle: String? = nil,
        onBack: @escaping () -> Void,
        @ViewBuilder centerLeading: @escaping () -> CenterLeadingContent = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> TrailingContent = { EmptyView() },
        @ViewBuilder centerTrailing: @escaping () -> CenterContent = { EmptyView() },
        searchText: Binding<String>? = nil,
        showSearchBar: Binding<Bool>? = nil,
        searchPlaceholder: String = "Search",
        isSearchFieldFocused: FocusState<Bool>.Binding? = nil
    ) {
        self.title = title
        self.highlightedTitle = highlightedTitle
        self.onBack = onBack
        self.centerLeading = centerLeading
        self.trailing = trailing
        self.centerTrailing = centerTrailing
        self.searchText = searchText
        self.showSearchBar = showSearchBar
        self.searchPlaceholder = searchPlaceholder
        self.isSearchFieldFocused = isSearchFieldFocused
    }

    private let buttonWidth: CGFloat = 48
    private let progressViewSize: CGFloat = 20

    private var hasSearchBar: Bool {
        self.searchText != nil && self.showSearchBar != nil
    }

    private var isSearchBarVisible: Bool {
        self.showSearchBar?.wrappedValue ?? false
    }

    var body: some View {
        if self.hasSearchBar {
            ZStack(alignment: .top) {
                self.header
                self.searchBarView
            }
        } else {
            self.header
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let reservedPerSide = self.buttonWidth + self.progressViewSize * 1.5
                let maxTextWidth = max(geometry.size.width - reservedPerSide * 2, 0)

                ZStack {
                    HStack(spacing: 6) {
                        self.centerLeading()
                        MarqueeText(
                            self.title,
                            highlightedPrefix: self.highlightedTitle,
                            font: .headline,
                            fontWeight: .bold,
                            foregroundColor: .white,
                            maxWidth: maxTextWidth,
                            alignment: .center
                        )
                        self.centerTrailing()
                    }

                    HStack(spacing: 0) {
                        Button(action: self.onBack) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundColor(Color.purp)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }

                        Spacer()

                        self.trailing()
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(height: 44)

            if !self.isSearchBarVisible {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.5), location: 0),
                                .init(color: .clear, location: 0.5),
                                .init(color: .black.opacity(0.5), location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
            }
        }
    }

    @ViewBuilder
    private var searchBarView: some View {
        if let searchText = self.searchText,
           let showSearchBar = self.showSearchBar,
           let isSearchFieldFocused = self.isSearchFieldFocused
        {
            StoredSearchToolbar(
                searchText: searchText,
                showSearchBar: showSearchBar,
                placeholder: self.searchPlaceholder,
                isSearchFieldFocused: isSearchFieldFocused
            )
            .padding(.top, 40)
        }
    }
}
