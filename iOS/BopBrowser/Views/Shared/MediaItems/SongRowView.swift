import SwiftUI

enum SongRowStyle {
    case regular
    case compact
}

// TODO: Add custom waveform animation, potentially with FFT

struct SongRow: View {
    let song: Song
    var isSelected: Bool = false
    var isLoading: Bool = false
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
                    .foregroundColor(self.isSelected ? .purp : .white)
                    .lineLimit(1)
                if let artist = self.song.artist {
                    Text(artist)
                        .font(.caption2)
                        .fontWeight(self.isSelected ? .bold : .regular)
                        .foregroundColor(self.isSelected ? .purp.opacity(0.5) : Color(.systemGray))
                        .lineLimit(1)
                }
            }
            Spacer()
            if self.isSelected && self.isLoading {
                ProgressView()
                    .tint(.purp)
            } else if self.isSelected && self.isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(.purp)
                    .symbolEffect(.variableColor.iterative.reversing)
            } else if self.isSelected {
                Image(systemName: "waveform")
                    .foregroundColor(.purp.opacity(0.3))
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
