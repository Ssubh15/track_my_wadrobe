# Wardrobe App: Spec and Codex Build Guide

Nov 2, 2026 · @Ssubham

Everything for the wardrobe app in one place: the PRD, the screen list, the feature list, and a step-by-step Codex plan that builds it without a Mac.

# Part 1: Product Requirements (PRD)

Status: Draft v2 · Platform: iOS

## 1. Overview

A personal wardrobe app for iOS. There are two ways to add clothes. In Product photo mode, the user photographs one garment and the app cleans up that same photo (background removed, light and clarity improved) without altering the garment itself. In Outfit photo mode, the user uploads an ordinary photo such as an OOTD or a mirror selfie, and the app extracts each visible garment as its own item, using only the pixels in that photo. AI then suggests each garment's category and details, the user reviews and edits them, and the item is saved to a digital wardrobe. After processing, the app asks for the brand and tries to find a better official product photo online as an optional upgrade.

## 2. Problem Statement

People forget what they own, buy duplicates, and struggle to plan outfits. Existing wardrobe apps need tedious manual cataloguing, and their photos look messy (cluttered backgrounds, bad lighting). Some AI tools fix this by regenerating the clothing, which changes its color, fit and details, and that makes the catalogue untrustworthy.

## 3. Goals and Non-Goals

**Goals**

- Add a garment to the wardrobe in under 60 seconds.
- Let users build a wardrobe from photos they already have (OOTDs, mirror selfies), not only from new product shots.
- Produce a clean cut-out image that is faithful to the real garment (same color, size, shape).
- Auto-fill details with high accuracy, with the user always in control before saving.
- Give the user an easy way to browse and manage everything they own.

**Non-goals (v1)**

- Generative AI imagery of any kind (no re-drawing, no virtual models).
- Social features, marketplace or resale.
- Shopping or purchase flows.
- Android or web versions.

## 4. Target Users

- **Primary:** fashion-conscious young adults (18–35) who want a tidy digital closet.
- **Secondary:** people decluttering, packing for trips, or tracking what they actually wear.

## 5. Core User Flow

Both modes end on the same review screen.

**Mode A: Product photo (one garment)**

1. Tap **Add item**, choose Product photo, and take a photo (or pick one from the library).
2. App processes the image: background removal, cropping, enhancement.
3. User compares the original and the processed image and can retry or adjust.
4. AI suggests category, color, and other attributes.
5. App asks for the brand (skippable).
6. If a brand is given, app searches for a better product photo and offers it as an alternative.
7. User reviews and edits every detail on a review screen.
8. User confirms, and the item is saved to the wardrobe.

**Mode B: Outfit photo (OOTD or mirror selfie, several garments)**

1. Tap **Add item**, choose Outfit photo, and take or import the photo.
2. App finds the person and outlines each visible garment.
3. User checks the outlines: select or deselect items, tap to add a missed one, fix an outline.
4. For each selected item, the app cuts it out, applies light cleanup, and suggests category and attributes. Partly hidden items are marked as partial.
5. User steps through a review queue: edit details, enter the brand, and optionally swap in a better online product photo or retake the item as a product photo.
6. User confirms, and each item is saved to the wardrobe as its own entry. The original photo is deleted unless the user keeps it.

## 6. Functional Requirements

### 6.1 Photo Capture

- FR-1: In-app camera with a framing guide and flat-lay/hanger tips.
- FR-2: Import from photo library.
- FR-3: Basic quality checks (blur, too dark, garment cut off) with a prompt to retake.

### 6.2 AI Photo Enhancement for Product Photos (critical requirement)

- FR-4: Remove the background and cut out only the garment, with clean edges.
- FR-5: Enhance the user's own photo only: exposure, white balance, sharpness, noise and wrinkle-neutral clarity.
- FR-6: **Fidelity guarantee:** the garment's color, proportions, shape, print and texture must remain as in the original. No generative fill that invents garment pixels.
- FR-7: Show a before/after comparison with a one-tap revert to the original or the plain cut-out.
- FR-8: Manual touch-up of the mask (erase/restore edges) if the cut-out is wrong.
- FR-9: Export transparent PNG at a consistent canvas size so all items look uniform in the grid.

### 6.3 Outfit Photo Extraction

Users can also add clothes from ordinary photos, such as an OOTD or a mirror selfie, and the app pulls each visible garment out as its own item. Product photo mode (6.1 and 6.2) stays as it is.

- FR-O1: Add item offers two modes: Product photo and Outfit photo.
- FR-O2: Outfit photo mode accepts normal photos: mirror selfies, OOTD shots taken by someone else, full-body or half-body, with any background. One person per photo in v1; if several people are found, the user picks whose outfit to extract.
- FR-O3: Detect and outline each visible garment (tops, outerwear, bottoms, dresses, shoes) and, later, accessories (bags, hats, belts, watches).
- FR-O4: Show the detected items on the photo. The user can select or deselect each one, tap to add a missed item, and fix an outline with the mask editor (FR-8).
- FR-O5: **Extraction fidelity:** an extracted item uses only pixels that are in the photo, with the garment's real color, shape and proportions. Hidden parts are never invented (no drawing in the missing legs of trousers or the back of a shirt).
- FR-O6: Correct for how the photo was taken, without changing the garment: flip mirror selfies back so logos and text read correctly (with a toggle), straighten tilt and perspective, and apply light, reversible white-balance correction.
- FR-O7: Handle layers and occlusion: extract each visible layer (jacket over t-shirt), and mark items that are partly hidden or cut off by the frame as partial, with a note on what is missing.
- FR-O8: Flag weak extractions (small, blurry, mostly covered) and offer two fixes: retake as a product photo, or use brand photo lookup (FR-18, FR-19) to get a clean image.
- FR-O9: Every extracted item goes through categorization, review and edit, and the brand step (6.4 to 6.6). Brand lookup matters most here, since cut-outs from photos are lower quality than product shots.
- FR-O10: Several items from one photo go through one review queue, where the user confirms or edits them one by one.
- FR-O11: Privacy: process outfit photos on the device, keep faces and bodies out of saved item images, and delete the original photo after extraction unless the user chooses to keep it.
- FR-O12: Optionally record which items came from the same photo, so outfit features can use it later.

### 6.4 AI Categorization and Attributes

- FR-10: Predict garment type (t-shirt, shirt, polo, hoodie, sweater, jacket, pants, trousers, jeans, shorts, skirt, dress, shoes, accessories, etc.).
- FR-11: Predict secondary attributes: dominant color(s), pattern, sleeve length, fit, and likely season.
- FR-12: Show confidence; if low, ask the user to pick from the top suggestions.
- FR-13: Allow the user to add custom categories and tags.

### 6.5 Review and Edit Before Saving

- FR-14: A single review screen shows every detected field as editable.
- FR-15: Editable fields: category, color, pattern, size, fit, season, material, brand, price, purchase date, notes, tags.
- FR-16: Nothing is saved until the user confirms; drafts are kept if the app is closed.

### 6.6 Brand Input and Better Photo Lookup

- FR-17: After processing, ask for the brand with autocomplete (skippable).
- FR-18: With the brand, category and color, search the web or the brand's website for a matching official product photo.
- FR-19: Show candidate matches side by side with the user's own photo; the user chooses one or keeps their own.
- FR-20: Keep the user's original photo as a fallback even if an online photo is chosen.
- FR-21: Show image source attribution, and respect licensing and terms of use of the source.
- FR-22: If nothing good is found, say so and keep the user's own cut-out.

### 6.7 Wardrobe Management

- FR-23: Grid view of all items with category filters and a search bar.
- FR-24: Filter and sort by category, color, brand, season, recently added and favorites.
- FR-25: Item detail screen with all attributes and the photo.
- FR-26: Edit, duplicate, favorite, archive, or delete items.
- FR-27: Bulk select for delete, archive or re-tagging.
- FR-28: Basic stats: item count by category, by color, and by brand.

### 6.8 Account, Sync and Settings

- FR-29: Sign in with Apple and iCloud sync across devices.
- FR-30: Data export and account deletion.
- FR-31: Settings for default photo behavior, units, and notifications.

## 7. Non-Functional Requirements

- **Performance:** photo processing target under 5 seconds on supported devices; on-device processing preferred (Vision, Core ML) with an optional cloud fallback for hard cases.
- **Privacy:** photos are the user's private data. Disclose clearly if any image leaves the device, process only what is needed, and don't use the images to train models without consent.
- **Reliability:** works offline for capture, enhancement and wardrobe browsing; online only for brand photo lookup and sync.
- **Accessibility:** Dynamic Type, VoiceOver labels, sufficient contrast.
- **Quality bar:** color accuracy measured against the original (e.g., a max color-difference threshold) as an automated test for the fidelity guarantee.

## 8. Technical Considerations

- **Stack:** Swift and SwiftUI; SwiftData or Core Data for storage; CloudKit for sync.
- **Background removal:** Apple Vision foreground instance masking as the baseline, with a segmentation model for garment-specific edge cases.
- **Enhancement:** deterministic image processing (Core Image) rather than generative models, which guarantees shape and color stay intact.
- **Classification:** a Core ML image classifier fine-tuned on clothing datasets, or a vision-language model API as a fallback.
- **Brand photo search:** a web or image-search API plus matching by embedding similarity to ensure the found photo matches the user's garment. Confirm licensing before storing third-party images (link to or cache with attribution if needed).
- **Outfit extraction:** person segmentation (Vision) to isolate the wearer, then a clothing-parsing or promptable segmentation model on Core ML to split the person into garment regions. Each region then runs through the same cut-out and enhancement pipeline as a product photo. Test on mirror selfies, low light, layered outfits and baggy fits.
- **Build and distribution (no Mac):** builds run on GitHub Actions macOS runners, with the Xcode project generated by XcodeGen. Test installs use an unsigned .ipa sideloaded with a free Apple ID; CloudKit sync and Sign in with Apple need a paid Apple Developer account, so they stay behind flags until then.

## 9. Success Metrics

- Time to add an item (target: under 60 seconds median).
- Percent of items saved with no category edits (AI accuracy proxy).
- Percent of cut-outs accepted without manual touch-up.
- Percent of users who provide a brand, and percent who accept the online photo.
- Items added per user in week 1, and week-4 retention.
- Outfit mode: percent of extracted items saved without a redo, and share of items added through outfit photos.

## 10. Risks and Open Questions

- **Fidelity vs. polish:** aggressive enhancement can shift colors. Mitigation: conservative adjustments plus revert.
- **Cut-out errors** on similar-colored backgrounds, white-on-white items, sheer fabrics, or folded clothes. Mitigation: guidance in the camera UI and manual mask editing.
- **Brand photo matching** may return the wrong colorway or season. Mitigation: always user-confirmed.
- **Legal:** using brand images may require permission; decide whether to store, or only link.
- **Outfit extraction quality:** hidden or overlapping garments, phones covering the torso, layering, baggy fits, patterns that blend into skin or background, and low-resolution selfies. Mitigation: partial flags, adjustable outlines, a fallback to a product photo, and brand photo lookup.
- **Privacy of outfit photos:** they show faces and homes. Mitigation: on-device processing, no faces in saved images, and originals deleted by default.
- **No Mac:** cloud builds are slower to iterate on, and free-Apple-ID installs expire every 7 days. Mitigation: small steps, a green build before each next step, and a paid developer account or a rented Mac when needed.
- **Open:** on-device vs. cloud for processing? Free vs. paid tiers? Is multi-photo (front, back, detail) per item in v1?

## 11. Release Plan

- **MVP:** capture, background removal and enhancement, categorization, review and edit, wardrobe grid and detail, local storage, and outfit photo extraction (one person per photo).
- **v1.1:** brand input and better photo lookup, iCloud sync, filters and stats.
- **v2:** outfit builder, an OOTD diary linked to extracted items, wear tracking, packing lists, weather-based suggestions.

# Part 2: Screens Required

**Onboarding and access**

- Splash / launch screen
- Onboarding carousel (what the app does, the fidelity promise)
- Sign in / Sign in with Apple
- Permissions (camera, photo library, notifications)

**Add item: start**

- Add item entry (choose Product photo or Outfit photo)

**Add item: product photo mode**

- Camera capture (guide overlay and tips)
- Photo quality feedback / retake prompt
- Processing screen (progress indicator)
- Before/after result screen (revert and retry)
- Mask touch-up editor (erase/restore)
- AI category and attributes confirmation

**Add item: outfit photo mode**

- Outfit photo capture or import (mirror-selfie and full-body tips)
- Outfit processing screen
- Detected garments screen (photo with tappable outlines; outline fixes reuse the mask touch-up editor)
- Partial item notice (what is missing; retake, use a brand photo, or keep as is)
- Multi-item review queue (swipe through the extracted items, 2 of 4)

**Add item: shared steps**

- Brand entry (with autocomplete and skip)
- Brand photo search results and comparison
- Review and edit details (all fields)
- Save confirmation / success (one item, or a summary of several)

**Wardrobe section**

- Wardrobe home (grid with category tabs)
- Search and filter / sort sheet
- Item detail
- Edit item
- Bulk select mode
- Empty state (first-time wardrobe)
- Favorites / archive views

**Insights and profile**

- Stats / insights dashboard
- Profile and settings
- Category and tag management
- Data export, privacy and delete account

**Utility states (not full screens)**

- Error and no-internet states, low-confidence picker, draft-resume prompt, and no garment found and more than one person prompts

# Part 3: Feature List

**From your idea**

1. Photo capture with the camera or the library
2. AI photo enhancement that improves the user's own photo without generating a new image
3. Background removal that cuts out only the garment
4. Fidelity guarantee: color, size and shape are preserved
5. AI garment categorization (t-shirt, shirt, pants, trousers, shorts, and more)
6. Review and edit all details before adding to the wardrobe
7. Brand prompt after processing
8. Better product photo lookup from the internet or the brand website
9. Dedicated wardrobe section to manage added clothes

**Outfit photo mode**

- Add clothes from OOTDs and mirror selfies, not only product photos
- Detects each visible garment in the photo and extracts it as its own item
- Tap to select, deselect, add a missed item or fix an outline
- Extraction keeps the real color, shape and proportions, and never invents hidden parts
- Mirror-selfie correction (text and logos flipped back)
- Partial-item flags for layered or covered clothes
- Fallback to a product photo or brand photo lookup when an extraction is weak
- One review queue for all items from a photo
- On-device processing, with the original photo deleted by default

**Supporting features to round it out**

- Before/after comparison with one-tap revert
- Manual mask touch-up
- Photo quality checks and capture guidance
- Auto-detected color, pattern, fit, sleeve and season
- Confidence indicators and top-suggestion picker
- Custom categories and tags
- Search, filter and sort
- Favorites, archive, duplicate and delete
- Bulk actions
- Drafts for unfinished items
- Wardrobe stats
- iCloud sync and backup
- Data export and account deletion

**Future ideas**

- Outfit builder and saved outfits
- Wear tracking and cost-per-wear
- Weather-based outfit suggestions
- Packing lists for trips
- Duplicate and gap detection (you own five black tees)
- Multiple photos per item (front, back, details)

# Part 4: Codex Build Guide (No Mac)

Build the app in 16 small steps: add the AGENTS.md below to your repo, then give Codex one prompt at a time, pushing to GitHub and waiting for a green build after each.

## Before you start

- **No Mac, so build in the cloud.** Apple only lets you compile iOS apps on macOS. Instead, push your code to GitHub and let a GitHub Actions macOS runner build and test it on every push. Codex writes the code and the workflow; it cannot compile Swift itself, so expect a few rounds of fixing build errors (use the fix prompt at the end).
- **No Xcode needed to create the project.** Prompt 0b generates the Xcode project from a project.yml file (XcodeGen) inside the cloud build, so Codex only edits text files.
- Create a GitHub repo. Save the PRD (Part 1) as docs/PRD.md, the folder tree below as docs/STRUCTURE.md, and the AGENTS.md below at the repo root. Commit and push.
- **Getting it onto your iPhone, free route:** the cloud build produces an unsigned .ipa. Install it from a Windows PC with Sideloadly or AltStore, signing with your free Apple ID. Free signing expires after 7 days (you re-install weekly), allows only a few apps at a time, and does not support iCloud sync or Sign in with Apple.
- **Getting it onto your iPhone, paid route:** the Apple Developer Program (paid, yearly) lets you install through TestFlight with no Mac, and the cloud build can upload to it. Worth it once the app works and you want a stable install.
- **Easier alternative:** rent a cloud Mac by the hour for a session or two (setup, signing, debugging). Everything in this guide still applies, with faster feedback.
- Paste one prompt at a time. Push after each and wait for the green build before the next prompt. Test capture and outfit photos on your real iPhone, since cloud builds have no camera.

## Project structure

```text
Wardrobe/
├── AGENTS.md
├── README.md
├── project.yml                (XcodeGen config; the .xcodeproj is generated, not committed)
├── .github/
│   └── workflows/
│       └── ios.yml            (cloud build, tests, unsigned .ipa)
├── docs/
│   ├── PRD.md
│   ├── STRUCTURE.md
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md
│   └── BUILD.md               (how to sideload the .ipa)
├── Wardrobe/
│   ├── App/
│   │   ├── WardrobeApp.swift
│   │   ├── RootTabView.swift
│   │   └── DIContainer.swift
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── GarmentItem.swift
│   │   │   ├── GarmentCategory.swift
│   │   │   ├── DraftItem.swift
│   │   │   └── ExtractedGarment.swift
│   │   ├── Persistence/
│   │   │   ├── WardrobeRepository.swift
│   │   │   └── ImageStore.swift
│   │   ├── Services/
│   │   │   ├── Imaging/
│   │   │   │   ├── BackgroundRemovalService.swift
│   │   │   │   ├── ImageEnhancementService.swift
│   │   │   │   ├── FidelityChecker.swift
│   │   │   │   └── ImageQualityChecker.swift
│   │   │   ├── Classification/
│   │   │   │   ├── GarmentClassifier.swift
│   │   │   │   ├── CoreMLGarmentClassifier.swift
│   │   │   │   ├── MockGarmentClassifier.swift
│   │   │   │   └── AttributeExtractor.swift
│   │   │   ├── Outfit/
│   │   │   │   ├── OutfitSegmenter.swift
│   │   │   │   ├── ClothingParser.swift
│   │   │   │   ├── MirrorDetector.swift
│   │   │   │   └── OutfitExtractionPipeline.swift
│   │   │   └── BrandLookup/
│   │   │       ├── BrandPhotoProvider.swift
│   │   │       ├── MockBrandPhotoProvider.swift
│   │   │       ├── RemoteBrandPhotoProvider.swift
│   │   │       └── BrandCatalog.swift
│   │   └── Utilities/
│   ├── Features/
│   │   ├── Onboarding/
│   │   ├── AddItem/
│   │   │   ├── Entry/
│   │   │   ├── Capture/
│   │   │   ├── ProductMode/
│   │   │   ├── OutfitMode/
│   │   │   └── Shared/        (brand entry, brand results, review, save)
│   │   ├── Wardrobe/
│   │   ├── Insights/
│   │   └── Settings/
│   ├── DesignSystem/
│   │   ├── Theme.swift
│   │   └── Components/
│   └── Resources/
│       ├── Assets.xcassets
│       └── Models/            (Core ML models go here)
├── WardrobeTests/
├── WardrobeUITests/
└── backend/                   (optional later: proxy for brand photo search)
```

## AGENTS.md

Put this at the repo root. Codex reads it before every task.

```text
# Wardrobe: instructions for Codex

Product: iOS wardrobe app. Users add clothes in two ways: Product photo mode (one garment, cleaned up) and Outfit photo mode (OOTD or mirror selfie, garments extracted). Full requirements are in docs/PRD.md. Read it before any task.

## Hard rules
1. Fidelity: never generate or redraw clothing. Only use Vision masks and Core Image adjustments on the user's own pixels. A garment's color, shape and proportions must stay as photographed. Never invent hidden parts.
2. Privacy: process photos on device. Never upload a photo unless a task explicitly says so. Faces and bodies must not appear in saved item images. Delete original outfit photos after extraction unless the user opts to keep them.
3. No secrets in the app or the repo. API keys belong on a backend.
4. No third-party packages without asking first.

## Stack
Swift 5.9+, SwiftUI, SwiftData, iOS 17+, Swift concurrency (async/await, actors), Observation (@Observable). Vision, Core Image, Core ML, PhotosUI, AVFoundation.

## Architecture
- Features/ has one folder per feature: views plus a view model each. Core/ holds models, persistence and services.
- Every service sits behind a protocol with a mock implementation, so views and tests never depend on Vision, Core ML or the network.
- Dependencies are created in App/DIContainer.swift and injected through the SwiftUI environment.
- Views contain no business logic.

## Workflow
- One task at a time. Keep diffs small. Do not refactor unrelated code.
- Add or update unit tests for every service and view model.
- You may not be able to run xcodebuild in this environment (there is no Mac). If you can, run it with an installed iPhone simulator. If you cannot, say clearly what you could not verify, and make sure the GitHub Actions workflow in .github/workflows/ios.yml would pass: check imports, types and availability annotations by reading carefully.
- Fix warnings you introduce.
- End every task with: files changed, how to test it manually, and anything you were unsure about.

## Style
- Small files, clear names, no force unwraps. Use typed errors with user-facing messages.
- A SwiftUI preview for every screen, using mock data.
- Dynamic Type and VoiceOver labels from the start.
```

## The prompts

Run them in order. Each one builds on the last.

### Prompt 0: Read and plan

```text
Read AGENTS.md, docs/PRD.md and docs/STRUCTURE.md fully. Do not write app code yet.
Create docs/ARCHITECTURE.md covering: the folder layout, the data model, both add-item flows (product photo and outfit photo) as step lists, the service protocols you plan to define, and the build order.
List any PRD ambiguities or risks as questions in docs/DECISIONS.md.
```

### Prompt 0b: Project generation and cloud build (no Mac)

Run this right after Prompt 0 and before Prompt 1.

```text
Follow AGENTS.md. I do not have a Mac, so builds run on GitHub Actions. Set up the project and CI.
- Create project.yml for XcodeGen: an iOS 17 app target Wardrobe (sources: Wardrobe/), a unit test target WardrobeTests, a UI test target WardrobeUITests, a shared Wardrobe scheme, bundle id com.example.wardrobe (I will change it), SwiftUI app lifecycle, and Info.plist keys for camera and photo library usage with clear explanations. Do not commit a generated .xcodeproj; add it to .gitignore.
- Add a minimal WardrobeApp.swift and one passing unit test so the pipeline has something to build.
- Create .github/workflows/ios.yml that runs on every push and pull request on a macOS runner: install XcodeGen, generate the project, build and run the unit tests on an available iPhone simulator (look one up with xcrun simctl instead of hard-coding a name), then build for a device with code signing disabled and package the app as an unsigned Wardrobe.ipa uploaded as a build artifact.
- Add docs/BUILD.md explaining how to download the .ipa from the Actions run and sideload it with Sideloadly or AltStore using a free Apple ID.
Keep the workflow simple and comment every step.
```

### Prompt 1: App shell and design system

```text
Follow AGENTS.md. Create the folder structure from docs/STRUCTURE.md inside the Wardrobe target. Then build the app shell:
- WardrobeApp with a TabView: Wardrobe, Add, Insights, Settings. The Add tab opens AddItemEntryView as a full-screen sheet instead of showing a page.
- DesignSystem with a Theme (colors, spacing, type styles) and components: PrimaryButton, SectionHeader, EmptyStateView, GarmentCard.
- DIContainer injected through the environment.
- Placeholder screens with previews.
Keep the build green.
```

### Prompt 2: Data models and storage

```text
Follow AGENTS.md. Implement the data layer.
- SwiftData model GarmentItem: id, createdAt, category, subtype, primaryColorHex, secondaryColorHexes, pattern, sleeveLength, fit, season, material, size, brand, price, purchaseDate, notes, tags, isFavorite, isArchived, imageSource (productPhoto, outfitPhoto, brandPhoto), cutoutImagePath, originalImagePath (optional), sourceGroupID (optional, links items from the same outfit photo), isPartial.
- GarmentCategory enum with the PRD categories (t-shirt, shirt, polo, hoodie, sweater, jacket, pants, trousers, jeans, shorts, skirt, dress, shoes, accessory, other) plus support for user-defined categories.
- DraftItem: the in-progress item used by the add flow before saving, persisted so drafts survive app restarts.
- ImageStore: saves and loads transparent PNGs in Application Support, keyed by item id, with delete.
- WardrobeRepository protocol with a SwiftData implementation and an in-memory mock.
Write unit tests for the repository and ImageStore.
```

### Prompt 3: Wardrobe section

```text
Follow AGENTS.md. Build the Wardrobe feature (PRD 6.7) using the repository and mock data.
- Wardrobe home: grid of GarmentCard, category tabs, search bar, empty state.
- Filter and sort sheet: category, color, brand, season, favorites, recently added.
- Item detail, edit item, favorite, archive, duplicate, delete, and bulk select mode.
- Favorites and archive views.
Add a debug-only button in Settings to seed sample items. Add view model tests.
```

### Prompt 4: Add item entry and capture

```text
Follow AGENTS.md. Build the start of the add flow.
- AddItemEntryView: two options, Product photo and Outfit photo. Remember the last choice.
- Capture: a camera screen (AVFoundation wrapper) with a framing guide overlay, and import via PhotosPicker. Handle camera permission states with a clear explanation screen.
- ImageQualityChecker: detect blur (variance of Laplacian), too dark or too bright, and a garment cut off at the frame edge. Show a retake prompt with the reason.
Do not process the image yet. Pass the chosen image and mode to the next step through a coordinator or router. Unit test the quality checker with fixture images.
```

### Prompt 5: Product photo processing (the fidelity-critical step)

```text
Follow AGENTS.md. Implement Product photo mode processing (PRD 6.2).
- BackgroundRemovalService protocol and VisionBackgroundRemovalService using VNGenerateForegroundInstanceMaskRequest. Output a transparent PNG cropped to the garment with small padding, plus the mask.
- ImageEnhancementService using Core Image only: conservative exposure, white balance, sharpness and noise reduction. No generative models.
- FidelityChecker: compare average color (in Lab) and silhouette area before and after enhancement, and fail if the difference passes a threshold. Unit test with fixture images.
- Normalize every cut-out to the same square canvas with the garment centered.
- ProcessingView (progress) and BeforeAfterView with an Original / Cut-out / Enhanced toggle, Retry, and Use plain cut-out (no enhancement).
Use mock services in previews.
```

### Prompt 6: Mask touch-up editor

```text
Follow AGENTS.md. Build MaskEditorView (PRD FR-8): the cut-out over a checkerboard, with Erase and Restore brushes (adjustable size), undo and redo, and zoom and pan. Editing changes only the mask, never the garment pixels. Make it reusable, because Outfit mode will use it to fix outlines. Add unit tests for the mask editing logic.
```

### Prompt 7: Categorization and attributes

```text
Follow AGENTS.md. Implement PRD 6.4.
- GarmentClassifier protocol returning ranked CategoryPrediction values with confidence. MockGarmentClassifier returns fixed values. CoreMLGarmentClassifier wraps a Core ML model from Resources/Models; leave a clear TODO and a config for the model name, and do not invent a model file.
- AttributeExtractor: dominant and secondary colors using k-means on masked pixels only (deterministic), plus placeholders for pattern, sleeve length and fit.
- When confidence is below a threshold, show CategoryPickerSheet with the top 3 suggestions.
- AttributesConfirmationView.
Add unit tests.
```

### Prompt 8: Review, edit and save

```text
Follow AGENTS.md. Build ReviewItemView (PRD 6.5): a single screen showing the image and every field as editable (category, color, pattern, size, fit, season, material, brand, price, purchase date, notes, tags). Nothing is saved until the user taps Confirm. Persist the draft if the app is closed, and offer to resume it. On Confirm, save through the repository and ImageStore, then show a success screen. Support a list of drafts so Outfit mode can reuse this screen later. Add view model tests.
```

### Prompt 9: Brand input and better photo lookup

```text
Follow AGENTS.md. Implement PRD 6.6.
- BrandEntryView with autocomplete from BrandCatalog (a local list of common brands) and a Skip button.
- BrandPhotoProvider protocol: search(brand, category, colors) -> [BrandPhotoCandidate] with image, source URL and attribution. Implement MockBrandPhotoProvider now and a RemoteBrandPhotoProvider stub that calls a configurable backend URL. Never put API keys in the app.
- BrandPhotoResultsView: show candidates beside the user's own photo, let the user pick one or keep their own, show source attribution, and handle no results and no internet.
- Always keep the user's own cut-out as a fallback.
Add tests with the mock provider.
```

### Prompt 10: Outfit mode, part 1 (extraction pipeline)

```text
Follow AGENTS.md. Implement the extraction pipeline for Outfit photo mode (PRD 6.3, FR-O1 to FR-O12). No UI yet.
- OutfitSegmenter protocol and VisionOutfitSegmenter using VNGeneratePersonInstanceMaskRequest to find the wearer. If more than one person is found, return all of them so the UI can ask.
- ClothingParser protocol: splits the person mask into garment regions (top, outerwear, bottoms, dress, shoes). Implement a StubClothingParser that splits the mask by body proportions as a rough baseline, and design the protocol so a Core ML clothing segmentation model can replace it later. Mark the stub clearly in code and in docs/DECISIONS.md.
- MirrorDetector: a simple heuristic that guesses a mirror selfie (phone visible in the frame, or text and logos reading backwards) and a flip function.
- ExtractedGarment model: cut-out image, mask, guessed category, isPartial with a reason, and confidence.
- OutfitExtractionPipeline combining the steps. It must use only pixels from the photo and never fill in hidden parts. Mark an item partial when its region touches the frame edge or is covered.
Add unit tests with fixture images.
```

### Prompt 11: Outfit mode, part 2 (screens)

```text
Follow AGENTS.md. Build the Outfit photo screens.
- OutfitCaptureView: capture or import, with mirror-selfie and full-body tips.
- OutfitProcessingView.
- DetectedGarmentsView: the photo with tappable outlines for each garment. The user can select or deselect, tap to add a missed item, and open MaskEditorView to fix an outline. Include a flip toggle for mirror selfies.
- PartialItemSheet: explains what is missing and offers three choices: retake as a product photo, use a brand photo, or keep as is.
- Multi-item review queue: swipe through the selected garments (2 of 4), using ReviewItemView, then the brand step, then save them all with a shared sourceGroupID.
- Privacy: after extraction, delete the original photo unless the user turned on Keep originals in Settings. Never save faces or bodies in item images.
Add view model tests.
```

### Prompt 12: Settings, privacy and sync

```text
Follow AGENTS.md. Build Settings: Keep original outfit photos (off by default), default photo behavior, category and tag management, data export (zip of item data and images), and delete all data. Add a privacy screen that explains what stays on the device. Then add CloudKit sync for the SwiftData store behind a feature flag, off by default. CloudKit and Sign in with Apple need a paid Apple Developer account and will not work in builds signed with a free Apple ID, so the app must work fully without them. Add Sign in with Apple only if the PRD still requires it after your read of the CloudKit setup; otherwise note the decision in docs/DECISIONS.md.
```

### Prompt 13: Insights

```text
Follow AGENTS.md. Build the Insights screen: item count by category, by color and by brand, using Swift Charts (bar charts, sorted descending), plus a simple summary line at the top. Compute the stats in a view model from the repository and unit test them.
```

### Prompt 14: Polish and release checklist

```text
Follow AGENTS.md. Do a polish pass.
- Accessibility: VoiceOver labels and hints, Dynamic Type at the largest sizes, contrast.
- Error and empty states for every screen, including no garment found and more than one person.
- Performance: downscale large photos before processing, run Vision and Core Image off the main thread, and cache thumbnails in the grid.
- UI tests for the main flows: add a product photo item, add items from an outfit photo (with mock services), edit an item, delete an item.
- Write docs/RELEASE_CHECKLIST.md: privacy manifest and camera and photo usage strings, App Store privacy answers, screenshots, TestFlight steps.
```

## Reusable prompts

**When the build fails**

```text
The build or tests failed with the output below. Find the root cause, fix it with the smallest change, and re-run the build and tests. Do not delete or weaken tests to make them pass.

<paste the error output here>
```

**Review before you commit**

```text
Review the changes since the last commit against AGENTS.md. Check specifically for: anything that generates or alters garment pixels beyond masks and Core Image adjustments, photos leaving the device, secrets, force unwraps, logic inside views, and missing tests. List problems first, then fix them.
```
