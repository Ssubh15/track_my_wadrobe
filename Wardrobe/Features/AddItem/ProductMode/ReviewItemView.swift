import Observation
import SwiftUI
import UIKit

@Observable
@MainActor
final class ReviewItemViewModel {
    enum State: Equatable { case editing, saving, success, failed(String) }

    let image: UIImage
    /// Name of the model that produced the cut-out, shown under the image. Nil hides the line.
    let extractionModelName: String?
    private let repository: any WardrobeRepository
    private let imageStore: any ImageStore
    private(set) var draft: DraftItem
    var state: State = .editing
    var category: GarmentCategory
    var color: String
    var pattern: String
    var size: String
    var fit: String
    var season: String
    var material: String
    var brand: String
    var price: String
    var purchaseDate: Date?
    var notes: String
    var tags: String

    init(image: UIImage, repository: any WardrobeRepository, imageStore: any ImageStore,
         draft: DraftItem? = nil, initialCategory: GarmentCategory = .other,
         initialColor: String? = nil, initialPattern: String? = nil,
         initialFit: String? = nil, initialSeason: String? = nil, initialBrand: String? = nil,
         imageSource: ImageSource = .productPhoto, sourceGroupID: UUID? = nil, isPartial: Bool = false,
         extractionModelName: String? = nil) {
        self.image = image
        self.extractionModelName = extractionModelName
        self.repository = repository
        self.imageStore = imageStore
        let draft = draft ?? DraftItem(category: initialCategory, imageSource: imageSource)
        if draft.cutoutImagePath == nil {
            draft.sourceGroupID = sourceGroupID
            draft.isPartial = isPartial
        }
        self.draft = draft
        category = draft.category
        color = draft.primaryColorHex ?? initialColor ?? ""
        pattern = draft.pattern ?? initialPattern ?? ""
        size = draft.size ?? ""
        fit = draft.fit ?? initialFit ?? ""
        season = draft.season ?? initialSeason ?? ""
        material = draft.material ?? ""
        brand = initialBrand ?? draft.brand ?? ""
        price = draft.price.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        purchaseDate = draft.purchaseDate
        notes = draft.notes ?? ""
        tags = draft.tags.joined(separator: ", ")
    }

    func persistDraft() {
        guard state != .success else { return }
        draft.category = category
        draft.primaryColorHex = color.nilIfBlank
        draft.pattern = pattern.nilIfBlank
        draft.size = size.nilIfBlank
        draft.fit = fit.nilIfBlank
        draft.season = season.nilIfBlank
        draft.material = material.nilIfBlank
        draft.brand = brand.nilIfBlank
        draft.price = Decimal(string: price.trimmingCharacters(in: .whitespacesAndNewlines))
        draft.purchaseDate = purchaseDate
        draft.notes = notes.nilIfBlank
        draft.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        draft.cutoutImagePath = "\(draft.id.uuidString).png"
        do {
            guard let data = image.pngData() else { throw ReviewItemError.imageEncodingFailed }
            try imageStore.savePNG(data, for: draft.id)
            try repository.saveDraft(draft)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func confirm() {
        guard state != .saving else { return }
        state = .saving
        do {
            guard let data = image.pngData() else { throw ReviewItemError.imageEncodingFailed }
            let itemID = UUID()
            let item = GarmentItem(id: itemID, category: category, primaryColorHex: color.nilIfBlank,
                                   pattern: pattern.nilIfBlank, fit: fit.nilIfBlank, season: season.nilIfBlank,
                                   material: material.nilIfBlank, size: size.nilIfBlank, brand: brand.nilIfBlank,
                                   price: Decimal(string: price.trimmingCharacters(in: .whitespacesAndNewlines)),
                                   purchaseDate: purchaseDate, notes: notes.nilIfBlank,
                                   tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                                   imageSource: draft.imageSource, cutoutImagePath: "\(itemID.uuidString).png",
                                   originalImagePath: draft.originalImagePath, sourceGroupID: draft.sourceGroupID, isPartial: draft.isPartial)
            try imageStore.savePNG(data, for: itemID)
            do {
                try repository.save(item)
                try repository.deleteDraft(draft)
                try imageStore.deletePNG(for: draft.id)
                state = .success
            } catch {
                try? imageStore.deletePNG(for: itemID)
                throw error
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

enum ReviewItemError: LocalizedError {
    case imageEncodingFailed
    var errorDescription: String? { "The garment image could not be prepared." }
}

private extension String {
    var nilIfBlank: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}

struct ReviewItemView: View {
    @Bindable var viewModel: ReviewItemViewModel
    let onDone: () -> Void
    let actionTitle: String
    let onConfirm: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasPurchaseDate = false

    init(viewModel: ReviewItemViewModel, onDone: @escaping () -> Void = {}, actionTitle: String = "Confirm", onConfirm: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onDone = onDone
        self.actionTitle = actionTitle
        self.onConfirm = onConfirm
        _hasPurchaseDate = State(initialValue: viewModel.purchaseDate != nil)
    }

    var body: some View {
        Group {
            if viewModel.state == .success {
                SuccessView(onDone: onDone)
            } else {
                form
            }
        }
        .navigationTitle("Review item")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.persistDraft() }
        .onDisappear { viewModel.persistDraft() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.persistDraft() } }
        .onChange(of: viewModel.category) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.color) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.pattern) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.size) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.fit) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.season) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.material) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.brand) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.price) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.purchaseDate) { _, _ in viewModel.persistDraft() }
        .onChange(of: hasPurchaseDate) { _, enabled in
            if enabled && viewModel.purchaseDate == nil { viewModel.purchaseDate = .now }
            if !enabled { viewModel.purchaseDate = nil }
        }
        .onChange(of: viewModel.notes) { _, _ in viewModel.persistDraft() }
        .onChange(of: viewModel.tags) { _, _ in viewModel.persistDraft() }
    }

    private var form: some View {
        Form {
            Section {
                Image(uiImage: viewModel.image).resizable().scaledToFit().frame(maxHeight: 260)
                    .frame(maxWidth: .infinity).accessibilityLabel("Garment cut-out")
                if let modelName = viewModel.extractionModelName {
                    Text("Segmented by: \(modelName)").font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            Section("Details") {
                Picker("Category", selection: $viewModel.category) {
                    ForEach(categoryOptions, id: \.self) { Text($0.displayName).tag($0) }
                }
                field("Color", text: $viewModel.color)
                field("Pattern", text: $viewModel.pattern)
                field("Size", text: $viewModel.size)
                field("Fit", text: $viewModel.fit)
                field("Season", text: $viewModel.season)
                field("Material", text: $viewModel.material)
                field("Brand", text: $viewModel.brand)
            }
            Section("Purchase") {
                TextField("Price", text: $viewModel.price).keyboardType(.decimalPad)
                Toggle("Purchase date", isOn: $hasPurchaseDate)
                if hasPurchaseDate { DatePicker("Date", selection: Binding(get: { viewModel.purchaseDate ?? .now }, set: { viewModel.purchaseDate = $0 }), displayedComponents: .date) }
            }
            Section("Notes and tags") {
                TextField("Notes", text: $viewModel.notes, axis: .vertical).lineLimit(3...6)
                TextField("Tags (comma separated)", text: $viewModel.tags)
            }
            if case let .failed(message) = viewModel.state { Section { Text(message).foregroundStyle(.red) } }
            Section {
                PrimaryButton(title: actionTitle, systemImage: "checkmark") {
                    if let onConfirm {
                        viewModel.persistDraft()
                        onConfirm()
                    } else {
                        viewModel.confirm()
                    }
                }
                .disabled(viewModel.state == .saving)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View { TextField(title, text: text) }
    private var categoryOptions: [GarmentCategory] {
        GarmentCategory.builtIn + (GarmentCategory.builtIn.contains(viewModel.category) ? [] : [viewModel.category])
    }
}

private struct SuccessView: View {
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.Colors.accent)
            Text("Added to your wardrobe").font(.title2.weight(.semibold))
            Text("Your garment and its details are saved on this device.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            PrimaryButton(title: "Done", action: onDone)
        }.padding(Theme.Spacing.large).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack { ReviewItemView(viewModel: ReviewItemViewModel(image: ProductPhotoPreviewImage.garment, repository: InMemoryWardrobeRepository(), imageStore: PreviewImageStore())) }
}

private final class PreviewImageStore: ImageStore {
    func savePNG(_ data: Data, for id: UUID) throws {}
    func loadPNG(for id: UUID) throws -> Data { throw ImageStoreError.missingImage }
    func deletePNG(for id: UUID) throws {}
}
