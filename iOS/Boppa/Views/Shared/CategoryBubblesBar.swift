import SwiftUI

protocol CategoryBarItem: Hashable {
    var icon: String { get }
    var displayName: String { get }
}

struct CategoryBubblesBar<Category: CategoryBarItem>: View {
    let categories: [Category]
    let selectedCategory: Category
    let scrollHandler: SearchBarScrollHandler
    var isFocused: Bool = false
    var highlightSelectedWhenFocused: Bool = false
    let onSelect: (Category) -> Void

    var body: some View {
        let fadeHeight = self.isFocused ? CGFloat(0) : self.scrollHandler.fadeHeight

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
                                .accessibilityHint(self.selectedCategory == category ? "Currently selected" : "Filter by \(category.displayName)")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 5)
            .background(Color.black)
            .background(
                GeometryReader { geo in
                    Color.clear.onChange(of: geo.size.height, initial: true) { _, height in
                        self.scrollHandler.bubblesBarHeight = height
                    }
                }
            )

            LinearGradient(
                colors: [.black.opacity(self.scrollHandler.searchBarTopFade), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeHeight)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: self.scrollHandler.showSearchBar ? .infinity : 0, alignment: .top)
        .clipped()
        .allowsHitTesting(self.scrollHandler.showSearchBar)
    }

    private func bubbleLabel(for category: Category) -> some View {
        let isSelected = self.selectedCategory == category && (!self.isFocused || self.highlightSelectedWhenFocused)
        return HStack(spacing: 5) {
            Image(systemName: category.icon)
                .font(.system(size: 15))
            Text(category.displayName)
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundColor(isSelected ? .purp : Color(.systemGray))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(.systemGray6).opacity(0.6))
                .overlay(Capsule().fill(Color.purp.opacity(isSelected ? 0.1 : 0)))
                .overlay(Capsule().strokeBorder(isSelected ? Color.purp.opacity(0.5) : Color(.systemGray3), lineWidth: 1.5))
        )
    }
}
