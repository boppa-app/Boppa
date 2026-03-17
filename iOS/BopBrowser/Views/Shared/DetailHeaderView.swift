import SwiftUI

struct DetailHeaderView<TrailingContent: View, CenterContent: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder let trailing: () -> TrailingContent
    @ViewBuilder let centerTrailing: () -> CenterContent

    init(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> TrailingContent = { EmptyView() },
        @ViewBuilder centerTrailing: @escaping () -> CenterContent = { EmptyView() }
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing
        self.centerTrailing = centerTrailing
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 6) {
                    Text(self.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
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
            .frame(height: 44)
        }
    }
}
