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
        let width = sourceImage.width
        let height = sourceImage.height
        guard width > 0, height > 0 else { throw MaskEditingError.unsupportedImage }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)

        // Both bitmaps are drawn into plain (un-flipped) CGContexts, so memory row 0 is the
        // top row of the picture for the mask and the source alike. Going through a
        // UIGraphicsImageRenderer's flipped context with clip(to:mask:) turned the cut-out
        // upside down, which scrambled every outfit crop.
        var alpha = [UInt8](repeating: 0, count: width * height)
        let maskDrawn = alpha.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .high
            context.draw(maskImage, in: bounds)
            return true
        }
        guard maskDrawn else { throw MaskEditingError.unableToRenderCutout }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let cutoutImage: CGImage? = rgba.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.draw(sourceImage, in: bounds)
            // Scale premultiplied colour and alpha by the mask: white keeps a pixel, black removes it.
            let pixels = buffer.bindMemory(to: UInt8.self)
            for index in 0..<(width * height) {
                let coverage = Int(alpha[index])
                guard coverage != 255 else { continue }
                for channel in 0..<4 {
                    let offset = index * 4 + channel
                    pixels[offset] = UInt8((Int(pixels[offset]) * coverage + 127) / 255)
                }
            }
            return context.makeImage()
        }
        guard let cutoutImage else { throw MaskEditingError.unableToRenderCutout }
        return UIImage(cgImage: cutoutImage, scale: 1, orientation: .up)
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
