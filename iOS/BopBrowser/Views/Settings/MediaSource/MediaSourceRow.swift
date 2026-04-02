import SwiftUI

struct MediaSourceRow: View {
    let source: MediaSource

    private var isEnabled: Bool {
        self.source.isEnabled
    }

    var body: some View {
        HStack(spacing: 12) {
            if let iconSvg = self.source.config.iconSvg {
                SVGImageView(svgString: iconSvg, size: 24)
                    .frame(width: 32, height: 32)
                    .opacity(self.isEnabled ? 1.0 : 0.5)
            } else {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundColor(self.isEnabled ? Color.purp : Color(.systemGray2))
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(self.source.name)
                    .font(.body)
                    .foregroundColor(self.isEnabled ? .primary : Color(.systemGray2))
                Text(self.source.url)
                    .font(.caption)
                    .foregroundColor(self.isEnabled ? .secondary : Color(.systemGray3))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
