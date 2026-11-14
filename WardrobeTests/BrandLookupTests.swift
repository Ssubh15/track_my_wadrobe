import XCTest
@testable import Wardrobe

@MainActor
final class BrandLookupTests: XCTestCase {
    func testCatalogSuggestionsMatchTypedBrand() {
        XCTAssertEqual(BrandCatalog.suggestions(for: "nik"), ["Nike"])
        XCTAssertTrue(BrandCatalog.suggestions(for: "unknown brand").isEmpty)
    }

    func testMockProviderReturnsCandidatesAndViewModelKeepsOwnPhotoFallback() async throws {
        let source = try XCTUnwrap(URL(string: "https://example.com/product"))
        let candidate = BrandPhotoCandidate(image: ProductPhotoPreviewImage.garment, sourceURL: source, attribution: "Example Brand")
        let provider = MockBrandPhotoProvider(candidates: [candidate])
        let model = BrandPhotoResultsViewModel(ownImage: ProductPhotoPreviewImage.garment, brand: "Example", provider: provider)

        await model.search(category: .shirt, colors: ["#123456"])

        XCTAssertEqual(model.state, .results)
        XCTAssertEqual(model.candidates.count, 1)
        model.selectedCandidate = candidate
        model.keepOwnPhoto()
        XCTAssertNil(model.selectedCandidate)
    }

    func testMockProviderNoResultsAndOfflineFailure() async {
        let image = ProductPhotoPreviewImage.garment
        let empty = BrandPhotoResultsViewModel(ownImage: image, brand: "Example", provider: MockBrandPhotoProvider(candidates: []))
        await empty.search(category: .shirt, colors: [])
        XCTAssertEqual(empty.state, .noResults)

        let offline = BrandPhotoResultsViewModel(ownImage: image, brand: "Example", provider: MockBrandPhotoProvider(candidates: [], shouldFail: true))
        await offline.search(category: .shirt, colors: [])
        XCTAssertEqual(offline.state, .offline)
    }
}
