import Foundation

/// Fixes a common segmentation error on dark, same-coloured outfits
/// (e.g. black top + black trousers): the model labels the front of the top
/// as trousers, so the top loses its middle and the trousers gain a torso.
///
/// The waistline is estimated as the lowest row where "upper clothes" still
/// covers the body's centre line (measured from the trouser legs). Any
/// trouser/skirt pixels above that row are reassigned to the top.
/// Only labels change; no pixels are generated.
enum TorsoLabelCorrector {
    static func correct(_ labels: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard width > 0, height > 0, labels.count == width * height else { return labels }
        let upper = ClothClass.upperClothes.rawValue
        let bottoms: Set<UInt8> = [ClothClass.pants.rawValue, ClothClass.skirt.rawValue]

        // Vertical extent of the bottom garment.
        var bottomMinY = height, bottomMaxY = -1
        for index in labels.indices where bottoms.contains(labels[index]) {
            let y = index / width
            bottomMinY = min(bottomMinY, y)
            bottomMaxY = max(bottomMaxY, y)
        }
        guard bottomMaxY >= 0 else { return labels }
        let bottomHeight = bottomMaxY - bottomMinY + 1

        // Body centre line from the lower half of the bottom garment (the legs),
        // which the model rarely confuses with the top.
        let legsStartY = bottomMinY + bottomHeight / 2
        var legsMinX = width, legsMaxX = -1
        for y in legsStartY...bottomMaxY {
            for x in 0..<width where bottoms.contains(labels[y * width + x]) {
                legsMinX = min(legsMinX, x)
                legsMaxX = max(legsMaxX, x)
            }
        }
        guard legsMaxX >= legsMinX else { return labels }
        let centerX = (legsMinX + legsMaxX) / 2
        let halfBand = max(2, (legsMaxX - legsMinX) / 4)
        let band = max(0, centerX - halfBand)...min(width - 1, centerX + halfBand)

        // Waistline: lowest row where the top still covers the centre band.
        var waistY = -1
        for y in stride(from: height - 1, through: 0, by: -1) {
            if band.contains(where: { labels[y * width + $0] == upper }) { waistY = y; break }
        }

        // Only act when the top overlaps the upper part of the bottoms. If it reaches
        // past half-way down, it is likely a long top or tunic, so leave it alone.
        guard waistY > bottomMinY, waistY < bottomMinY + bottomHeight / 2 else { return labels }

        var corrected = labels
        for y in bottomMinY...waistY {
            for x in 0..<width where bottoms.contains(corrected[y * width + x]) {
                corrected[y * width + x] = upper
            }
        }
        return corrected
    }
}
