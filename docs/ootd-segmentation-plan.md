# OOTD clothing segmentation plan

## PROTECTED – DO NOT MODIFY

These files implement the existing single-item product-photo extraction flow or shared helpers it depends on. Keep them byte-for-byte unchanged while adding OOTD segmentation. If OOTD needs helper behavior from one of these files, copy the needed logic into a new file under `Wardrobe/Features/AddItem/OutfitMode/Segmentation/`.

- `Wardrobe/Features/AddItem/ProductMode/ProductPhotoProcessingView.swift` — product-photo processing and review state.
- `Wardrobe/Features/AddItem/Capture/CaptureView.swift` — shared capture and image-quality checking entry used by product photos.
- `Wardrobe/Features/AddItem/Capture/CameraService.swift` — shared camera implementation.
- `Wardrobe/Features/AddItem/Shared/MaskEditorView.swift` — shared mask repair UI and mask-editing helper use.
- `Wardrobe/Core/Services/Imaging/BackgroundRemovalService.swift` — product cut-out implementations and shared mask image processor.
- `Wardrobe/Core/Services/Imaging/MaskEditingService.swift` — shared mask and cut-out editing.
- `Wardrobe/Core/Services/Imaging/ImageEnhancementService.swift` — product enhancement.
- `Wardrobe/Core/Services/Imaging/FidelityChecker.swift` — product fidelity checks.
- `Wardrobe/Core/Services/Imaging/ImageQualityChecker.swift` — shared capture quality checks.
- `Wardrobe/App/DIContainer.swift` — constructs and injects product extraction services.

The inventory is enforced by `scripts/check_protected_files.sh` and its SHA-256 manifest at `scripts/protected_files.sha256`.

## Current OOTD flow

1. `AddItemEntryView` presents `OutfitCaptureView` (or shared `CaptureView`) and routes the captured/imported photo to `.outfitProcessing` through `AddItemFlowCoordinator.showNextStep`.
2. `OutfitProcessingView` runs `OutfitProcessingViewModel.process()`, which calls the injected `OutfitExtracting` pipeline (`DIContainer.outfitExtractionPipeline`). The source outfit photo remains in memory during processing.
3. `OutfitExtractionPipeline.extract` concurrently calls `OutfitSegmenter.segmentPeople` and `MirrorDetector.detect`. The default `VisionOutfitSegmenter` uses the on-device Vision person-instance mask. For multiple people, the UI asks the user to choose one.
4. For the selected person, the pipeline calls `ClothingParser.parse(personMask:in:)`. Today the default `StubClothingParser` divides the person mask into broad height bands. For each region, the pipeline intersects its mask with the selected person's mask and uses `MaskEditing.makingCutout(from:using:)` to create a source-pixel cut-out.
5. The result is `OutfitExtractionResult`, containing people, the selected person, mirror detection, and `[ExtractedGarment]`. Each garment carries `cutoutImage`, `mask`, `guessedCategory`, partial-item metadata, and confidence. `DetectedGarmentsViewModel` turns these into selectable candidates, allows mask repair, then the review flow saves each selected `cutoutImage` with its `guessedCategory` as the initial category.

### Single plug-in point

The new model belongs behind the existing `ClothingParser` protocol at the `parser.parse(personMask:in:)` call in `OutfitExtractionPipeline.extract`. Implement the `.clothSegformer` parser in a new file under `Wardrobe/Features/AddItem/OutfitMode/Segmentation/`; leave person selection and the product-photo pipeline untouched. The `.legacy` mode continues using the existing parser. `OOTDSegmentationMode.defaultMode` is `.legacy`, so merely adding the flag does not change runtime behavior.

## OOTD output contract

The parser must produce source-aligned garment regions whose masks are constrained to the supplied person mask. The pipeline must continue providing an `OutfitExtractionResult` with an `ExtractedGarment` for every candidate, including:

- `cutoutImage`: a cut-out made from the user's original outfit-photo pixels using the final mask; no generated or redrawn garment pixels.
- `mask`: source-aligned garment mask, intersected with the selected person's mask.
- `guessedCategory`: a `GarmentCategory` used as the initial category in the next review/save steps.
- `isPartial`, `partialReason`, and `confidence`: existing review metadata.

Downstream review expects the pair of item image (`cutoutImage`) and category (`guessedCategory`) per selected garment; the surrounding result and metadata must remain compatible with the current flow.
