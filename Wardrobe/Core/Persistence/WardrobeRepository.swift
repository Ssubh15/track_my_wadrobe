import Foundation
import SwiftData

@MainActor
protocol WardrobeRepository {
    func save(_ item: GarmentItem) throws
    func fetchItems(includeArchived: Bool) throws -> [GarmentItem]
    func item(id: UUID) throws -> GarmentItem?
    func delete(_ item: GarmentItem) throws
    func saveDraft(_ draft: DraftItem) throws
    func fetchDrafts() throws -> [DraftItem]
    func deleteDraft(_ draft: DraftItem) throws
}

enum WardrobeRepositoryError: LocalizedError {
    case saveFailed
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed: return "The wardrobe item could not be saved."
        case .fetchFailed: return "The wardrobe could not be loaded."
        }
    }
}

@MainActor
final class SwiftDataWardrobeRepository: WardrobeRepository {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func save(_ item: GarmentItem) throws {
        if item.modelContext == nil { context.insert(item) }
        try context.save()
    }

    func fetchItems(includeArchived: Bool = false) throws -> [GarmentItem] {
        var descriptor = FetchDescriptor<GarmentItem>(sortBy: [SortDescriptor(\GarmentItem.createdAt, order: .reverse)])
        if !includeArchived { descriptor.predicate = #Predicate { !$0.isArchived } }
        return try context.fetch(descriptor)
    }

    func item(id: UUID) throws -> GarmentItem? {
        var descriptor = FetchDescriptor<GarmentItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func delete(_ item: GarmentItem) throws {
        context.delete(item)
        try context.save()
    }

    func saveDraft(_ draft: DraftItem) throws {
        draft.updatedAt = .now
        if draft.modelContext == nil { context.insert(draft) }
        try context.save()
    }

    func fetchDrafts() throws -> [DraftItem] {
        try context.fetch(FetchDescriptor<DraftItem>(sortBy: [SortDescriptor(\DraftItem.updatedAt, order: .reverse)]))
    }

    func deleteDraft(_ draft: DraftItem) throws {
        context.delete(draft)
        try context.save()
    }
}

@MainActor
final class InMemoryWardrobeRepository: WardrobeRepository {
    private(set) var items: [UUID: GarmentItem] = [:]
    private(set) var drafts: [UUID: DraftItem] = [:]

    func save(_ item: GarmentItem) throws { items[item.id] = item }
    func fetchItems(includeArchived: Bool = false) throws -> [GarmentItem] {
        items.values.filter { includeArchived || !$0.isArchived }.sorted { $0.createdAt > $1.createdAt }
    }
    func item(id: UUID) throws -> GarmentItem? { items[id] }
    func delete(_ item: GarmentItem) throws { items.removeValue(forKey: item.id) }
    func saveDraft(_ draft: DraftItem) throws { draft.updatedAt = .now; drafts[draft.id] = draft }
    func fetchDrafts() throws -> [DraftItem] { drafts.values.sorted { $0.updatedAt > $1.updatedAt } }
    func deleteDraft(_ draft: DraftItem) throws { drafts.removeValue(forKey: draft.id) }
}
