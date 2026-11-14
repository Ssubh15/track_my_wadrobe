import CoreGraphics
import UIKit

/// Trims a full-frame garment cut-out to its mask bounds so review and saved items show the
/// garment itself, not a photo-sized transparent canvas. Pixels are only cropped, never altered.
enum GarmentCutoutCropper {
    static func crop(_ cutout: UIImage, to mask: UIImage, paddingFraction: CGFloat = 0.04) -> UIImage {
        guard let cutoutCG = cutout.cgImage, let maskCG = mask.cgImage,
              cutoutCG.width == maskCG.width, cutoutCG.height == maskCG.height,
              let bounds = MaskImageProcessor.foregroundBounds(in: maskCG) else { return cutout }
        let padX = (bounds.width * paddingFraction).rounded(.up)
        let padY = (bounds.height * paddingFraction).rounded(.up)
        let full = CGRect(x: 0, y: 0, width: cutoutCG.width, height: cutoutCG.height)
        let rect = bounds.insetBy(dx: -padX, dy: -padY).intersection(full).integral
        guard !rect.isEmpty, let cropped = cutoutCG.cropping(to: rect) else { return cutout }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }
}
