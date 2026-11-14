#if DEBUG
import SwiftUI

#if DEBUG
import CoreGraphics
import CoreVideo
import Darwin
import Foundation
import ImageIO
import Observation
import PhotosUI
import UIKit

private struct OOTDDebugInput: Identifiable {
    let id: String
    let title: String
    let image: UIImage
    let goldenName: String?
}

private struct OOTDDebugResult: Identifiable {
    let id: String
    let title: String
    let original: UIImage
    let overlay: UIImage
    let items: [OutfitItem]
    let inferenceMs: Double
    let postProcessingMs: Double
    let agreement: Double?
    let error: String?
}

@Observable
@MainActor
private final class OOTDSegmentationDebugViewModel {
    private(set) var results: [OOTDDebugResult] = []
    private(set) var isRunning = false
    private(set) var progress = ""
    private(set) var error: String?
    private(set) var deviceModel = OOTDSegmentationDebugViewModel.deviceIdentifier
    private(set) var computeUnits = "All available (CPU, GPU, Neural Engine)"
    var selectedPhoto: PhotosPickerItem?

    private let segmenter = ClothSegmenter()
    private let extractor = OutfitItemExtractor()

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ootd-debug-preview") {
            results = [Self.previewResult]
        }
        #endif
    }

    private static var deviceIdentifier: String {
        var system = utsname()
        uname(&system)
        let machine = system.machine
        let capacity = MemoryLayout.size(ofValue: machine)
        return withUnsafeBytes(of: machine) { bytes in
            String(decoding: bytes.prefix(capacity).prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    private static var previewResult: OOTDDebugResult {
        let image = UIImage(systemName: "tshirt") ?? UIImage()
        return OOTDDebugResult(id: "preview", title: "Preview image", original: image, overlay: image,
                               items: [], inferenceMs: 42.7, postProcessingMs: 8.3, agreement: 0.982, error: nil)
    }

    var averageInferenceMs: Double? {
        let values = results.map(\.inferenceMs).filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var maxInferenceMs: Double? { results.map(\.inferenceMs).filter { $0 > 0 }.max() }

    func runBundledImages() async {
        let inputs = Self.bundledInputs()
        guard !inputs.isEmpty else {
            error = "No OOTD test images are bundled. Build the Debug target after staging the evaluation assets."
            return
        }
        await run(inputs)
    }

    func addLibraryPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                error = "That photo could not be loaded. Choose another image."
                return
            }
            let input = OOTDDebugInput(id: UUID().uuidString, title: "Photo Library", image: image, goldenName: nil)
            await run([input], appending: true)
        } catch {
            self.error = "That photo could not be loaded: \(error.localizedDescription)"
        }
    }

    private func run(_ inputs: [OOTDDebugInput], appending: Bool = false) async {
        guard !isRunning else { return }
        isRunning = true
        error = nil
        if !appending { results = [] }
        computeUnits = await segmenter.computeUnitsDescription()
        let device = ProcessInfo.processInfo.operatingSystemVersion
        deviceModel = "\(Self.deviceIdentifier) · iOS \(device.majorVersion).\(device.minorVersion).\(device.patchVersion)"
        defer { isRunning = false; progress = "" }

        for (index, input) in inputs.enumerated() {
            progress = "Analyzing \(index + 1) of \(inputs.count): \(input.title)"
            do {
                let labelMap = try await segmenter.segment(input.image)
                let postStart = ContinuousClock.now
                let items = extractor.extract(from: labelMap, image: input.image)
                let overlay = Self.overlay(for: labelMap)
                let agreement = input.goldenName.flatMap { Self.agreement(for: labelMap, goldenName: $0) }
                let duration = postStart.duration(to: .now).components
                let postMs = Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
                results.append(OOTDDebugResult(id: input.id, title: input.title, original: input.image, overlay: overlay,
                                               items: items, inferenceMs: labelMap.inferenceMs, postProcessingMs: postMs,
                                               agreement: agreement, error: nil))
            } catch {
                results.append(OOTDDebugResult(id: input.id, title: input.title, original: input.image, overlay: input.image,
                                               items: [], inferenceMs: 0, postProcessingMs: 0, agreement: nil,
                                               error: error.localizedDescription))
            }
        }
    }

    var shareReport: String {
        var lines = ["OOTD Segmentation Debug Report", "Device: \(deviceModel)", "Compute units: \(computeUnits)",
                     "Average inference: \(averageInferenceMs.map { String(format: "%.1f ms", $0) } ?? "—")",
                     "Maximum inference: \(maxInferenceMs.map { String(format: "%.1f ms", $0) } ?? "—")", ""]
        lines += results.map { result in
            var line = "\(result.title): inference \(String(format: "%.1f", result.inferenceMs)) ms, post-processing \(String(format: "%.1f", result.postProcessingMs)) ms, items \(result.items.count)"
            if let agreement = result.agreement { line += String(format: ", pixel agreement %.2f%%%@", agreement * 100, agreement < 0.97 ? " (BELOW 97%)" : "") }
            if let error = result.error { line += ", ERROR: \(error)" }
            return line
        }
        return lines.joined(separator: "\n")
    }

    private static func bundledInputs() -> [OOTDDebugInput] {
        let folder = Bundle.main.resourceURL?.appendingPathComponent("OOTDTestImages", isDirectory: true)
        let urls = folder.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) } ?? []
        let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "webp"]
        let imageURLs = urls.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        return imageURLs.compactMap { url in
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            let goldenName = url.deletingPathExtension().lastPathComponent + ".png"
            return OOTDDebugInput(id: url.lastPathComponent, title: url.lastPathComponent, image: image, goldenName: goldenName)
        }
    }

    private static func agreement(for map: ClothLabelMap, goldenName: String) -> Double? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("golden", isDirectory: true).appendingPathComponent(goldenName),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil).flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) else { return nil }
        let width = map.width
        let height = map.height
        guard source.width == width, source.height == height,
              let providerData = source.dataProvider?.data,
              let sourceBytes = CFDataGetBytePtr(providerData),
              source.bitsPerComponent == 8,
              source.colorSpace?.model == .monochrome else { return nil }
        let bytesPerPixel = source.bitsPerPixel / 8
        guard bytesPerPixel > 0 else { return nil }
        let bytesPerRow = source.bytesPerRow
        let matches = map.labels.indices.reduce(into: 0) { count, index in
            let offset = (index / width) * bytesPerRow + (index % width) * bytesPerPixel
            if map.labels[index] == sourceBytes[offset] { count += 1 }
        }
        return Double(matches) / Double(map.labels.count)
    }

    private static func overlay(for map: ClothLabelMap) -> UIImage {
        let colors: [(UInt8, UInt8, UInt8)] = [(0, 0, 0), (230, 25, 75), (245, 130, 48), (255, 225, 25),
            (60, 180, 75), (145, 30, 180), (70, 240, 240), (240, 50, 230), (210, 245, 60), (250, 190, 212),
            (0, 128, 128), (220, 190, 255), (170, 110, 40), (255, 250, 200), (128, 0, 0), (170, 255, 195),
            (128, 128, 0), (255, 215, 180)]
        let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: map.labels.count * 4)
        pixels.initialize(repeating: 0, count: map.labels.count * 4)
        defer { pixels.deallocate() }
        for index in map.labels.indices {
            let label = Int(map.labels[index])
            guard label > 0, label < colors.count else { continue }
            let color = colors[label]
            pixels[index * 4] = color.0
            pixels[index * 4 + 1] = color.1
            pixels[index * 4 + 2] = color.2
            pixels[index * 4 + 3] = 115
        }
        guard let context = CGContext(data: pixels, width: map.width, height: map.height, bitsPerComponent: 8,
                                      bytesPerRow: map.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
              let image = context.makeImage() else { return UIImage() }
        return UIImage(cgImage: image)
    }
}

struct OOTDSegmentationDebugView: View {
    @State private var viewModel = OOTDSegmentationDebugViewModel()
    var body: some View {
        #if DEBUG
        List {
            Section("Device") {
                LabeledContent("Model", value: viewModel.deviceModel)
                LabeledContent("Compute units", value: viewModel.computeUnits)
                LabeledContent("Average inference", value: viewModel.averageInferenceMs.map { String(format: "%.1f ms", $0) } ?? "—")
                LabeledContent("Maximum inference", value: viewModel.maxInferenceMs.map { String(format: "%.1f ms", $0) } ?? "—")
            }
            Section("Run") {
                Button { Task { await viewModel.runBundledImages() } } label: {
                    Label("Run all bundled test images", systemImage: "play.fill")
                }
                .disabled(viewModel.isRunning)
                PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                    Label("Choose a photo from Library", systemImage: "photo")
                }
                if viewModel.isRunning { ProgressView(viewModel.progress) }
                if !viewModel.results.isEmpty {
                    ShareLink(item: viewModel.shareReport) { Label("Share report", systemImage: "square.and.arrow.up") }
                }
            }
            if let error = viewModel.error { Section("Issue") { Text(error).foregroundStyle(.red) } }
            ForEach(viewModel.results) { result in
                Section(result.title) {
                    imageRow("Original", result.original)
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: result.original).resizable().scaledToFit()
                        Image(uiImage: result.overlay).resizable().scaledToFit()
                    }
                    .accessibilityLabel("Colored segmentation label overlay")
                    if !result.items.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(Array(result.items.enumerated()), id: \.offset) { index, item in
                                    VStack(alignment: .leading) {
                                        CheckerboardCutoutView(image: item.cutoutImage)
                                        Text(item.category.displayName).font(.caption.weight(.semibold))
                                    }
                                    .frame(width: 145)
                                    .accessibilityLabel("Extracted \(item.category.displayName) cutout \(index + 1)")
                                }
                            }
                        }
                    } else if result.error == nil {
                        Text("No garment cutouts extracted.").foregroundStyle(.secondary)
                    }
                    LabeledContent("Inference", value: String(format: "%.1f ms", result.inferenceMs))
                    LabeledContent("Post-processing", value: String(format: "%.1f ms", result.postProcessingMs))
                    if let agreement = result.agreement {
                        LabeledContent("Pixel agreement", value: String(format: "%.2f%%", agreement * 100))
                            .foregroundStyle(agreement < 0.97 ? .red : .primary)
                        if agreement < 0.97 { Label("Below 97% target", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                    } else if result.error == nil {
                        Text("No matching golden PNG.").font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = result.error { Text(error).foregroundStyle(.red) }
                }
            }
        }
        .navigationTitle("OOTD Segmentation")
        .task { if viewModel.results.isEmpty { await viewModel.runBundledImages() } }
        .onChange(of: viewModel.selectedPhoto) { _, item in
            guard let item else { return }
            Task { await viewModel.addLibraryPhoto(item); viewModel.selectedPhoto = nil }
        }
        #else
        ContentUnavailableView("Debug only", systemImage: "ladybug", description: Text("This screen is available in Debug builds."))
        #endif
    }

    @ViewBuilder
    private func imageRow(_ title: String, _ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold))
            Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct CheckerboardCutoutView: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity).padding(8)
            .background(Checkerboard().clipShape(RoundedRectangle(cornerRadius: 8)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
}

private struct Checkerboard: View {
    private let cell: CGFloat = 12
    var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            for row in 0..<rows { for column in 0..<columns where (row + column).isMultiple(of: 2) {
                context.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)), with: .color(.gray.opacity(0.18)))
            } }
        }
    }
}

#Preview("OOTD segmentation debug") {
    NavigationStack { OOTDSegmentationDebugView() }
}
#endif
#endif
