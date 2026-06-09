import SwiftUI

struct ArtworkView: View {
    let url: String?
    var placeholder: String = "music.note"
    var tracklistType: Tracklist.TracklistType? = nil
    var size: CGFloat = 48
    var isCircular: Bool = false
    var cornerRadius: CGFloat?
    var placeholderBackground: Color? = nil

    private var resolvedCornerRadius: CGFloat {
        if self.isCircular {
            return self.size / 2
        }
        return self.cornerRadius ?? 6
    }

    private var resolvedURL: URL? {
        guard self.tracklistType != .likes else { return nil }
        guard let urlString = self.url, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }

    private var resolvedPlaceholder: String {
        guard let type = self.tracklistType else { return self.placeholder }
        switch type {
        case .likes:
            return "heart.fill"
        case .album:
            if #available(iOS 26.0, *) {
                return "music.note.square.stack.fill"
            } else {
                return "square.stack.fill"
            }
        default:
            return "music.note.list"
        }
    }

    var body: some View {
        Group {
            if let url = self.resolvedURL {
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
        .background(self.placeholderBackground ?? Color(.systemGray6))
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
        Image(systemName: self.resolvedPlaceholder)
            .font(.title3)
            .foregroundColor(.white)
            .frame(width: self.size, height: self.size)
    }
}
