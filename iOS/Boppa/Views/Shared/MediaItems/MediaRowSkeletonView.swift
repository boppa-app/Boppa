import SwiftUI

/// Metrics for placeholder rows. Everything with a counterpart on TrackRow or TracklistRow is
/// read from there rather than copied, so changing a row's layout moves the skeleton with it and
/// the two can't drift apart. Only the bar heights are the skeleton's own (see titleHeight).
enum MediaRowSkeletonStyle {
    case track
    case tracklist

    var artworkSize: CGFloat {
        switch self {
        case .track: return TrackRow.regularArtworkSize
        case .tracklist: return TracklistRow.defaultArtworkSize
        }
    }

    var artworkCornerRadius: CGFloat {
        ArtworkView.defaultCornerRadius
    }

    var verticalPadding: CGFloat {
        switch self {
        case .track: return TrackRow.regularVerticalPadding
        case .tracklist: return TracklistRow.verticalPadding
        }
    }

    var leadingPadding: CGFloat {
        switch self {
        case .track: return TrackRow.regularLeadingPadding
        case .tracklist: return TracklistRow.horizontalPadding
        }
    }

    var trailingPadding: CGFloat {
        switch self {
        case .track: return TrackRow.regularTrailingPadding
        case .tracklist: return TracklistRow.horizontalPadding
        }
    }

    /// Gap between the artwork and the text column
    var horizontalSpacing: CGFloat {
        switch self {
        case .track: return TrackRow.regularHorizontalSpacing
        case .tracklist: return TracklistRow.horizontalSpacing
        }
    }

    /// Gap between the title and subtitle bars
    var textSpacing: CGFloat {
        switch self {
        case .track: return TrackRow.regularTextSpacing
        case .tracklist: return TracklistRow.textSpacing
        }
    }

    /// (Approximate) bar heights stand in for rendered text, which has no constant to mirror
    var titleHeight: CGFloat {
        switch self {
        case .track: return 13
        case .tracklist: return 15
        }
    }

    var subtitleHeight: CGFloat {
        switch self {
        case .track: return 9
        case .tracklist: return 12
        }
    }

    /// Space the real row reserves on the trailing edge for its control
    var trailingControlWidth: CGFloat {
        switch self {
        case .track: return TrackRow.trailingControlWidth
        case .tracklist: return TracklistRow.chevronWidth
        }
    }

    var rowHeight: CGFloat {
        self.artworkSize + self.verticalPadding * 2
    }
}

struct MediaRowSkeletonList: View {
    let style: MediaRowSkeletonStyle
    var topInset: CGFloat = 0

    static let fadeDuration: TimeInterval = 0.15

    /// Width of the travelling highlight, as a fraction of the list's width. The gradient ramps
    /// from clear to peak across half of this, so widening it lengthens the fade. It also
    /// lengthens the sweep's travel, so raise shimmerDuration alongside it to keep the pace.
    private static let shimmerBandFraction: CGFloat = 1.0
    private static let shimmerDuration: TimeInterval = 2
    private static let shimmerPeakOpacity: CGFloat = 0.15

    private static let titleWidthFractions: [CGFloat] = [
        0.72, 0.54, 0.83, 0.61, 0.48, 0.77, 0.66, 0.58,
    ]
    private static let subtitleWidthFractions: [CGFloat] = [
        0.38, 0.46, 0.30, 0.52, 0.34, 0.42, 0.28, 0.50,
    ]

    var body: some View {
        GeometryReader { proxy in
            let rowCount = self.rowCount(forHeight: proxy.size.height)
            let contentWidth = self.contentWidth(forWidth: proxy.size.width)
            let bars = self.bars(rowCount: rowCount, contentWidth: contentWidth)

            bars
                .overlay {
                    // Deliberately not gated on Reduce Motion
                    TimelineView(.animation) { timeline in
                        self.shimmer(
                            listWidth: proxy.size.width,
                            phase: Self.shimmerPhase(at: timeline.date)
                        )
                    }
                    .mask { bars }
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func bars(rowCount: Int, contentWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(0 ..< rowCount), id: \.self) { index in
                self.row(index: index, contentWidth: contentWidth)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, self.topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Sweep progress (0.0...1.0), read off the clock rather than from animated state. A
    /// withAnimation started in onAppear is absorbed by the transition that brings the
    /// skeleton on screen, which parks the band off the trailing edge and leaves it static.
    private static func shimmerPhase(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSinceReferenceDate
        return CGFloat(
            elapsed.truncatingRemainder(dividingBy: Self.shimmerDuration) / Self.shimmerDuration
        )
    }

    private func shimmer(listWidth: CGFloat, phase: CGFloat) -> some View {
        let bandWidth = listWidth * Self.shimmerBandFraction
        let travel = listWidth + bandWidth

        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: Color.white.opacity(Self.shimmerPeakOpacity), location: 0.5),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: bandWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .offset(x: -bandWidth + phase * travel)
    }

    private func rowCount(forHeight height: CGFloat) -> Int {
        let available = max(0, height - self.topInset)
        return max(1, Int(ceil(available / self.style.rowHeight)))
    }

    private func contentWidth(forWidth width: CGFloat) -> CGFloat {
        let used = self.style.leadingPadding
            + self.style.trailingPadding
            + self.style.artworkSize
            + self.style.horizontalSpacing
            + self.style.trailingControlWidth
        return max(40, width - used)
    }

    private func row(index: Int, contentWidth: CGFloat) -> some View {
        let titleFraction = Self.titleWidthFractions[index % Self.titleWidthFractions.count]
        let subtitleFraction = Self
            .subtitleWidthFractions[index % Self.subtitleWidthFractions.count]

        return HStack(spacing: self.style.horizontalSpacing) {
            RoundedRectangle(cornerRadius: self.style.artworkCornerRadius, style: .continuous)
                .fill(Color(.systemGray6))
                .frame(width: self.style.artworkSize, height: self.style.artworkSize)

            VStack(alignment: .leading, spacing: self.style.textSpacing) {
                self.bar(width: contentWidth * titleFraction, height: self.style.titleHeight)
                self.bar(width: contentWidth * subtitleFraction, height: self.style.subtitleHeight)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, self.style.leadingPadding)
        .padding(.trailing, self.style.trailingPadding)
        .padding(.vertical, self.style.verticalPadding)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color(.systemGray6))
            .frame(width: width, height: height)
    }
}
