import Observation
import SwiftUI
import UIKit

@Observable
@MainActor
final class MaskEditorViewModel {
    let original: UIImage
    private let maskEditingService: any MaskEditing
    private var revisions: [UIImage]
    private var revisionIndex = 0
    private var activeStrokeStartMask: UIImage?
    private var lastStrokePoint: CGPoint?

    private(set) var mask: UIImage
    private(set) var preview: UIImage?
    private(set) var errorMessage: String?
    var tool: MaskBrushTool = .erase
    /// Fraction of the shortest mask dimension, so the brush remains useful at every zoom level.
    var brushDiameter: CGFloat = 0.035

    var canUndo: Bool { revisionIndex > 0 }
    var canRedo: Bool { revisionIndex < revisions.count - 1 }
    var brushSizeDescription: String { "\(Int((brushDiameter * 100).rounded()))%" }

    init(original: UIImage, mask: UIImage, maskEditingService: any MaskEditing = MaskEditingService()) {
        self.original = original
        self.mask = mask
        self.maskEditingService = maskEditingService
        revisions = [mask]
        preview = try? maskEditingService.makingCutout(from: original, using: mask)
    }

    func beginStroke(at point: CGPoint) {
        errorMessage = nil
        activeStrokeStartMask = mask
        lastStrokePoint = point
        applyStroke(from: point, to: point)
    }

    func continueStroke(to point: CGPoint) {
        guard let lastStrokePoint else { return }
        applyStroke(from: lastStrokePoint, to: point)
        self.lastStrokePoint = point
    }

    func endStroke() {
        guard let startingMask = activeStrokeStartMask else { return }
        defer {
            activeStrokeStartMask = nil
            lastStrokePoint = nil
        }
        guard startingMask.pngData() != mask.pngData() else { return }
        revisions = Array(revisions.prefix(revisionIndex + 1))
        revisions.append(mask)
        revisionIndex = revisions.count - 1
    }

    func cancelStroke() {
        guard let activeStrokeStartMask else { return }
        mask = activeStrokeStartMask
        refreshPreview()
        self.activeStrokeStartMask = nil
        lastStrokePoint = nil
    }

    func undo() {
        guard canUndo else { return }
        revisionIndex -= 1
        mask = revisions[revisionIndex]
        errorMessage = nil
        refreshPreview()
    }

    func redo() {
        guard canRedo else { return }
        revisionIndex += 1
        mask = revisions[revisionIndex]
        errorMessage = nil
        refreshPreview()
    }

    private func applyStroke(from start: CGPoint, to end: CGPoint) {
        do {
            mask = try maskEditingService.applying(
                MaskBrushStroke(points: [start, end], diameter: brushDiameter, tool: tool),
                to: mask
            )
            refreshPreview()
        } catch {
            errorMessage = error.localizedDescription
            cancelStroke()
        }
    }

    private func refreshPreview() {
        do {
            preview = try maskEditingService.makingCutout(from: original, using: mask)
        } catch {
            preview = nil
            errorMessage = error.localizedDescription
        }
    }
}

/// A reusable editor for repairing Vision masks. It always produces a revised mask, never a redrawn garment.
struct MaskEditorView: View {
    private enum InteractionMode: String, CaseIterable, Identifiable {
        case brush = "Brush"
        case pan = "Pan"

        var id: String { rawValue }
    }

    @State private var viewModel: MaskEditorViewModel
    @State private var interactionMode: InteractionMode = .brush
    @State private var zoom: CGFloat = 1
    @State private var zoomAtGestureStart: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var panAtGestureStart: CGSize = .zero
    @State private var isDrawing = false
    @State private var isZooming = false
    let onCancel: () -> Void
    let onSave: (UIImage) -> Void

    init(
        original: UIImage,
        mask: UIImage,
        maskEditingService: any MaskEditing = MaskEditingService(),
        onCancel: @escaping () -> Void = {},
        onSave: @escaping (UIImage) -> Void
    ) {
        _viewModel = State(initialValue: MaskEditorViewModel(
            original: original,
            mask: mask,
            maskEditingService: maskEditingService
        ))
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Text("Edit the outline, not the garment")
                .font(.subheadline.weight(.semibold))
            Text("Brushes change only the mask. Your photographed pixels are never altered.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            editorCanvas
                .accessibilityLabel("Garment cut-out editor")
                .accessibilityHint(interactionMode == .brush ? "Drag to edit the mask. Pinch to zoom." : "Drag to pan. Pinch to zoom.")

            controls

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Theme.Spacing.large)
        .navigationTitle("Repair outline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onSave(viewModel.mask) }
            }
        }
    }

    private var editorCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                CheckerboardView()
                if let preview = viewModel.preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoom)
                        .offset(panOffset)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
            .gesture(canvasGesture(in: geometry.size))
        }
        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 440)
    }

    @ViewBuilder
    private var controls: some View {
        Picker("Interaction", selection: $interactionMode) {
            ForEach(InteractionMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Choose brush or pan")

        if interactionMode == .brush {
            Picker("Brush tool", selection: $viewModel.tool) {
                ForEach(MaskBrushTool.allCases) { tool in
                    Label(tool.title, systemImage: tool.systemImage).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Choose erase or restore brush")

            HStack {
                Text("Brush size")
                Slider(value: $viewModel.brushDiameter, in: 0.01...0.15, step: 0.005)
                    .accessibilityValue(viewModel.brushSizeDescription)
                Text(viewModel.brushSizeDescription)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }

        HStack(spacing: Theme.Spacing.medium) {
            Button("Undo", systemImage: "arrow.uturn.backward", action: viewModel.undo)
                .disabled(!viewModel.canUndo)
            Button("Redo", systemImage: "arrow.uturn.forward", action: viewModel.redo)
                .disabled(!viewModel.canRedo)
            Spacer()
            Button("Reset view", systemImage: "arrow.counterclockwise") {
                zoom = 1
                zoomAtGestureStart = 1
                panOffset = .zero
                panAtGestureStart = .zero
            }
        }
        .buttonStyle(.bordered)
        .accessibilityElement(children: .contain)
    }

    private func canvasGesture(in size: CGSize) -> some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    isZooming = true
                    zoom = (zoomAtGestureStart * value).clamped(to: 1...6)
                }
                .onEnded { _ in
                    zoomAtGestureStart = zoom
                    isZooming = false
                },
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !isZooming else { return }
                    if interactionMode == .pan {
                        panOffset = CGSize(
                            width: panAtGestureStart.width + value.translation.width,
                            height: panAtGestureStart.height + value.translation.height
                        )
                    } else {
                        if !isDrawing {
                            isDrawing = true
                            viewModel.beginStroke(at: normalizedPoint(value.location, in: size))
                        } else {
                            viewModel.continueStroke(to: normalizedPoint(value.location, in: size))
                        }
                    }
                }
                .onEnded { _ in
                    if interactionMode == .pan {
                        panAtGestureStart = panOffset
                    } else if isDrawing {
                        viewModel.endStroke()
                        isDrawing = false
                    }
                }
        )
    }

    private func normalizedPoint(_ point: CGPoint, in canvasSize: CGSize) -> CGPoint {
        let imageSize = viewModel.original.size
        guard imageSize.width > 0, imageSize.height > 0, canvasSize.width > 0, canvasSize.height > 0 else {
            return .zero
        }
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let displayedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let baseCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let renderedCenter = CGPoint(x: baseCenter.x + panOffset.width, y: baseCenter.y + panOffset.height)
        let unscaledPoint = CGPoint(
            x: baseCenter.x + (point.x - renderedCenter.x) / zoom,
            y: baseCenter.y + (point.y - renderedCenter.y) / zoom
        )
        return CGPoint(
            x: ((unscaledPoint.x - (canvasSize.width - displayedSize.width) / 2) / displayedSize.width).clamped(to: 0...1),
            y: ((unscaledPoint.y - (canvasSize.height - displayedSize.height) / 2) / displayedSize.height).clamped(to: 0...1)
        )
    }
}

private struct CheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 18
            for row in 0...Int((size.height / tile).rounded(.up)) {
                for column in 0...Int((size.width / tile).rounded(.up)) {
                    let color: Color = (row + column).isMultiple(of: 2) ? .gray.opacity(0.18) : .gray.opacity(0.06)
                    context.fill(
                        Path(CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)),
                        with: .color(color)
                    )
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#Preview("Mask editor") {
    NavigationStack {
        MaskEditorView(
            original: ProductPhotoPreviewImage.garment,
            mask: ProductPhotoPreviewImage.garment,
            onSave: { _ in }
        )
    }
}
