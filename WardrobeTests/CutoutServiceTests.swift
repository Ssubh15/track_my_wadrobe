import CoreML
import UIKit
import XCTest
@testable import Wardrobe

final class CutoutServiceTests: XCTestCase {
    func testOrientationIsNormalizedToUpBeforeInference() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let base = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 60), format: format).image { context in
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

    func testFloat16ModelMaskIsReadWithItsRealElementType() throws {
        // U²-Net outputs a 1×1×320×320 Float16 mask; a left-half foreground must stay on the left.
        let scalars: [Float16] = (0..<16).map { $0 % 4 < 2 ? 1 : 0 }
        let array = MLMultiArray(MLShapedArray<Float16>(scalars: scalars, shape: [1, 1, 4, 4]))
        XCTAssertEqual(array.dataType, .float16)

        let mask = try XCTUnwrap(MaskImageProcessor.image(from: array, size: CGSize(width: 4, height: 4)))
        let pixels = try XCTUnwrap(Self.grayPixels(of: mask))
        XCTAssertEqual(pixels.count, 16)
        for y in 0..<4 {
            for x in 0..<4 {
                let value = pixels[y * 4 + x]
                if x < 2 { XCTAssertGreaterThan(value, 200, "pixel (\(x),\(y)) all=\(pixels)") }
                else { XCTAssertLessThan(value, 55, "pixel (\(x),\(y)) all=\(pixels)") }
            }
        }
    }

    private static func grayPixels(of image: UIImage) -> [UInt8]? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    func testBundledU2NetModelIsFoundByCutoutService() {
        XCTAssertNotNil(Bundle.main.url(forResource: "U2NetP", withExtension: "mlmodelc"), "U2NetP.mlmodelc must be in the app bundle")
    }
}
