# Wardrobe App — Handoff for Claude

Date: 2026-11-14

## What this project is

Wardrobe is an iOS 17+ SwiftUI wardrobe app. It supports:

- Product photo mode: one garment, local Vision/Core ML background removal, mask editing, review, and save.
- Outfit photo mode: local person segmentation, OOTD garment segmentation, garment selection/repair, per-item review, and save.
- SwiftData persistence, local image storage, PhotosUI/AVFoundation capture, Vision, Core Image, and Core ML.

Read `AGENTS.md` and `docs/PRD.md` before making changes. The hard constraints are: preserve the user’s photographed pixels, never invent hidden clothing, process photos on device, do not save faces/bodies in garment images, and do not add third-party packages without approval.

## Repository state

- Remote: `https://github.com/Ssubh15/Wardrobe-app.git`
- Current branch: `codex/product-photo-mode`
- Latest commit: `7a7e113 Fix diagnostics property mutability`
- The working tree was clean when this handoff was created.
- The project uses XcodeGen; generated `.xcodeproj` files are not committed.

The latest diagnostics-related commits are:

1. `8fb3f0a` — Add release outfit diagnostics and image dumps
2. `6b35409` — Fix release diagnostics compile errors
3. `34a0569` — Fix diagnostics release initializer and string errors
4. `7a7e113` — Fix diagnostics property mutability

## Diagnostics work already implemented

Settings now has a Diagnostics section with:

- Outfit segmenter name in use.
- Persisted model load status/error.
- U2NetP loaded/failed status.
- `Save diagnostic images` toggle, off by default.

Outfit extraction results carry:

- `segmenterModelName: String`
- `elapsedSeconds: Double`

The detected-garments screen displays:

`Segmented by: <model name> · <seconds>s`

When diagnostic image saving is enabled, the app writes PNGs under:

`Documents/Diagnostics/<timestamp>/`

The dump includes the original/normalized input, model input, raw class-coloured mask, scaled mask, overlay, and final garment crops. `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are enabled in `project.yml`, so the Documents folder should be visible in Files under Wardrobe.

Model failure is no longer silent: the outfit fallback records the error in `UserDefaults`, and Settings shows it.

## Important files

- `Wardrobe/Core/Services/Outfit/OutfitExtractionPipeline.swift`
  - `OutfitExtractionResult`
  - `OutfitDiagnostics`
  - `OutfitDiagnosticImageWriter`
  - extraction timing and result metadata
- `Wardrobe/Features/OOTD/Segmentation/ClothSegmenter.swift`
  - `ClothLabelMap`
  - OOTD Core ML loading/inference
  - model input and raw mask diagnostic PNG data
- `Wardrobe/Features/AddItem/OutfitMode/Segmentation/ClothSegformerClothingParser.swift`
  - OOTD model/fallback selection and failure recording
- `Wardrobe/Features/AddItem/OutfitMode/OutfitPhotoViews.swift`
  - detected-garments view model and Release-visible caption
- `Wardrobe/Features/Settings/SettingsView.swift`
  - diagnostics UI and toggle
- `Wardrobe/Core/Services/Imaging/BackgroundRemovalService.swift`
  - U2NetP status recording
- `project.yml`
  - model resources and Files-app plist settings
- `.github/workflows/ios.yml`
  - macOS/XcodeGen build, unit tests, Release build, unsigned IPA artifact

## Build and delivery

This environment is Windows-only and cannot run Xcode or Swift/iOS builds. Verification performed here is limited to repository inspection and `git diff --check`.

The GitHub Actions workflow requires a push to `main` or a pull request. It:

1. Unpacks `Models/U2NetP.mlpackage.zip`.
2. Installs XcodeGen.
3. Generates the Xcode project.
4. Builds Debug for a generic iPhone device.
5. Runs `WardrobeTests` on an available iPhone simulator.
6. Builds an unsigned Release app.
7. Packages `Wardrobe.ipa` and uploads the `wardrobe-ipa` artifact.

The current branch is not `main`, so merge or open a PR before expecting the main push workflow. The IPA is unsigned and must be sideloaded with an Apple ID using AltStore, Sideloadly, or a similar tool. See `docs/BUILD.md`.

## Coordinate-system audit already performed

No orientation fix was guessed or changed as part of the diagnostics task. Relevant behavior:

- `MaskImageProcessor.normalizedUpImage` establishes an upright UIKit image first.
- Vision handlers in outfit/person and background removal use `.up` after normalization.
- Vision masks are converted to `CIImage`/`CGImage`, then resized back into the normalized UIKit image space.
- Core Image uses a bottom-left origin; `MaskImageProcessor.result` explicitly converts the top-left foreground bounds before cropping.
- `ClothSegmenter` redraws the normalized source into the 512×512 model buffer and records the exact model input.
- `MirrorDetector` has its own EXIF orientation mapping and should be reviewed separately if mirror behavior is wrong.
- `CGContext` reads in the imaging, mask, fidelity, quality, and debug services were reported but not changed during the orientation investigation.

## Recommended next steps for Claude

1. Open the latest GitHub Actions run or create a PR to force the macOS build.
2. Fix any remaining Swift/Xcode errors from the actual CI log, not from Windows assumptions.
3. Test Release on a physical iPhone and confirm Settings diagnostics update after:
   - successful OOTD model load;
   - forced/missing model failure;
   - U2NetP load/fallback;
   - enabled diagnostic image saving.
4. Download and inspect the diagnostic folder from Files to determine whether the upside-down crop originates before model input, in model output, during mask scaling, or during final cropping.
5. Add/adjust unit tests for any service or view-model changes. Do not change orientation math until the diagnostic images identify the exact stage that flips.

## Transfer notes

After moving accounts, update the GitHub remote and branch protection/Actions settings as needed. Do not copy Apple signing credentials, API keys, or personal Apple ID material into this repository. Keep the model packages and local-only processing behavior intact.
