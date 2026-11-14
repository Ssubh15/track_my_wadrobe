import UIKit
import XCTest
@testable import Wardrobe

final class GarmentCutoutCropperTests: XCTestCase {
    func testCropTrimsFullFrameCutoutToMaskBoundsWithPadding() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 200, height: 400)
        let cutout = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 50, y: 100, width: 100, height: 200))
        }
        let mask = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill(); context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill(); context.fill(CGRect(x: 50, y: 100, width: 100, height: 200))
        }
        let cropped = GarmentCutoutCropper.crop(cutout, to: mask, paddingFraction: 0.04)
        let width = try XCTUnwrap(cropped.cgImage?.width)
        let height = try XCTUnwrap(cropped.cgImage?.height)
        XCTAssertEqual(Double(width), 108, accuracy: 3)
        XCTAssertEqual(Double(height), 216, accuracy: 3)
    }

    func testCropReturnsOriginalWhenSizesDiffer() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let cutout = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10), format: format).image { _ in }
        let mask = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20), format: format).image { _ in }
        XCTAssertEqual(GarmentCutoutCropper.crop(cutout, to: mask).cgImage?.width, 10)
    }
}
