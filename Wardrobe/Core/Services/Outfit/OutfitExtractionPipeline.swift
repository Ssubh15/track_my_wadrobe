import Foundation
import UIKit

enum PartialGarmentReason: String, Equatable, Sendable {
    case touchesFrame = "Part of this item is outside the photo frame."
    case occluded = "Part of this item is covered by another garment or object."
}

/// A temporary candidate for review. It is not persisted; saving must use a reviewed garment mask.
struct ExtractedGarment {
    let cutoutImage: UIImage
    let mask: UIImage
    let guessedCategory: GarmentCategory
    let isPartial: Bool
    let partialReason: PartialGarmentReason?
    let confidence: Double
}

struct OutfitExtractionResult {
    let people: [OutfitPerson]
    let selectedPerson: OutfitPerson?
    let garments: [ExtractedGarment]
    let mirrorDetection: MirrorDetection
    let segmenterModelName: String
    let elapsedSeconds: Double

    init(people: [OutfitPerson], selectedPerson: OutfitPerson?, garments: [ExtractedGarment], mirrorDetection: MirrorDetection, segmenterModelName: String = "OOTDClothSegmenter_w8", elapsedSeconds: Double = 0) {
        self.people = people
        self.selectedPerson = selectedPerson
        self.garments = garments
        self.mirrorDetection = mirrorDetection
        self.segmenterModelName = segmenterModelName
        self.elapsedSeconds = elapsedSeconds
    }

    var requiresPersonSelection: Bool { people.count > 1 && selectedPerson == nil }
}

enum OutfitExtractionError: LocalizedError, Equatable {
    case personNotInPhoto
    case noGarmentsDetected
    case unableToCreateCutout

    var errorDescription: String? {
        switch self {
        case .personNotInPhoto: "Choose one of the people detected in this photo."
        case .noGarmentsDetected: "We couldn’t find clear garment candidates. You can try another photo."
        case .unableToCreateCutout: "We couldn’t create a garment cut-out from this photo."
        }
    }
}

protocol OutfitExtracting {
    func extract(from image: UIImage, personIdentifier: Int?) async throws -> OutfitExtractionResult
}

/// Local-only extraction coordinator. It retains neither the source photo nor any result.
struct OutfitExtractionPipeline: OutfitExtracting {
    private let segmenter: any OutfitSegmenter
    private let parser: any ClothingParser
    private let mirrorDetector: any MirrorDetector
    private let maskEditor: any MaskEditing

    init(segmenter: any OutfitSegmenter = VisionOutfitSegmenter(), parser: (any ClothingParser)? = nil, mirrorDetector: any MirrorDetector = VisionMirrorDetector(), maskEditor: any MaskEditing = MaskEditingService()) {
        self.segmenter = segmenter
        let legacyParser = parser ?? StubClothingParser()
        self.parser = parser ?? (OOTDSegmentationMode.activeMode == .clothSegformer ? ClothSegformerClothingParser(legacy: legacyParser) : legacyParser)
        self.mirrorDetector = mirrorDetector
        self.maskEditor = maskEditor
    }

    func extract(from image: UIImage, personIdentifier: Int? = nil) async throws -> OutfitExtractionResult {
        let started = ContinuousClock.now
        // All masks in this pipeline use UIKit's top-left pixel coordinates. Redraw
        // camera/Photos images once so EXIF orientation cannot split that space.
        guard let source = MaskImageProcessor.normalizedUpImage(image) else {
            throw OutfitExtractionError.unableToCreateCutout
        }
        async let peopleTask = segmenter.segmentPeople(in: source)
        async let mirrorTask = mirrorDetector.detect(in: source)
        let people = try await peopleTask
        let mirrorDetection = try await mirrorTask
        let selected = try selectedPerson(from: people, identifier: personIdentifier)

        guard let selected else {
            return OutfitExtractionResult(people: people, selectedPerson: nil, garments: [], mirrorDetection: mirrorDetection, segmenterModelName: OutfitDiagnostics.currentSegmenterName, elapsedSeconds: Self.seconds(started.duration(to: .now)))
        }
        let regions = try await parser.parse(personMask: selected.mask, in: source)
        let garments = try regions.map { region in
            guard let normalizedMask = OutfitMaskRenderer.intersection(of: selected.mask, and: region.mask) else {
                throw OutfitExtractionError.unableToCreateCutout
            }
            let cutout = GarmentCutoutCropper.crop(try maskEditor.makingCutout(from: source, using: normalizedMask), to: normalizedMask)
            let reason = region.occlusionReason ?? (OutfitMaskRenderer.touchesFrame(normalizedMask) ? .touchesFrame : nil)
            return ExtractedGarment(cutoutImage: cutout, mask: normalizedMask, guessedCategory: region.kind.suggestedCategory, isPartial: reason != nil, partialReason: reason, confidence: region.confidence)
        }
        guard !garments.isEmpty else { throw OutfitExtractionError.noGarmentsDetected }
        let result = OutfitExtractionResult(people: people, selectedPerson: selected, garments: garments, mirrorDetection: mirrorDetection, segmenterModelName: OutfitDiagnostics.currentSegmenterName, elapsedSeconds: Self.seconds(started.duration(to: .now)))
        return result
    }

    private static func seconds(_ duration: Duration) -> Double {
        let c = duration.components
        return Double(c.seconds) + Double(c.attoseconds) / 1e18
    }

    private func selectedPerson(from people: [OutfitPerson], identifier: Int?) throws -> OutfitPerson? {
        if let identifier {
            guard let person = people.first(where: { $0.identifier == identifier }) else { throw OutfitExtractionError.personNotInPhoto }
            return person
        }
        if people.count == 1 { return people[0] }
        return nil
    }
}

struct MockOutfitExtractionPipeline: OutfitExtracting {
    var result: OutfitExtractionResult?
    var error: OutfitExtractionError?
    func extract(from image: UIImage, personIdentifier: Int?) async throws -> OutfitExtractionResult {
        if let error { throw error }
        guard let result else { throw OutfitExtractionError.noGarmentsDetected }
        return result
    }
}

enum OutfitDiagnostics {
    static let modelNameKey = "diagnostics.outfitModelName"
    static let modelErrorKey = "diagnostics.outfitModelError"
    static let u2NetStatusKey = "diagnostics.u2NetStatus"
    static var saveDiagnosticImages: Bool { UserDefaults.standard.bool(forKey: "saveDiagnosticImages") }
    static var currentSegmenterName: String { UserDefaults.standard.string(forKey: modelNameKey) ?? "OOTDClothSegmenter_w8" }
    static func recordSegmenterFailure(_ error: Error) {
        UserDefaults.standard.set(error.localizedDescription, forKey: modelErrorKey)
        UserDefaults.standard.set("Vision/legacy fallback", forKey: modelNameKey)
    }
    static func recordSegmenterLoaded() {
        UserDefaults.standard.set("OOTDClothSegmenter_w8", forKey: modelNameKey)
        UserDefaults.standard.removeObject(forKey: modelErrorKey)
    }
}

enum OutfitDiagnosticImageWriter {
    static func write(source: UIImage, garments: [ExtractedGarment]) {
        let fm = FileManager.default
        let root = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Diagnostics", isDirectory: true)
        let folder = root.appendingPathComponent(Self.timestamp(), isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let images: [(String, UIImage)] = [("01_input_original", source), ("02_input_normalized", source)] + garments.enumerated().map { ("07_crop_\($0.offset)_\($0.element.guessedCategory.displayName)", $0.element.cutoutImage) }
        for (name, image) in images { try? image.pngData()?.write(to: folder.appendingPathComponent("\(name).png"), options: .atomic) }
    }
    static func write(source: UIImage, map: ClothLabelMap, items: [OutfitItem]) {
        let fm: FileManager = FileManager.default
        let documents: URL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root: URL = documents.appendingPathComponent("Diagnostics", isDirectory: true)
        let folder: URL = root.appendingPathComponent(timestamp(), isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let normalized: UIImage = MaskImageProcessor.normalizedUpImage(source) ?? source
        let rawMask: UIImage? = UIImage(data: map.rawMaskPNG)
        var scaledMask: UIImage?
        if let rawMask {
            let renderer: UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: normalized.size)
            scaledMask = renderer.image { _ in
                rawMask.draw(in: CGRect(origin: .zero, size: normalized.size))
            }
        }
        var overlay: UIImage?
        if let scaledMask {
            let renderer: UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: normalized.size)
            overlay = renderer.image { _ in
                normalized.draw(in: CGRect(origin: .zero, size: normalized.size))
                scaledMask.draw(in: CGRect(origin: .zero, size: normalized.size), blendMode: .screen, alpha: 0.45)
            }
        }
        var images: [(String, UIImage)] = []
        images.append(("01_input_original", source))
        images.append(("02_input_normalized", normalized))
        if let img: UIImage = UIImage(data: map.modelInputPNG) { images.append(("03_model_input", img)) }
        if let img: UIImage = rawMask { images.append(("04_mask_raw", img)) }
        if let img: UIImage = scaledMask { images.append(("05_mask_scaled", img)) }
        if let img: UIImage = overlay { images.append(("06_mask_overlay", img)) }
        for (index, item) in items.enumerated() {
            let name: String = "07_crop_\(index)_\(item.category.displayName)"
            images.append((name, item.cutoutImage))
        }
        for (name, image) in images {
            try? image.pngData()?.write(to: folder.appendingPathComponent("\(name).png"), options: .atomic)
        }
    }
    private static func timestamp() -> String { ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-") }
}

enum OutfitMaskRenderer {
    static func intersecting(_ mask: UIImage, with rectangle: CGRect) -> UIImage? {
        guard let cgImage = mask.cgImage else { return nil }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.draw(cgImage, in: CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: max(0, rectangle.minY)))
            context.fill(CGRect(x: 0, y: max(0, rectangle.maxY), width: size.width, height: max(0, size.height - rectangle.maxY)))
            context.fill(CGRect(x: 0, y: rectangle.minY, width: max(0, rectangle.minX), height: rectangle.height))
            context.fill(CGRect(x: max(0, rectangle.maxX), y: rectangle.minY, width: max(0, size.width - rectangle.maxX), height: rectangle.height))
        }
    }

    static func intersection(of first: UIImage, and second: UIImage) -> UIImage? {
        guard let firstImage = first.cgImage, let secondImage = second.cgImage else { return nil }
        let size = CGSize(width: firstImage.width, height: firstImage.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.setBlendMode(.multiply)
            context.cgContext.draw(firstImage, in: CGRect(origin: .zero, size: size))
            context.cgContext.draw(secondImage, in: CGRect(origin: .zero, size: size))
        }
    }

    static func touchesFrame(_ mask: UIImage) -> Bool {
        guard let cgImage = mask.cgImage, let bounds = MaskImageProcessor.foregroundBounds(in: cgImage) else { return false }
        return bounds.minX <= 0 || bounds.minY <= 0 || bounds.maxX >= CGFloat(cgImage.width) || bounds.maxY >= CGFloat(cgImage.height)
    }
}
