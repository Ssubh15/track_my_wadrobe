import Foundation
import SwiftData

enum GarmentCategory: Codable, Equatable, Hashable, Sendable {
    case tShirt
    case shirt
    case polo
    case hoodie
    case sweater
    case jacket
    case pants
    case trousers
    case jeans
    case shorts
    case skirt
    case dress
    case shoes
    case accessory
    case other
    case custom(String)

    var displayName: String {
        switch self {
        case .tShirt: return "T-shirt"
        case .shirt: return "Shirt"
        case .polo: return "Polo"
        case .hoodie: return "Hoodie"
        case .sweater: return "Sweater"
        case .jacket: return "Jacket"
        case .pants: return "Pants"
        case .trousers: return "Trousers"
        case .jeans: return "Jeans"
        case .shorts: return "Shorts"
        case .skirt: return "Skirt"
        case .dress: return "Dress"
        case .shoes: return "Shoes"
        case .accessory: return "Accessory"
        case .other: return "Other"
        case let .custom(value): return value
        }
    }

    static var builtIn: [GarmentCategory] {
        [.tShirt, .shirt, .polo, .hoodie, .sweater, .jacket, .pants, .trousers,
         .jeans, .shorts, .skirt, .dress, .shoes, .accessory, .other]
    }
}

enum ImageSource: String, Codable, CaseIterable, Sendable {
    case productPhoto
    case outfitPhoto
    case brandPhoto
}

@Model
final class GarmentItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var category: GarmentCategory
    var subtype: String?
    var primaryColorHex: String?
    var secondaryColorHexes: [String]
    var pattern: String?
    var sleeveLength: String?
    var fit: String?
    var season: String?
    var material: String?
    var size: String?
    var brand: String?
    var price: Decimal?
    var purchaseDate: Date?
    var notes: String?
    var tags: [String]
    var isFavorite: Bool
    var isArchived: Bool
    var imageSource: ImageSource
    var cutoutImagePath: String
    var originalImagePath: String?
    var sourceGroupID: UUID?
    var isPartial: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        category: GarmentCategory = .other,
        subtype: String? = nil,
        primaryColorHex: String? = nil,
        secondaryColorHexes: [String] = [],
        pattern: String? = nil,
        sleeveLength: String? = nil,
        fit: String? = nil,
        season: String? = nil,
        material: String? = nil,
        size: String? = nil,
        brand: String? = nil,
        price: Decimal? = nil,
        purchaseDate: Date? = nil,
        notes: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false,
        isArchived: Bool = false,
        imageSource: ImageSource = .productPhoto,
        cutoutImagePath: String,
        originalImagePath: String? = nil,
        sourceGroupID: UUID? = nil,
        isPartial: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.category = category
        self.subtype = subtype
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHexes = secondaryColorHexes
        self.pattern = pattern
        self.sleeveLength = sleeveLength
        self.fit = fit
        self.season = season
        self.material = material
        self.size = size
        self.brand = brand
        self.price = price
        self.purchaseDate = purchaseDate
        self.notes = notes
        self.tags = tags
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.imageSource = imageSource
        self.cutoutImagePath = cutoutImagePath
        self.originalImagePath = originalImagePath
        self.sourceGroupID = sourceGroupID
        self.isPartial = isPartial
    }
}

@Model
final class DraftItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var category: GarmentCategory
    var subtype: String?
    var primaryColorHex: String?
    var secondaryColorHexes: [String]
    var pattern: String?
    var sleeveLength: String?
    var fit: String?
    var season: String?
    var material: String?
    var size: String?
    var brand: String?
    var price: Decimal?
    var purchaseDate: Date?
    var notes: String?
    var tags: [String]
    var imageSource: ImageSource
    var cutoutImagePath: String?
    var originalImagePath: String?
    var sourceGroupID: UUID?
    var isPartial: Bool

    init(id: UUID = UUID(), createdAt: Date = .now, updatedAt: Date = .now,
         category: GarmentCategory = .other, imageSource: ImageSource = .productPhoto) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
        self.subtype = nil
        self.primaryColorHex = nil
        self.secondaryColorHexes = []
        self.pattern = nil
        self.sleeveLength = nil
        self.fit = nil
        self.season = nil
        self.material = nil
        self.size = nil
        self.brand = nil
        self.price = nil
        self.purchaseDate = nil
        self.notes = nil
        self.tags = []
        self.imageSource = imageSource
        self.cutoutImagePath = nil
        self.originalImagePath = nil
        self.sourceGroupID = nil
        self.isPartial = false
    }
}
