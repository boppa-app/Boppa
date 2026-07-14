import SwiftUI

struct ErrorMessageView: View {
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 32))
            Text(self.message)
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.red)
    }
}
