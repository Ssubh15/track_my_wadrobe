import Foundation
import UIKit

protocol ClothSegmenting: Sendable {
    func segment(_ image: UIImage) async throws -> ClothLabelMap
}

extension ClothSegmenter: ClothSegmenting {}

/// Adapts the OOTD label model to the existing parser contract.
struct ClothSegformerClothingParser: ClothingParser {
    let legacy: any ClothingParser
    let segmenter: any ClothSegmenting
    let extractor: OutfitItemExtractor
    let logFallback: @Sendable (String) -> Void

    init(legacy: any ClothingParser = StubClothingParser(), segmenter: any ClothSegmenting = ClothSegmenter(), extractor: OutfitItemExtractor = OutfitItemExtractor(), logFallback: @escaping @Sendable (String) -> Void = { NSLog("ClothSegformer fallback: %@", $0) }) {
        self.legacy = legacy
        self.segmenter = segmenter
        self.extractor = extractor
        self.logFallback = logFallback
    }

    func parse(personMask: UIImage, in image: UIImage) async throws -> [GarmentRegion] {
        do {
            #if DEBUG
            NSLog("Outfit segmenter: OOTDClothSegmenter_w8")
            #endif
            let map = try await segmenter.segment(image)
            OutfitDiagnostics.recordSegmenterLoaded()
            let items = extractor.extract(from: map, image: image)
            if OutfitDiagnostics.saveDiagnosticImages { OutfitDiagnosticImageWriter.write(source: image, map: map, items: items) }
            guard !items.isEmpty else {
                logFallback("zero clothing items")
                return try await legacy.parse(personMask: personMask, in: image)
            }
            return items.map { item in
                let kind: OutfitGarmentKind = switch item.category {
                case .dress: .dress
                case .jacket: .outerwear
                case .pants, .trousers, .jeans, .skirt, .shorts: .bottoms
                case .shoes: .shoes
                default: .top
                }
                let mask = OutfitMaskRenderer.intersection(of: item.mask, and: personMask) ?? item.mask
                return GarmentRegion(kind: kind, mask: mask, confidence: 0.75, occlusionReason: nil)
            }
        } catch {
            #if DEBUG
            assertionFailure("OOTDClothSegmenter_w8 failed to load or segment: \(error)")
            #endif
            logFallback("segmentation failed: \(error)")
            OutfitDiagnostics.recordSegmenterFailure(error)
            return try await legacy.parse(personMask: personMask, in: image)
        }
    }
}
