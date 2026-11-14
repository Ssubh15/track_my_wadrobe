import UIKit
import XCTest
@testable import Wardrobe

final class ClassificationAndAttributesTests: XCTestCase {
    func testMockClassifierReturnsFixedRankedValues() async throws {
        let classifier = MockGarmentClassifier()
        let predictions = try await classifier.classify(fixtureImage(color: .red))

        XCTAssertEqual(predictions.map(\.category), [.tShirt, .shirt, .polo])
        XCTAssertEqual(predictions.map(\.confidence), [0.62, 0.22, 0.10])
    }

    func testCoreMLClassifierReportsMissingConfiguredModel() async {
        let classifier = CoreMLGarmentClassifier(configuration: .init(modelName: "MissingModel"))

        do {
            _ = try await classifier.classify(fixtureImage(color: .red))
            XCTFail("Expected a missing model error")
        } catch let error as GarmentClassifierError {
            XCTAssertEqual(error, .modelUnavailable("MissingModel"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAttributeExtractorUsesOnlyMaskedPixelsAndIsDeterministic() throws {
        let image = makeImage { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
            UIColor.red.setFill()
            context.fill(CGRect(x: 50, y: 0, width: 50, height: 100))
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 10))
        }
        let mask = makeImage { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 10, width: 100, height: 90))
        }

        let extractor = KMeansAttributeExtractor(clusterCount: 2, maximumSamples: 10_000, iterations: 10)
        let first = try extractor.extract(from: image, mask: mask)
        let second = try extractor.extract(from: image, mask: mask)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.dominantColorHex, "#0000FF")
        XCTAssertEqual(first.secondaryColorHexes, ["#FF0000"])
        XCTAssertNil(first.pattern)
        XCTAssertNil(first.sleeveLength)
        XCTAssertNil(first.fit)
    }

    func testAttributeExtractorRejectsEmptyMask() {
        let image = fixtureImage(color: .red)
        XCTAssertThrowsError(try KMeansAttributeExtractor().extract(from: image, mask: fixtureImage(color: .black))) { error in
            XCTAssertEqual(error as? AttributeExtractorError, .noMaskedPixels)
        }
    }

    @MainActor
    func testLowConfidenceClassificationPresentsTopThreePicker() async {
        let viewModel = AttributesConfirmationViewModel(
            image: fixtureImage(color: .red),
            mask: fixtureImage(color: .white),
            classifier: MockGarmentClassifier(predictions: [
                CategoryPrediction(category: .shirt, confidence: 0.45),
                CategoryPrediction(category: .polo, confidence: 0.30),
                CategoryPrediction(category: .tShirt, confidence: 0.20),
                CategoryPrediction(category: .hoodie, confidence: 0.05)
            ]),
            extractor: KMeansAttributeExtractor()
        )

        await viewModel.load()

        XCTAssertTrue(viewModel.isCategoryPickerPresented)
        XCTAssertEqual(viewModel.topSuggestions.map(\.category), [.shirt, .polo, .tShirt])
    }

    private func fixtureImage(color: UIColor) -> UIImage {
        makeImage { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }

    private func makeImage(_ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format).image { draw($0.cgContext) }
    }
}
