import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct ImageQualityCheckResult: Equatable {
    let issues: [ImageQualityIssue]
    var isAcceptable: Bool { issues.isEmpty }
}

enum ImageQualityIssue: String, Equatable, Identifiable {
    case blurry
    case tooDark
    case tooBright
    case garmentCutOff

    var id: String { rawValue }
    var title: String {
        switch self { case .blurry: "The photo looks blurry"; case .tooDark: "The photo is too dark"; case .tooBright: "The photo is too bright"; case .garmentCutOff: "The garment may be cut off" }
    }
    var explanation: String {
        switch self { case .blurry: "Hold the phone steady and try again."; case .tooDark: "Move to a brighter, evenly lit spot."; case .tooBright: "Avoid direct glare and strong backlighting."; case .garmentCutOff: "Leave a little space around every edge of the garment." }
    }
}

protocol ImageQualityChecking {
    func check(_ image: UIImage) -> ImageQualityCheckResult
}

struct ImageQualityChecker: ImageQualityChecking {
    var blurThreshold: Float = 35
    var darkThreshold: Float = 0.12
    var brightThreshold: Float = 0.92

    func check(_ image: UIImage) -> ImageQualityCheckResult {
        guard let ciImage = CIImage(image: image) else { return ImageQualityCheckResult(issues: [.blurry]) }
        var issues: [ImageQualityIssue] = []
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        if laplacianVariance(ciImage, context: context) < blurThreshold { issues.append(.blurry) }
        let brightness = averageBrightness(ciImage, context: context)
        if brightness < darkThreshold { issues.append(.tooDark) }
        if brightness > brightThreshold { issues.append(.tooBright) }
        if touchesFrameEdge(ciImage, context: context) { issues.append(.garmentCutOff) }
        return ImageQualityCheckResult(issues: issues)
    }

    private func averageBrightness(_ image: CIImage, context: CIContext) -> Float {
        let filter = CIFilter.areaAverage(); filter.inputImage = image; filter.extent = image.extent
        guard let output = filter.outputImage else { return 0.5 }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return (Float(pixel[0]) + Float(pixel[1]) + Float(pixel[2])) / (3 * 255)
    }

    private func laplacianVariance(_ image: CIImage, context: CIContext) -> Float {
        let filter = CIFilter.convolution3X3(); filter.inputImage = image; filter.weights = CIVector(values: [0, 1, 0, 1, -4, 1, 0, 1, 0], count: 9); filter.bias = 0
        guard let output = filter.outputImage?.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0]) else { return 0 }
        let extent = output.extent
        let mean = output.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: extent)])
        let squared = output.applyingFilter("CIColorPolynomial", parameters: ["inputRedCoefficients": CIVector(x: 0, y: 0, z: 1, w: 0), "inputGreenCoefficients": CIVector(x: 0, y: 0, z: 1, w: 0), "inputBlueCoefficients": CIVector(x: 0, y: 0, z: 1, w: 0)])
        let squareMean = squared.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: extent)])
        var meanPixel = [UInt8](repeating: 0, count: 4)
        var squarePixel = [UInt8](repeating: 0, count: 4)
        context.render(mean, toBitmap: &meanPixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        context.render(squareMean, toBitmap: &squarePixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        let meanValue = Float(meanPixel[0]) / 255
        let squareValue = Float(squarePixel[0]) / 255
        return max(0, squareValue - meanValue * meanValue) * 255
    }

    private func touchesFrameEdge(_ image: CIImage, context: CIContext) -> Bool {
        let extent = image.extent
        let inner = extent.insetBy(dx: extent.width * 0.08, dy: extent.height * 0.08)
        let centerBrightness = averageBrightness(image, in: inner, context: context)
        let edgeWidth = max(1, extent.width * 0.04)
        let edgeHeight = max(1, extent.height * 0.04)
        let edges = [
            CGRect(x: extent.minX, y: extent.minY, width: extent.width, height: edgeHeight),
            CGRect(x: extent.minX, y: extent.maxY - edgeHeight, width: extent.width, height: edgeHeight),
            CGRect(x: extent.minX, y: extent.minY, width: edgeWidth, height: extent.height),
            CGRect(x: extent.maxX - edgeWidth, y: extent.minY, width: edgeWidth, height: extent.height)
        ]
        return edges.contains { abs(averageBrightness(image, in: $0, context: context) - centerBrightness) > 0.25 }
    }

    private func averageBrightness(_ image: CIImage, in region: CGRect, context: CIContext) -> Float {
        let filter = CIFilter.areaAverage(); filter.inputImage = image; filter.extent = region
        guard let output = filter.outputImage else { return 0.5 }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return (Float(pixel[0]) + Float(pixel[1]) + Float(pixel[2])) / (3 * 255)
    }
}
