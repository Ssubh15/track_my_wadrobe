import Foundation
import Observation

/// Keeps the user's own category and tag names in UserDefaults.
/// Built-in categories are never stored here and cannot be changed.
@MainActor
@Observable
final class CategoryTagStore {
    static let categoriesKey = "customCategoryNames"
    static let tagsKey = "customTagNames"

    enum StoreError: LocalizedError, Equatable {
        case empty
        case duplicate
        case reserved

        var errorDescription: String? {
            switch self {
            case .empty: return "Enter a name first."
            case .duplicate: return "That name already exists."
            case .reserved: return "That name is used by a built-in category."
            }
        }
    }

    private let defaults: UserDefaults
    private(set) var categories: [String]
    private(set) var tags: [String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.categories = defaults.stringArray(forKey: Self.categoriesKey) ?? []
        self.tags = defaults.stringArray(forKey: Self.tagsKey) ?? []
    }

    /// Read-only access for screens that only need the names, such as the category picker.
    nonisolated static func storedCategories(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: categoriesKey) ?? []
    }

    // MARK: Categories

    @discardableResult
    func addCategory(_ raw: String) throws -> String {
        let name = try validated(raw, existing: categories, checkBuiltIn: true)
        categories.append(name)
        persist()
        return name
    }

    @discardableResult
    func renameCategory(from old: String, to raw: String) throws -> String {
        guard let index = categories.firstIndex(of: old) else { return old }
        let others = categories.enumerated().filter { $0.offset != index }.map(\.element)
        let name = try validated(raw, existing: others, checkBuiltIn: true)
        categories[index] = name
        persist()
        return name
    }

    func removeCategory(_ name: String) {
        categories.removeAll { $0 == name }
        persist()
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
        categories = Self.moved(categories, from: source, to: destination)
        persist()
    }

    // MARK: Tags

    @discardableResult
    func addTag(_ raw: String) throws -> String {
        let name = try validated(raw, existing: tags, checkBuiltIn: false)
        tags.append(name)
        persist()
        return name
    }

    @discardableResult
    func renameTag(from old: String, to raw: String) throws -> String {
        guard let index = tags.firstIndex(of: old) else { return old }
        let others = tags.enumerated().filter { $0.offset != index }.map(\.element)
        let name = try validated(raw, existing: others, checkBuiltIn: false)
        tags[index] = name
        persist()
        return name
    }

    func removeTag(_ name: String) {
        tags.removeAll { $0 == name }
        persist()
    }

    // MARK: Helpers

    private func validated(_ raw: String, existing: [String], checkBuiltIn: Bool) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw StoreError.empty }
        let lowered = name.lowercased()
        if checkBuiltIn {
            let reserved = GarmentCategory.builtIn.map { $0.displayName.lowercased() } + ["__all__", "all"]
            if reserved.contains(lowered) { throw StoreError.reserved }
        }
        if existing.contains(where: { $0.lowercased() == lowered }) { throw StoreError.duplicate }
        return name
    }

    private static func moved(_ list: [String], from source: IndexSet, to destination: Int) -> [String] {
        var result = list
        let moving = source.sorted().map { list[$0] }
        for index in source.sorted(by: >) { result.remove(at: index) }
        let removedBefore = source.filter { $0 < destination }.count
        let insertAt = max(0, min(result.count, destination - removedBefore))
        result.insert(contentsOf: moving, at: insertAt)
        return result
    }

    private func persist() {
        defaults.set(categories, forKey: Self.categoriesKey)
        defaults.set(tags, forKey: Self.tagsKey)
    }
}
