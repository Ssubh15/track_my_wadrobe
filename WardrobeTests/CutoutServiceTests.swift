import UIKit
import XCTest
@testable import Wardrobe

final class CutoutServiceTests: XCTestCase {
    func testOrientationIsNormalizedToUpBeforeInference() {
        let base = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 60)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 60))
        }
        guard let baseCGImage = base.cgImage else {
            XCTFail("Fixture image should have a CGImage")
            return
        }
        let oriented = UIImage(cgImage: baseCGImage, scale: 1, orientation: .right)

        let normalized = MaskImageProcessor.normalizedUpImage(oriented)

        XCTAssertEqual(normalized?.imageOrientation, .up)
        XCTAssertEqual(normalized?.cgImage?.width, 60)
        XCTAssertEqual(normalized?.cgImage?.height, 100)
    }

    func testMaskResizingKeepsForegroundOnTheSameSideOfTheImage() {
        let mask = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 2)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }

        let resized = MaskImageProcessor.resizeMask(mask, to: CGSize(width: 40, height: 20))
        let bounds: CGRect? = resized.flatMap { (image: UIImage) -> CGRect? in
            guard let cgImage = image.cgImage else { return nil }
            return MaskImageProcessor.foregroundBounds(in: cgImage)
        }

        XCTAssertNotNil(bounds)
        XCTAssertLessThan(bounds?.midX ?? 40, 22)
        XCTAssertEqual(bounds?.height ?? 0, 20, accuracy: 1)
    }
}
