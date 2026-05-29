import SwiftUI

struct HorizontalFadeModifier: ViewModifier {
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

struct CategoryBubblesBar: View {
    let categories: [SearchCategory]
    let selectedCategory: SearchCategory
    let scrollHandler: SearchBarScrollHandler
    var isFocused: Bool = false
    let onSelect: (SearchCategory) -> Void

    static let barHeight: CGFloat = 40

    @State private var leftFade: CGFloat = 0
    @State private var rightFade: CGFloat = 0

    private let fadeWidth: CGFloat = 40

    var body: some View {
        let fadeHeight = self.isFocused ? CGFloat(0) : self.scrollHandler.fadeHeight

        VStack(spacing: 0) {
            ScrollViewReader { proxy in
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
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, 16)
                .modifier(HorizontalFadeModifier(
                    leftFade: self.$leftFade,
                    rightFade: self.$rightFade,
                    fadeWidth: self.fadeWidth
                ))
                .mask(self.horizontalFadeMask)
            }
            .padding(.top, 10)
            .background(Color.black)

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

    private func bubbleLabel(for category: SearchCategory) -> some View {
        let isSelected = self.selectedCategory == category && !self.isFocused
        return HStack(spacing: 5) {
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
                .overlay(Capsule().strokeBorder(isSelected ? Color.purp.opacity(0.5) : Color(.systemGray3), lineWidth: 1.5))
        )
    }

    private var horizontalFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(1 - self.leftFade), .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: self.fadeWidth)
            Color.black
            LinearGradient(
                colors: [.black, .black.opacity(1 - self.rightFade)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: self.fadeWidth)
        }
    }
}
