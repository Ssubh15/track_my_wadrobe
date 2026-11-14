import Observation
import SwiftUI
import UIKit

struct ProcessedProductPhoto {
    let original: UIImage
    let cutout: UIImage
    let mask: UIImage
    let enhanced: UIImage?
    let selectedImage: UIImage
    let extractionModel: ExtractionModel
}

@Observable
@MainActor
final class ProductPhotoProcessingViewModel {
    enum State: Equatable {
        case idle
        case removingBackground
        case enhancing
        case verifying
        case ready
        case failed(String)

        var progressTitle: String {
            switch self {
            case .idle: "Preparing your photo"
            case .removingBackground: "Removing the background"
            case .enhancing: "Applying gentle adjustments"
            case .verifying: "Checking garment fidelity"
            case .ready: "Your cut-out is ready"
            case .failed: "Processing couldn’t finish"
            }
        }
    }

    let original: UIImage
    private let backgroundRemovalService: any BackgroundRemovalService
    let maskEditingService: any MaskEditing
    private let enhancementService: any ImageEnhancementServing
    private let fidelityChecker: any FidelityChecking
    var state: State = .idle
    var cutout: UIImage?
    var mask: UIImage?
    var maskSource: UIImage?
    var enhanced: UIImage?
    var fidelityResult: FidelityCheckResult?
    var enhancementMessage: String?
    var extractionModel: ExtractionModel?

    init(
        original: UIImage,
        backgroundRemovalService: any BackgroundRemovalService,
        maskEditingService: any MaskEditing = MaskEditingService(),
        enhancementService: any ImageEnhancementServing,
        fidelityChecker: any FidelityChecking
    ) {
        self.original = original
        self.backgroundRemovalService = backgroundRemovalService
        self.maskEditingService = maskEditingService
        self.enhancementService = enhancementService
        self.fidelityChecker = fidelityChecker
    }

    func process() async {
        state = .removingBackground
        enhancementMessage = nil
        enhanced = nil
        fidelityResult = nil
        do {
            let removalResult = try await backgroundRemovalService.removeBackground(from: original)
            cutout = removalResult.cutout
            mask = removalResult.mask
            maskSource = removalResult.maskSource
            extractionModel = removalResult.extractionModel
            state = .enhancing
            let candidate = try enhancementService.enhance(removalResult.cutout)
            state = .verifying
            do {
                fidelityResult = try fidelityChecker.check(before: removalResult.cutout, after: candidate)
                enhanced = candidate
            } catch let error as FidelityError {
                enhancementMessage = error.localizedDescription
            }
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func retry() async {
        cutout = nil
        mask = nil
        maskSource = nil
        extractionModel = nil
        await process()
    }

    func processedPhoto(usingPlainCutout: Bool) -> ProcessedProductPhoto? {
        guard let cutout, let mask else { return nil }
        guard let extractionModel else { return nil }
        return ProcessedProductPhoto(
            original: original,
            cutout: cutout,
            mask: mask,
            enhanced: enhanced,
            selectedImage: usingPlainCutout ? cutout : (enhanced ?? cutout),
            extractionModel: extractionModel
        )
    }

    func replaceMask(with editedMask: UIImage) {
        do {
            guard let maskSource else { return }
            mask = editedMask
            cutout = try maskEditingService.makingCutout(from: maskSource, using: editedMask)
            // The existing enhancement used an earlier alpha mask, so it must never be reused.
            enhanced = nil
            fidelityResult = nil
            enhancementMessage = "The outline was updated. The plain cut-out keeps your original garment pixels."
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct ProcessingView: View {
    @Bindable var viewModel: ProductPhotoProcessingViewModel
    let onRetryCapture: () -> Void
    let onComplete: (ProcessedProductPhoto) -> Void
    @State private var started = false
    @State private var isEditingMask = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .ready:
                if let processed = viewModel.processedPhoto(usingPlainCutout: false) {
                    BeforeAfterView(
                        processed: processed,
                        onRetry: { Task { await viewModel.retry() } },
                        onEditMask: { isEditingMask = true },
                        onUsePlainCutout: {
                            guard let plain = viewModel.processedPhoto(usingPlainCutout: true) else { return }
                            onComplete(plain)
                        },
                        onUseEnhanced: { onComplete(processed) }
                    )
                }
            case let .failed(message):
                ContentUnavailableView {
                    Label("Couldn’t process photo", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { Task { await viewModel.retry() } }
                        .buttonStyle(.borderedProminent)
                    Button("Choose another photo", action: onRetryCapture)
                        .buttonStyle(.bordered)
                }
            default:
                VStack(spacing: Theme.Spacing.large) {
                    ProgressView().controlSize(.large)
                    Text(viewModel.state.progressTitle).font(.title3.weight(.semibold))
                    if viewModel.state == .removingBackground {
                        Text("Trying U²-Net, then Apple Vision if needed")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("Your photo stays on this device.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(Theme.Spacing.large)
        .task {
            guard !started else { return }
            started = true
            await viewModel.process()
        }
        .sheet(isPresented: $isEditingMask) {
            if let mask = viewModel.mask, let maskSource = viewModel.maskSource {
                NavigationStack {
                    MaskEditorView(
                        original: maskSource,
                        mask: mask,
                        maskEditingService: viewModel.maskEditingService,
                        onCancel: { isEditingMask = false },
                        onSave: { editedMask in
                            viewModel.replaceMask(with: editedMask)
                            isEditingMask = false
                        }
                    )
                }
            }
        }
    }
}

struct BeforeAfterView: View {
    enum DisplayImage: String, CaseIterable, Identifiable {
        case original = "Original"
        case cutout = "Cut-out"
        case enhanced = "Enhanced"

        var id: String { rawValue }
    }

    let processed: ProcessedProductPhoto
    let onRetry: () -> Void
    let onEditMask: () -> Void
    let onUsePlainCutout: () -> Void
    let onUseEnhanced: () -> Void
    @State private var selection: DisplayImage = .enhanced

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            Picker("Image version", selection: $selection) {
                ForEach(availableImages) { image in
                    Text(image.rawValue).tag(image)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Choose image version")

            GeometryReader { geometry in
                Image(uiImage: image(for: selection))
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            }
                .frame(height: 360)
                .background(checkerboard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("\(selection.rawValue) garment image")

            Label("Extracted with \(processed.extractionModel.rawValue)", systemImage: "cpu")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Garment mask extracted with \(processed.extractionModel.rawValue)")

            if processed.enhanced == nil {
                Label("Enhancement was skipped to protect the garment’s color and shape.", systemImage: "checkmark.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if processed.enhanced != nil {
                PrimaryButton(title: "Use enhanced image", action: onUseEnhanced)
            }
            Button("Edit outline", systemImage: "paintbrush.pointed", action: onEditMask)
                .buttonStyle(.bordered)
            Button("Use plain cut-out", action: onUsePlainCutout)
                .buttonStyle(.bordered)
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
        .navigationTitle("Review cut-out")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: processed.enhanced != nil) { _, hasEnhancement in
            if !hasEnhancement { selection = .cutout }
        }
    }

    private var availableImages: [DisplayImage] {
        processed.enhanced == nil ? [.original, .cutout] : DisplayImage.allCases
    }

    private var checkerboard: some View {
        Rectangle().fill(.quaternary)
    }

    private func image(for selection: DisplayImage) -> UIImage {
        switch selection {
        case .original: processed.original
        case .cutout: processed.cutout
        case .enhanced: processed.enhanced ?? processed.cutout
        }
    }
}

#Preview("Processing") {
    let image = ProductPhotoPreviewImage.garment
    let result = BackgroundRemovalResult(cutout: image, mask: image)
    let viewModel = ProductPhotoProcessingViewModel(
        original: image,
        backgroundRemovalService: MockBackgroundRemovalService(result: result),
        enhancementService: MockImageEnhancementService(enhancedImage: image),
        fidelityChecker: MockFidelityChecker()
    )
    return NavigationStack {
        ProcessingView(viewModel: viewModel, onRetryCapture: {}, onComplete: { _ in })
    }
}

#Preview("Before and after") {
    NavigationStack {
        BeforeAfterView(
            processed: ProcessedProductPhoto(
                original: ProductPhotoPreviewImage.garment,
                cutout: ProductPhotoPreviewImage.garment,
                mask: ProductPhotoPreviewImage.garment,
                enhanced: ProductPhotoPreviewImage.garment,
                selectedImage: ProductPhotoPreviewImage.garment,
                extractionModel: .appleVision
            ),
            onRetry: {},
            onEditMask: {},
            onUsePlainCutout: {},
            onUseEnhanced: {}
        )
    }
}

enum ProductPhotoPreviewImage {
    static let garment: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 360, height: 360), format: format).image { context in
            UIColor.systemIndigo.setFill()
            context.cgContext.fill(CGRect(x: 100, y: 60, width: 160, height: 240))
            context.cgContext.fill(CGRect(x: 60, y: 90, width: 240, height: 70))
        }
    }()
}
