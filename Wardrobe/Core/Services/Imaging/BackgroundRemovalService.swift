import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML
import Foundation
import UIKit
import Vision

struct BackgroundRemovalResult {
    let cutout: UIImage
    let mask: UIImage
    let maskSource: UIImage
    let extractionModel: ExtractionModel

    init(cutout: UIImage, mask: UIImage, maskSource: UIImage? = nil, extractionModel: ExtractionModel = .appleVision) {
        self.cutout = cutout
        self.mask = mask
        self.maskSource = maskSource ?? cutout
        self.extractionModel = extractionModel
    }

    var cutoutPNG: Data? { cutout.pngData() }
    var maskPNG: Data? { mask.pngData() }
}

enum ExtractionModel: String {
    case u2Net = "U²-Net"
    case appleVision = "Apple Vision"
}

enum BackgroundRemovalError: LocalizedError, Equatable {
    case unsupportedImage
    case noGarmentDetected
    case modelUnavailable
    case maskQualityTooLow
    case unableToCreateCutout

    var errorDescription: String? {
        switch self {
        case .unsupportedImage: "This photo format can’t be processed. Try choosing another photo."
        case .noGarmentDetected: "We couldn’t find a clear foreground garment. Tap Retry to try again."
        case .modelUnavailable: "The on-device cut-out model is unavailable. Tap Retry to try again."
        case .maskQualityTooLow: "We couldn’t make a reliable cut-out. Tap Retry to try again."
        case .unableToCreateCutout: "We couldn’t make a cut-out from this photo. Tap Retry to try again."
        }
    }
}

protocol CutoutService {
    func removeBackground(from image: UIImage) async throws -> BackgroundRemovalResult
}

struct CoreMLCutoutService: CutoutService {
    private let fallback: any CutoutService
    private let modelURL: URL?

    init(fallback: any CutoutService = VisionCutoutService(), modelURL: URL? = nil) {
        self.fallback = fallback
        self.modelURL = modelURL ?? Bundle.main.url(forResource: "U2NetP", withExtension: "mlmodelc")
    }

    func removeBackground(from image: UIImage) async throws -> BackgroundRemovalResult {
        do {
            return try await Task.detached(priority: .userInitiated) {
                try Self.makeResult(from: image, modelURL: modelURL)
            }.value
        } catch {
            do { return try await fallback.removeBackground(from: image) }
            catch { throw (error as? BackgroundRemovalError) ?? .maskQualityTooLow }
        }
    }

    private static func makeResult(from image: UIImage, modelURL: URL?) throws -> BackgroundRemovalResult {
        guard let source = MaskImageProcessor.normalizedUpImage(image), let sourceCGImage = source.cgImage else { throw BackgroundRemovalError.unsupportedImage }
        guard let modelURL else {
            recordStatus("U2NetP.mlmodelc missing from app bundle; used Apple Vision")
            throw BackgroundRemovalError.modelUnavailable
        }
        let model: MLModel
        do {
            model = try MLModel(contentsOf: modelURL)
        } catch {
            recordStatus("U2NetP failed to load: \(error.localizedDescription); used Apple Vision")
            throw error
        }
        guard model.modelDescription.inputDescriptionsByName["image"]?.type == .image,
              let pixelBuffer = try makePixelBuffer(from: sourceCGImage, size: 320) else {
            recordStatus("U2NetP input mismatch; used Apple Vision")
            throw BackgroundRemovalError.modelUnavailable
        }
        let prediction = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)]))
        guard let output = prediction.featureValue(for: "mask")?.multiArrayValue
                ?? prediction.featureNames.sorted().compactMap({ prediction.featureValue(for: $0)?.multiArrayValue }).first,
              let mask = try MaskImageProcessor.image(from: output, size: CGSize(width: sourceCGImage.width, height: sourceCGImage.height)) else {
            recordStatus("U2NetP output unreadable; used Apple Vision")
            throw BackgroundRemovalError.maskQualityTooLow
        }
        guard MaskImageProcessor.passesQualityCheck(mask) else {
            recordStatus("U2NetP ran, but its mask failed the quality check; used Apple Vision")
            throw BackgroundRemovalError.maskQualityTooLow
        }
        recordStatus("U2NetP used")
        return try MaskImageProcessor.result(source: source, mask: mask, extractionModel: .u2Net)
    }

    private static func recordStatus(_ status: String) {
        UserDefaults.standard.set(status, forKey: OutfitDiagnostics.u2NetStatusKey)
    }

    private static func makePixelBuffer(from image: CGImage, size: Int) throws -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, size, size, kCVPixelFormatType_32BGRA, attributes, &buffer) == kCVReturnSuccess, let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, []); defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer), let context = CGContext(data: baseAddress, width: size, height: size, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        return buffer
    }
}

struct VisionCutoutService: CutoutService {
    func removeBackground(from image: UIImage) async throws -> BackgroundRemovalResult {
        try await Task.detached(priority: .userInitiated) { try Self.makeResult(from: image) }.value
    }

    private static func makeResult(from image: UIImage) throws -> BackgroundRemovalResult {
        guard let source = MaskImageProcessor.normalizedUpImage(image), let cgImage = source.cgImage else { throw BackgroundRemovalError.unsupportedImage }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else { throw BackgroundRemovalError.noGarmentDetected }
        let buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        let maskCI = CIImage(cvPixelBuffer: buffer)
        guard let maskCGImage = CIContext().createCGImage(maskCI, from: maskCI.extent), let mask = MaskImageProcessor.resizeMask(UIImage(cgImage: maskCGImage), to: source.size), MaskImageProcessor.passesQualityCheck(mask) else { throw BackgroundRemovalError.maskQualityTooLow }
        return try MaskImageProcessor.result(source: source, mask: mask, extractionModel: .appleVision)
    }
}

typealias BackgroundRemovalService = CutoutService
typealias VisionBackgroundRemovalService = VisionCutoutService

struct MockBackgroundRemovalService: CutoutService {
    var result: BackgroundRemovalResult?
    var error: BackgroundRemovalError?
    func removeBackground(from image: UIImage) async throws -> BackgroundRemovalResult {
        if let error { throw error }
        return result ?? BackgroundRemovalResult(cutout: image, mask: image)
    }
}

enum MaskImageProcessor {
    static func normalizedUpImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        guard image.imageOrientation != .up else { return UIImage(cgImage: cgImage, scale: 1, orientation: .up) }
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    static func resizeMask(_ mask: UIImage, to size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in mask.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// Converts a model mask (e.g. U²-Net's 1×1×320×320 Float16 `mask`) into a grayscale image.
    /// Reads the array with its real element type and strides; U²-Net emits Float16, so
    /// reinterpreting the buffer as Float32 produces garbage.
    static func image(from array: MLMultiArray, size: CGSize) throws -> UIImage? {
        let shape = array.shape.map(\.intValue)
        let strides = array.strides.map(\.intValue)
        guard shape.count >= 2 else { return nil }
        let height = shape[shape.count - 2], width = shape[shape.count - 1]
        let rowStride = strides[strides.count - 2], columnStride = strides[strides.count - 1]
        let count = width * height
        guard width > 0, height > 0, array.count == count else { return nil }
        var values = [Float](repeating: 0, count: count)
        func read<T: MLShapedArrayScalar>(_ type: T.Type, _ convert: (T) -> Float) {
            array.withUnsafeBufferPointer(ofType: T.self) { pointer in
                for y in 0..<height {
                    for x in 0..<width { values[y * width + x] = convert(pointer[y * rowStride + x * columnStride]) }
                }
            }
        }
        switch array.dataType {
        case .float16: read(Float16.self) { Float($0) }
        case .float32: read(Float32.self) { $0 }
        case .double: read(Double.self) { Float($0) }
        default: return nil
        }
        var minimum = Float.greatestFiniteMagnitude, maximum = -Float.greatestFiniteMagnitude
        for value in values { minimum = min(minimum, value); maximum = max(maximum, value) }
        let range = max(maximum - minimum, 0.0001)
        var pixels = [UInt8](repeating: 0, count: count)
        for index in 0..<count { pixels[index] = UInt8(max(0, min(255, ((values[index] - minimum) / range) * 255))) }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData), let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return resizeMask(UIImage(cgImage: cgImage), to: size)
    }

    static func passesQualityCheck(_ mask: UIImage) -> Bool {
        guard let image = mask.cgImage else { return false }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let threshold: UInt8 = 26
        let foreground = pixels.enumerated().filter { $0.element > threshold }.map(\.offset)
        guard Double(foreground.count) / Double(pixels.count) >= 0.10 else { return false }
        var border = Set<Int>()
        border.reserveCapacity(2 * width + 2 * height)
        for x in 0..<width {
            border.insert(x)
            border.insert((height - 1) * width + x)
        }
        for y in 0..<height {
            border.insert(y * width)
            border.insert(y * width + width - 1)
        }
        guard !foreground.contains(where: { border.contains($0) }) else { return false }
        return disconnectedRegionCount(pixels: pixels, width: width, threshold: threshold) <= 1
    }

    static func result(source: UIImage, mask: UIImage, extractionModel: ExtractionModel = .appleVision) throws -> BackgroundRemovalResult {
        guard let sourceCGImage = source.cgImage, let maskCGImage = mask.cgImage else { throw BackgroundRemovalError.unableToCreateCutout }
        let extent = CGRect(x: 0, y: 0, width: sourceCGImage.width, height: sourceCGImage.height)
        let sourceCI = CIImage(cgImage: sourceCGImage), maskCI = CIImage(cgImage: maskCGImage).cropped(to: extent)
        let adjusted = (CIFilter(name: "CIColorControls", parameters: [kCIInputImageKey: maskCI, kCIInputContrastKey: 1.12])?.outputImage ?? maskCI).clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.25]).cropped(to: extent)
        let output = sourceCI.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: extent), kCIInputMaskImageKey: adjusted])
        let context = CIContext()
        guard let bounds = foregroundBounds(in: maskCGImage), let outputCGImage = context.createCGImage(output, from: extent) else { throw BackgroundRemovalError.unableToCreateCutout }
        let padding = max(2, min(extent.width, extent.height) * 0.02)
        let paddedBounds = bounds.insetBy(dx: -padding, dy: -padding)
        // foregroundBounds is measured in top-left pixel coordinates; Core Image uses a bottom-left origin.
        let crop = CGRect(
            x: paddedBounds.minX,
            y: extent.height - paddedBounds.maxY,
            width: paddedBounds.width,
            height: paddedBounds.height
        ).intersection(extent).integral
        guard let cropped = context.createCGImage(CIImage(cgImage: outputCGImage).cropped(to: crop), from: crop), let croppedMask = context.createCGImage(maskCI.cropped(to: crop), from: crop), let croppedSource = context.createCGImage(sourceCI.cropped(to: crop), from: crop) else { throw BackgroundRemovalError.unableToCreateCutout }
        return BackgroundRemovalResult(cutout: UIImage(cgImage: cropped), mask: UIImage(cgImage: croppedMask), maskSource: UIImage(cgImage: croppedSource), extractionModel: extractionModel)
    }

    static func foregroundBounds(in image: CGImage) -> CGRect? {
        let width = image.width, height = image.height; var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let points = pixels.enumerated().filter { $0.element > 24 }.map(\.offset)
        guard let minX = points.map({ $0 % width }).min(), let maxX = points.map({ $0 % width }).max(), let minY = points.map({ $0 / width }).min(), let maxY = points.map({ $0 / width }).max() else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private static func disconnectedRegionCount(pixels: [UInt8], width: Int, threshold: UInt8) -> Int {
        var visited = Set<Int>(), regions = 0
        for index in pixels.indices where pixels[index] > threshold && !visited.contains(index) {
            var regionSize = 0; var queue = [index]; visited.insert(index)
            while let current = queue.popLast() { let x = current % width, y = current / width
                regionSize += 1
                for neighbor in [current - 1, current + 1, current - width, current + width] where neighbor >= 0 && neighbor < pixels.count { let nx = neighbor % width, ny = neighbor / width
                    guard abs(nx - x) + abs(ny - y) == 1, pixels[neighbor] > threshold, !visited.contains(neighbor) else { continue }; visited.insert(neighbor); queue.append(neighbor)
                }
            }
            if regionSize >= max(1, pixels.count / 100) { regions += 1 }
        }
        return regions
    }
}
