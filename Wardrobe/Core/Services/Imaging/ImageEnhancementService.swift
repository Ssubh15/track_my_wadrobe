import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum ImageEnhancementError: LocalizedError, Equatable {
    case unableToEnhance

    var errorDescription: String? {
        "We couldn’t enhance this cut-out. You can still use the original cut-out."
    }
}

protocol ImageEnhancementServing {
    func enhance(_ image: UIImage) throws -> UIImage
}

/// Conservative, deterministic Core Image adjustments. This service never generates or draws garment pixels.
struct ImageEnhancementService: ImageEnhancementServing {
    private let context = CIContext()

    func enhance(_ image: UIImage) throws -> UIImage {
        guard let input = CIImage(image: image) else { throw ImageEnhancementError.unableToEnhance }
        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = input
        exposure.ev = 0.08

        let whiteBalance = CIFilter.temperatureAndTint()
        whiteBalance.inputImage = exposure.outputImage
        whiteBalance.neutral = CIVector(x: 6_500, y: 0)
        whiteBalance.targetNeutral = CIVector(x: 6_475, y: 0)

        let noiseReduction = CIFilter.noiseReduction()
        noiseReduction.inputImage = whiteBalance.outputImage
        noiseReduction.noiseLevel = 0.008
        noiseReduction.sharpness = 0.20

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = noiseReduction.outputImage
        sharpen.sharpness = 0.08
        guard let output = sharpen.outputImage,
              let cgImage = context.createCGImage(output, from: input.extent) else {
            throw ImageEnhancementError.unableToEnhance
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

struct MockImageEnhancementService: ImageEnhancementServing {
    var enhancedImage: UIImage?
    var error: ImageEnhancementError?

    func enhance(_ image: UIImage) throws -> UIImage {
        if let error { throw error }
        return enhancedImage ?? image
    }
}
