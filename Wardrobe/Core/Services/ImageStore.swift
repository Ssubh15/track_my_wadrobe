import Foundation

protocol ImageStore {
    func savePNG(_ data: Data, for id: UUID) throws
    func loadPNG(for id: UUID) throws -> Data
    func deletePNG(for id: UUID) throws
}

enum ImageStoreError: LocalizedError, Equatable {
    case invalidPNG
    case missingImage

    var errorDescription: String? {
        switch self {
        case .invalidPNG: return "The garment image is not a valid PNG."
        case .missingImage: return "The garment image could not be found."
        }
    }
}

final class FileImageStore: ImageStore {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            self.directory = try fileManager.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("GarmentImages", isDirectory: true)
        }
        try fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func savePNG(_ data: Data, for id: UUID) throws {
        guard data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) else {
            throw ImageStoreError.invalidPNG
        }
        try data.write(to: url(for: id), options: .atomic)
    }

    func loadPNG(for id: UUID) throws -> Data {
        do { return try Data(contentsOf: url(for: id)) }
        catch { throw ImageStoreError.missingImage }
    }

    func deletePNG(for id: UUID) throws {
        let imageURL = url(for: id)
        guard fileManager.fileExists(atPath: imageURL.path) else { return }
        try fileManager.removeItem(at: imageURL)
    }

    private func url(for id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).png") }
}
