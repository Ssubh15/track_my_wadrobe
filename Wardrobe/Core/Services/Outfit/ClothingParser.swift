import Foundation
import UIKit

enum OutfitGarmentKind: String, CaseIterable, Sendable {
    case top
    case outerwear
    case bottoms
    case dress
    case shoes

    var suggestedCategory: GarmentCategory {
        switch self {
        case .top: .tShirt
        case .outerwear: .jacket
        case .bottoms: .pants
        case .dress: .dress
        case .shoes: .shoes
        }
    }
}

/// A parser-produced mask must contain only pixels from the supplied person mask.
struct GarmentRegion {
    let kind: OutfitGarmentKind
    let mask: UIImage
    let confidence: Double
    /// A model may set this when it detects another object or garment covering this region.
    let occlusionReason: PartialGarmentReason?
}

enum ClothingParserError: LocalizedError, Equatable {
    case unsupportedMask
    case unableToParse

    var errorDescription: String? {
        switch self {
        case .unsupportedMask: "We couldn’t read the person outline in this photo."
        case .unableToParse: "We couldn’t separate the visible garments in this photo."
        }
    }
}

/// The Core ML replacement point. A model implementation should return only visible, source-aligned pixels.
protocol ClothingParser {
    func parse(personMask: UIImage, in image: UIImage) async throws -> [GarmentRegion]
}

/// Temporary baseline until an approved on-device Core ML clothing model is bundled.
/// It divides the visible person mask into broad body-height bands; it does not claim semantic accuracy.
struct StubClothingParser: ClothingParser {
    func parse(personMask: UIImage, in image: UIImage) async throws -> [GarmentRegion] {
        guard let bounds = personMask.cgImage.flatMap(MaskImageProcessor.foregroundBounds) else {
            throw ClothingParserError.unsupportedMask
        }
        let fullHeight = CGFloat(personMask.cgImage?.height ?? 0)
        guard fullHeight > 0 else { throw ClothingParserError.unsupportedMask }

        let bands: [(OutfitGarmentKind, ClosedRange<CGFloat>, Double)] = [
            (.top, 0.22...0.52, 0.25),
            (.bottoms, 0.52...0.88, 0.25),
            (.shoes, 0.88...1.0, 0.20)
        ]
        return bands.compactMap { kind, range, confidence in
            let rect = CGRect(
                x: bounds.minX,
                y: bounds.minY + bounds.height * range.lowerBound,
                width: bounds.width,
                height: bounds.height * (range.upperBound - range.lowerBound)
            )
            guard let mask = OutfitMaskRenderer.intersecting(personMask, with: rect),
                  let maskImage = mask.cgImage,
                  MaskImageProcessor.foregroundBounds(in: maskImage) != nil else {
                return nil
            }
            return GarmentRegion(kind: kind, mask: mask, confidence: confidence, occlusionReason: nil)
        }
    }
}

struct MockClothingParser: ClothingParser {
    var regions: [GarmentRegion] = []
    var error: ClothingParserError?

    func parse(personMask: UIImage, in image: UIImage) async throws -> [GarmentRegion] {
        if let error { throw error }
        return regions
    }
}
