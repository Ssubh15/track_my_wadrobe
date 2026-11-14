import AVFoundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

@Observable
@MainActor
final class CaptureViewModel {
    let mode: AddItemMode
    let camera: any CameraServicing
    let qualityChecker: any ImageQualityChecking
    var selectedImage: UIImage?
    private(set) var selectedAssetIdentifier: String?
    var qualityResult: ImageQualityCheckResult?
    var errorMessage: String?
    var isShowingPhotoPicker = false
    var isCameraReady = false

    init(mode: AddItemMode, camera: any CameraServicing = AVCaptureCameraService(), qualityChecker: any ImageQualityChecking = ImageQualityChecker()) {
        self.mode = mode; self.camera = camera; self.qualityChecker = qualityChecker
    }

    func prepareCamera() async {
        switch camera.authorization {
        case .authorized: camera.start(); isCameraReady = true
        case .notDetermined: isCameraReady = await camera.requestAccess(); if isCameraReady { camera.start() }
        default: isCameraReady = false
        }
    }

    func capture() async {
        do {
            let image = try await camera.capturePhoto()
            accept(image, assetIdentifier: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importImage(_ data: Data, assetIdentifier: String? = nil) {
        guard let image = UIImage(data: data) else { errorMessage = "That photo could not be opened."; return }
        accept(image, assetIdentifier: assetIdentifier)
    }

    func accept(_ image: UIImage, assetIdentifier: String? = nil) {
        selectedImage = image
        selectedAssetIdentifier = assetIdentifier
        qualityResult = qualityChecker.check(image)
    }

    func clearQualityResult() { selectedImage = nil; selectedAssetIdentifier = nil; qualityResult = nil }
}

struct CaptureView: View {
    let mode: AddItemMode
    let onImageReady: (UIImage, String?) -> Void
    @State private var viewModel: CaptureViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var qualitySheetData: QualitySheetData?

    init(mode: AddItemMode, camera: any CameraServicing = AVCaptureCameraService(), qualityChecker: any ImageQualityChecking = ImageQualityChecker(), onImageReady: @escaping (UIImage, String?) -> Void) {
        self.mode = mode; self.onImageReady = onImageReady
        _viewModel = State(initialValue: CaptureViewModel(mode: mode, camera: camera, qualityChecker: qualityChecker))
    }

    var body: some View {
        Group {
            if viewModel.isCameraReady {
                cameraContent
            } else if viewModel.camera.authorization == .denied || viewModel.camera.authorization == .restricted {
                CameraPermissionView()
            } else {
                ProgressView("Preparing camera…")
            }
        }
        .task { await viewModel.prepareCamera() }
        .onDisappear { viewModel.camera.stop() }
        .alert("Couldn’t use that photo", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }

    private var cameraContent: some View {
        GeometryReader { geometry in
            CameraPreview(session: viewModel.camera.session)
                .ignoresSafeArea()
                .overlay(alignment: .center) {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .frame(width: max(0, geometry.size.width - Theme.Spacing.large * 2),
                               height: min(geometry.size.height * 0.68, mode == .product ? 420 : 560))
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .top) {
                    Text(mode == .product
                         ? "Fit the whole garment inside the frame"
                         : "Mirror selfie: stand back. Include your full outfit and keep garment edges visible.")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Spacing.medium)
                        .padding(.vertical, Theme.Spacing.small)
                        .background(.black.opacity(0.55), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.medium)
                        .padding(.top, Theme.Spacing.small)
                        .allowsHitTesting(false)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: Theme.Spacing.large) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Import", systemImage: "photo.on.rectangle")
                                .font(.headline)
                                .frame(minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Choose an outfit photo from your library")

                        Button { Task { await viewModel.capture() } } label: {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 66))
                                .symbolRenderingMode(.hierarchical)
                                .frame(minWidth: 72, minHeight: 72)
                        }
                        .accessibilityLabel("Capture outfit photo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.top, Theme.Spacing.small)
                    .padding(.bottom, Theme.Spacing.small)
                    .background(.black.opacity(0.62))
                    .foregroundStyle(.white)
                }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        viewModel.errorMessage = "That photo could not be opened. Choose another photo."
                        return
                    }
                    viewModel.importImage(data, assetIdentifier: item.itemIdentifier)
                } catch {
                    viewModel.errorMessage = "That photo could not be opened. Choose another photo."
                }
            }
        }
        .onChange(of: viewModel.qualityResult) { _, result in
            guard let result, let image = viewModel.selectedImage else {
                qualitySheetData = nil
                return
            }
            qualitySheetData = QualitySheetData(result: result, image: image, assetIdentifier: viewModel.selectedAssetIdentifier)
        }
        .sheet(item: $qualitySheetData, onDismiss: viewModel.clearQualityResult) { data in
            QualityResultView(data: data, onRetake: viewModel.clearQualityResult, onUse: { onImageReady(data.image, data.assetIdentifier) })
        }
    }
}

private struct QualitySheetData: Identifiable {
    let id = UUID()
    let result: ImageQualityCheckResult
    let image: UIImage
    let assetIdentifier: String?

    init(result: ImageQualityCheckResult, image: UIImage, assetIdentifier: String?) {
        self.result = result
        self.image = image
        self.assetIdentifier = assetIdentifier
    }
}

private struct QualityResultView: View {
    let data: QualitySheetData; let onRetake: () -> Void; let onUse: () -> Void
    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(uiImage: data.image).resizable().scaledToFit().frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 12))
            if data.result.isAcceptable { Text("Photo looks good").font(.title2.weight(.semibold)) } else {
                Text("Retake recommended").font(.title2.weight(.semibold))
                ForEach(data.result.issues) { issue in Label { Text("\(issue.title). \(issue.explanation)") } icon: { Image(systemName: "exclamationmark.triangle.fill") }.frame(maxWidth: .infinity, alignment: .leading) }
            }
            PrimaryButton(title: data.result.isAcceptable ? "Use photo" : "Use anyway", action: onUse)
            Button("Retake", action: onRetake).buttonStyle(.bordered)
        }.padding(Theme.Spacing.large).presentationDetents([.medium, .large])
    }
}

private struct CameraPermissionView: View {
    var body: some View { VStack(spacing: Theme.Spacing.medium) { Image(systemName: "camera.fill").font(.largeTitle); Text("Camera access is off").font(.title2.weight(.semibold)); Text("Wardrobe needs camera access to take a garment or outfit photo. Your photo stays on this device.").multilineTextAlignment(.center).foregroundStyle(.secondary); Button("Open Settings") { guard let url = URL(string: UIApplication.openSettingsURLString) else { return }; UIApplication.shared.open(url) }.buttonStyle(.borderedProminent) }.padding(Theme.Spacing.large) }
}

private struct CameraPreview: UIViewRepresentable { let session: AVCaptureSession; func makeUIView(context: Context) -> PreviewView { let view = PreviewView(); view.previewLayer.session = session; view.previewLayer.videoGravity = .resizeAspectFill; return view }; func updateUIView(_ uiView: PreviewView, context: Context) {} }
private final class PreviewView: UIView { override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }; var previewLayer: AVCaptureVideoPreviewLayer { layer as? AVCaptureVideoPreviewLayer ?? AVCaptureVideoPreviewLayer() } }

#Preview("Capture") { CaptureView(mode: .product, onImageReady: { _, _ in }) }
