import AVFoundation
import UIKit
import XCTest
@testable import Wardrobe

final class ImageQualityCheckerTests: XCTestCase {
    @MainActor
    func testCaptureViewModelForwardsAcceptedImageAndMode() async {
        let camera = MockCameraService()
        let viewModel = CaptureViewModel(mode: .outfit, camera: camera, qualityChecker: ImageQualityChecker())
        viewModel.accept(fixture(color: .white))
        XCTAssertNotNil(viewModel.selectedImage)
        XCTAssertEqual(viewModel.mode, .outfit)
    }

    func testDarkFixtureIsFlaggedAsTooDark() {
        let result = ImageQualityChecker().check(fixture(color: .black))
        XCTAssertTrue(result.issues.contains(.tooDark))
    }

    func testBrightFixtureIsFlaggedAsTooBright() {
        let result = ImageQualityChecker().check(fixture(color: .white))
        XCTAssertTrue(result.issues.contains(.tooBright))
    }

    func testFlatFixtureIsFlaggedAsBlurry() {
        let result = ImageQualityChecker().check(fixture(color: .gray))
        XCTAssertTrue(result.issues.contains(.blurry))
    }

    func testEdgeFixtureIsFlaggedWhenSubjectReachesFrameEdge() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 12))
            context.fill(CGRect(x: 0, y: 188, width: 200, height: 12))
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 200))
            context.fill(CGRect(x: 188, y: 0, width: 12, height: 200))
        }
        XCTAssertTrue(ImageQualityChecker().check(image).issues.contains(.garmentCutOff))
    }

    @MainActor
    func testCoordinatorStartsProductProcessingWithOriginalImage() {
        let coordinator = AddItemFlowCoordinator()
        let image = fixture(color: .white)
        coordinator.showCapture(for: .product)
        coordinator.showNextStep(image: image, mode: .product)
        guard case let .productProcessing(result) = coordinator.route else {
            return XCTFail("Expected product processing route")
        }
        XCTAssertEqual(result.pngData(), image.pngData())
    }

    private func fixture(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { context in
            color.setFill(); context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
    }
}

private final class MockCameraService: CameraServicing {
    let session = AVCaptureSession()
    let authorization: AVAuthorizationStatus = .authorized
    func requestAccess() async -> Bool { true }
    func start() {}
    func stop() {}
    func capturePhoto() async throws -> UIImage { fixtureImage() }

    private func fixtureImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }
}
