import CoreGraphics
import Foundation
import UIKit

/// The tools available when changing a foreground mask. Neither tool changes source pixels.
enum MaskBrushTool: String, CaseIterable, Identifiable {
    case erase
    case restore

    var id: String { rawValue }
    var title: String { self == .erase ? "Erase" : "Restore" }
    var systemImage: String { self == .erase ? "eraser" : "paintbrush" }
}

/// A brush stroke expressed as positions relative to the mask's width and height.
/// Using normalized positions lets an outline be edited at any display zoom.
struct MaskBrushStroke {
    let points: [CGPoint]
    let diameter: CGFloat
    let tool: MaskBrushTool
}

enum MaskEditingError: LocalizedError, Equatable {
    case unsupportedImage
    case emptyStroke
    case unableToRenderMask
    case unableToRenderCutout

    var errorDescription: String? {
        switch self {
        case .unsupportedImage:
            "This image can’t be edited. Try choosing the photo again."
        case .emptyStroke:
            "Draw over the outline to make an edit."
        case .unableToRenderMask:
            "We couldn’t update that outline. Please try again."
        case .unableToRenderCutout:
            "We couldn’t preview that outline. Please try again."
        }
    }
}

protocol MaskEditing {
    func applying(_ stroke: MaskBrushStroke, to mask: UIImage) throws -> UIImage
    func makingCutout(from source: UIImage, using mask: UIImage) throws -> UIImage
}

/// A deterministic, on-device mask renderer. It paints only white and black values into a mask.
struct MaskEditingService: MaskEditing {
    func applying(_ stroke: MaskBrushStroke, to mask: UIImage) throws -> UIImage {
        guard !stroke.points.isEmpty else { throw MaskEditingError.emptyStroke }
        guard let maskImage = mask.normalizedCGImage else { throw MaskEditingError.unsupportedImage }

        let size = CGSize(width: CGFloat(maskImage.width), height: CGFloat(maskImage.height))
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let brushDiameter = max(1, min(size.width, size.height) * stroke.diameter)

        let editedMask = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.draw(maskImage, in: CGRect(origin: .zero, size: size))
            context.setStrokeColor((stroke.tool == .erase ? UIColor.black : UIColor.white).cgColor)
            context.setFillColor((stroke.tool == .erase ? UIColor.black : UIColor.white).cgColor)
            context.setLineWidth(brushDiameter)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let convertedPoints = stroke.points.map {
                CGPoint(x: $0.x.clamped(to: 0...1) * size.width, y: $0.y.clamped(to: 0...1) * size.height)
            }
            if let first = convertedPoints.first {
                if convertedPoints.dropFirst().allSatisfy({ $0 == first }) {
                    let dot = CGRect(
                        x: first.x - brushDiameter / 2,
                        y: first.y - brushDiameter / 2,
                        width: brushDiameter,
                        height: brushDiameter
                    )
                    context.fillEllipse(in: dot)
                } else {
                    context.beginPath()
                    context.move(to: first)
                    for point in convertedPoints.dropFirst() { context.addLine(to: point) }
                    context.strokePath()
                }
            }
        }
        guard editedMask.cgImage != nil else { throw MaskEditingError.unableToRenderMask }
        return editedMask
    }

    func makingCutout(from source: UIImage, using mask: UIImage) throws -> UIImage {
        guard let sourceImage = source.normalizedCGImage,
              let maskImage = mask.normalizedCGImage else {
            throw MaskEditingError.unsupportedImage
        }

        let size = CGSize(width: CGFloat(sourceImage.width), height: CGFloat(sourceImage.height))
        guard let alphaMask = makeAlphaMask(from: maskImage, size: size) else {
            throw MaskEditingError.unableToRenderCutout
        }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let cutout = UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.clip(to: CGRect(origin: .zero, size: size), mask: alphaMask)
            context.draw(sourceImage, in: CGRect(origin: .zero, size: size))
        }
        guard cutout.cgImage != nil else { throw MaskEditingError.unableToRenderCutout }
        return cutout
    }

    private func makeAlphaMask(from image: CGImage, size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        // Quartz clip masks use 0 for opaque and 255 for transparent. Wardrobe masks
        // use the clearer white-for-foreground convention, so invert at this boundary.
        pixels = pixels.map { 255 - $0 }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            maskWidth: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            provider: provider,
            decode: nil,
            shouldInterpolate: true
        )
    }
}

/// A deterministic test and preview double. It can supply a known result without editing images.
struct MockMaskEditingService: MaskEditing {
    var editedMask: UIImage?
    var cutout: UIImage?
    var error: MaskEditingError?

    func applying(_ stroke: MaskBrushStroke, to mask: UIImage) throws -> UIImage {
        if let error { throw error }
        return editedMask ?? mask
    }

    func makingCutout(from source: UIImage, using mask: UIImage) throws -> UIImage {
        if let error { throw error }
        return cutout ?? source
    }
}

private extension UIImage {
    var normalizedCGImage: CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized.cgImage
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
