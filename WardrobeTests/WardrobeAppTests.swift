import XCTest
import SwiftData
import UIKit
@testable import Wardrobe

final class WardrobeAppTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertTrue(true)
    }

    @MainActor
    func testInMemoryRepositorySavesFetchesAndDeletesItems() throws {
        let repository = InMemoryWardrobeRepository()
        let item = GarmentItem(category: .custom("Vintage"), cutoutImagePath: "item.png")

        try repository.save(item)
        XCTAssertEqual(try repository.item(id: item.id)?.category, .custom("Vintage"))
        XCTAssertEqual(try repository.fetchItems(includeArchived: false).count, 1)

        item.isArchived = true
        XCTAssertTrue(try repository.fetchItems(includeArchived: false).isEmpty)
        XCTAssertEqual(try repository.fetchItems(includeArchived: true).count, 1)
        try repository.delete(item)
        XCTAssertNil(try repository.item(id: item.id))
    }

    @MainActor
    func testSwiftDataRepositoryPersistsDraftAndItem() throws {
        let container = try ModelContainer(for: GarmentItem.self, DraftItem.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repository = SwiftDataWardrobeRepository(context: container.mainContext)
        let draft = DraftItem(category: .hoodie)
        let item = GarmentItem(category: .jeans, cutoutImagePath: "jeans.png")

        try repository.saveDraft(draft)
        try repository.save(item)
        XCTAssertEqual(try repository.fetchDrafts().first?.category, .hoodie)
        XCTAssertEqual(try repository.fetchItems(includeArchived: true).first?.category, .jeans)
    }

    func testImageStoreRoundTripsAndDeletesPNG() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try FileImageStore(directory: directory)
        let id = UUID()
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])

        try store.savePNG(png, for: id)
        XCTAssertEqual(try store.loadPNG(for: id), png)
        try store.deletePNG(for: id)
        XCTAssertThrowsError(try store.loadPNG(for: id)) { error in
            XCTAssertEqual(error as? ImageStoreError, .missingImage)
        }
    }

    func testImageStoreRejectsNonPNGData() throws {
        let store = try FileImageStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        XCTAssertThrowsError(try store.savePNG(Data("not an image".utf8), for: UUID())) { error in
            XCTAssertEqual(error as? ImageStoreError, .invalidPNG)
        }
    }

    @MainActor
    func testWardrobeViewModelFiltersSearchAndSorts() throws {
        let repository = InMemoryWardrobeRepository()
        let tee = GarmentItem(createdAt: Date(timeIntervalSince1970: 100), category: .tShirt, subtype: "White tee", brand: "Basics", cutoutImagePath: "tee")
        let jeans = GarmentItem(createdAt: Date(timeIntervalSince1970: 200), category: .jeans, subtype: "Blue jeans", brand: "Denim Co.", cutoutImagePath: "jeans")
        try repository.save(tee); try repository.save(jeans)
        let viewModel = WardrobeViewModel(repository: repository)

        XCTAssertEqual(viewModel.filteredItems.map(\.id), [jeans.id, tee.id])
        viewModel.selectedCategory = .tShirt
        XCTAssertEqual(viewModel.filteredItems.map(\.id), [tee.id])
        viewModel.selectedCategory = nil
        viewModel.searchText = "denim"
        XCTAssertEqual(viewModel.filteredItems.map(\.id), [jeans.id])
    }

    @MainActor
    func testWardrobeViewModelLoadsSavedGarmentImageAndRefreshesItems() throws {
        let repository = InMemoryWardrobeRepository()
        let imageStore = TestWardrobeImageStore()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        let item = GarmentItem(category: .shirt, subtype: "Blue shirt", cutoutImagePath: "shirt.png")
        try imageStore.savePNG(XCTUnwrap(image.pngData()), for: item.id)
        try repository.save(item)
        let viewModel = WardrobeViewModel(repository: repository, imageStore: imageStore)

        XCTAssertNotNil(viewModel.itemImages[item.id])
        let laterItem = GarmentItem(category: .pants, subtype: "Trousers", cutoutImagePath: "pants.png")
        try repository.save(laterItem)
        viewModel.reload()
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }

    @MainActor
    func testWardrobeViewModelFavoriteArchiveDuplicateAndBulkDelete() throws {
        let repository = InMemoryWardrobeRepository()
        let item = GarmentItem(category: .hoodie, subtype: "Hoodie", cutoutImagePath: "hoodie")
        let second = GarmentItem(category: .jacket, subtype: "Jacket", cutoutImagePath: "jacket")
        try repository.save(item); try repository.save(second)
        let viewModel = WardrobeViewModel(repository: repository)

        viewModel.toggleFavorite(item)
        XCTAssertTrue(item.isFavorite)
        viewModel.toggleArchive(item)
        viewModel.section = .archived
        XCTAssertEqual(viewModel.filteredItems.map(\.id), [item.id])
        viewModel.section = .all
        viewModel.duplicate(second)
        XCTAssertEqual(try repository.fetchItems(includeArchived: true).count, 3)
        viewModel.selectedIDs = [item.id, second.id]
        viewModel.deleteSelected()
        XCTAssertEqual(try repository.fetchItems(includeArchived: true).count, 1)
        XCTAssertTrue(viewModel.selectedIDs.isEmpty)
    }

    @MainActor
    func testSeedSampleItemsIsRepeatableAndUsesLocalPaths() throws {
        let repository = InMemoryWardrobeRepository()
        let viewModel = WardrobeViewModel(repository: repository)
        viewModel.seedSampleItems()
        XCTAssertEqual(try repository.fetchItems(includeArchived: true).count, 4)
        XCTAssertTrue(try repository.fetchItems(includeArchived: true).allSatisfy { $0.cutoutImagePath == "debug-placeholder" })
    }
}

private final class TestWardrobeImageStore: ImageStore {
    private var images: [UUID: Data] = [:]
    func savePNG(_ data: Data, for id: UUID) throws { images[id] = data }
    func loadPNG(for id: UUID) throws -> Data {
        guard let image = images[id] else { throw ImageStoreError.missingImage }
        return image
    }
    func deletePNG(for id: UUID) throws { images.removeValue(forKey: id) }
}
