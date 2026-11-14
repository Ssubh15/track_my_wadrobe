import Foundation
import Observation
import UIKit

enum WardrobeSection: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"
    case archived = "Archived"

    var id: String { rawValue }
}

enum WardrobeSort: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently added"
    case oldest = "Oldest first"
    case name = "Name"

    var id: String { rawValue }
}

struct WardrobeFilters: Equatable {
    var category: GarmentCategory?
    var color: String?
    var brand: String?
    var season: String?
    var favoritesOnly = false
    var recentlyAdded = false

    var isActive: Bool {
        category != nil || color != nil || brand != nil || season != nil || favoritesOnly || recentlyAdded
    }
}

@MainActor
@Observable
final class WardrobeViewModel {
    let repository: any WardrobeRepository
    private let imageStore: (any ImageStore)?
    private(set) var items: [GarmentItem] = []
    private(set) var itemImages: [UUID: UIImage] = [:]
    var searchText = ""
    var selectedCategory: GarmentCategory?
    var filters = WardrobeFilters(category: nil, color: nil, brand: nil, season: nil)
    var sort: WardrobeSort = .recentlyAdded
    var section: WardrobeSection = .all
    var selectedIDs: Set<UUID> = []
    var isSelectMode = false
    var errorMessage: String?

    init(repository: any WardrobeRepository, imageStore: (any ImageStore)? = nil) {
        self.repository = repository
        self.imageStore = imageStore
        reload()
    }

    var categories: [GarmentCategory] {
        [.allCategory] + Array(Set(items.map(\.category))).sorted { $0.displayName < $1.displayName }
    }

    var filteredItems: [GarmentItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let result = items.filter { item in
            guard (section == .archived ? item.isArchived : !item.isArchived) else { return false }
            if section == .favorites && !item.isFavorite { return false }
            if let selectedCategory, selectedCategory != .allCategory, item.category != selectedCategory { return false }
            if let category = filters.category, item.category != category { return false }
            if let color = filters.color, item.primaryColorHex != color { return false }
            if let brand = filters.brand, item.brand != brand { return false }
            if let season = filters.season, item.season != season { return false }
            if filters.favoritesOnly && !item.isFavorite { return false }
            if filters.recentlyAdded, let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now), item.createdAt < cutoff { return false }
            guard !query.isEmpty else { return true }
            return [item.category.displayName, item.brand, item.subtype, item.notes, item.tags.joined(separator: " ")]
                .compactMap { $0?.lowercased() }.contains { $0.contains(query) }
        }
        switch sort {
        case .recentlyAdded: return result.sorted { $0.createdAt > $1.createdAt }
        case .oldest: return result.sorted { $0.createdAt < $1.createdAt }
        case .name: return result.sorted { ($0.subtype ?? $0.category.displayName) < ($1.subtype ?? $1.category.displayName) }
        }
    }

    func reload() {
        do {
            items = try repository.fetchItems(includeArchived: true)
            itemImages = Dictionary(uniqueKeysWithValues: items.compactMap { item in
                guard let imageStore, let data = try? imageStore.loadPNG(for: item.id), let image = UIImage(data: data) else { return nil }
                return (item.id, image)
            })
        }
        catch { errorMessage = error.localizedDescription }
    }

    func toggleFavorite(_ item: GarmentItem) { item.isFavorite.toggle(); save(item) }
    func saveChanges(_ item: GarmentItem) { save(item) }
    func toggleArchive(_ item: GarmentItem) { item.isArchived.toggle(); save(item) }
    func delete(_ item: GarmentItem) { do { try repository.delete(item); reload() } catch { errorMessage = error.localizedDescription } }
    func duplicate(_ item: GarmentItem) {
        let copy = GarmentItem(createdAt: .now, category: item.category, subtype: item.subtype, primaryColorHex: item.primaryColorHex,
                               secondaryColorHexes: item.secondaryColorHexes, pattern: item.pattern, sleeveLength: item.sleeveLength,
                               fit: item.fit, season: item.season, material: item.material, size: item.size, brand: item.brand,
                               price: item.price, purchaseDate: item.purchaseDate, notes: item.notes, tags: item.tags,
                               imageSource: item.imageSource, cutoutImagePath: item.cutoutImagePath, originalImagePath: item.originalImagePath,
                               isPartial: item.isPartial)
        save(copy)
    }
    func toggleSelection(_ item: GarmentItem) { selectedIDs.toggleMembership(item.id) }
    func clearSelection() { selectedIDs.removeAll(); isSelectMode = false }
    func deleteSelected() { selectedItems.forEach { try? repository.delete($0) }; reload(); clearSelection() }
    func archiveSelected() { selectedItems.forEach { $0.isArchived = true; try? repository.save($0) }; reload(); clearSelection() }
    func seedSampleItems() {
        let samples: [(GarmentCategory, String, String, String)] = [(.tShirt, "White tee", "#F4F1EA", "Basics"), (.jeans, "Straight-leg jeans", "#4A6A8A", "Denim Co."), (.jacket, "Olive overshirt", "#66705A", "Field Notes"), (.dress, "Black midi dress", "#191919", "Atelier")]
        for (category, name, color, brand) in samples { save(GarmentItem(category: category, subtype: name, primaryColorHex: color, season: "All season", brand: brand, cutoutImagePath: "debug-placeholder")) }
    }

    var selectedItems: [GarmentItem] { items.filter { selectedIDs.contains($0.id) } }
    var availableColors: [String] { Array(Set(items.compactMap(\.primaryColorHex))).sorted() }
    var availableBrands: [String] { Array(Set(items.compactMap(\.brand))).sorted() }
    var availableSeasons: [String] { Array(Set(items.compactMap(\.season))).sorted() }

    private func save(_ item: GarmentItem) { do { try repository.save(item); reload() } catch { errorMessage = error.localizedDescription } }
}

private extension Set where Element == UUID {
    mutating func toggleMembership(_ value: UUID) { if contains(value) { remove(value) } else { insert(value) } }
}

extension GarmentCategory {
    static let allCategory = GarmentCategory.custom("__all__")
}
