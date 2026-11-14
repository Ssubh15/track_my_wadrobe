import UIKit
import XCTest
@testable import Wardrobe

final class FidelityCheckerTests: XCTestCase {
    func testMatchingGarmentFixturesPassFidelityCheck() throws {
        let fixture = garmentFixture(color: .systemBlue)
        let result = try FidelityChecker().check(before: fixture, after: fixture)

        XCTAssertTrue(result.passes)
        XCTAssertEqual(result.colorDifference, 0, accuracy: 0.001)
        XCTAssertEqual(result.silhouetteAreaChange, 0, accuracy: 0.001)
    }

    func testTransparentCutoutSerializesAsPNG() {
        let fixture = garmentFixture(color: .systemBlue)
        let result = BackgroundRemovalResult(cutout: fixture, mask: fixture)

        XCTAssertEqual(result.cutoutPNG.map { Data($0.prefix(8)) }, Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }

    func testCutoutFixtureNormalizesToRequestedSquareCanvas() {
        let fixture = garmentFixture(color: .systemBlue, garmentRect: CGRect(x: 10, y: 10, width: 40, height: 100))
        let normalized = MaskImageProcessor.normalizedSquare(fixture, canvasSize: 512)

        XCTAssertEqual(normalized.size, CGSize(width: 512, height: 512))
        XCTAssertEqual(normalized.scale, 1)
    }

    func testColorChangedFixtureFailsFidelityCheck() {
        XCTAssertThrowsError(
            try FidelityChecker(maximumColorDifference: 2).check(
                before: garmentFixture(color: .systemBlue),
                after: garmentFixture(color: .systemRed)
            )
        ) { error in
            guard case let FidelityError.thresholdExceeded(result) = error else {
                return XCTFail("Expected fidelity threshold error")
            }
            XCTAssertGreaterThan(result.colorDifference, 2)
        }
    }

    func testSilhouetteChangedFixtureFailsFidelityCheck() {
        let before = garmentFixture(color: .systemBlue, garmentRect: CGRect(x: 35, y: 20, width: 50, height: 80))
        let after = garmentFixture(color: .systemBlue, garmentRect: CGRect(x: 45, y: 30, width: 30, height: 60))

        XCTAssertThrowsError(
            try FidelityChecker(maximumSilhouetteAreaChange: 0.01).check(before: before, after: after)
        ) { error in
            guard case let FidelityError.thresholdExceeded(result) = error else {
                return XCTFail("Expected fidelity threshold error")
            }
            XCTAssertGreaterThan(result.silhouetteAreaChange, 0.01)
        }
    }

    @MainActor
    func testProcessingViewModelUsesPlainCutoutWhenEnhancementFailsFidelity() async {
        let fixture = garmentFixture(color: .systemBlue)
        let removal = BackgroundRemovalResult(cutout: fixture, mask: fixture)
        let viewModel = ProductPhotoProcessingViewModel(
            original: fixture,
            backgroundRemovalService: MockBackgroundRemovalService(result: removal),
            enhancementService: MockImageEnhancementService(enhancedImage: fixture),
            fidelityChecker: MockFidelityChecker(error: .thresholdExceeded(FidelityCheckResult(colorDifference: 10, silhouetteAreaChange: 0, passes: false)))
        )

        await viewModel.process()

        XCTAssertEqual(viewModel.state, .ready)
        XCTAssertNil(viewModel.enhanced)
        XCTAssertNotNil(viewModel.processedPhoto(usingPlainCutout: true))
    }

    private func garmentFixture(color: UIColor, garmentRect: CGRect = CGRect(x: 25, y: 15, width: 70, height: 90)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120), format: format).image { context in
            color.setFill()
            context.fill(garmentRect)
        }
    }
}
