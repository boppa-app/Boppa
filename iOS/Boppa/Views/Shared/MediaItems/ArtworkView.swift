import Kingfisher
import SwiftUI

struct ArtworkView: View {
    let lowResUrl: String?
    let highResUrl: String?
    var preferLowRes: Bool = true
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

    private var candidateURLs: [URL] {
        guard self.tracklistType != .likes else { return [] }
        let orderedStrings = self.preferLowRes
            ? [self.lowResUrl, self.highResUrl]
            : [self.highResUrl, self.lowResUrl]
        var seen = Set<URL>()
        return orderedStrings.compactMap { string -> URL? in
            guard let string, !string.isEmpty, let url = URL(string: string) else { return nil }
            return url
        }.filter { seen.insert($0).inserted }
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
            if !self.candidateURLs.isEmpty {
                ArtworkImageContent(
                    urls: self.candidateURLs, size: self.size,
                    placeholderSystemName: self.resolvedPlaceholder
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
            .font(.system(size: Self.placeholderIconSize(for: self.size)))
            .foregroundColor(.white)
            .frame(width: self.size, height: self.size)
    }
}

/// title3 renders at ~20pt for the default 48pt artwork size, so scale
/// proportionally from there instead of a fixed text style
private let artworkPlaceholderIconRatio: CGFloat = 20.0 / 48.0

private extension ArtworkView {
    static func placeholderIconSize(for size: CGFloat) -> CGFloat {
        size * artworkPlaceholderIconRatio
    }
}

private struct ArtworkImageContent: View {
    let urls: [URL]
    let size: CGFloat
    let placeholderSystemName: String

    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: UIImage? = nil
    @State private var candidateIndex = 0
    @State private var failed = false

    private var currentURL: URL? {
        self.urls.indices.contains(self.candidateIndex) ? self.urls[self.candidateIndex] : nil
    }

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
            } else if self.failed || self.currentURL == nil {
                Image(systemName: self.placeholderSystemName)
                    .font(.system(size: ArtworkView.placeholderIconSize(for: self.size)))
                    .foregroundColor(.white)
                    .frame(width: self.size, height: self.size)
            } else if let url = self.currentURL {
                ZStack {
                    SpinnerView(tint: Color(.systemGray), lineWidth: max(self.size * 0.03, 2))
                        .frame(width: max(self.size * 0.25, 16), height: max(self.size * 0.25, 16))

                    KFImage(url)
                        .onSuccess { result in self.loadedImage = result.image }
                        .onFailure { _ in self.advanceToNextCandidate() }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: self.size, height: self.size)
                        .opacity(0)
                }
                .frame(width: self.size, height: self.size)
            }
        }
        .onChange(of: self.urls) { _ in
            self.loadedImage = nil
            self.candidateIndex = 0
            self.failed = false
        }
    }

    private func advanceToNextCandidate() {
        let nextIndex = self.candidateIndex + 1
        if self.urls.indices.contains(nextIndex) {
            self.candidateIndex = nextIndex
        } else {
            self.failed = true
        }
    }
}
