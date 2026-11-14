import UIKit
import XCTest
@testable import Wardrobe

@MainActor
final class OutfitPhotoViewModelTests: XCTestCase {
    func testDetectedGarmentsCanBeDeselectedAndRepairedWithSourcePixels() throws {
        let source = fixtureImage()
        let initialMask = fixtureMask(rect: CGRect(x: 10, y: 30, width: 40, height: 50))
        let replacementMask = fixtureMask(rect: CGRect(x: 20, y: 40, width: 30, height: 40))
        let garment = ExtractedGarment(cutoutImage: source, mask: initialMask, guessedCategory: .tShirt, isPartial: false, partialReason: nil, confidence: 0.8)
        let result = OutfitExtractionResult(people: [], selectedPerson: nil, garments: [garment], mirrorDetection: MirrorDetection(isLikelyMirrorSelfie: true, confidence: 0.6, reasons: []))
        let viewModel = DetectedGarmentsViewModel(sourceImage: source, result: result)
        let candidate = try XCTUnwrap(viewModel.candidates.first)

        XCTAssertTrue(viewModel.isFlipped)
        viewModel.toggle(candidate.id)
        XCTAssertTrue(viewModel.selectedCandidates.isEmpty)
        viewModel.replaceMask(replacementMask, for: candidate.id)

        let repairedBounds = try XCTUnwrap(viewModel.candidates.first?.garment.mask.cgImage.flatMap(MaskImageProcessor.foregroundBounds))
        let expectedBounds = try XCTUnwrap(replacementMask.cgImage.flatMap(MaskImageProcessor.foregroundBounds))
        XCTAssertEqual(repairedBounds.minX, expectedBounds.minX, accuracy: 1)
        XCTAssertEqual(repairedBounds.minY, expectedBounds.minY, accuracy: 1)
        XCTAssertEqual(repairedBounds.width, expectedBounds.width, accuracy: 1)
        XCTAssertEqual(repairedBounds.height, expectedBounds.height, accuracy: 1)
        XCTAssertNotNil(viewModel.candidates.first?.garment.cutoutImage.pngData())
    }

    func testReviewQueueSavesAllItemsWithTheSameOutfitGroupAndPartialState() throws {
        let source = fixtureImage()
        let mask = fixtureMask(rect: CGRect(x: 20, y: 20, width: 45, height: 50))
        let complete = ExtractedGarment(cutoutImage: source, mask: mask, guessedCategory: .tShirt, isPartial: false, partialReason: nil, confidence: 0.9)
        let partial = ExtractedGarment(cutoutImage: source, mask: mask, guessedCategory: .pants, isPartial: true, partialReason: .occluded, confidence: 0.9)
        let candidates = [
            DetectedGarmentsViewModel.Candidate(garment: complete),
            DetectedGarmentsViewModel.Candidate(garment: partial)
        ]
        let repository = InMemoryWardrobeRepository()
        let queue = OutfitReviewQueueViewModel(candidates: candidates, repository: repository, imageStore: QueueImageStore())
        queue.sharedBrand = "Wardrobe Co."

        queue.saveAll()

        let items = try repository.fetchItems(includeArchived: true)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(Set(items.compactMap(\.sourceGroupID)).count, 1)
        XCTAssertEqual(items.map(\.imageSource), [.outfitPhoto, .outfitPhoto])
        XCTAssertEqual(items.filter(\.isPartial).count, 1)
        XCTAssertTrue(items.allSatisfy { $0.originalImagePath == nil })
        XCTAssertTrue(items.allSatisfy { $0.brand == "Wardrobe Co." })
    }

    func testProcessingDeletesImportedOriginalUnlessKeepOriginalIsEnabled() async {
        let deleter = TrackingOriginalPhotoDeleter()
        let pipeline = MockOutfitExtractionPipeline(error: .noGarmentsDetected)
        let deletingViewModel = OutfitProcessingViewModel(original: fixtureImage(), pipeline: pipeline, originalPhotoDeleter: deleter, originalAssetIdentifier: "asset-id", keepOriginal: false)
        await deletingViewModel.finalizePrivacy()
        XCTAssertEqual(deleter.deletedIdentifiers, ["asset-id"])

        let retainingViewModel = OutfitProcessingViewModel(original: fixtureImage(), pipeline: pipeline, originalPhotoDeleter: deleter, originalAssetIdentifier: "kept-id", keepOriginal: true)
        await retainingViewModel.finalizePrivacy()
        XCTAssertEqual(deleter.deletedIdentifiers, ["asset-id"])
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

private final class QueueImageStore: ImageStore {
    private var images: [UUID: Data] = [:]
    func savePNG(_ data: Data, for id: UUID) throws { images[id] = data }
    func loadPNG(for id: UUID) throws -> Data { try XCTUnwrap(images[id]) }
    func deletePNG(for id: UUID) throws { images.removeValue(forKey: id) }
}

private final class TrackingOriginalPhotoDeleter: OriginalOutfitPhotoDeleting {
    var deletedIdentifiers: [String] = []
    func deletePhoto(assetIdentifier: String) async throws { deletedIdentifiers.append(assetIdentifier) }
}
