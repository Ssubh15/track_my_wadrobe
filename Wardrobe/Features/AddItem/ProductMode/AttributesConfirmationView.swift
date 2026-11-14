import Observation
import SwiftUI
import UIKit

@Observable
@MainActor
final class AttributesConfirmationViewModel {
    enum State: Equatable { case idle, loading, ready, failed(String) }

    let image: UIImage
    let mask: UIImage
    private let classifier: any GarmentClassifier
    private let extractor: any AttributeExtractor
    let confidenceThreshold: Double
    var state: State = .idle
    var predictions: [CategoryPrediction] = []
    var selectedCategory: GarmentCategory = .other
    var attributes = GarmentAttributes(dominantColorHex: nil, secondaryColorHexes: [], pattern: nil, sleeveLength: nil, fit: nil)
    var isCategoryPickerPresented = false

    init(image: UIImage, mask: UIImage, classifier: any GarmentClassifier, extractor: any AttributeExtractor, confidenceThreshold: Double = 0.70) {
        self.image = image
        self.mask = mask
        self.classifier = classifier
        self.extractor = extractor
        self.confidenceThreshold = confidenceThreshold
    }

    func load() async {
        guard state == .idle else { return }
        state = .loading
        do {
            attributes = try extractor.extract(from: image, mask: mask)
            predictions = try await classifier.classify(image).sorted { $0.confidence > $1.confidence }
            selectedCategory = predictions.first?.category ?? .other
            state = .ready
            if predictions.first?.confidence ?? 0 < confidenceThreshold { isCategoryPickerPresented = true }
        } catch {
            state = .failed(error.localizedDescription)
            isCategoryPickerPresented = true
        }
    }

    func select(category: GarmentCategory) {
        selectedCategory = category
        isCategoryPickerPresented = false
    }

    var topSuggestions: [CategoryPrediction] { Array(predictions.prefix(3)) }
}

struct AttributesConfirmationView: View {
    @Bindable var viewModel: AttributesConfirmationViewModel
    let onSave: (GarmentCategory, GarmentAttributes) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                Image(uiImage: viewModel.image)
                    .resizable().scaledToFit().frame(maxHeight: 280)
                    .frame(maxWidth: .infinity)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Garment cut-out")

                switch viewModel.state {
                case .loading, .idle: ProgressView("Reading garment attributes…")
                case let .failed(message):
                    Label(message, systemImage: "info.circle").foregroundStyle(.secondary)
                case .ready: EmptyView()
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Category").font(.headline)
                    Button {
                        viewModel.isCategoryPickerPresented = true
                    } label: {
                        HStack {
                            Text(viewModel.selectedCategory.displayName)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .padding(Theme.Spacing.medium)
                        .frame(maxWidth: .infinity)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Choose a different garment category")
                }

                AttributeSummaryView(attributes: viewModel.attributes)

                PrimaryButton(title: "Confirm attributes", systemImage: "checkmark") {
                    onSave(viewModel.selectedCategory, viewModel.attributes)
                }
            }
            .padding(Theme.Spacing.large)
        }
        .navigationTitle("Confirm attributes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.isCategoryPickerPresented) {
            CategoryPickerSheet(predictions: viewModel.topSuggestions, selectedCategory: viewModel.selectedCategory, onSelect: viewModel.select)
                .presentationDetents([.medium, .large])
        }
    }
}

struct CategoryPickerSheet: View {
    let predictions: [CategoryPrediction]
    let selectedCategory: GarmentCategory
    let onSelect: (GarmentCategory) -> Void

    var body: some View {
        NavigationStack {
            List {
                if !predictions.isEmpty { Section("Suggestions") { ForEach(predictions) { prediction in categoryRow(prediction.category, confidence: prediction.confidence) } } }
                Section("All categories") { ForEach(GarmentCategory.builtIn, id: \.self) { category in categoryRow(category, confidence: nil) } }
            }
            .navigationTitle("Choose category")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func categoryRow(_ category: GarmentCategory, confidence: Double?) -> some View {
        Button { onSelect(category) } label: {
            HStack {
                Text(category.displayName)
                Spacer()
                if let confidence { Text("\(Int(confidence * 100))%") .foregroundStyle(.secondary).font(.caption) }
                if category == selectedCategory { Image(systemName: "checkmark") }
            }
        }
        .accessibilityLabel(confidence.map { "\(category.displayName), \(Int($0 * 100)) percent confidence" } ?? category.displayName)
    }
}

private struct AttributeSummaryView: View {
    let attributes: GarmentAttributes

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Suggested attributes").font(.headline)
            LabeledContent("Dominant color", value: attributes.dominantColorHex ?? "Not detected")
            LabeledContent("Secondary colors", value: attributes.secondaryColorHexes.isEmpty ? "None detected" : attributes.secondaryColorHexes.joined(separator: ", "))
            LabeledContent("Pattern", value: attributes.pattern ?? "Not detected")
            LabeledContent("Sleeve length", value: attributes.sleeveLength ?? "Not detected")
            LabeledContent("Fit", value: attributes.fit ?? "Not detected")
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Confirmation") {
    NavigationStack {
        AttributesConfirmationView(
            viewModel: AttributesConfirmationViewModel(image: ProductPhotoPreviewImage.garment, mask: ProductPhotoPreviewImage.garment, classifier: MockGarmentClassifier(), extractor: KMeansAttributeExtractor()),
            onSave: { _, _ in }
        )
    }
}
