import SwiftUI
import UIKit

extension UIColor {
    static var charcoal: UIColor {
        UIColor { traits in
            let base = UIColor.systemGray6.resolvedColor(with: traits)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            base.getRed(&r, green: &g, blue: &b, alpha: &a)
            return UIColor(red: r * 0.75, green: g * 0.75, blue: b * 0.75, alpha: a)
        }
    }
}

extension Color {
    static var charcoal: Color {
        Color(UIColor.charcoal)
    }
}
