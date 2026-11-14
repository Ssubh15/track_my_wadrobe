import Foundation
import Observation

struct InsightRow: Identifiable, Equatable {
    let name: String
    let count: Int
    var id: String { name }
}

/// Computes the Insights numbers from the saved (non-archived) items.
/// Read-only: it only calls `fetchItems` on the existing repository.
@MainActor
@Observable
final class InsightsViewModel {
    nonisolated static let maxRowsPerChart = 6

    private let repository: any WardrobeRepository
    private(set) var totalItems = 0
    private(set) var categoryRows: [InsightRow] = []
    private(set) var colorRows: [InsightRow] = []
    private(set) var brandRows: [InsightRow] = []
    var errorMessage: String?

    init(repository: any WardrobeRepository) {
        self.repository = repository
        reload()
    }

    func reload() {
        do {
            let items = try repository.fetchItems(includeArchived: false)
            totalItems = items.count
            categoryRows = Self.rows(from: items.map { $0.category.displayName })
            colorRows = Self.rows(from: items.compactMap { $0.primaryColorHex.flatMap(Self.colorName(forHex:)) })
            brandRows = Self.rows(from: items.compactMap { item in
                let brand = item.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (brand?.isEmpty == false) ? brand : nil
            })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var summary: String {
        guard totalItems > 0 else { return "" }
        var text = totalItems == 1 ? "1 item." : "\(totalItems) items."
        if let category = categoryRows.first {
            text += " Most are in \(category.name)."
        }
        if let color = colorRows.first {
            text += " \(color.name) is your most common colour."
        }
        return text
    }

    /// Counts the names, sorted from highest to lowest (ties by name), capped per chart.
    nonisolated static func rows(from names: [String], limit: Int = maxRowsPerChart) -> [InsightRow] {
        var counts: [String: Int] = [:]
        for name in names { counts[name, default: 0] += 1 }
        let sorted = counts
            .map { InsightRow(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        return Array(sorted.prefix(limit))
    }

    /// Turns a stored hex colour into a plain colour name. Returns nil if the hex is not valid.
    nonisolated static func colorName(forHex hex: String) -> String? {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        let high = max(red, green, blue)
        let low = min(red, green, blue)
        let delta = high - low
        let lightness = (high + low) / 2
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))

        if lightness < 0.15 { return "Black" }
        if lightness > 0.9 { return "White" }
        if saturation < 0.08 { return "Grey" }

        var hue: Double
        if high == red {
            hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if high == green {
            hue = 60 * ((blue - red) / delta + 2)
        } else {
            hue = 60 * ((red - green) / delta + 4)
        }
        if hue < 0 { hue += 360 }

        switch hue {
        case 15..<45: return lightness < 0.45 ? "Brown" : "Orange"
        case 45..<70: return "Yellow"
        case 70..<170: return "Green"
        case 170..<260: return "Blue"
        case 260..<300: return "Purple"
        case 300..<345: return "Pink"
        default: return "Red"
        }
    }
}
