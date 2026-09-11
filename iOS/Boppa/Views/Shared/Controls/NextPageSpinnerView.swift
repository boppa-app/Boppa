import SwiftUI

struct NextPageSpinnerView: View {
    let onAppear: () -> Void
    @State private var spinnerToken = UUID()

    var body: some View {
        VStack {
            SpinnerView(lineWidth: 3)
                .frame(width: 20, height: 20)
                .id(self.spinnerToken)
        }
        .onAppear {
            self.spinnerToken = UUID()
            self.onAppear()
        }
    }
}
