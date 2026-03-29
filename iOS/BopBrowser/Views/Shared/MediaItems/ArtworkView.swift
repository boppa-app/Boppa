import SwiftUI

struct ArtworkView: View {
    let url: String?
    let placeholder: String
    var size: CGFloat = 48
    var isCircular: Bool = false

    var body: some View {
        Group {
            if let artworkUrl = self.url, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        self.placeholderImage
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.6)
                    @unknown default:
                        self.placeholderImage
                    }
                }
            } else {
                self.placeholderImage
            }
        }
        .frame(width: self.size, height: self.size)
        .background(Color(.systemGray6))
        .cornerRadius(self.isCircular ? self.size / 2 : 6)
        .clipped()
    }

    private var placeholderImage: some View {
        Image(systemName: self.placeholder)
            .font(.title3)
            .foregroundColor(Color(.systemGray3))
            .frame(width: self.size, height: self.size)
    }
}
