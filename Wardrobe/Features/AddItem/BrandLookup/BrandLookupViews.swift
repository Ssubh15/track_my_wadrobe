import Observation
import SwiftUI

@Observable
@MainActor
final class BrandPhotoResultsViewModel {
    enum State: Equatable { case searching, results, noResults, offline, failed(String) }

    let ownImage: UIImage
    let brand: String
    private let provider: any BrandPhotoProvider
    private(set) var candidates: [BrandPhotoCandidate] = []
    var state: State = .searching
    var selectedCandidate: BrandPhotoCandidate?

    init(ownImage: UIImage, brand: String, provider: any BrandPhotoProvider) {
        self.ownImage = ownImage
        self.brand = brand
        self.provider = provider
    }

    func search(category: GarmentCategory, colors: [String]) async {
        state = .searching
        do {
            candidates = try await provider.search(brand: brand, category: category, colors: colors)
            state = candidates.isEmpty ? .noResults : .results
        } catch let error as URLError where Self.isOffline(error) {
            state = .offline
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func keepOwnPhoto() { selectedCandidate = nil }

    private static func isOffline(_ error: URLError) -> Bool {
        [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut].contains(error.code)
    }
}

struct BrandEntryView: View {
    @State private var brand: String
    let onSearch: (String) -> Void
    let onSkip: () -> Void

    init(initialBrand: String = "", onSearch: @escaping (String) -> Void, onSkip: @escaping () -> Void) {
        _brand = State(initialValue: initialBrand)
        self.onSearch = onSearch
        self.onSkip = onSkip
    }

    var body: some View {
        Form {
            Section {
                TextField("Brand", text: $brand).textInputAutocapitalization(.words).accessibilityHint("Enter a brand to search for an optional product photo")
                ForEach(BrandCatalog.suggestions(for: brand), id: \.self) { suggestion in
                    Button(suggestion) { brand = suggestion }
                }
            } header: { Text("Brand (optional)") }
            Section {
                Button("Search for product photos") { onSearch(brand.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    .disabled(brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Skip", action: onSkip).foregroundStyle(.secondary)
            } footer: { Text("Your cut-out stays on this device. Only the brand and garment details are sent to the configured search service.") }
        }
        .navigationTitle("Add a brand")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BrandPhotoResultsView: View {
    @Bindable var viewModel: BrandPhotoResultsViewModel
    let category: GarmentCategory
    let colors: [String]
    let onContinue: (UIImage) -> Void
    @State private var didSearch = false

    var body: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal) {
              HStack(alignment: .top, spacing: 12) {
                photoCard(title: "Your cut-out", image: viewModel.ownImage, selected: viewModel.selectedCandidate == nil) {
                    viewModel.keepOwnPhoto()
                }
                ForEach(viewModel.candidates) { candidate in
                    VStack(alignment: .leading, spacing: 4) {
                        photoCard(title: viewModel.brand, image: candidate.image, selected: viewModel.selectedCandidate?.id == candidate.id) {
                            viewModel.selectedCandidate = candidate
                        }
                        Link(candidate.attribution, destination: candidate.sourceURL).font(.caption2).lineLimit(2)
                    }
                }
              }
            }
            .frame(maxHeight: 300)
            switch viewModel.state {
            case .searching: ProgressView("Searching for product photos…")
            case .results: Text("Choose a photo, or keep your cut-out.").font(.footnote).foregroundStyle(.secondary)
            case .noResults: ContentUnavailableView("No photos found", systemImage: "photo", description: Text("You can continue with your own cut-out."))
            case .offline: ContentUnavailableView("No internet connection", systemImage: "wifi.slash", description: Text("You can continue with your own cut-out."))
            case let .failed(message): ContentUnavailableView("Search unavailable", systemImage: "exclamationmark.triangle", description: Text("\(message) You can continue with your own cut-out."))
            }
            if let candidate = viewModel.selectedCandidate {
                Link("Photo source: \(candidate.attribution)", destination: candidate.sourceURL).font(.footnote)
                    .accessibilityHint("Opens the photo source website")
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "Continue with selected photo", systemImage: "checkmark") {
                onContinue(viewModel.selectedCandidate?.image ?? viewModel.ownImage)
            }
        }
        .padding(16)
        .navigationTitle("Choose a photo")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didSearch else { return }
            didSearch = true
            await viewModel.search(category: category, colors: colors)
        }
    }

    private func photoCard(title: String, image: UIImage, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 220)
                Text(title).font(.caption).lineLimit(1)
                if selected { Label("Selected", systemImage: "checkmark.circle.fill").font(.caption2).foregroundStyle(.tint) }
            }
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(selected ? ", selected" : "")")
    }
}

#Preview("Brand entry") {
    NavigationStack { BrandEntryView(onSearch: { _ in }, onSkip: {}) }
}

#Preview("Brand results") {
    let image = ProductPhotoPreviewImage.garment
    let candidate = BrandPhotoCandidate(image: image, sourceURL: URL(string: "https://example.com") ?? URL(fileURLWithPath: "/"), attribution: "Example")
    NavigationStack {
        BrandPhotoResultsView(viewModel: BrandPhotoResultsViewModel(ownImage: image, brand: "Example", provider: MockBrandPhotoProvider(candidates: [candidate])), category: .shirt, colors: ["blue"], onContinue: { _ in })
    }
}
