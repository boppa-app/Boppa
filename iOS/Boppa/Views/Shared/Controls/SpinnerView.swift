import SwiftUI

struct SpinnerView: View {
    var tint: Color = .white
    var lineWidth: CGFloat = 3

    @State private var isRotating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(self.tint, style: StrokeStyle(lineWidth: self.lineWidth, lineCap: .round))
            .rotationEffect(.degrees(self.isRotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    self.isRotating = true
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black
        SpinnerView(lineWidth: 6)
            .frame(width: 88, height: 88)
    }
}
