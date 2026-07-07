import Kingfisher
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
                ArtworkImageContent(
                    url: url, size: self.size, placeholderSystemName: self.resolvedPlaceholder
                )
            } else {
                self.placeholderImage
            }
        }
        .frame(width: self.size, height: self.size)
        .background(self.placeholderBackground ?? Color(.systemGray6))
        .cornerRadius(self.resolvedCornerRadius)
        .clipped()
    }

    private var placeholderImage: some View {
        Image(systemName: self.resolvedPlaceholder)
            .font(.title3)
            .foregroundColor(.white)
            .frame(width: self.size, height: self.size)
    }
}

private struct ArtworkImageContent: View {
    let url: URL
    let size: CGFloat
    let placeholderSystemName: String

    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: UIImage? = nil
    @State private var failed = false

    // Blur ramps smoothly with how far the source is upscaled past its native resolution
    private static let upscaleRatioBeforeBlur: CGFloat = 2.0
    private static let upscaleRatioAtMaxBlur: CGFloat = 5.0
    private static let maxBlurRadiusFraction: CGFloat = 0.03
    private static let maxBlurRadiusCap: CGFloat = 5

    private var maxBlurRadius: CGFloat {
        min(self.size * Self.maxBlurRadiusFraction, Self.maxBlurRadiusCap)
    }

    private func upscaleBlurRadius(for image: UIImage) -> CGFloat {
        guard let cgImage = image.cgImage else { return 0 }
        let nativePixels = CGFloat(min(cgImage.width, cgImage.height))
        guard nativePixels > 0 else { return 0 }

        let displayPixels = self.size * self.displayScale
        let upscaleRatio = displayPixels / nativePixels
        guard upscaleRatio > Self.upscaleRatioBeforeBlur else { return 0 }

        let progress = min(
            (upscaleRatio - Self.upscaleRatioBeforeBlur)
                / (Self.upscaleRatioAtMaxBlur - Self.upscaleRatioBeforeBlur),
            1
        )
        return progress * self.maxBlurRadius
    }

    var body: some View {
        Group {
            if let img = loadedImage {
                ZStack {
                    Color(.systemGray6)

                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: self.size, height: self.size)
                        .clipped()
                        .blur(radius: 20)
                        .opacity(0.6)

                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: self.size, height: self.size)
                        .blur(radius: self.upscaleBlurRadius(for: img))
                }
            } else if self.failed {
                Image(systemName: self.placeholderSystemName)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: self.size, height: self.size)
            } else {
                KFImage(self.url)
                    .placeholder { ProgressView().scaleEffect(0.6) }
                    .onSuccess { result in self.loadedImage = result.image }
                    .onFailure { _ in self.failed = true }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: self.size, height: self.size)
            }
        }
        .onChange(of: self.url) { _ in
            self.loadedImage = nil
            self.failed = false
        }
    }
}
