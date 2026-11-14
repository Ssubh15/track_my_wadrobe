import XCTest
@testable import Wardrobe

@MainActor
final class CategoryTagStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let name = "CategoryTagStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testAddTrimsAndPersists() throws {
        let defaults = makeDefaults()
        let store = CategoryTagStore(defaults: defaults)
        try store.addCategory("  Gym wear ")
        try store.addTag("Office")

        let reloaded = CategoryTagStore(defaults: defaults)
        XCTAssertEqual(reloaded.categories, ["Gym wear"])
        XCTAssertEqual(reloaded.tags, ["Office"])
        XCTAssertEqual(CategoryTagStore.storedCategories(defaults: defaults), ["Gym wear"])
    }

    func testRejectsEmptyDuplicateAndBuiltInNames() throws {
        let store = CategoryTagStore(defaults: makeDefaults())
        try store.addCategory("Gym wear")
        XCTAssertThrowsError(try store.addCategory("   ")) { XCTAssertEqual($0 as? CategoryTagStore.StoreError, .empty) }
        XCTAssertThrowsError(try store.addCategory("gym WEAR")) { XCTAssertEqual($0 as? CategoryTagStore.StoreError, .duplicate) }
        XCTAssertThrowsError(try store.addCategory("Jeans")) { XCTAssertEqual($0 as? CategoryTagStore.StoreError, .reserved) }
    }

    func testRenameRemoveAndMove() throws {
        let store = CategoryTagStore(defaults: makeDefaults())
        try store.addCategory("A")
        try store.addCategory("B")
        try store.addCategory("C")

        XCTAssertEqual(try store.renameCategory(from: "A", to: "Alpha"), "Alpha")
        store.moveCategories(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(store.categories, ["B", "C", "Alpha"])

        store.removeCategory("C")
        XCTAssertEqual(store.categories, ["B", "Alpha"])
    }

    func testTagsRenameAndRemove() throws {
        let store = CategoryTagStore(defaults: makeDefaults())
        try store.addTag("Party")
        XCTAssertEqual(try store.renameTag(from: "Party", to: "Evening"), "Evening")
        store.removeTag("Evening")
        XCTAssertTrue(store.tags.isEmpty)
    }
}
