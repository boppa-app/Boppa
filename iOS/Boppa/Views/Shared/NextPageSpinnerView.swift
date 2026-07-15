import SwiftUI

struct NextPageSpinnerView: View {
    let onAppear: () -> Void
    @State private var spinnerToken = UUID()

    var body: some View {
        VStack {
            ProgressView()
                .id(self.spinnerToken)
        }
        .onAppear {
            self.spinnerToken = UUID()
            self.onAppear()
        }
    }
}
