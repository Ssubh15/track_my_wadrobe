import Observation
import SwiftUI
import UIKit

/// Outfit-specific capture entry point. It reuses the shared camera safely while providing outfit framing guidance.
struct OutfitCaptureView: View {
    let onImageReady: (UIImage, String?) -> Void

    var body: some View {
        CaptureView(mode: .outfit, onImageReady: onImageReady)
            .navigationTitle("Outfit photo")
    }
}

@Observable
@MainActor
final class OutfitProcessingViewModel {
    enum State: Equatable { case processing, choosePerson, complete, failed(String) }

    let original: UIImage
    private let pipeline: any OutfitExtracting
    private let originalPhotoDeleter: any OriginalOutfitPhotoDeleting
    private let originalAssetIdentifier: String?
    private let keepOriginal: Bool
    private(set) var result: OutfitExtractionResult?
    var state: State = .processing
    var privacyMessage: String?
    private var didFinalize = false

    init(original: UIImage, pipeline: any OutfitExtracting, originalPhotoDeleter: any OriginalOutfitPhotoDeleting = MockOriginalOutfitPhotoDeleter(), originalAssetIdentifier: String? = nil, keepOriginal: Bool = false) {
        self.original = original
        self.pipeline = pipeline
        self.originalPhotoDeleter = originalPhotoDeleter
        self.originalAssetIdentifier = originalAssetIdentifier
        self.keepOriginal = keepOriginal
    }

    func process(personIdentifier: Int? = nil) async {
        state = .processing
        do {
            let result = try await pipeline.extract(from: original, personIdentifier: personIdentifier)
            self.result = result
            state = result.requiresPersonSelection ? .choosePerson : .complete
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func finalizePrivacy() async {
        guard !didFinalize else { return }
        didFinalize = true
        guard !keepOriginal, let originalAssetIdentifier else { return }
        do { try await originalPhotoDeleter.deletePhoto(assetIdentifier: originalAssetIdentifier) }
        catch { privacyMessage = error.localizedDescription }
    }
}

/// This view only keeps the source image while extraction is in progress. It is never written to the item image store.
struct OutfitProcessingView: View {
    @Bindable var viewModel: OutfitProcessingViewModel
    let onComplete: (OutfitExtractionResult) -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            switch viewModel.state {
            case .processing:
                ProgressView("Finding visible garments…")
                Text("Processing stays on this device. Faces and bodies are not saved with items.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .choosePerson:
                Text("Choose the person whose outfit you want to add").font(.title3.weight(.semibold))
                ForEach(viewModel.result?.people ?? [], id: \.identifier) { person in
                    Button("Person \(person.identifier)") { Task { await viewModel.process(personIdentifier: person.identifier) } }
                        .buttonStyle(.bordered)
                }
            case .complete:
                ProgressView()
                    .task {
                        await viewModel.finalizePrivacy()
                        if let result = viewModel.result { onComplete(result) }
                    }
            case let .failed(message):
                ContentUnavailableView("Couldn’t extract garments", systemImage: "exclamationmark.triangle", description: Text(message))
                Button("Try another photo", action: onRetry).buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.Spacing.large)
        .navigationTitle("Processing outfit")
        .alert("Original photo", isPresented: Binding(get: { viewModel.privacyMessage != nil }, set: { if !$0 { viewModel.privacyMessage = nil } })) { Button("OK") {} } message: { Text(viewModel.privacyMessage ?? "") }
        .task { if viewModel.result == nil { await viewModel.process() } }
    }
}

@Observable
@MainActor
final class DetectedGarmentsViewModel {
    struct Candidate: Identifiable {
        let id = UUID()
        var garment: ExtractedGarment
        /// Repairs are constrained to the Vision-detected garment pixels, never the surrounding body or face.
        let allowedMask: UIImage
        var isSelected = true

        init(garment: ExtractedGarment, allowedMask: UIImage? = nil, isSelected: Bool = true) {
            self.garment = garment
            self.allowedMask = allowedMask ?? garment.mask
            self.isSelected = isSelected
        }
    }

    let sourceImage: UIImage
    private let maskEditor: any MaskEditing
    private(set) var candidates: [Candidate]
    let mirrorDetection: MirrorDetection
    var segmenterModelName: String
    var elapsedSeconds: Double
    var isFlipped: Bool
    var errorMessage: String?

    init(sourceImage: UIImage, result: OutfitExtractionResult, maskEditor: any MaskEditing = MaskEditingService()) {
        self.sourceImage = sourceImage
        self.maskEditor = maskEditor
        candidates = result.garments.map { Candidate(garment: $0) }
        mirrorDetection = result.mirrorDetection
        segmenterModelName = result.segmenterModelName
        elapsedSeconds = result.elapsedSeconds
        isFlipped = result.mirrorDetection.isLikelyMirrorSelfie
    }

    var selectedCandidates: [Candidate] { candidates.filter(\.isSelected) }

    func toggle(_ id: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        candidates[index].isSelected.toggle()
    }

    func replaceMask(_ mask: UIImage, for id: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        do {
            guard let safeMask = OutfitMaskRenderer.intersection(of: mask, and: candidates[index].allowedMask) else {
                throw OutfitExtractionError.unableToCreateCutout
            }
            let cutout = GarmentCutoutCropper.crop(try maskEditor.makingCutout(from: sourceImage, using: safeMask), to: safeMask)
            candidates[index].garment = ExtractedGarment(
                cutoutImage: cutout, mask: safeMask, guessedCategory: candidates[index].garment.guessedCategory,
                isPartial: candidates[index].garment.isPartial, partialReason: candidates[index].garment.partialReason,
                confidence: candidates[index].garment.confidence
            )
        } catch { errorMessage = error.localizedDescription }
    }

    /// Adds a conservative lower-body candidate. Its initial region excludes the head; the user can repair its outline.
    func addMissedItem() {
        guard let base = candidates.first?.garment.mask,
              let bounds = base.cgImage.flatMap(MaskImageProcessor.foregroundBounds),
              let mask = OutfitMaskRenderer.intersecting(base, with: CGRect(x: bounds.minX, y: bounds.midY, width: bounds.width, height: bounds.height / 2)),
              let fullCutout = try? maskEditor.makingCutout(from: sourceImage, using: mask) else {
            errorMessage = "Add a detected item before adding another outline."
            return
        }
        let cutout = GarmentCutoutCropper.crop(fullCutout, to: mask)
        candidates.append(Candidate(garment: ExtractedGarment(cutoutImage: cutout, mask: mask, guessedCategory: .accessory, isPartial: false, partialReason: nil, confidence: 0), allowedMask: mask))
    }
}

struct DetectedGarmentsView: View {
    @Bindable var viewModel: DetectedGarmentsViewModel
    let onContinue: ([DetectedGarmentsViewModel.Candidate]) -> Void
    let onRetakeAsProduct: () -> Void
    @State private var editingCandidate: DetectedGarmentsViewModel.Candidate?
    @State private var partialCandidate: DetectedGarmentsViewModel.Candidate?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.large) {
                let secondsText: String = String(format: "%.1f", viewModel.elapsedSeconds)
                let caption: String = "Segmented by: \(viewModel.segmenterModelName) · \(secondsText)s"
                Text(caption)
                    .font(.caption).foregroundStyle(.secondary)
                ZStack {
                    Image(uiImage: viewModel.sourceImage).resizable().scaledToFit().scaleEffect(x: viewModel.isFlipped ? -1 : 1, y: 1)
                    GeometryReader { proxy in
                        ForEach(viewModel.candidates) { candidate in
                            if let bounds = candidate.garment.mask.cgImage.flatMap(MaskImageProcessor.foregroundBounds) {
                                let imageSize = CGSize(width: candidate.garment.mask.cgImage?.width ?? 1, height: candidate.garment.mask.cgImage?.height ?? 1)
                                let frame = fittedFrame(imageSize: imageSize, in: proxy.size)
                                let rect = CGRect(x: frame.minX + bounds.minX / imageSize.width * frame.width, y: frame.minY + bounds.minY / imageSize.height * frame.height, width: bounds.width / imageSize.width * frame.width, height: bounds.height / imageSize.height * frame.height)
                                RoundedRectangle(cornerRadius: 8).stroke(candidate.isSelected ? Theme.Colors.accent : .gray, lineWidth: 3)
                                    .frame(width: rect.width, height: rect.height).position(x: viewModel.isFlipped ? frame.maxX - (rect.midX - frame.minX) : rect.midX, y: rect.midY)
                                    .onTapGesture { viewModel.toggle(candidate.id) }
                                    .accessibilityLabel("\(candidate.garment.guessedCategory.displayName) outline")
                                    .accessibilityHint(candidate.isSelected ? "Double tap to deselect" : "Double tap to select")
                            }
                        }
                    }
                }
                .aspectRatio(viewModel.sourceImage.size, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if viewModel.mirrorDetection.isLikelyMirrorSelfie {
                    Toggle("Flip mirror-selfie preview", isOn: $viewModel.isFlipped)
                }
                Text("Tap an outline to select it. Item images contain only cut-out garment pixels, never the full outfit photo.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                ForEach(viewModel.candidates) { candidate in
                    HStack {
                        Toggle(candidate.garment.guessedCategory.displayName, isOn: Binding(get: { candidate.isSelected }, set: { _ in viewModel.toggle(candidate.id) }))
                        Spacer()
                        Button("Fix outline") { editingCandidate = candidate }.buttonStyle(.bordered)
                    }
                }
                Button("Add a missed item", systemImage: "plus.viewfinder") { viewModel.addMissedItem() }.buttonStyle(.bordered)
                PrimaryButton(title: "Review \(viewModel.selectedCandidates.count) items", action: {
                    partialCandidate = viewModel.selectedCandidates.first(where: { $0.garment.isPartial })
                    if partialCandidate == nil { onContinue(viewModel.selectedCandidates) }
                })
                    .disabled(viewModel.selectedCandidates.isEmpty)
            }
            .padding(Theme.Spacing.large)
        }
        .navigationTitle("Detected garments")
        .sheet(item: $editingCandidate) { candidate in
            NavigationStack {
                MaskEditorView(original: viewModel.sourceImage, mask: candidate.garment.mask, onCancel: { editingCandidate = nil }) { mask in
                    viewModel.replaceMask(mask, for: candidate.id)
                    editingCandidate = nil
                }
            }
        }
        .sheet(item: $partialCandidate) { candidate in
            PartialItemSheet(reason: candidate.garment.partialReason ?? .occluded, onRetake: {
                partialCandidate = nil
                onRetakeAsProduct()
            }, onBrandPhoto: {
                partialCandidate = nil
                onContinue(viewModel.selectedCandidates)
            }, onKeep: {
                partialCandidate = nil
                onContinue(viewModel.selectedCandidates)
            })
        }
        .alert("Couldn’t update outline", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) { Button("OK") {} } message: { Text(viewModel.errorMessage ?? "") }
    }

    private func fittedFrame(imageSize: CGSize, in size: CGSize) -> CGRect {
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let rendered = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (size.width - rendered.width) / 2, y: (size.height - rendered.height) / 2, width: rendered.width, height: rendered.height)
    }
}

struct PartialItemSheet: View {
    let reason: PartialGarmentReason
    let onRetake: () -> Void
    let onBrandPhoto: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Label("This item is partial", systemImage: "viewfinder.trianglebadge.exclamationmark")
                .font(.title3.weight(.semibold))
            Text(reason.rawValue).foregroundStyle(.secondary)
            Text("A partial cut-out may not show the complete garment.").font(.footnote)
            PrimaryButton(title: "Retake as a product photo", action: onRetake)
            Button("Use a brand photo", action: onBrandPhoto).buttonStyle(.bordered)
            Button("Keep as is", action: onKeep).buttonStyle(.bordered)
        }
        .padding(Theme.Spacing.large)
        .presentationDetents([.medium])
    }
}

@Observable
@MainActor
final class OutfitReviewQueueViewModel {
    let sourceGroupID: UUID
    private(set) var itemViewModels: [ReviewItemViewModel]
    var index = 0
    var sharedBrand = ""
    var errorMessage: String?
    var isSaving = false

    init(candidates: [DetectedGarmentsViewModel.Candidate], repository: any WardrobeRepository, imageStore: any ImageStore, segmenterModelName: String = OutfitDiagnostics.currentSegmenterName) {
        let groupID = UUID()
        sourceGroupID = groupID
        itemViewModels = candidates.map {
            ReviewItemViewModel(image: $0.garment.cutoutImage, repository: repository, imageStore: imageStore,
                                initialCategory: $0.garment.guessedCategory, imageSource: .outfitPhoto,
                                sourceGroupID: groupID, isPartial: $0.garment.isPartial, extractionModelName: segmenterModelName)
        }
    }

    var current: ReviewItemViewModel { itemViewModels[index] }
    var progressText: String { "\(index + 1) of \(itemViewModels.count)" }
    var isLastItem: Bool { index == itemViewModels.count - 1 }

    func advance() { if !isLastItem { index += 1 } }
    func saveAll() {
        guard !isSaving else { return }
        isSaving = true
        for viewModel in itemViewModels {
            viewModel.brand = sharedBrand
            viewModel.confirm()
            if case let .failed(message) = viewModel.state { errorMessage = message; isSaving = false; return }
        }
        isSaving = false
    }
}

struct OutfitReviewQueueView: View {
    @Bindable var viewModel: OutfitReviewQueueViewModel
    let onDone: () -> Void
    @State private var isBrandStep = false

    var body: some View {
        Group {
            if isBrandStep {
                Form {
                    Section("Brand") { TextField("Brand (optional)", text: $viewModel.sharedBrand) }
                    Section { PrimaryButton(title: "Save all \(viewModel.itemViewModels.count) items", systemImage: "checkmark") { viewModel.saveAll() }.disabled(viewModel.isSaving) }
                }
                .navigationTitle("Brand details")
            } else {
                VStack(spacing: 0) {
                    Text(viewModel.progressText).font(.subheadline.weight(.semibold)).padding(.top, Theme.Spacing.small)
                    TabView(selection: $viewModel.index) {
                        ForEach(viewModel.itemViewModels.indices, id: \.self) { itemIndex in
                            ReviewItemView(viewModel: viewModel.itemViewModels[itemIndex], actionTitle: itemIndex == viewModel.itemViewModels.indices.last ? "Continue to brand" : "Next item") {
                                if itemIndex == viewModel.itemViewModels.indices.last { isBrandStep = true }
                                else { viewModel.index = itemIndex + 1 }
                            }
                            .tag(itemIndex)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .onChange(of: viewModel.itemViewModels.map(\.state)) { _, states in
            if isBrandStep && states.allSatisfy({ $0 == .success }) { onDone() }
        }
        .alert("Couldn’t save items", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) { Button("OK") {} } message: { Text(viewModel.errorMessage ?? "") }
    }
}

#Preview("Detected garments") {
    NavigationStack {
        DetectedGarmentsView(viewModel: DetectedGarmentsViewModel(sourceImage: ProductPhotoPreviewImage.garment, result: OutfitExtractionResult(people: [], selectedPerson: nil, garments: [], mirrorDetection: MirrorDetection(isLikelyMirrorSelfie: false, confidence: 0, reasons: []))), onContinue: { _ in }, onRetakeAsProduct: {})
    }
}
