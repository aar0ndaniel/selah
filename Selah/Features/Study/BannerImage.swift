import SwiftUI
import UIKit

/// Prepares a picked photo for use as a book banner.
enum BannerImage {
    static let maxWidth: CGFloat = 1600

    /// Downscales to at most `maxWidth` points wide (never enlarges) and returns JPEG data, or nil when the
    /// data is not an image.
    static func jpegData(from data: Data, maxWidth: CGFloat = BannerImage.maxWidth, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, maxWidth / size.width)
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

/// The banner photo, cropped to fill. Decorative (the book name is next to it), so hidden from VoiceOver.
struct BannerImageView: View {
    let data: Data
    var height: CGFloat = 160

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
                .accessibilityHidden(true)
        }
    }
}
