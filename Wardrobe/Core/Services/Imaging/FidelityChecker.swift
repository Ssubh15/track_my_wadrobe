import UIKit

struct FidelityCheckResult: Equatable {
    let colorDifference: Double
    let silhouetteAreaChange: Double
    let passes: Bool
}

enum FidelityError: LocalizedError, Equatable {
    case unableToMeasure
    case thresholdExceeded(FidelityCheckResult)

    var errorDescription: String? {
        switch self {
        case .unableToMeasure:
            "We couldn’t verify the enhanced image. You can use the plain cut-out instead."
        case .thresholdExceeded:
            "The enhancement changed the garment more than allowed, so we kept the plain cut-out."
        }
    }
}

protocol FidelityChecking {
    func check(before: UIImage, after: UIImage) throws -> FidelityCheckResult
}

struct FidelityChecker: FidelityChecking {
    let maximumColorDifference: Double
    let maximumSilhouetteAreaChange: Double

    init(maximumColorDifference: Double = 4.0, maximumSilhouetteAreaChange: Double = 0.01) {
        self.maximumColorDifference = maximumColorDifference
        self.maximumSilhouetteAreaChange = maximumSilhouetteAreaChange
    }

    func check(before: UIImage, after: UIImage) throws -> FidelityCheckResult {
        let beforeMeasurement = try measurement(for: before)
        let afterMeasurement = try measurement(for: after)
        let colorDifference = labDistance(beforeMeasurement.lab, afterMeasurement.lab)
        let areaChange = abs(afterMeasurement.area - beforeMeasurement.area) / max(beforeMeasurement.area, 1)
        let result = FidelityCheckResult(
            colorDifference: colorDifference,
            silhouetteAreaChange: areaChange,
            passes: colorDifference <= maximumColorDifference && areaChange <= maximumSilhouetteAreaChange
        )
        guard result.passes else { throw FidelityError.thresholdExceeded(result) }
        return result
    }

    private func measurement(for image: UIImage) throws -> (lab: (Double, Double, Double), area: Double) {
        guard let cgImage = image.cgImage else { throw FidelityError.unableToMeasure }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FidelityError.unableToMeasure }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var area = 0.0
        var totalOpacity = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.02 else { continue }
            // Rendered RGB values are premultiplied by alpha. Dividing their sum by
            // total opacity measures the garment, not its transparent canvas.
            red += Double(pixels[index]) / 255
            green += Double(pixels[index + 1]) / 255
            blue += Double(pixels[index + 2]) / 255
            area += 1
            totalOpacity += alpha
        }
        guard area > 0, totalOpacity > 0 else { throw FidelityError.unableToMeasure }
        return (rgbToLab(red / totalOpacity, green / totalOpacity, blue / totalOpacity), area)
    }

    private func labDistance(_ lhs: (Double, Double, Double), _ rhs: (Double, Double, Double)) -> Double {
        sqrt(pow(lhs.0 - rhs.0, 2) + pow(lhs.1 - rhs.1, 2) + pow(lhs.2 - rhs.2, 2))
    }

    private func rgbToLab(_ red: Double, _ green: Double, _ blue: Double) -> (Double, Double, Double) {
        func linear(_ value: Double) -> Double {
            value > 0.04045 ? pow((value + 0.055) / 1.055, 2.4) : value / 12.92
        }
        let r = linear(red)
        let g = linear(green)
        let b = linear(blue)
        let x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
        let y = (r * 0.2126 + g * 0.7152 + b * 0.0722)
        let z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
        func pivot(_ value: Double) -> Double {
            value > 0.008856 ? pow(value, 1.0 / 3.0) : 7.787 * value + 16.0 / 116.0
        }
        let fx = pivot(x)
        let fy = pivot(y)
        let fz = pivot(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }
}

struct MockFidelityChecker: FidelityChecking {
    var result = FidelityCheckResult(colorDifference: 0, silhouetteAreaChange: 0, passes: true)
    var error: FidelityError?

    func check(before: UIImage, after: UIImage) throws -> FidelityCheckResult {
        if let error { throw error }
        return result
    }
}
