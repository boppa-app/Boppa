import SwiftUI

struct MediaSourceIcon: View {
    let mediaSource: MediaSource
    var isSelected: Bool?
    var onDelete: (() -> Void)?
    var showDeleteButton: Bool = true

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
                .strokeBorder(self.isHighlighted ? self.outlineColor : Color(.systemGray3), lineWidth: 2)
                .frame(width: MediaSourceGridLayout.iconSize, height: MediaSourceGridLayout.iconSize)

            if let iconSvg = self.mediaSource.config.iconSvg {
                SVGImageView(svgString: iconSvg, size: 32)
                    .opacity(self.isHighlighted ? 1.0 : 0.5)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 24))
                    .foregroundColor(self.isHighlighted ? Color.purp : Color(.systemGray2))
            }
        }
        .overlay(alignment: .topLeading) {
            if let onDelete = self.onDelete, self.showDeleteButton {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, Color.purp)
                }
                .buttonStyle(.plain)
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
