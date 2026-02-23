import SwiftUI

struct SVGImageView: View {
    let svgString: String
    let size: CGFloat

    private var renderedImage: UIImage? {
        guard let svg = SVG(self.svgString) else { return nil }
        let svgSize = svg.size
        guard svgSize.width > 0, svgSize.height > 0 else { return nil }

        let aspectRatio = svgSize.width / svgSize.height
        let renderWidth: CGFloat
        let renderHeight: CGFloat

        if aspectRatio >= 1 {
            renderWidth = self.size
            renderHeight = self.size / aspectRatio
        } else {
            renderHeight = self.size
            renderWidth = self.size * aspectRatio
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: renderWidth, height: renderHeight))
        return renderer.image { ctx in
            svg.draw(in: ctx.cgContext, size: CGSize(width: renderWidth, height: renderHeight))
        }
    }

    var body: some View {
        if let image = self.renderedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: self.size, height: self.size)
        } else {
            EmptyView()
        }
    }
}
