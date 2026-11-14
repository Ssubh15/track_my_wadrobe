import SwiftUI

struct AddItemEntryView: View {
    var onClose: () -> Void = {}
    @State private var coordinator = AddItemFlowCoordinator()

    var body: some View {
        NavigationStack {
            AddItemFlowView(coordinator: coordinator, onFinish: onClose)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                }
            }
        }
    }
}

private struct AddItemFlowView: View {
    @Bindable var coordinator: AddItemFlowCoordinator
    let onFinish: () -> Void

    var body: some View {
        Group {
            switch coordinator.route {
            case .entry:
                AddItemModeSelectionView(onSelect: { mode in coordinator.showCapture(for: mode) }, onSelectDraft: coordinator.showDraftReview)
            case let .capture(mode):
                if mode == .outfit {
                    OutfitCaptureView { image, assetIdentifier in coordinator.showNextStep(image: image, mode: mode, originalAssetIdentifier: assetIdentifier) }
                } else {
                    CaptureView(mode: mode) { image, assetIdentifier in coordinator.showNextStep(image: image, mode: mode, originalAssetIdentifier: assetIdentifier) }
                }
            case let .nextStep(result):
                AddItemNextStepView(result: result)
            case let .outfitProcessing(image, assetIdentifier):
                OutfitProcessingDestination(image: image, originalAssetIdentifier: assetIdentifier, onRetry: { coordinator.showCapture(for: .outfit) }) { result in
                    coordinator.showDetectedGarments(image: image, result: result)
                }
            case let .detectedGarments(image, result):
                DetectedGarmentsDestination(image: image, result: result, onContinue: coordinator.showOutfitReview, onRetakeAsProduct: { coordinator.showCapture(for: .product) })
            case let .outfitReview(candidates):
                OutfitReviewDestination(candidates: candidates, onDone: onFinish)
            case let .productProcessing(image):
                ProductProcessingDestination(
                    image: image,
                    onRetryCapture: { coordinator.showCapture(for: .product) },
                    onComplete: coordinator.showProductReview
                )
            case let .productReview(result):
                ProductReviewReadyView(result: result, onDone: onFinish)
            case let .brandEntry(result):
                BrandEntryView(onSearch: { coordinator.showBrandResults(result, brand: $0) }, onSkip: { coordinator.showSelectedBrandPhoto(result, image: result.selectedImage, brand: nil) })
            case let .brandResults(result, brand):
                BrandResultsDestination(result: result, brand: brand) { image in coordinator.showSelectedBrandPhoto(result, image: image, brand: brand) }
            case let .selectedBrandPhoto(result, image, brand):
                ProductReviewReadyView(result: result, image: image, brand: brand, onDone: onFinish)
            case let .draftReview(draft, image):
                DraftReviewDestination(draft: draft, image: image, onDone: onFinish)
            }
        }
        .background(Theme.Colors.canvas)
        .navigationTitle("Add item")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OutfitProcessingDestination: View {
    let image: UIImage
    let originalAssetIdentifier: String?
    let onRetry: () -> Void
    let onComplete: (OutfitExtractionResult) -> Void
    @Environment(DIContainer.self) private var container
    @AppStorage("keepOriginalOutfitPhotos") private var keepOriginalOutfitPhotos = false
    @State private var viewModel: OutfitProcessingViewModel?

    var body: some View {
        Group {
            if let viewModel { OutfitProcessingView(viewModel: viewModel, onComplete: onComplete, onRetry: onRetry) }
            else { ProgressView("Preparing outfit…") }
        }
        .task {
            if viewModel == nil {
                viewModel = OutfitProcessingViewModel(original: image, pipeline: container.outfitExtractionPipeline, originalPhotoDeleter: container.originalOutfitPhotoDeleter, originalAssetIdentifier: originalAssetIdentifier, keepOriginal: keepOriginalOutfitPhotos)
            }
        }
    }
}

private struct DetectedGarmentsDestination: View {
    let image: UIImage
    let result: OutfitExtractionResult
    let onContinue: ([DetectedGarmentsViewModel.Candidate]) -> Void
    let onRetakeAsProduct: () -> Void
    @State private var viewModel: DetectedGarmentsViewModel?

    var body: some View {
        Group {
            if let viewModel { DetectedGarmentsView(viewModel: viewModel, onContinue: onContinue, onRetakeAsProduct: onRetakeAsProduct) }
            else { ProgressView("Preparing garment outlines…") }
        }
        .task { if viewModel == nil { viewModel = DetectedGarmentsViewModel(sourceImage: image, result: result) } }
    }
}

private struct OutfitReviewDestination: View {
    let candidates: [DetectedGarmentsViewModel.Candidate]
    let onDone: () -> Void
    @Environment(DIContainer.self) private var container
    @State private var viewModel: OutfitReviewQueueViewModel?

    var body: some View {
        Group {
            if let viewModel { OutfitReviewQueueView(viewModel: viewModel, onDone: onDone) }
            else { ProgressView("Preparing your review queue…") }
        }
        .task {
            if viewModel == nil {
                viewModel = OutfitReviewQueueViewModel(candidates: candidates, repository: container.wardrobeRepository, imageStore: container.imageStore)
            }
        }
    }
}

private struct ProductProcessingDestination: View {
    let image: UIImage
    let onRetryCapture: () -> Void
    let onComplete: (ProcessedProductPhoto) -> Void
    @Environment(DIContainer.self) private var container
    @State private var viewModel: ProductPhotoProcessingViewModel?

    init(image: UIImage, onRetryCapture: @escaping () -> Void, onComplete: @escaping (ProcessedProductPhoto) -> Void) {
        self.image = image
        self.onRetryCapture = onRetryCapture
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            if let viewModel {
                ProcessingView(viewModel: viewModel, onRetryCapture: onRetryCapture, onComplete: onComplete)
            } else {
                ProgressView("Preparing photo…")
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ProductPhotoProcessingViewModel(
                    original: image,
                    backgroundRemovalService: container.backgroundRemovalService,
                    maskEditingService: container.maskEditingService,
                    enhancementService: container.imageEnhancementService,
                    fidelityChecker: container.fidelityChecker
                )
            }
        }
    }
}

private struct AddItemModeSelectionView: View {
    @AppStorage("lastAddItemMode") private var lastModeRawValue = AddItemMode.product.rawValue
    let onSelect: (AddItemMode) -> Void
    let onSelectDraft: (DraftItem, UIImage) -> Void
    @State private var isDraftsPresented = false
    @Environment(DIContainer.self) private var container

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            EmptyStateView(title: "Add to your wardrobe", message: "Choose how you want to add your clothes. Your photos stay on this device.")
            VStack(spacing: Theme.Spacing.medium) {
                ForEach(AddItemMode.allCases) { mode in
                    Button {
                        lastModeRawValue = mode.rawValue
                        onSelect(mode)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.title).font(.headline)
                                Text(mode.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if mode.rawValue == lastModeRawValue { Image(systemName: "checkmark.circle.fill") }
                        } icon: { Image(systemName: mode.systemImage).font(.title2) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.medium)
                    }
                    .buttonStyle(.bordered)
                    .tint(mode.rawValue == lastModeRawValue ? Theme.Colors.accent : .secondary)
                    .accessibilityHint("Opens the camera and photo import screen")
                }
            }
            .padding(.horizontal, Theme.Spacing.large)
            Button("Resume a draft", systemImage: "doc.text.magnifyingglass") { isDraftsPresented = true }
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding(.top, Theme.Spacing.large)
        .sheet(isPresented: $isDraftsPresented) {
            DraftListView(repository: container.wardrobeRepository, imageStore: container.imageStore) { draft, image in
                isDraftsPresented = false
                onSelectDraft(draft, image)
            }
        }
    }

}

private struct AddItemNextStepView: View {
    let result: AddItemCaptureResult

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            Image(uiImage: result.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(result.mode == .product ? "Product photo ready" : "Outfit photo ready").font(.title2.weight(.semibold))
            Text("The original image and selected mode are ready for the next step.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Theme.Spacing.large)
    }
}

private struct ProductReviewReadyView: View {
    let result: ProcessedProductPhoto
    var image: UIImage
    var brand: String?
    let onDone: () -> Void
    init(result: ProcessedProductPhoto, image: UIImage? = nil, brand: String? = nil, onDone: @escaping () -> Void = {}) {
        self.result = result
        self.image = image ?? result.selectedImage
        self.brand = brand
        self.onDone = onDone
    }
    @Environment(DIContainer.self) private var container
    @State private var viewModel: ReviewItemViewModel?

    var body: some View {
        Group {
            if let viewModel {
                ReviewItemView(viewModel: viewModel, onDone: onDone)
            } else {
                ProgressView("Preparing attribute review…")
            }
        }
        .navigationTitle("Review product")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                            let suggestions = AttributesConfirmationViewModel(
                                image: image,
                                mask: result.mask,
                                classifier: container.garmentClassifier,
                                extractor: container.attributeExtractor
                            )
                            await suggestions.load()
                viewModel = ReviewItemViewModel(
                    image: image,
                    repository: container.wardrobeRepository,
                    imageStore: container.imageStore,
                    initialCategory: suggestions.selectedCategory,
                    initialColor: suggestions.attributes.dominantColorHex,
                    initialPattern: suggestions.attributes.pattern,
                    initialFit: suggestions.attributes.fit,
                    initialSeason: nil,
                    initialBrand: brand
                )
            }
        }
    }
}

private struct BrandResultsDestination: View {
    let result: ProcessedProductPhoto
    let brand: String
    let onContinue: (UIImage) -> Void
    @Environment(DIContainer.self) private var container
    @State private var viewModel: BrandPhotoResultsViewModel?
    @State private var category: GarmentCategory = .other
    @State private var colors: [String] = []

    var body: some View {
        Group {
            if let viewModel {
                BrandPhotoResultsView(viewModel: viewModel, category: category, colors: colors, onContinue: onContinue)
            } else { ProgressView("Preparing brand search…") }
        }
        .task {
            guard viewModel == nil else { return }
            let suggestions = AttributesConfirmationViewModel(image: result.selectedImage, mask: result.mask, classifier: container.garmentClassifier, extractor: container.attributeExtractor)
            await suggestions.load()
            category = suggestions.selectedCategory
            colors = [suggestions.attributes.dominantColorHex].compactMap { $0 }
            viewModel = BrandPhotoResultsViewModel(ownImage: result.selectedImage, brand: brand, provider: container.brandPhotoProvider)
        }
    }
}

private struct DraftReviewDestination: View {
    let draft: DraftItem
    let image: UIImage
    let onDone: () -> Void
    @Environment(DIContainer.self) private var container
    @State private var viewModel: ReviewItemViewModel?

    var body: some View {
        Group {
            if let viewModel { ReviewItemView(viewModel: viewModel, onDone: onDone) }
            else { ProgressView("Preparing draft…") }
        }
        .task {
            if viewModel == nil {
                viewModel = ReviewItemViewModel(image: image, repository: container.wardrobeRepository, imageStore: container.imageStore, draft: draft)
            }
        }
    }
}

struct DraftListView: View {
    let repository: any WardrobeRepository
    let imageStore: any ImageStore
    let onResume: (DraftItem, UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [DraftItem] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if drafts.isEmpty { ContentUnavailableView("No drafts", systemImage: "doc", description: Text("Drafts will appear here if you leave an item before confirming it.")) }
                else { List(drafts, id: \.id) { draft in Button { resume(draft) } label: { Label(draft.category.displayName, systemImage: "doc.text") } } }
            }
            .navigationTitle("Drafts")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
            .task { reload() }
            .alert("Couldn’t load drafts", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") }
        }
    }

    private func reload() { do { drafts = try repository.fetchDrafts() } catch { errorMessage = error.localizedDescription } }
    private func resume(_ draft: DraftItem) {
        Task { @MainActor in
            do {
                let data = try imageStore.loadPNG(for: draft.id)
                guard let image = UIImage(data: data) else { throw ImageStoreError.invalidPNG }
                onResume(draft, image)
            }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

#Preview {
    AddItemEntryView().environment(DIContainer())
}

