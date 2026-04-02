import SwiftUI

struct SolidToggle: View {
    @Binding var isOn: Bool
    var onColor: Color = .purp
    var offColor: Color = .init(.systemGray4)

    private let width: CGFloat = 51
    private let height: CGFloat = 31
    private let thumbSize: CGFloat = 27
    private let thumbPadding: CGFloat = 2

    var body: some View {
        ZStack(alignment: self.isOn ? .trailing : .leading) {
            Capsule()
                .fill(self.isOn ? self.onColor : self.offColor)
                .frame(width: self.width, height: self.height)

            Circle()
                .fill(Color.white)
                .frame(width: self.thumbSize, height: self.thumbSize)
                .padding(self.thumbPadding)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isOn.toggle()
            }
        }
    }
}
