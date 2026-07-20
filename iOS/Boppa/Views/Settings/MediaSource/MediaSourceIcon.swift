import SwiftUI

struct MediaSourceIcon: View {
    let mediaSource: StoredMediaSource
    var isSelected: Bool?
    var size: CGFloat = MediaSourceGridLayout.iconSize

    private var isHighlighted: Bool {
        self.isSelected ?? self.mediaSource.isEnabled
    }

    private var outlineColor: Color {
        if let hex = self.mediaSource.config.highlightColor {
            return Color(hex: hex)
        }
        return Color.purp
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(self.mediaSource.isEnabled ? self.outlineColor : Color(.systemGray), lineWidth: 2)

            if let iconSvg = self.mediaSource.config.iconSvg {
                SVGImageView(svgString: iconSvg, size: self.size * 0.5)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: self.size * 0.375))
                    .foregroundColor(Color.purp)
            }
        }
        .frame(width: self.size, height: self.size)
        .opacity(self.isHighlighted ? 1.0 : 0.35)
        .accessibilityLabel(self.mediaSource.config.name)
        .accessibilityHint(self.mediaSource.isEnabled ? "Enabled" : "Disabled")
    }
}

extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)

        let r: Double
        let g: Double
        let b: Double

        if hexSanitized.count == 6 {
            r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            b = Double(rgbValue & 0x0000FF) / 255.0
        } else {
            r = 0
            g = 0
            b = 0
        }

        self.init(red: r, green: g, blue: b)
    }
}
