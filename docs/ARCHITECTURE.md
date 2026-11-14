# Wardrobe Architecture

This document describes the implementation plan for the iOS 17+ Wardrobe app. It is intentionally planning-level: no app source or generated Xcode project is defined here.

## Folder layout

```text
Wardrobe/
├── App/
│   ├── WardrobeApp.swift
│   ├── DIContainer.swift
│   └── AppEnvironment.swift
├── Core/
│   ├── Models/
│   ├── Persistence/
│   ├── Services/
│   │   ├── Imaging/
│   │   ├── Classification/
│   │   ├── Outfit/
│   │   └── BrandLookup/
│   └── Utilities/
├── Features/
│   ├── Onboarding/
│   ├── AddItem/
│   │   ├── Entry/
│   │   ├── Capture/
│   │   ├── ProductMode/
│   │   ├── OutfitMode/
│   │   └── Shared/
│   ├── Wardrobe/
│   ├── Insights/
│   └── Settings/
├── DesignSystem/Components/
└── Resources/
    ├── Assets.xcassets
    └── Models/
```

Each feature owns its screens and view models. Views render state and send user intents; they do not perform persistence, Vision, image editing, classification, or network work. Core services are protocol-based and are assembled by `App/DIContainer.swift` and injected through the SwiftUI environment. Tests mirror the app boundaries in `WardrobeTests/`, with UI coverage in `WardrobeUITests/`.

## Data model

The local store is the source of truth. SwiftData is the default direction, with model boundaries kept independent enough to change persistence technology if needed.

### `WardrobeItem`

- Stable identifier, creation and update dates, and lifecycle state (`active`, `archived`).
- User-editable category, color, pattern, sleeve length, fit, season, brand, notes, favorite flag, and optional source metadata.
- References to the item's original user pixels, transparent cut-out, and optional deterministic enhancement. The original is retained only as required for user comparison/revert and privacy policy.
- Provenance indicating product-photo or outfit-photo origin and the source capture identifier.
- Partial-item flag for garments extracted from an outfit.

### `ImageAsset`

- Stable identifier, local file reference, media kind (`source`, `mask`, `cutOut`, `enhanced`), dimensions, format, color space, and creation date.
- Stored locally; no remote URL is required for the MVP. Saved item images contain garment pixels only and never a face or body.

### `MaskRevision`

- Stable identifier, item/source reference, mask data reference, revision number, and whether the revision came from automatic Vision output or manual editing.
- Supports repair, undo/revert, and reproducible cut-out generation without modifying the user's source pixels.

### `AttributeSuggestion`

- Attribute name, proposed value, confidence, model/version metadata, and accepted/edited status.
- Suggestions are never authoritative: the review screen always lets the user edit or clear them.

### `OutfitExtractionSession`

- Temporary local session for one outfit source, detected garment candidates, selection state, mask revisions, and cleanup preference.
- Owns the deletion lifecycle for the original outfit photo. It is deleted after successful extraction by default, or retained only when the user explicitly opts in.

### `BrandResult` and `SourceAttribution`

- Optional, separate metadata for an officially sourced brand/product result, including attribution and lookup status.
- A lookup result never replaces the user's image; the user image remains the fallback. External processing must be disclosed before any eligible request.

Persistence should support fetch/search/filter/sort, favorites, archive, duplicate, delete, bulk actions, and basic statistics without making view code aware of storage details.

## Add-item flows

### Product photo mode

1. The user chooses Product photo mode from Add Item.
2. The user captures a photo in the in-app camera or imports one from the photo library. Framing guidance helps keep one garment in view.
3. The capture service runs local quality checks (usable subject, focus/exposure, and an acceptable framing/background signal) and explains any retryable issue.
4. The imaging service creates a Vision foreground mask from the user's pixels. No garment pixels are generated or redrawn.
5. The user can manually edit or repair the mask. The app produces a transparent cut-out from the selected original pixels only.
6. The app applies only reversible, deterministic Core Image adjustments. The original, cut-out, and enhanced versions are shown for comparison, with revert available.
7. Classification proposes category, color, pattern, sleeve length, fit, and season with confidence. The user reviews, edits, or clears every field.
8. The user may enter a brand and optionally request an officially sourced product-photo lookup. Results include attribution, and the user's image remains the fallback.
9. The review view presents the final attributes, provenance, partial-item state if applicable, and image comparison.
10. On confirmation, the persistence service saves the item and its local assets atomically. The app does not save a face or body in the item image.
11. On cancellation or failure, temporary assets are cleaned up without deleting a source the user chose to keep in Photos.

### Outfit photo mode

1. The user chooses Outfit photo mode and captures or imports one-person OOTD or mirror-selfie imagery.
2. The app provides framing guidance and performs local quality checks, including the one-person constraint.
3. The outfit service detects visible garment regions using Vision person/foreground masking and creates candidate outlines. It does not infer hidden garment portions.
4. The user selects or deselects candidates, adds a missing candidate where supported, and repairs outlines manually.
5. Each accepted candidate is cut out from existing garment pixels only. The user can mark an item partial when the complete garment is not visible.
6. The app steps through per-garment review. Classification suggestions are editable and each garment remains an independent draft.
7. The user confirms the selected garments. The persistence service saves each accepted item independently and reports partial failures without losing successful drafts.
8. The original outfit photo is deleted from the app's temporary storage after successful extraction by default. It is retained only when the user explicitly chose to keep it, subject to the product's final retention policy.
9. The extraction session and other temporary masks are cleaned up after save, cancellation, or an unrecoverable failure.

## Service protocols

Every service has a production implementation and a deterministic mock implementation. Typed errors carry user-facing recovery messages.

- `PhotoCaptureService`: camera authorization, capture, photo-library import, framing guidance, and source cleanup.
- `ImageQualityChecking`: local quality checks and retry guidance.
- `ForegroundMaskingService`: Vision foreground/person segmentation and candidate masks.
- `MaskEditingService`: add, remove, feather, repair, undo, and revision management for masks.
- `ImageProcessingService`: transparent cut-out creation and reversible Core Image adjustments; must preserve source pixels and report color-difference measurements.
- `OutfitExtractionService`: candidate detection, selection state, partial-item marking, and extraction-session lifecycle.
- `AttributeClassificationService`: on-device Core ML suggestions and confidence values for item attributes.
- `BrandLookupService`: optional officially sourced lookup, attribution, disclosure state, and user-image fallback. It must not be used for the offline MVP path.
- `WardrobeRepository`: item CRUD, search, filters, sorting, favorites, archive, duplicate, delete, bulk actions, and statistics queries.
- `ImageAssetStore`: local asset write/read/delete and atomic cleanup.
- `PrivacyService`: authorization state, temporary-photo retention, deletion, export, and account-deletion orchestration.
- `SyncService`: optional iCloud/CloudKit synchronization boundary, disabled or no-op for the local-only MVP.

`DIContainer` supplies these protocols to feature view models. Mocks provide sample images, masks, suggestions, repository data, failure cases, and preview data without network access or real camera access.

## Build order

1. Confirm unresolved product/privacy decisions and lock the MVP contract.
2. Establish the XcodeGen project, targets, CI workflow, test targets, app entry point, dependency container, and environment injection.
3. Define SwiftData models, local asset storage, typed errors, repository operations, and migration strategy.
4. Build the shared design system, accessibility foundations, previews, and Add Item navigation shell.
5. Implement capture/import and quality checks with mock-backed tests.
6. Implement product-mode Vision masking, manual mask editing, deterministic Core Image processing, comparison, revert, and fidelity measurements.
7. Implement classification suggestions and editable review/save for one product item.
8. Implement wardrobe browsing and management: grid, search, details, edit, favorites, archive, duplicate, delete, bulk actions, and basic stats.
9. Implement outfit-mode candidate detection, selection/repair, partial items, independent reviews, multi-item save, and original-photo cleanup.
10. Add onboarding, settings, privacy controls, export, and account-deletion flows needed for the MVP surface.
11. Add optional brand lookup behind disclosure and a feature boundary; keep offline behavior complete without it.
12. Add CloudKit sync and Sign in with Apple only after the local model and privacy lifecycle are stable.
13. Run unit/UI tests, accessibility checks, fidelity/privacy checks, and CI builds; resolve warnings before release.
