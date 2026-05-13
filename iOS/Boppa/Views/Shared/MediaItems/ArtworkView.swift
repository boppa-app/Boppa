import SwiftUI

struct ArtworkView: View {
    let url: String?
    let placeholder: String
    var size: CGFloat = 48
    var isCircular: Bool = false
    var cornerRadius: CGFloat?

    private var resolvedCornerRadius: CGFloat {
        if self.isCircular {
            return self.size / 2
        }
        return self.cornerRadius ?? 6
    }

    var body: some View {
        Group {
            if let artworkUrl = self.url, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        self.squareArtwork(image: image)
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
        .cornerRadius(self.resolvedCornerRadius)
        .clipped()
    }

    private func squareArtwork(image: Image) -> some View {
        ZStack {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: self.size, height: self.size)
                .clipped()
                .blur(radius: 20)
                .opacity(0.6)

            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: self.size, height: self.size)
        }
    }

    private var placeholderImage: some View {
        Image(systemName: self.placeholder)
            .font(.title3)
            .foregroundColor(Color(.systemGray3))
            .frame(width: self.size, height: self.size)
    }
}
