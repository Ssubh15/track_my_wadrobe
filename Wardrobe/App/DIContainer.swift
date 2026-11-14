import Observation
import SwiftData

@Observable
@MainActor
final class DIContainer {
    let appName = "Wardrobe"
    let modelContainer: ModelContainer
    let wardrobeRepository: any WardrobeRepository
    let imageStore: any ImageStore
    let backgroundRemovalService: any BackgroundRemovalService
    let maskEditingService: any MaskEditing
    let imageEnhancementService: any ImageEnhancementServing
    let fidelityChecker: any FidelityChecking
    let garmentClassifier: any GarmentClassifier
    let attributeExtractor: any AttributeExtractor
    let brandPhotoProvider: any BrandPhotoProvider
    let outfitExtractionPipeline: any OutfitExtracting
    let originalOutfitPhotoDeleter: any OriginalOutfitPhotoDeleting

    init() {
        do {
            let container = try ModelContainer(for: GarmentItem.self, DraftItem.self)
            modelContainer = container
            wardrobeRepository = SwiftDataWardrobeRepository(context: container.mainContext)
            imageStore = try FileImageStore()
            backgroundRemovalService = CoreMLCutoutService()
            maskEditingService = MaskEditingService()
            imageEnhancementService = ImageEnhancementService()
            fidelityChecker = FidelityChecker()
            garmentClassifier = CoreMLGarmentClassifier()
            attributeExtractor = KMeansAttributeExtractor()
            brandPhotoProvider = RemoteBrandPhotoProvider(configuration: .init(backendURL: nil))
            outfitExtractionPipeline = OutfitExtractionPipeline()
            originalOutfitPhotoDeleter = PhotosOriginalOutfitPhotoDeleter()
        } catch {
            fatalError("Unable to initialize local wardrobe storage: \(error)")
        }
    }
}

