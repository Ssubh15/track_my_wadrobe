import AVFoundation
import UIKit

protocol CameraServicing: AnyObject {
    var session: AVCaptureSession { get }
    var authorization: AVAuthorizationStatus { get }
    func requestAccess() async -> Bool
    func start()
    func stop()
    func capturePhoto() async throws -> UIImage
}

enum CameraServiceError: LocalizedError {
    case unavailable
    case captureFailed

    var errorDescription: String? {
        switch self { case .unavailable: "The camera is unavailable on this device."; case .captureFailed: "The photo could not be captured. Please try again." }
    }
}

final class AVCaptureCameraService: NSObject, CameraServicing, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage, Error>?
    private(set) var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    func requestAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorization = AVCaptureDevice.authorizationStatus(for: .video)
        if granted { configureIfNeeded() }
        return granted
    }

    func start() {
        configureIfNeeded()
        if !session.isRunning { session.startRunning() }
    }

    func stop() { if session.isRunning { session.stopRunning() } }

    func capturePhoto() async throws -> UIImage {
        guard session.isRunning else { throw CameraServiceError.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    private func configureIfNeeded() {
        guard session.inputs.isEmpty,
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input), session.canAddOutput(output) else { return }
        session.beginConfiguration()
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { continuation?.resume(throwing: error); continuation = nil; return }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            continuation?.resume(throwing: CameraServiceError.captureFailed); continuation = nil; return
        }
        continuation?.resume(returning: image); continuation = nil
    }
}
