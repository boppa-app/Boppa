import SwiftUI

protocol CategoryBarItem: Hashable {
    var icon: String { get }
    var displayName: String { get }
}

/// Fixed layout metrics for CategoryBubblesBar, so screens can reserve space for it without
/// measuring. Lives outside the generic view because generic types can't hold static stored
/// properties.
enum CategoryBubblesBarMetrics {
    static let topPadding: CGFloat = 10
    /// Pinned to the 15pt system font's line height so the row height doesn't depend on layout.
    static let labelHeight: CGFloat = 18
    static let labelVerticalPadding: CGFloat = 6

    /// The opaque row: top padding plus one bubble.
    static let solidHeight: CGFloat = topPadding + labelHeight + 2 * labelVerticalPadding
    /// The solid row plus the trailing fade drawn when the search field isn't focused.
    static let totalHeight: CGFloat = solidHeight + EdgeFade.height
}

struct CategoryBubblesBar<Category: CategoryBarItem>: View {
    let categories: [Category]
    let selectedCategory: Category
    let scrollHandler: ScrollAwareVisibilityHandler
    var isFocused: Bool = false
    var highlightSelectedWhenFocused: Bool = false
    let onSelect: (Category) -> Void

    var body: some View {
        let fadeHeight = self.isFocused ? CGFloat(0) : EdgeFade.height

        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                HorizontalScrollFadeView {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(self.categories, id: \.self) { category in
                                Button {
                                    self.onSelect(category)
                                    withAnimation {
                                        proxy.scrollTo(category, anchor: .center)
                                    }
                                } label: {
                                    self.bubbleLabel(for: category)
                                }
                                .buttonStyle(.plain)
                                .id(category)
                                .accessibilityLabel(category.displayName)
                                .accessibilityHint(self
                                    .selectedCategory == category ? "Currently selected" :
                                    "Filter by \(category.displayName)")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, CategoryBubblesBarMetrics.topPadding)
            .background(Color.black)

            LinearGradient(
                colors: [.black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeHeight)
            .allowsHitTesting(false)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: self.scrollHandler.isHeaderVisible ? .infinity : 0,
            alignment: .top
        )
        .clipped()
        .allowsHitTesting(self.scrollHandler.isHeaderVisible)
    }

    private func bubbleLabel(for category: Category) -> some View {
        let isSelected = self
            .selectedCategory == category && (!self.isFocused || self.highlightSelectedWhenFocused)
        return HStack(spacing: 5) {
            Image(systemName: category.icon)
                .font(.system(size: 15))
            Text(category.displayName)
                .font(.system(size: 15, weight: .medium))
        }
        .frame(height: CategoryBubblesBarMetrics.labelHeight)
        .foregroundColor(isSelected ? .purp : Color(.systemGray))
        .padding(.horizontal, 12)
        .padding(.vertical, CategoryBubblesBarMetrics.labelVerticalPadding)
        .background(
            Capsule().fill(Color(.systemGray6).opacity(0.6))
                .overlay(Capsule().fill(Color.purp.opacity(isSelected ? 0.1 : 0)))
                .overlay(Capsule().strokeBorder(
                    isSelected ? Color.purp.opacity(0.5) : Color(.systemGray3),
                    lineWidth: 1.5
                ))
        )
    }
}
