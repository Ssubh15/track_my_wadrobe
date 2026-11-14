import CoreGraphics
import Foundation
import UIKit

struct GarmentAttributes: Equatable, Sendable {
    var dominantColorHex: String?
    var secondaryColorHexes: [String]
    var pattern: String?
    var sleeveLength: String?
    var fit: String?
}

protocol AttributeExtractor {
    func extract(from image: UIImage, mask: UIImage) throws -> GarmentAttributes
}

enum AttributeExtractorError: LocalizedError, Equatable {
    case unsupportedImage
    case noMaskedPixels

    var errorDescription: String? {
        switch self {
        case .unsupportedImage: "This garment image can’t be read for attributes."
        case .noMaskedPixels: "No garment pixels were found in the mask."
        }
    }
}

struct KMeansAttributeExtractor: AttributeExtractor {
    let clusterCount: Int
    let maximumSamples: Int
    let iterations: Int

    init(clusterCount: Int = 3, maximumSamples: Int = 4_096, iterations: Int = 8) {
        self.clusterCount = max(1, clusterCount)
        self.maximumSamples = max(1, maximumSamples)
        self.iterations = max(1, iterations)
    }

    func extract(from image: UIImage, mask: UIImage) throws -> GarmentAttributes {
        guard let source = rgbaPixels(for: image), let maskPixels = rgbaPixels(for: mask),
              source.width == maskPixels.width, source.height == maskPixels.height else {
            throw AttributeExtractorError.unsupportedImage
        }

        var samples: [RGB] = []
        let sampleStride = max(1, (source.width * source.height) / maximumSamples)
        for index in stride(from: 0, to: source.width * source.height, by: sampleStride) {
            let maskIndex = index * 4
            let alpha = Double(maskPixels.bytes[maskIndex + 3]) / 255
            guard alpha > 0.1 else { continue }
            let coverage = Double(maskPixels.bytes[maskIndex]) / 255
            guard coverage > 0.1 else { continue }
            let pixelIndex = index * 4
            let sourceAlpha = Double(source.bytes[pixelIndex + 3]) / 255
            guard sourceAlpha > 0 else { continue }
            let pixel = RGB(
                red: min(1, Double(source.bytes[pixelIndex]) / 255 / sourceAlpha),
                green: min(1, Double(source.bytes[pixelIndex + 1]) / 255 / sourceAlpha),
                blue: min(1, Double(source.bytes[pixelIndex + 2]) / 255 / sourceAlpha)
            )
            samples.append(pixel)
        }
        guard !samples.isEmpty else { throw AttributeExtractorError.noMaskedPixels }

        let clusters = kMeans(samples: samples, k: min(clusterCount, samples.count))
        let ordered = clusters.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.index < $1.index
        }
        return GarmentAttributes(
            dominantColorHex: ordered.first.map { $0.center.hex },
            secondaryColorHexes: ordered.dropFirst().filter { $0.count > 0 }.map { $0.center.hex },
            pattern: nil,
            sleeveLength: nil,
            fit: nil
        )
    }

    private func kMeans(samples: [RGB], k: Int) -> [Cluster] {
        // Choose the first sample, then the farthest sample from the selected
        // centers. This is deterministic and avoids seeding both centers in one
        // solid-color region of an ordered image.
        var centers = [samples[0]]
        while centers.count < k {
            let nextIndex = samples.indices.max { lhs, rhs in
                let leftDistance = centers.map { samples[lhs].distance(to: $0) }.min() ?? 0
                let rightDistance = centers.map { samples[rhs].distance(to: $0) }.min() ?? 0
                if leftDistance != rightDistance { return leftDistance < rightDistance }
                return lhs > rhs
            } ?? 0
            centers.append(samples[nextIndex])
        }
        for _ in 0..<iterations {
            var buckets = Array(repeating: [RGB](), count: k)
            for sample in samples {
                let index = nearestCenterIndex(for: sample, centers: centers)
                buckets[index].append(sample)
            }
            let updated = buckets.enumerated().map { index, bucket in
                bucket.isEmpty ? centers[index] : RGB.average(bucket)
            }
            if updated == centers { break }
            centers = updated
        }
        return centers.enumerated().map { index, center in
            let count = samples.reduce(into: 0) { result, sample in
                let nearest = nearestCenterIndex(for: sample, centers: centers)
                if nearest == index { result += 1 }
            }
            return Cluster(index: index, center: center, count: count)
        }
    }

    private func nearestCenterIndex(for sample: RGB, centers: [RGB]) -> Int {
        centers.indices.min {
            let leftDistance = sample.distance(to: centers[$0])
            let rightDistance = sample.distance(to: centers[$1])
            if leftDistance != rightDistance { return leftDistance < rightDistance }
            return $0 < $1
        } ?? 0
    }

    private struct Cluster { let index: Int; let center: RGB; let count: Int }
    private struct PixelBuffer { let bytes: [UInt8]; let width: Int; let height: Int }
    private struct RGB: Equatable {
        let red: Double; let green: Double; let blue: Double
        func distance(to other: RGB) -> Double { (red - other.red) * (red - other.red) + (green - other.green) * (green - other.green) + (blue - other.blue) * (blue - other.blue) }
        static func average(_ values: [RGB]) -> RGB { RGB(red: values.map(\.red).reduce(0, +) / Double(values.count), green: values.map(\.green).reduce(0, +) / Double(values.count), blue: values.map(\.blue).reduce(0, +) / Double(values.count)) }
        var hex: String { String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded())) }
    }

    private func rgbaPixels(for image: UIImage) -> PixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return PixelBuffer(bytes: bytes, width: width, height: height)
    }
}
