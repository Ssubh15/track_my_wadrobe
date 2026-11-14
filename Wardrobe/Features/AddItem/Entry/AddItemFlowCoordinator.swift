import Observation
import UIKit

enum AddItemMode: String, CaseIterable, Identifiable {
    case product
    case outfit

    var id: String { rawValue }
    var title: String { self == .product ? "Product photo" : "Outfit photo" }
    var subtitle: String { self == .product ? "One garment, photographed clearly" : "Extract garments from an OOTD or mirror selfie" }
    var systemImage: String { self == .product ? "tshirt" : "person.crop.rectangle" }
}

struct AddItemCaptureResult {
    let image: UIImage
    let mode: AddItemMode
}

@Observable
@MainActor
final class AddItemFlowCoordinator {
    enum Route {
        case entry
        case capture(AddItemMode)
        case nextStep(AddItemCaptureResult)
        case outfitProcessing(UIImage, String?)
        case detectedGarments(UIImage, OutfitExtractionResult)
        case outfitReview([DetectedGarmentsViewModel.Candidate])
        case productProcessing(UIImage)
        case productReview(ProcessedProductPhoto)
        case brandEntry(ProcessedProductPhoto)
        case brandResults(ProcessedProductPhoto, String)
        case selectedBrandPhoto(ProcessedProductPhoto, UIImage, String?)
        case draftReview(DraftItem, UIImage)
    }

    var route: Route = .entry

    func showCapture(for mode: AddItemMode) { route = .capture(mode) }
    func showNextStep(image: UIImage, mode: AddItemMode, originalAssetIdentifier: String? = nil) {
        route = mode == .product ? .productProcessing(image) : .outfitProcessing(image, originalAssetIdentifier)
    }

    func showDetectedGarments(image: UIImage, result: OutfitExtractionResult) { route = .detectedGarments(image, result) }
    func showOutfitReview(_ candidates: [DetectedGarmentsViewModel.Candidate]) { route = .outfitReview(candidates) }

    func showProductReview(_ result: ProcessedProductPhoto) { route = .brandEntry(result) }
    func showBrandResults(_ result: ProcessedProductPhoto, brand: String) { route = .brandResults(result, brand) }
    func showSelectedBrandPhoto(_ result: ProcessedProductPhoto, image: UIImage, brand: String?) { route = .selectedBrandPhoto(result, image, brand) }
    func showDraftReview(_ draft: DraftItem, image: UIImage) { route = .draftReview(draft, image) }
}
