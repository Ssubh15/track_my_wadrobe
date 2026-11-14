import XCTest
@testable import Wardrobe

@MainActor
final class ReviewItemViewModelTests: XCTestCase {
    func testPersistDraftStoresEditsWithoutCreatingWardrobeItem() throws {
        let repository = InMemoryWardrobeRepository()
        let imageStore = TestImageStore()
        let viewModel = ReviewItemViewModel(image: ProductPhotoPreviewImage.garment, repository: repository, imageStore: imageStore)
        viewModel.category = .jacket
        viewModel.color = "#123456"
        viewModel.brand = "Local brand"
        viewModel.tags = "work, blue"

        viewModel.persistDraft()

        XCTAssertEqual(repository.items.count, 0)
        let draft = try XCTUnwrap(repository.drafts.values.first)
        XCTAssertEqual(draft.category, .jacket)
        XCTAssertEqual(draft.primaryColorHex, "#123456")
        XCTAssertEqual(draft.tags, ["work", "blue"])
        XCTAssertNotNil(imageStore.images[draft.id])
    }

    func testConfirmSavesItemAndCleansUpDraft() throws {
        let repository = InMemoryWardrobeRepository()
        let imageStore = TestImageStore()
        let viewModel = ReviewItemViewModel(image: ProductPhotoPreviewImage.garment, repository: repository, imageStore: imageStore)
        viewModel.brand = "Wardrobe Co."
        viewModel.price = "42.50"
        viewModel.persistDraft()
        let draftID = try XCTUnwrap(repository.drafts.keys.first)

        viewModel.confirm()

        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(repository.items.count, 1)
        XCTAssertTrue(repository.drafts.isEmpty)
        XCTAssertNil(imageStore.images[draftID])
        let item = try XCTUnwrap(repository.items.values.first)
        XCTAssertEqual(item.brand, "Wardrobe Co.")
        XCTAssertEqual(item.price, Decimal(string: "42.50"))
        XCTAssertNotNil(imageStore.images[item.id])
    }
}

private final class TestImageStore: ImageStore {
    var images: [UUID: Data] = [:]
    func savePNG(_ data: Data, for id: UUID) throws { images[id] = data }
    func loadPNG(for id: UUID) throws -> Data { try XCTUnwrap(images[id]) }
    func deletePNG(for id: UUID) throws { images.removeValue(forKey: id) }
}
