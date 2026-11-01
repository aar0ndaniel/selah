import CoreImage
import UIKit

/// Ready-made tab bar images for Selah's 3D tab objects. The tab bar recolours every image as a template and ignores
/// SwiftUI size and colour modifiers, so the size (28 pt), the greyscale for idle tabs and the "always original"
/// rendering are baked into the `UIImage` itself.
@MainActor
enum TabObjectIcon {
    private static let side: CGFloat = 28
    private static var cache: [String: UIImage] = [:]

    static func image(named name: String, selected: Bool) -> UIImage? {
        let key = "\(name)-\(selected)"
        if let cached = cache[key] { return cached }
        guard let source = UIImage(named: name) else { return nil }

        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.preferred()
        var drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        if !selected, let grey = greyscale(drawn) {
            // Idle tabs: grey and a little faded, like Airbnb.
            drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                grey.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: 0.6)
            }
        }
        let result = drawn.withRenderingMode(.alwaysOriginal)
        cache[key] = result
        return result
    }

    private static func greyscale(_ image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(0, forKey: kCIInputSaturationKey)
        guard let output = filter.outputImage,
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }
}
