import SwiftUI
import UIKit

// TODO: Fix slider to avoid shifting back to previous state momentarily when scrubbing

struct SeekSlider: UIViewRepresentable {
    var value: Double
    var minimum: Double
    var maximum: Double
    var onEditingChanged: (Bool, Double) -> Void
    var onValueChanged: (Double) -> Void

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = Float(self.minimum)
        slider.maximumValue = Float(self.maximum)
        slider.value = Float(self.value)
        slider.minimumTrackTintColor = UIColor(.purp)
        slider.maximumTrackTintColor = UIColor(Color(.systemGray5))

        let thumb = Self.makeThumbImage(size: 16, color: UIColor(.purp))
        slider.setThumbImage(thumb, for: .normal)
        slider.setThumbImage(thumb, for: .highlighted)

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
