import UIKit
import XCTest
@testable import Wardrobe

final class OutfitItemExtractorTests: XCTestCase {
    func testGroupsBottomClassesAndBothShoesIntoSingleItems() {
        var labels = [UInt8](repeating: 0, count: 512 * 512)
        fill(&labels, x: 40..<120, y: 30..<130, label: 4)
        fill(&labels, x: 50..<90, y: 180..<300, label: 6)
        fill(&labels, x: 90..<130, y: 180..<300, label: 5)
        fill(&labels, x: 50..<90, y: 400..<430, label: 9)
        fill(&labels, x: 100..<140, y: 400..<430, label: 10)
        let items = OutfitItemExtractor(minimumAreaShare: 0.001).extract(from: map(labels), image: image())
        XCTAssertEqual(items.map(\.category), [.tShirt, .pants, .shoes])
    }

    func testSmallDisconnectedLabelComponentIsRemoved() throws {
        var labels = [UInt8](repeating: 0, count: 512 * 512)
        fill(&labels, x: 20..<100, y: 20..<110, label: 4)
        fill(&labels, x: 300..<305, y: 300..<305, label: 4)
        let item = try XCTUnwrap(OutfitItemExtractor(minimumAreaShare: 0.001).extract(from: map(labels), image: image()).first)
        XCTAssertEqual(item.category, .tShirt)
        XCTAssertTrue(item.pixelAreaShare < 0.04)
    }

    func testDressFragmentTouchingBottomIsMergedAndDominantDressGetsDressCategory() {
        var labels = [UInt8](repeating: 0, count: 512 * 512)
        fill(&labels, x: 100..<180, y: 30..<100, label: 4)
        fill(&labels, x: 100..<180, y: 150..<250, label: 6)
        fill(&labels, x: 100..<180, y: 250..<350, label: 7)
        let merged = OutfitItemExtractor(minimumAreaShare: 0.001).extract(from: map(labels), image: image())
        XCTAssertEqual(merged.map(\.category), [.tShirt, .pants])

        labels = [UInt8](repeating: 0, count: 512 * 512)
        fill(&labels, x: 100..<180, y: 30..<60, label: 4)
        fill(&labels, x: 100..<180, y: 150..<180, label: 6)
        fill(&labels, x: 100..<180, y: 180..<350, label: 7)
        XCTAssertTrue(OutfitItemExtractor(minimumAreaShare: 0.001).extract(from: map(labels), image: image()).contains { $0.category == .dress })
    }

    func testUpperMaskCropsTopPixelsWithoutVerticalFlip() throws {
        let width = 10
        var labels = [UInt8](repeating: ClothClass.background.rawValue, count: width * width)
        for y in 0..<5 {
            for x in 0..<width { labels[y * width + x] = ClothClass.upperClothes.rawValue }
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 50, width: 100, height: 50))
        }
        let transform = ClothImageTransform.stretched(sourceSize: CGSize(width: 100, height: 100), modelSize: CGSize(width: width, height: width))
        let labelMap = ClothLabelMap(width: width, height: width, labels: labels, originalSize: CGSize(width: 100, height: 100), sourceToModelTransform: transform, inferenceMs: 0)

        let item = try XCTUnwrap(OutfitItemExtractor(minimumAreaShare: 0.001).extract(from: labelMap, image: source).first)
        let center = pixel(in: item.cutoutImage, x: item.cutoutImage.cgImage!.width / 2, y: item.cutoutImage.cgImage!.height / 2)
        XCTAssertGreaterThan(center.red, 0.9)
        XCTAssertLessThan(center.blue, 0.1)
    }

    func testTorsoMislabelledAsTrousersMovesBackToTop() {
        var labels = [UInt8](repeating: 0, count: 512 * 512)
        // Sleeves either side, and a top band across the chest.
        fill(&labels, x: 150..<190, y: 100..<260, label: 4)
        fill(&labels, x: 320..<360, y: 100..<260, label: 4)
        fill(&labels, x: 190..<320, y: 100..<140, label: 4)
        // Trousers wrongly start on the chest; the top still reaches the centre at y 220.
        fill(&labels, x: 190..<320, y: 140..<480, label: 6)
        fill(&labels, x: 240..<270, y: 200..<220, label: 4)

        let corrected = TorsoLabelCorrector.correct(labels, width: 512, height: 512)
        XCTAssertEqual(corrected[180 * 512 + 255], ClothClass.upperClothes.rawValue)
        XCTAssertEqual(corrected[400 * 512 + 255], ClothClass.pants.rawValue)
    }

    func testLongTopDoesNotEatTrousers() {
        var labels = [UInt8](repeating: 0, count: 512 * 512)
        fill(&labels, x: 190..<320, y: 100..<200, label: 6)
        fill(&labels, x: 190..<320, y: 200..<400, label: 6)
        fill(&labels, x: 240..<270, y: 100..<350, label: 4)
        XCTAssertEqual(TorsoLabelCorrector.correct(labels, width: 512, height: 512), labels)
    }

    private func map(_ labels: [UInt8]) -> ClothLabelMap { ClothLabelMap(width: 512, height: 512, labels: labels, originalSize: CGSize(width: 512, height: 512), sourceToModelTransform: .stretched(sourceSize: CGSize(width: 512, height: 512), modelSize: CGSize(width: 512, height: 512)), inferenceMs: 0) }
    private func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
        }
    }
    private func fill(_ labels: inout [UInt8], x: Range<Int>, y: Range<Int>, label: UInt8) {
        for row in y { for column in x { labels[row * 512 + column] = label } }
    }

    private func pixel(in image: UIImage, x: Int, y: Int) -> (red: CGFloat, blue: CGFloat) {
        guard let cgImage = image.cgImage else { return (0, 0) }
        var values = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &values, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(cgImage, in: CGRect(x: -x, y: -y, width: cgImage.width, height: cgImage.height))
        return (CGFloat(values[0]) / 255, CGFloat(values[2]) / 255)
    }
}
