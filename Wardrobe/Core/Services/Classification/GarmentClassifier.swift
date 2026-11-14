import CoreML
import UIKit

struct CategoryPrediction: Equatable, Identifiable, Sendable {
    let category: GarmentCategory
    let confidence: Double

    var id: GarmentCategory { category }
}

protocol GarmentClassifier {
    func classify(_ image: UIImage) async throws -> [CategoryPrediction]
}

enum GarmentClassifierError: LocalizedError, Equatable {
    case unsupportedImage
    case modelUnavailable(String)
    case classificationFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedImage:
            "This garment image can’t be classified. Try another photo."
        case let .modelUnavailable(name):
            "The on-device garment model “\(name)” isn’t installed yet. You can choose a category manually."
        case .classificationFailed:
            "We couldn’t suggest a category. You can choose one manually."
        }
    }
}

struct MockGarmentClassifier: GarmentClassifier {
    let predictions: [CategoryPrediction]

    init(predictions: [CategoryPrediction] = [
        CategoryPrediction(category: .tShirt, confidence: 0.62),
        CategoryPrediction(category: .shirt, confidence: 0.22),
        CategoryPrediction(category: .polo, confidence: 0.10)
    ]) {
        self.predictions = predictions
    }

    func classify(_ image: UIImage) async throws -> [CategoryPrediction] {
        predictions
    }
}

struct CoreMLGarmentClassifier: GarmentClassifier {
    struct Configuration: Sendable {
        let modelName: String

        static let `default` = Configuration(modelName: "GarmentClassifier")
    }

    let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    func classify(_ image: UIImage) async throws -> [CategoryPrediction] {
        guard image.cgImage != nil else { throw GarmentClassifierError.unsupportedImage }

        // TODO: Add the vetted on-device .mlmodelc to Resources/Models and map its
        // output labels to GarmentCategory. No model is bundled until that mapping
        // and its fidelity/latency characteristics have been reviewed.
        guard let modelURL = Bundle.main.url(forResource: configuration.modelName, withExtension: "mlmodelc", subdirectory: "Models") else {
            throw GarmentClassifierError.modelUnavailable(configuration.modelName)
        }

        // Keep the Vision/Core ML integration behind this service. The placeholder
        // above intentionally prevents inventing predictions from an absent model.
        _ = try? MLModel(contentsOf: modelURL)
        throw GarmentClassifierError.classificationFailed
    }
}
