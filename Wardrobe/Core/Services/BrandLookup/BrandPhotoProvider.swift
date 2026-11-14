import Foundation
import UIKit

struct BrandPhotoCandidate: Identifiable {
    let id: UUID
    let image: UIImage
    let sourceURL: URL
    let attribution: String

    init(id: UUID = UUID(), image: UIImage, sourceURL: URL, attribution: String) {
        self.id = id
        self.image = image
        self.sourceURL = sourceURL
        self.attribution = attribution
    }
}

protocol BrandPhotoProvider {
    func search(brand: String, category: GarmentCategory, colors: [String]) async throws -> [BrandPhotoCandidate]
}

enum BrandPhotoProviderError: LocalizedError {
    case invalidBackendURL
    case invalidResponse
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidBackendURL: "Brand photo search is not configured yet."
        case .invalidResponse: "Brand photo search returned an invalid response."
        case .imageUnavailable: "A brand photo could not be loaded. Your cut-out is still available."
        }
    }
}

struct MockBrandPhotoProvider: BrandPhotoProvider {
    var candidates: [BrandPhotoCandidate]
    var shouldFail: Bool = false

    func search(brand: String, category: GarmentCategory, colors: [String]) async throws -> [BrandPhotoCandidate] {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return candidates
    }
}

struct RemoteBrandPhotoProvider: BrandPhotoProvider {
    struct Configuration { let backendURL: URL? }
    let configuration: Configuration
    var session: URLSession = .shared

    private struct Response: Decodable { let candidates: [Candidate] }
    private struct Candidate: Decodable { let imageURL: URL; let sourceURL: URL; let attribution: String }

    func search(brand: String, category: GarmentCategory, colors: [String]) async throws -> [BrandPhotoCandidate] {
        guard var components = URLComponents(url: configuration.backendURL ?? URL(fileURLWithPath: "/"), resolvingAgainstBaseURL: false),
              configuration.backendURL != nil else { throw BrandPhotoProviderError.invalidBackendURL }
        components.queryItems = [URLQueryItem(name: "brand", value: brand), URLQueryItem(name: "category", value: category.displayName),
                                 URLQueryItem(name: "colors", value: colors.joined(separator: ","))]
        guard let url = components.url else { throw BrandPhotoProviderError.invalidBackendURL }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw BrandPhotoProviderError.invalidResponse }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return try await withThrowingTaskGroup(of: BrandPhotoCandidate.self) { group in
            for candidate in decoded.candidates {
                group.addTask {
                    let (imageData, _) = try await session.data(from: candidate.imageURL)
                    guard let image = UIImage(data: imageData) else { throw BrandPhotoProviderError.imageUnavailable }
                    return BrandPhotoCandidate(image: image, sourceURL: candidate.sourceURL, attribution: candidate.attribution)
                }
            }
            var results: [BrandPhotoCandidate] = []
            for try await result in group { results.append(result) }
            return results
        }
    }
}

enum BrandCatalog {
    static let brands = ["Adidas", "Aerie", "American Eagle", "Banana Republic", "Calvin Klein", "Gap", "H&M", "Levi's", "Lululemon", "Nike", "Old Navy", "Puma", "Uniqlo", "Zara"]

    static func suggestions(for query: String) -> [String] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return brands }
        return brands.filter { $0.localizedCaseInsensitiveContains(query) }
    }
}
