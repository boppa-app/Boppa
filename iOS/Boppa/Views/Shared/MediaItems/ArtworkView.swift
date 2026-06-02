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

    private var resolvedURL: URL? {
        guard let localURLString = ArtworkServer.localURL(for: self.url) else { return nil }
        return URL(string: localURLString)
    }

    var body: some View {
        Group {
            if let url = self.resolvedURL {
                CachedAsyncImage(url: url, size: self.size) {
                    self.placeholderImage
                } content: { image in
                    self.squareArtwork(image: image)
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

// MARK: - CachedAsyncImage

/// A custom async image loader that does NOT cache failures, unlike SwiftUI's AsyncImage.
/// This ensures that if the ArtworkServer is temporarily unavailable, images will be
/// retried on next appearance rather than permanently showing as failed.
private struct CachedAsyncImage<Placeholder: View, Content: View>: View {
    let url: URL
    let size: CGFloat
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let content: (Image) -> Content

    @State private var phase: AsyncImagePhase = .empty
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        Group {
            switch self.phase {
            case let .success(image):
                self.content(image)
            case .failure:
                self.placeholder()
            case .empty:
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .onAppear {
            if case .success = self.phase { return }
            self.loadImage()
        }
        .onChange(of: self.url) {
            self.phase = .empty
            self.loadTask?.cancel()
            self.loadImage()
        }
    }

    private func loadImage() {
        self.loadTask = Task {
            do {
                let (data, response) = try await ArtworkImageLoader.shared.session.data(from: self.url)

                if Task.isCancelled { return }

                // Check for HTTP errors
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    self.phase = .failure(URLError(.badServerResponse))
                    // Schedule a retry after a delay for server errors
                    self.scheduleRetry()
                    return
                }

                guard let uiImage = UIImage(data: data) else {
                    self.phase = .failure(URLError(.cannotDecodeContentData))
                    return
                }

                self.phase = .success(Image(uiImage: uiImage))
            } catch {
                if Task.isCancelled { return }
                self.phase = .failure(error)
                // Schedule a retry for network errors (server might be temporarily overwhelmed)
                self.scheduleRetry()
            }
        }
    }

    private func scheduleRetry() {
        self.loadTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if Task.isCancelled { return }
            self.loadImage()
        }
    }

    private enum AsyncImagePhase {
        case empty
        case success(Image)
        case failure(Error)
    }
}

// MARK: - Shared Image Loader

/// Shared URLSession for loading artwork from the local ArtworkServer.
/// Configured to NOT cache responses so that failed requests are always retried.
private final class ArtworkImageLoader {
    static let shared = ArtworkImageLoader()

    let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.httpMaximumConnectionsPerHost = 50
        self.session = URLSession(configuration: config)
    }
}
