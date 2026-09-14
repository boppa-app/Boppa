import SwiftUI

protocol ThreeWaySliderOption: Hashable, CaseIterable {
    var label: String { get }
}

struct ThreeWaySlider<Option: ThreeWaySliderOption>: View
    where Option.AllCases: RandomAccessCollection
{
    @Binding var selection: Option
    var selectedColor: Color = .purp
    var backgroundColor: Color = .init(.systemGray5)
    var selectedTextColor: Color = .white
    var unselectedTextColor: Color = .init(.systemGray)

    private let height: CGFloat = 36
    private let thumbPadding: CGFloat = 3

    private var options: [Option] {
        Array(Option.allCases)
    }

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - self.thumbPadding * 2
            let segmentWidth = trackWidth / CGFloat(self.options.count)
            let selectedIndex = CGFloat(self.options.firstIndex(of: self.selection) ?? 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(self.backgroundColor)

                Capsule()
                    .fill(self.selectedColor)
                    .frame(width: segmentWidth, height: self.height - self.thumbPadding * 2)
                    .padding(.leading, self.thumbPadding)
                    .offset(x: selectedIndex * segmentWidth)

                HStack(spacing: 0) {
                    ForEach(self.options, id: \.self) { option in
                        Text(option.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(
                                option == self.selection ? self.selectedTextColor : self
                                    .unselectedTextColor
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    self.selection = option
                                }
                            }
                            .accessibilityLabel(option.label)
                            .accessibilityAddTraits(option == self.selection ? [
                                .isSelected,
                                .isButton,
                            ] : .isButton)
                    }
                }
            }
        }
        .frame(height: self.height)
        .animation(.easeInOut(duration: 0.2), value: self.selection)
    }
}
