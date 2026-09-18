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
    var showTrailingControls: Bool = true
    var revealInfo: MediaSourceRevealInfo?
    var style: TrackRowStyle = .regular
    var onTap: (() -> Void)?
    var onEllipsisTap: (() -> Void)?
    var onDeleteTap: (() -> Void)?
    var isDeleteDisabled: Bool = false

    @AppStorage(MediaSourceSeparatorVisibility.storageKey) private var separatorVisibilityRaw =
        MediaSourceSeparatorVisibility.defaultValue.rawValue

    static let regularArtworkSize: CGFloat = 48
    static let regularLeadingPadding: CGFloat = 18
    static let regularTrailingPadding: CGFloat = 4
    static let regularVerticalPadding: CGFloat = 10
    static let regularHorizontalSpacing: CGFloat = 12
    static let regularTextSpacing: CGFloat = 4
    static let trailingControlWidth: CGFloat = 44

    private var artworkSize: CGFloat {
        self.style == .compact ? 36 : Self.regularArtworkSize
    }

    private func mediaSourceColor(_ info: MediaSourceRevealInfo?) -> Color? {
        let separatorVisibility = MediaSourceSeparatorVisibility(
            rawValue: self.separatorVisibilityRaw
        ) ?? .defaultValue
        guard separatorVisibility.showsOnTracks, let info else { return nil }
        if let hex = info.highlightColor {
            return Color(hex: hex)
        }
        return Color.purp
    }

    private func mediaSourceRevealIcon(_ info: MediaSourceRevealInfo?) -> MediaSourceRevealIcon? {
        info?.iconSvg.map(MediaSourceRevealIcon.svg)
    }

    private var titleFont: Font {
        self.style == .compact ? .subheadline : .body
    }

    private var leftPadding: CGFloat {
        self.style == .compact ? 10 : Self.regularLeadingPadding
    }

    private var rightPadding: CGFloat {
        self.style == .compact ? 10 : Self.regularTrailingPadding
    }

    private var horizontalSpacing: CGFloat {
        self.style == .compact ? 10 : Self.regularHorizontalSpacing
    }

    private var textSpacing: CGFloat {
        self.style == .compact ? 2 : Self.regularTextSpacing
    }

    private var verticalPadding: CGFloat {
        self.style == .compact ? 6 : Self.regularVerticalPadding
    }

    var body: some View {
        let revealInfo = self.revealInfo
        let mediaSourceColor = self.mediaSourceColor(revealInfo)

        HStack(spacing: self.horizontalSpacing) {
            MediaSourceRevealArtwork(
                size: self.artworkSize,
                borderColor: mediaSourceColor,
                mediaSourceRevealIcon: self.mediaSourceRevealIcon(revealInfo),
                revealBackgroundColor: .init(.black)
            ) {
                ArtworkView(
                    lowResUrl: self.track.lowResArtworkUrl,
                    highResUrl: self.track.highResArtworkUrl,
                    placeholder: "music.note",
                    size: self.artworkSize
                )
            }
            .opacity(!self.isMediaSourceEnabled ? 0.3 : 1.0)
            if let mediaSourceColor {
                Capsule()
                    .fill(mediaSourceColor)
                    .frame(width: 2, height: self.artworkSize * 0.7)
            }
            VStack(alignment: .leading, spacing: self.textSpacing) {
                Text(self.track.title)
                    .font(self.titleFont)
                    .fontWeight(self.isSelected ? .bold : .regular)
                    .foregroundColor(!self
                        .isMediaSourceEnabled ? Color(.systemGray3) :
                        (self.isSelected ? .purp : .white))
                    .lineLimit(1)
                    .opacity(!self.isMediaSourceEnabled ? 0.7 : 1.0)
                if let subtitle = self.track.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .fontWeight(self.isSelected ? .bold : .regular)
                        .foregroundColor(!self
                            .isMediaSourceEnabled ? Color(.systemGray4) : Color(.systemGray))
                        .lineLimit(1)
                        .opacity(!self.isMediaSourceEnabled ? 0.7 : 1.0)
                }
            }
            Spacer()
            if self.showTrailingControls {
                if !self.isMediaSourceEnabled {
                    if self.style == .regular {
                        Image(systemName: "ellipsis")
                            .foregroundColor(Color(.systemGray4))
                            .frame(
                                width: Self.trailingControlWidth,
                                height: Self.trailingControlWidth
                            )
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
                        .frame(width: Self.trailingControlWidth, height: Self.trailingControlWidth)
                        .contentShape(Rectangle())
                        .onTapGesture { onDeleteTap() }
                        .accessibilityLabel("Remove from queue")
                        .accessibilityAddTraits(.isButton)
                } else if self.style == .regular {
                    if self.isSelected && self.isLoading {
                        SpinnerView(tint: .purp, lineWidth: 3)
                            .frame(width: 20, height: 20)
                            .frame(
                                width: Self.trailingControlWidth,
                                height: Self.trailingControlWidth
                            )
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
                        .frame(width: Self.trailingControlWidth, height: Self.trailingControlWidth)
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
                            .frame(
                                width: Self.trailingControlWidth,
                                height: Self.trailingControlWidth
                            )
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
        .accessibilityLabel([self.track.title, self.track.subtitle].compactMap { $0 }
            .joined(separator: ", "))
        .accessibilityHint(!self
            .isMediaSourceEnabled ? "Source unavailable" : "Play \(self.track.title)")
        .accessibilityAddTraits(.isButton)
    }
}
