import SwiftUI
import UIKit

struct SeekSlider: UIViewRepresentable {
    var value: Double
    var minimum: Double
    var maximum: Double
    var onEditingChanged: (Bool, Double) -> Void
    var onValueChanged: (Double) -> Void

    private static let thumbSize: CGFloat = 14
    private static let thumbPressedSize: CGFloat = 16

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = Float(self.minimum)
        slider.maximumValue = Float(self.maximum)
        slider.value = Float(self.value)
        slider.minimumTrackTintColor = UIColor(.purp)
        slider.maximumTrackTintColor = UIColor(.gray).withAlphaComponent(0.3)

        let normalThumb = Self.makeThumbImage(
            size: Self.thumbSize,
            color: UIColor(.purp)
        )
        let pressedThumb = Self.makeThumbImage(
            size: Self.thumbPressedSize,
            color: Self.darkenedColor(UIColor(.purp), by: 0.4)
        )
        slider.setThumbImage(normalThumb, for: .normal)
        slider.setThumbImage(pressedThumb, for: .highlighted)

        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.touchDown(_:)),
            for: .touchDown
        )
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.touchUp(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )

        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        slider.minimumValue = Float(self.minimum)
        slider.maximumValue = Float(self.maximum)

        if !context.coordinator.isTracking {
            slider.value = Float(self.value)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private static func makeThumbImage(size: CGFloat, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            ctx.cgContext.setFillColor(color.cgColor)
            ctx.cgContext.fillEllipse(in: rect)
        }
    }

    private static func darkenedColor(_ color: UIColor, by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(
            red: r * (1 - amount),
            green: g * (1 - amount),
            blue: b * (1 - amount),
            alpha: a
        )
    }

    final class Coordinator: NSObject {
        let parent: SeekSlider
        var isTracking = false

        init(parent: SeekSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ slider: UISlider) {
            let value = Double(slider.value)
            self.parent.onValueChanged(value)
        }

        @objc func touchDown(_ slider: UISlider) {
            self.isTracking = true
            self.parent.onEditingChanged(true, Double(slider.value))
        }

        @objc func touchUp(_ slider: UISlider) {
            self.isTracking = false
            self.parent.onEditingChanged(false, Double(slider.value))
        }
    }
}
