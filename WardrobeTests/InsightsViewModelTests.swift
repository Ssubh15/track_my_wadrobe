import XCTest
@testable import Wardrobe

final class InsightsViewModelTests: XCTestCase {
    func testRowsAreSortedHighToLowThenByNameAndCapped() {
        let rows = InsightsViewModel.rows(from: ["B", "A", "B", "C", "A", "B", "D"], limit: 3)
        XCTAssertEqual(rows, [InsightRow(name: "B", count: 3), InsightRow(name: "A", count: 2), InsightRow(name: "C", count: 1)])
    }

    func testColorNames() {
        XCTAssertEqual(InsightsViewModel.colorName(forHex: "#191919"), "Black")
        XCTAssertEqual(InsightsViewModel.colorName(forHex: "#F4F1EA"), "White")
        XCTAssertEqual(InsightsViewModel.colorName(forHex: "#4A6A8A"), "Blue")
        XCTAssertEqual(InsightsViewModel.colorName(forHex: "#66705A"), "Green")
        XCTAssertNil(InsightsViewModel.colorName(forHex: "not-a-colour"))
    }

    @MainActor
    func testCountsComeFromNonArchivedItemsOnly() throws {
        let repository = InMemoryWardrobeRepository()
        try repository.save(GarmentItem(category: .tShirt, primaryColorHex: "#191919", brand: "Basics", cutoutImagePath: "a"))
        try repository.save(GarmentItem(category: .tShirt, primaryColorHex: "#191919", brand: "Basics", cutoutImagePath: "b"))
        try repository.save(GarmentItem(category: .jeans, primaryColorHex: "#4A6A8A", brand: " ", cutoutImagePath: "c"))
        let archived = GarmentItem(category: .dress, primaryColorHex: "#191919", brand: "Atelier", cutoutImagePath: "d")
        archived.isArchived = true
        try repository.save(archived)

        let viewModel = InsightsViewModel(repository: repository)

        XCTAssertEqual(viewModel.totalItems, 3)
        XCTAssertEqual(viewModel.categoryRows.first, InsightRow(name: "T-shirt", count: 2))
        XCTAssertEqual(viewModel.colorRows.first, InsightRow(name: "Black", count: 2))
        XCTAssertEqual(viewModel.brandRows, [InsightRow(name: "Basics", count: 2)])
        XCTAssertTrue(viewModel.summary.hasPrefix("3 items."))
    }

    @MainActor
    func testEmptyWardrobeHasNoSummary() {
        let viewModel = InsightsViewModel(repository: InMemoryWardrobeRepository())
        XCTAssertEqual(viewModel.totalItems, 0)
        XCTAssertEqual(viewModel.summary, "")
    }
}
