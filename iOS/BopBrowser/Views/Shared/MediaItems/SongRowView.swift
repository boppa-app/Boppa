import SwiftUI

enum SongRowStyle {
    case regular
    case compact
}

struct SongRow: View {
    let song: Song
    var isSelected: Bool = false
    var isPlaying: Bool = false
    var style: SongRowStyle = .regular

    private var artworkSize: CGFloat {
        self.style == .compact ? 36 : 48
    }

    private var titleFont: Font {
        self.style == .compact ? .subheadline : .body
    }

    private var horizontalPadding: CGFloat {
        self.style == .compact ? 10 : 16
    }

    private var verticalPadding: CGFloat {
        self.style == .compact ? 6 : 10
    }

    var body: some View {
        HStack(spacing: self.style == .compact ? 10 : 12) {
            ArtworkView(url: self.song.artworkUrl, placeholder: "music.note", size: self.artworkSize)
            VStack(alignment: .leading, spacing: self.style == .compact ? 2 : 4) {
                Text(self.song.title)
                    .font(self.titleFont)
                    .fontWeight(self.isSelected ? .bold : .regular)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let artist = self.song.artist {
                    Text(artist)
                        .font(.caption2)
                        .fontWeight(self.isSelected ? .bold : .regular)
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
            }
            Spacer()
            if self.isSelected && self.isPlaying {
                WaveformAnimation()
                    .frame(width: 20, height: 16)
            } else if let duration = self.song.formattedDuration {
                Text(duration)
                    .font(.caption2)
                    .foregroundColor(Color(.systemGray))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, self.horizontalPadding)
        .padding(.vertical, self.verticalPadding)
        .contentShape(Rectangle())
    }
}

struct WaveformAnimation: View {
    @State private var animating = false

    private let barCount = 3
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2

    var body: some View {
        HStack(spacing: self.barSpacing) {
            ForEach(0 ..< self.barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: self.barWidth / 2)
                    .fill(Color.purp)
                    .frame(width: self.barWidth)
                    .scaleEffect(
                        y: self.animating ? CGFloat.random(in: 0.3 ... 1.0) : 0.4,
                        anchor: .bottom
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.3 ... 0.6))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: self.animating
                    )
            }
        }
        .onAppear {
            self.animating = true
        }
    }
}
