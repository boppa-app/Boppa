import SwiftUI

struct MediaSourceIcon: View {
    let source: MediaSource

    private var isEnabled: Bool {
        self.source.isEnabled
    }

    private var outlineColor: Color {
        if let hex = self.source.config.highlightColor {
            return Color(hex: hex)
        }
        return Color.purp
    }

    var body: some View {
        self.iconCircle
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .strokeBorder(self.isEnabled ? self.outlineColor : Color(.systemGray3), lineWidth: 2)
                .frame(width: 64, height: 64)

            if let iconSvg = self.source.config.iconSvg {
                SVGImageView(svgString: iconSvg, size: 32)
                    .opacity(self.isEnabled ? 1.0 : 0.5)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 24))
                    .foregroundColor(self.isEnabled ? Color.purp : Color(.systemGray2))
            }
        }
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
