import Foundation

/// Selects the on-device garment segmentation implementation for outfit photos.
/// Product-photo extraction does not use this setting.
enum OOTDSegmentationMode: Sendable, Equatable {
    case legacy
    case clothSegformer

    static let defaultMode: OOTDSegmentationMode = .clothSegformer

    #if DEBUG
    static var debugMode: OOTDSegmentationMode = defaultMode
    #endif

    static var activeMode: OOTDSegmentationMode {
        #if DEBUG
        debugMode
        #else
        defaultMode
        #endif
    }
}
