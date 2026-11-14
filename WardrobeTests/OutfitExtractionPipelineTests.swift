import UIKit
import XCTest
@testable import Wardrobe

final class OutfitExtractionPipelineTests: XCTestCase {
    func testPipelineReturnsEveryPersonUntilUserSelectsOne() async throws {
        let photo = fixtureImage()
        let first = OutfitPerson(identifier: 1, mask: fixtureMask(rect: CGRect(x: 15, y: 10, width: 20, height: 80)), boundingBox: CGRect(x: 15, y: 10, width: 20, height: 80))
        let second = OutfitPerson(identifier: 2, mask: fixtureMask(rect: CGRect(x: 55, y: 10, width: 20, height: 80)), boundingBox: CGRect(x: 55, y: 10, width: 20, height: 80))
        let pipeline = OutfitExtractionPipeline(
            segmenter: MockOutfitSegmenter(people: [first, second]),
            parser: MockClothingParser(),
            mirrorDetector: MockMirrorDetector()
        )

        let result = try await pipeline.extract(from: photo)

        XCTAssertTrue(result.requiresPersonSelection)
        XCTAssertEqual(result.people.map(\.identifier), [1, 2])
        XCTAssertTrue(result.garments.isEmpty)
    }

    func testPipelineCreatesOnlySelectedPersonsGarmentPixelsAndMarksFrameEdgePartial() async throws {
        let photo = fixtureImage()
        let personMask = fixtureMask(rect: CGRect(x: 0, y: 20, width: 45, height: 65))
        let person = OutfitPerson(identifier: 7, mask: personMask, boundingBox: CGRect(x: 0, y: 20, width: 45, height: 65))
        let topMask = fixtureMask(rect: CGRect(x: 0, y: 25, width: 45, height: 30))
        let region = GarmentRegion(kind: .top, mask: topMask, confidence: 0.8, occlusionReason: nil)
        let pipeline = OutfitExtractionPipeline(
            segmenter: MockOutfitSegmenter(people: [person]),
            parser: MockClothingParser(regions: [region]),
            mirrorDetector: MockMirrorDetector()
        )

        let result = try await pipeline.extract(from: photo, personIdentifier: 7)

        XCTAssertEqual(result.garments.count, 1)
        XCTAssertEqual(result.garments.first?.guessedCategory, .tShirt)
        XCTAssertTrue(result.garments.first?.isPartial ?? false)
        XCTAssertEqual(result.garments.first?.partialReason, .touchesFrame)
        XCTAssertEqual(MaskImageProcessor.foregroundBounds(in: try XCTUnwrap(result.garments.first?.mask.cgImage))?.minX, 0)
    }

    func testPipelineUsesParserOcclusionReason() async throws {
        let photo = fixtureImage()
        let mask = fixtureMask(rect: CGRect(x: 20, y: 20, width: 50, height: 60))
        let person = OutfitPerson(identifier: 3, mask: mask, boundingBox: CGRect(x: 20, y: 20, width: 50, height: 60))
        let region = GarmentRegion(kind: .outerwear, mask: mask, confidence: 0.7, occlusionReason: .occluded)
        let pipeline = OutfitExtractionPipeline(segmenter: MockOutfitSegmenter(people: [person]), parser: MockClothingParser(regions: [region]), mirrorDetector: MockMirrorDetector())

        let result = try await pipeline.extract(from: photo)

        XCTAssertEqual(result.garments.first?.partialReason, .occluded)
        XCTAssertTrue(result.garments.first?.isPartial ?? false)
    }

    func testStubParserCreatesTopBottomAndShoeCandidatesFromFixtureMask() async throws {
        let image = fixtureImage()
        let regions = try await StubClothingParser().parse(personMask: fixtureMask(rect: CGRect(x: 20, y: 10, width: 60, height: 80)), in: image)

        XCTAssertEqual(regions.map(\.kind), [.top, .bottoms, .shoes])
        XCTAssertTrue(regions.allSatisfy { $0.confidence < 0.30 })
    }

    func testMirrorFlipIsLosslessHorizontalTransform() throws {
        let image = fixtureImage()
        let flipped = try VisionMirrorDetector().flipped(image)

        XCTAssertEqual(flipped.imageOrientation, .upMirrored)
        XCTAssertEqual(flipped.cgImage?.width, image.cgImage?.width)
        XCTAssertEqual(flipped.cgImage?.height, image.cgImage?.height)
    }

    private func fixtureImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }

    private func fixtureMask(rect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.white.setFill()
            context.fill(rect)
        }
    }
}
