import SwiftUI

enum TrackRowStyle {
    case regular
    case compact
}

// TODO: Add custom waveform animation, potentially with FFT

struct TrackRow: View {
    let track: Track
    var isSelected: Bool = false
    var isLoading: Bool = false
    var isPlaying: Bool = false
    var style: TrackRowStyle = .regular
    var onTap: (() -> Void)?
    var onEllipsisTap: (() -> Void)?

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
            ArtworkView(url: self.track.artworkUrl, placeholder: "music.note", size: self.artworkSize)
            VStack(alignment: .leading, spacing: self.style == .compact ? 2 : 4) {
                Text(self.track.title)
                    .font(self.titleFont)
                    .fontWeight(self.isSelected ? .bold : .regular)
                    .foregroundColor(self.isSelected ? .purp : .white)
                    .lineLimit(1)
                if let subtitle = self.track.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .fontWeight(self.isSelected ? .bold : .regular)
                        .foregroundColor(self.isSelected ? .purp.opacity(0.5) : Color(.systemGray))
                        .lineLimit(1)
                }
            }
            Spacer()
            if self.style == .regular {
                if self.isSelected && self.isLoading {
                    ProgressView()
                        .tint(.purp)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.onEllipsisTap?()
                        }
                } else if self.isSelected {
                    ZStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.purp)
                            .symbolEffect(.variableColor.iterative.reversing)
                        if !self.isPlaying {
                            Image(systemName: "waveform")
                                .foregroundColor(.purp.opacity(0.3))
                                .background(Color.black)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.onEllipsisTap?()
                    }
                } else {
                    Image(systemName: "ellipsis")
                        .foregroundColor(Color(.systemGray))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.onEllipsisTap?()
                        }
                }
            }
        }
        .padding(.horizontal, self.horizontalPadding)
        .padding(.vertical, self.verticalPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            self.onTap?()
        }
    }
}
