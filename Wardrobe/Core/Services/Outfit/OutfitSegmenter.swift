import Foundation
import UIKit
import Vision

/// A person and its mask, both expressed in the source image's pixel coordinates.
struct OutfitPerson {
    let identifier: Int
    let mask: UIImage
    let boundingBox: CGRect
}

enum OutfitSegmenterError: LocalizedError, Equatable {
    case unsupportedImage
    case noPeopleDetected
    case unableToCreateMask

    var errorDescription: String? {
        switch self {
        case .unsupportedImage: "This photo format can’t be processed. Try choosing another photo."
        case .noPeopleDetected: "We couldn’t find a person in this photo. Try a clearer outfit photo."
        case .unableToCreateMask: "We couldn’t outline the person in this photo. Try another photo."
        }
    }
}

protocol OutfitSegmenter {
    /// Returns every detected person so the caller can ask the user to choose when needed.
    func segmentPeople(in image: UIImage) async throws -> [OutfitPerson]
}

/// Uses only Apple's on-device Vision person-instance mask. It does not upload the image.
struct VisionOutfitSegmenter: OutfitSegmenter {
    func segmentPeople(in image: UIImage) async throws -> [OutfitPerson] {
        try await Task.detached(priority: .userInitiated) {
            try Self.segmentPeopleSynchronously(in: image)
        }.value
    }

    private static func segmentPeopleSynchronously(in image: UIImage) throws -> [OutfitPerson] {
        guard let source = MaskImageProcessor.normalizedUpImage(image), let cgImage = source.cgImage else {
            throw OutfitSegmenterError.unsupportedImage
        }

        let request = VNGeneratePersonInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw OutfitSegmenterError.noPeopleDetected
        }

        let people = try observation.allInstances.sorted().map { instance in
            let buffer = try observation.generateScaledMaskForImage(forInstances: IndexSet(integer: instance), from: handler)
            let maskImage = CIImage(cvPixelBuffer: buffer)
            // CIContext produces a CGImage whose pixel rows match the Vision buffer;
            // resizeMask redraws that image in UIKit's top-left coordinate system.
            guard let maskCGImage = CIContext().createCGImage(maskImage, from: maskImage.extent),
                  let mask = MaskImageProcessor.resizeMask(UIImage(cgImage: maskCGImage), to: source.size),
                  let bounds = MaskImageProcessor.foregroundBounds(in: mask.cgImage ?? maskCGImage) else {
                throw OutfitSegmenterError.unableToCreateMask
            }
            return OutfitPerson(identifier: instance, mask: mask, boundingBox: bounds)
        }
        return people
    }
}

struct MockOutfitSegmenter: OutfitSegmenter {
    var people: [OutfitPerson] = []
    var error: OutfitSegmenterError?

    func segmentPeople(in image: UIImage) async throws -> [OutfitPerson] {
        if let error { throw error }
        guard !people.isEmpty else { throw OutfitSegmenterError.noPeopleDetected }
        return people
    }
}
