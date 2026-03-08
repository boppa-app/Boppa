import SwiftUI

struct MediaSourceRow: View {
    let source: MediaSource

    var body: some View {
        HStack(spacing: 12) {
            if let iconSvg = self.source.config.iconSvg {
                SVGImageView(svgString: iconSvg, size: 24)
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundColor(Color.purp)
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(self.source.name)
                    .font(.body)
                Text(self.source.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
