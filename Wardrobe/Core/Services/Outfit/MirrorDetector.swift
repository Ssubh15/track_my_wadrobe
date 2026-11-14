import CoreImage
import Foundation
import ImageIO
import UIKit
import Vision

struct MirrorDetection: Equatable {
    let isLikelyMirrorSelfie: Bool
    let confidence: Double
    let reasons: [String]
}

protocol MirrorDetector {
    func detect(in image: UIImage) async throws -> MirrorDetection
    /// A lossless horizontal transform; it never synthesizes garment pixels.
    func flipped(_ image: UIImage) throws -> UIImage
}

/// Conservative, on-device mirror-selfie heuristic. It looks for recognised text and a compact,
/// high-contrast rectangle around the upper body (a possible held phone). Results remain a guess
/// and the future UI must expose the requested flip toggle.
struct VisionMirrorDetector: MirrorDetector {
    func detect(in image: UIImage) async throws -> MirrorDetection {
        try await Task.detached(priority: .userInitiated) { try Self.detectSynchronously(in: image) }.value
    }

    func flipped(_ image: UIImage) throws -> UIImage {
        guard let source = MaskImageProcessor.normalizedUpImage(image), let cgImage = source.cgImage else {
            throw MirrorDetectorError.unsupportedImage
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .upMirrored)
    }

    private static func detectSynchronously(in image: UIImage) throws -> MirrorDetection {
        guard let source = MaskImageProcessor.normalizedUpImage(image), let cgImage = source.cgImage else {
            throw MirrorDetectorError.unsupportedImage
        }
        let uprightTextCount = try recognisedTextCount(in: cgImage, orientation: .up)
        let mirroredTextCount = try recognisedTextCount(in: cgImage, orientation: .upMirrored)
        let appearsBackwards = mirroredTextCount > uprightTextCount
        let phoneLikeRectangle = hasPhoneLikeRectangle(in: cgImage)
        var reasons: [String] = []
        if phoneLikeRectangle { reasons.append("A phone-shaped object may be visible near the upper body.") }
        if appearsBackwards { reasons.append("Text or a logo was recognised more reliably after mirroring.") }
        let confidence = min(0.75, (phoneLikeRectangle ? 0.45 : 0) + (appearsBackwards ? 0.35 : 0))
        return MirrorDetection(isLikelyMirrorSelfie: confidence >= 0.45, confidence: confidence, reasons: reasons)
    }

    private static func recognisedTextCount(in image: CGImage, orientation: CGImagePropertyOrientation) throws -> Int {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)
        try handler.perform([request])
        return request.results?.filter { !($0.topCandidates(1).first?.string.isEmpty ?? true) }.count ?? 0
    }

    private static func hasPhoneLikeRectangle(in image: CGImage) -> Bool {
        let width = image.width, height = image.height
        guard width > 20, height > 20 else { return false }
        let candidate = CGRect(x: CGFloat(width) * 0.30, y: CGFloat(height) * 0.12, width: CGFloat(width) * 0.40, height: CGFloat(height) * 0.48)
        guard let cropped = image.cropping(to: candidate.integral) else { return false }
        var pixels = [UInt8](repeating: 0, count: cropped.width * cropped.height)
        guard let context = CGContext(data: &pixels, width: cropped.width, height: cropped.height, bitsPerComponent: 8, bytesPerRow: cropped.width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
        let dark = pixels.filter { $0 < 35 }.count
        return Double(dark) / Double(pixels.count) > 0.06
    }
}

enum MirrorDetectorError: LocalizedError, Equatable {
    case unsupportedImage

    var errorDescription: String? { "This photo format can’t be flipped. Try choosing another photo." }
}

struct MockMirrorDetector: MirrorDetector {
    var result = MirrorDetection(isLikelyMirrorSelfie: false, confidence: 0, reasons: [])
    func detect(in image: UIImage) async throws -> MirrorDetection { result }
    func flipped(_ image: UIImage) throws -> UIImage { image }
}
