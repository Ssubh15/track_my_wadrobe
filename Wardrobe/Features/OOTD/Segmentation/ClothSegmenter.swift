import CoreML
import CoreVideo
import ImageIO
import UIKit

struct ClothLabelMap: Sendable {
    let width: Int
    let height: Int
    let labels: [UInt8]
    let originalSize: CGSize
    /// Exact mapping used to prepare the model's square input.
    let sourceToModelTransform: ClothImageTransform
    let inferenceMs: Double
    let modelInputPNG: Data
    let rawMaskPNG: Data

    init(width: Int, height: Int, labels: [UInt8], originalSize: CGSize, sourceToModelTransform: ClothImageTransform, inferenceMs: Double, modelInputPNG: Data = Data(), rawMaskPNG: Data = Data()) {
        self.width = width
        self.height = height
        self.labels = labels
        self.originalSize = originalSize
        self.sourceToModelTransform = sourceToModelTransform
        self.inferenceMs = inferenceMs
        self.modelInputPNG = modelInputPNG
        self.rawMaskPNG = rawMaskPNG
    }
}
/// Maps UIKit top-left source pixels to the model's top-left input pixels.
/// The shipped model was trained/evaluated with a 512×512 stretch, so this is
/// intentionally not an aspect-fill crop or implicit letterbox.
struct ClothImageTransform: Sendable, Equatable {
    let sourceSize: CGSize
    let modelSize: CGSize

    static func stretched(sourceSize: CGSize, modelSize: CGSize) -> ClothImageTransform {
        ClothImageTransform(sourceSize: sourceSize, modelSize: modelSize)
    }

    func sourcePoint(forModelPoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * sourceSize.width / modelSize.width,
            y: point.y * sourceSize.height / modelSize.height
        )
    }
}
enum ClothClass: UInt8, CaseIterable, Sendable {
    case background = 0
    case hat = 1
    case hair = 2
    case sunglasses = 3
    case upperClothes = 4
    case skirt = 5
    case pants = 6
    case dress = 7
    case belt = 8
    case leftShoe = 9
    case rightShoe = 10
    case face = 11
    case leftLeg = 12
    case rightLeg = 13
    case leftArm = 14
    case rightArm = 15
    case bag = 16
    case scarf = 17
}

enum ClothSegmenterError: Error, LocalizedError {
    case modelLoadFailed
    case predictionFailed
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "The outfit segmentation model could not be loaded."
        case .predictionFailed:
            return "The outfit image could not be segmented."
        case .invalidImage:
            return "This image could not be prepared for segmentation."
        }
    }
}

actor ClothSegmenter {
    private let modelName = "OOTDClothSegmenter_w8"
    private var model: MLModel?

    func computeUnitsDescription() -> String {
        switch model?.configuration.computeUnits ?? .all {
        case .all: "All available (CPU, GPU, Neural Engine)"
        case .cpuOnly: "CPU only"
        case .cpuAndGPU: "CPU and GPU"
        case .cpuAndNeuralEngine: "CPU and Neural Engine"
        @unknown default: "All available"
        }
    }

    func segment(_ image: UIImage) async throws -> ClothLabelMap {
        guard let source = MaskImageProcessor.normalizedUpImage(image),
              let sourceCGImage = source.cgImage else {
            throw ClothSegmenterError.invalidImage
        }
        let transform = ClothImageTransform.stretched(
            sourceSize: CGSize(width: sourceCGImage.width, height: sourceCGImage.height),
            modelSize: CGSize(width: 512, height: 512)
        )
        guard let prepared = Self.prepareImage(from: sourceCGImage, transform: transform), let pixelBuffer = Self.makePixelBuffer(from: prepared) else {
            throw ClothSegmenterError.invalidImage
        }

        let loadedModel: MLModel
        do {
            loadedModel = try loadModelIfNeeded()
        } catch {
            OutfitDiagnostics.recordSegmenterFailure(error)
            throw ClothSegmenterError.modelLoadFailed
        }

        let inputName = loadedModel.modelDescription.inputDescriptionsByName.first(where: {
            $0.value.type == .image
        })?.key
        guard let inputName else {
            throw ClothSegmenterError.predictionFailed
        }

        let output: MLFeatureProvider
        let startedAt = ContinuousClock.now
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                inputName: MLFeatureValue(pixelBuffer: pixelBuffer)
            ])
            output = try await loadedModel.prediction(from: input)
        } catch {
            throw ClothSegmenterError.predictionFailed
        }
        let elapsed = startedAt.duration(to: .now).components
        let inferenceMs = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15

        guard let labelsArray = output.featureValue(for: "labels")?.multiArrayValue,
              labelsArray.dataType == .int32,
              labelsArray.count == 512 * 512,
              labelsArray.shape.map(\.intValue) == [1, 512, 512] else {
            throw ClothSegmenterError.predictionFailed
        }

        let labels = (0..<labelsArray.count).map { index in
            UInt8(clamping: labelsArray[index].int32Value)
        }
        return ClothLabelMap(
            width: 512,
            height: 512,
            labels: labels,
            originalSize: transform.sourceSize,
            sourceToModelTransform: transform,
            inferenceMs: inferenceMs,
            modelInputPNG: prepared.pngData() ?? Data(),
            rawMaskPNG: Self.renderRawMask(labels: labels, width: 512, height: 512).pngData() ?? Data()
        )
    }

    /// Call when the OOTD flow is dismissed to release the loaded model.
    func releaseModel() {
        model = nil
    }

    private func loadModelIfNeeded() throws -> MLModel {
        if let model { return model }

        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            throw ClothSegmenterError.modelLoadFailed
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let loadedModel = try MLModel(contentsOf: modelURL, configuration: configuration)
        model = loadedModel
        return loadedModel
    }

    private static func prepareImage(from image: CGImage, transform: ClothImageTransform) -> UIImage? {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: transform.modelSize, format: format).image { _ in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: transform.modelSize))
        }
    }

    private static func makePixelBuffer(from prepared: UIImage) -> CVPixelBuffer? {
        let width = 512
        let height = 512
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        ) == kCVReturnSuccess,
              let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // UIKit redraw establishes a top-left image space before Core Graphics
        // writes into the model buffer; use the recorded transform exactly.
        guard let preparedImage = prepared.cgImage else { return nil }
        context.interpolationQuality = .high
        context.draw(preparedImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }

    private static func renderRawMask(labels: [UInt8], width: Int, height: Int) -> UIImage {
        // Distinct colours so hair, skin and bag are distinguishable in diagnostics.
        let colors: [UInt8: (UInt8, UInt8, UInt8)] = [
            1: (255, 165, 0), 2: (90, 50, 20), 3: (128, 128, 128), 4: (255, 0, 0), 5: (0, 128, 255), 6: (0, 0, 255),
            7: (255, 0, 255), 8: (255, 255, 0), 9: (0, 255, 0), 10: (0, 255, 0), 11: (255, 200, 170),
            12: (230, 170, 140), 13: (230, 170, 140), 14: (200, 140, 110), 15: (200, 140, 110), 16: (0, 255, 255), 17: (128, 0, 128)
        ]
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<min(labels.count, width * height) { let c = colors[labels[i]] ?? (0, 0, 0); bytes[i*4] = c.0; bytes[i*4+1] = c.1; bytes[i*4+2] = c.2; bytes[i*4+3] = labels[i] == 0 ? 0 : 255 }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return UIImage(cgImage: cg)
    }
}

