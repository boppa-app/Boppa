import SwiftUI

enum TrackRowStyle {
    case regular
    case compact
}

// TODO: Add custom waveform animation

struct TrackRow: View {
    let track: Track
    var isSelected: Bool = false
    var isLoading: Bool = false
    var isPlaying: Bool = false
    var isMediaSourceEnabled: Bool = true
    var style: TrackRowStyle = .regular
    var onTap: (() -> Void)?
    var onEllipsisTap: (() -> Void)?
    var onDeleteTap: (() -> Void)?
    var isDeleteDisabled: Bool = false

    private var artworkSize: CGFloat {
        self.style == .compact ? 36 : 48
    }

    private var titleFont: Font {
        self.style == .compact ? .subheadline : .body
    }

    private var leftPadding: CGFloat {
        self.style == .compact ? 10 : 18
    }

    private var rightPadding: CGFloat {
        self.style == .compact ? 10 : 4
    }

    private var verticalPadding: CGFloat {
        self.style == .compact ? 6 : 10
    }

    var body: some View {
        HStack(spacing: self.style == .compact ? 10 : 12) {
            ArtworkView(
                lowResUrl: self.track.resolvedLowResArtworkUrl,
                highResUrl: self.track.resolvedHighResArtworkUrl,
                placeholder: "music.note",
                size: self.artworkSize
            )
            .opacity(!self.isMediaSourceEnabled ? 0.3 : 1.0)
            VStack(alignment: .leading, spacing: self.style == .compact ? 2 : 4) {
                Text(self.track.title)
                    .font(self.titleFont)
                    .fontWeight(self.isSelected ? .bold : .regular)
                    .foregroundColor(!self.isMediaSourceEnabled ? Color(.systemGray3) : (self.isSelected ? .purp : .white))
                    .lineLimit(1)
                    .opacity(!self.isMediaSourceEnabled ? 0.7 : 1.0)
                if let subtitle = self.track.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .fontWeight(self.isSelected ? .bold : .regular)
                        .foregroundColor(!self.isMediaSourceEnabled ? Color(.systemGray4) : Color(.systemGray))
                        .lineLimit(1)
                        .opacity(!self.isMediaSourceEnabled ? 0.7 : 1.0)
                }
            }
            Spacer()
            if !self.isMediaSourceEnabled {
                if self.style == .regular {
                    Image(systemName: "ellipsis")
                        .foregroundColor(Color(.systemGray4))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.onEllipsisTap?()
                        }
                        .accessibilityLabel("More Options")
                        .accessibilityHint("More options for \(self.track.title)")
                        .accessibilityAddTraits(.isButton)
                }
            } else if let onDeleteTap = self.onDeleteTap, !self.isDeleteDisabled {
                Image(systemName: "xmark")
                    .foregroundColor(.purp)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture { onDeleteTap() }
                    .accessibilityLabel("Remove from queue")
                    .accessibilityAddTraits(.isButton)
            } else if self.style == .regular {
                if self.isSelected && self.isLoading {
                    SpinnerView(tint: .purp, lineWidth: 3)
                        .frame(width: 20, height: 20)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.onEllipsisTap?()
                        }
                        .accessibilityLabel("Loading")
                        .accessibilityAddTraits(.isButton)
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
                    .accessibilityLabel(self.isPlaying ? "Now Playing" : "Paused")
                    .accessibilityHint("More options for \(self.track.title)")
                    .accessibilityAddTraits(.isButton)
                } else {
                    Image(systemName: "ellipsis")
                        .foregroundColor(Color(.systemGray))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.onEllipsisTap?()
                        }
                        .accessibilityLabel("More Options")
                        .accessibilityHint("More options for \(self.track.title)")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .padding(.leading, self.leftPadding)
        .padding(.trailing, self.rightPadding)
        .padding(.vertical, self.verticalPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            if self.isMediaSourceEnabled {
                self.onTap?()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel([self.track.title, self.track.subtitle].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint(!self.isMediaSourceEnabled ? "Source unavailable" : "Play \(self.track.title)")
        .accessibilityAddTraits(.isButton)
    }
}
