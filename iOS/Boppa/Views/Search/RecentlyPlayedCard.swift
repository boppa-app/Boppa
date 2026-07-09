import SwiftUI

struct RecentlyPlayedCard: View {
    let track: Track
    var isSelected: Bool = false
    var isLoading: Bool = false
    var isPlaying: Bool = false
    let onTap: () -> Void
    let onShowActions: () -> Void

    static let artworkSize: CGFloat = 100
    static let textBlockHeight: CGFloat = 40

    static let height: CGFloat = Self.artworkSize + 6 + Self.textBlockHeight

    var body: some View {
        Button {
            if self.isSelected {
                self.onShowActions()
            } else {
                self.onTap()
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    ArtworkView(
                        lowResUrl: self.track.resolvedLowResArtworkUrl,
                        highResUrl: self.track.resolvedHighResArtworkUrl,
                        preferLowRes: false,
                        placeholder: "music.note",
                        size: Self.artworkSize
                    )
                    if self.isSelected {
                        Color.black
                            .opacity(0.8)
                            .frame(width: Self.artworkSize, height: Self.artworkSize)
                            .cornerRadius(6)
                        if self.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        } else if self.isPlaying {
                            Image(systemName: "waveform")
                                .foregroundColor(.white)
                                .symbolEffect(.variableColor.iterative.reversing)
                                .scaleEffect(1.5)
                        } else {
                            Image(systemName: "waveform")
                                .foregroundColor(Color(white: 0.6))
                                .scaleEffect(1.5)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.track.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(self.track.subtitle ?? " ")
                        .font(.caption)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
                .frame(height: Self.textBlockHeight, alignment: .top)
            }
            .frame(width: Self.artworkSize, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [self.track.title, self.track.subtitle].compactMap { $0 }.joined(separator: ", ")
        )
        .accessibilityHint(
            self.isSelected ? "More options for \(self.track.title)" : "Play \(self.track.title)"
        )
        .accessibilityAddTraits(.isButton)
    }
}
