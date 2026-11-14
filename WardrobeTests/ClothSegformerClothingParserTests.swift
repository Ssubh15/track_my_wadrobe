import UIKit
import XCTest
@testable import Wardrobe

final class ClothSegformerClothingParserTests: XCTestCase {
    func testThrowingSegmenterFallsBackAndLogsReason() async throws {
        let legacy = LegacyParserSpy()
        let logs = FallbackLogSpy()
        let parser = ClothSegformerClothingParser(legacy: legacy, segmenter: FixedClothSegmenter(error: TestError.failed), logFallback: { message in Task { await logs.append(message) } })
        let regions = try await parser.parse(personMask: mask(), in: image())
        XCTAssertEqual(regions.map(\.kind), [.top])
        let calls = await legacy.callCount
        let messages = await logs.messages
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(messages.first?.contains("segmentation failed") == true)
    }

    func testZeroItemsFallsBackToLegacyParser() async throws {
        let legacy = LegacyParserSpy()
        let parser = ClothSegformerClothingParser(legacy: legacy, segmenter: FixedClothSegmenter(map: labelMap([UInt8](repeating: 0, count: 512 * 512))), extractor: OutfitItemExtractor(minimumAreaShare: 0.001))
        let regions = try await parser.parse(personMask: mask(), in: image())
        XCTAssertEqual(regions.map(\.kind), [.top])
        let calls = await legacy.callCount
        XCTAssertEqual(calls, 1)
    }

    func testValidItemsMapToRegionsWithoutCallingLegacy() async throws {
        let legacy = LegacyParserSpy()
        var labels = [UInt8](repeating: 0, count: 512 * 512)
        for y in 30..<150 { for x in 80..<180 { labels[y * 512 + x] = ClothClass.upperClothes.rawValue } }
        let parser = ClothSegformerClothingParser(legacy: legacy, segmenter: FixedClothSegmenter(map: labelMap(labels)), extractor: OutfitItemExtractor(minimumAreaShare: 0.001))
        let regions = try await parser.parse(personMask: mask(), in: image())
        XCTAssertEqual(regions.map(\.kind), [.top])
        XCTAssertEqual(regions.first?.confidence, 0.75)
        let calls = await legacy.callCount
        XCTAssertEqual(calls, 0)
    }

    private func labelMap(_ labels: [UInt8]) -> ClothLabelMap {
        ClothLabelMap(width: 512, height: 512, labels: labels, originalSize: CGSize(width: 512, height: 512), sourceToModelTransform: .stretched(sourceSize: CGSize(width: 512, height: 512), modelSize: CGSize(width: 512, height: 512)), inferenceMs: 0)
    }
    private func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
        }
    }
    private func mask() -> UIImage { image() }
}

private enum TestError: Error { case failed }

private struct FixedClothSegmenter: ClothSegmenting {
    let map: ClothLabelMap?
    let error: Error?
    init(map: ClothLabelMap) { self.map = map; self.error = nil }
    init(error: Error) { self.map = nil; self.error = error }
    func segment(_ image: UIImage) async throws -> ClothLabelMap {
        if let error { throw error }
        return try XCTUnwrap(map)
    }
}

private actor LegacyParserSpy: ClothingParser {
    private(set) var callCount = 0
    func parse(personMask: UIImage, in image: UIImage) async throws -> [GarmentRegion] {
        callCount += 1
        return [GarmentRegion(kind: .top, mask: personMask, confidence: 0.2, occlusionReason: nil)]
    }
}

private actor FallbackLogSpy {
    private(set) var messages: [String] = []
    func append(_ message: String) { messages.append(message) }
}
