import Photos

protocol OriginalOutfitPhotoDeleting {
    func deletePhoto(assetIdentifier: String) async throws
}

enum OriginalOutfitPhotoDeletionError: LocalizedError {
    case unavailable
    case notFound

    var errorDescription: String? {
        switch self {
        case .unavailable: "Wardrobe couldn’t remove the original photo from your library."
        case .notFound: "The original photo is no longer available in your library."
        }
    }
}

/// Deletes only the user-selected Photos asset, after extraction. Camera photos are never added to the library by Wardrobe.
struct PhotosOriginalOutfitPhotoDeleter: OriginalOutfitPhotoDeleting {
    func deletePhoto(assetIdentifier: String) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { throw OriginalOutfitPhotoDeletionError.unavailable }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = assets.firstObject else { throw OriginalOutfitPhotoDeletionError.notFound }
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.deleteAssets([asset] as NSArray) }) { success, error in
                if success { continuation.resume() }
                else { continuation.resume(throwing: error ?? OriginalOutfitPhotoDeletionError.unavailable) }
            }
        }
    }
}

struct MockOriginalOutfitPhotoDeleter: OriginalOutfitPhotoDeleting {
    var error: Error?
    func deletePhoto(assetIdentifier: String) async throws { if let error { throw error } }
}
