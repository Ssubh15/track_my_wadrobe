import UIKit
import XCTest
@testable import Wardrobe

final class MaskEditingServiceTests: XCTestCase {
    private let editor = MaskEditingService()

    func testEraseBrushChangesOnlyMaskPixels() throws {
        let source = sourceFixture()
        let initialMask = solidMask(.white)
        let editedMask = try editor.applying(
            MaskBrushStroke(points: [CGPoint(x: 0.5, y: 0.5)], diameter: 0.3, tool: .erase),
            to: initialMask
        )

        let sourcePixel = pixel(in: source, at: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(sourcePixel.red, 1, accuracy: 0.02)
        XCTAssertEqual(sourcePixel.green, 0, accuracy: 0.02)
        XCTAssertLessThan(pixel(in: editedMask, at: CGPoint(x: 0.5, y: 0.5)).red, 0.1)
        XCTAssertGreaterThan(pixel(in: editedMask, at: CGPoint(x: 0.1, y: 0.1)).red, 0.9)
    }

    func testRestoreBrushAddsMaskCoverage() throws {
        let initialMask = solidMask(.black)
        let editedMask = try editor.applying(
            MaskBrushStroke(points: [CGPoint(x: 0.5, y: 0.5)], diameter: 0.3, tool: .restore),
            to: initialMask
        )

        XCTAssertGreaterThan(pixel(in: editedMask, at: CGPoint(x: 0.5, y: 0.5)).red, 0.9)
        XCTAssertLessThan(pixel(in: editedMask, at: CGPoint(x: 0.1, y: 0.1)).red, 0.1)
    }

    func testCutoutUsesSourcePixelsAndMaskTransparency() throws {
        let source = sourceFixture()
        let sourceData = source.pngData()
        let mask = halfMask()
        let cutout = try editor.makingCutout(from: source, using: mask)

        let kept = pixel(in: cutout, at: CGPoint(x: 0.25, y: 0.5))
        let removed = pixel(in: cutout, at: CGPoint(x: 0.75, y: 0.5))
        XCTAssertEqual(kept.red, 1, accuracy: 0.02)
        XCTAssertEqual(kept.green, 0, accuracy: 0.02)
        XCTAssertGreaterThan(kept.alpha, 0.98)
        XCTAssertLessThan(removed.alpha, 0.02)
        XCTAssertEqual(source.pngData(), sourceData)
    }

    @MainActor
    func testViewModelUndoAndRedoRestoreMaskRevisions() {
        let initialMask = solidMask(.white)
        let viewModel = MaskEditorViewModel(original: sourceFixture(), mask: initialMask, maskEditingService: editor)
        viewModel.brushDiameter = 0.3
        viewModel.beginStroke(at: CGPoint(x: 0.5, y: 0.5))
        viewModel.endStroke()
        let erasedMask = viewModel.mask

        XCTAssertTrue(viewModel.canUndo)
        XCTAssertFalse(viewModel.canRedo)
        XCTAssertLessThan(pixel(in: erasedMask, at: CGPoint(x: 0.5, y: 0.5)).red, 0.1)

        viewModel.undo()
        XCTAssertGreaterThan(pixel(in: viewModel.mask, at: CGPoint(x: 0.5, y: 0.5)).red, 0.9)
        XCTAssertTrue(viewModel.canRedo)

        viewModel.redo()
        XCTAssertEqual(viewModel.mask.pngData(), erasedMask.pngData())
    }

    @MainActor
    func testProductProcessingDropsPriorEnhancementWhenMaskChanges() async {
        let source = sourceFixture()
        let originalMask = solidMask(.white)
        let replacementMask = solidMask(.black)
        let replacementCutout = solidMask(.clear)
        let viewModel = ProductPhotoProcessingViewModel(
            original: source,
            backgroundRemovalService: MockBackgroundRemovalService(
                result: BackgroundRemovalResult(cutout: source, mask: originalMask)
            ),
            maskEditingService: MockMaskEditingService(cutout: replacementCutout),
            enhancementService: MockImageEnhancementService(enhancedImage: source),
            fidelityChecker: MockFidelityChecker()
        )

        await viewModel.process()
        viewModel.replaceMask(with: replacementMask)

        XCTAssertEqual(viewModel.mask?.pngData(), replacementMask.pngData())
        XCTAssertEqual(viewModel.cutout?.pngData(), replacementCutout.pngData())
        XCTAssertNil(viewModel.enhanced)
    }

    private func sourceFixture() -> UIImage {
        image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }

    private func solidMask(_ color: UIColor) -> UIImage {
        image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }

    private func halfMask() -> UIImage {
        image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
        }
    }

    private func image(_ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format).image { context in
            draw(context.cgContext)
        }
    }

    private func pixel(in image: UIImage, at normalizedPoint: CGPoint) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        guard let cgImage = image.cgImage else { return (0, 0, 0, 0) }
        let x = min(max(Int(normalizedPoint.x * CGFloat(cgImage.width)), 0), cgImage.width - 1)
        let y = min(max(Int(normalizedPoint.y * CGFloat(cgImage.height)), 0), cgImage.height - 1)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: -x, y: -y, width: cgImage.width, height: cgImage.height))
        return (
            CGFloat(pixel[0]) / 255,
            CGFloat(pixel[1]) / 255,
            CGFloat(pixel[2]) / 255,
            CGFloat(pixel[3]) / 255
        )
    }
}
