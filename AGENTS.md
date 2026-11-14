# Wardrobe: instructions for Codex

Product: iOS wardrobe app. Users add clothes using Product photo mode (one garment, cleaned up) or Outfit photo mode (OOTD or mirror selfie, garments extracted). Full requirements are in `docs/PRD.md`. Read it before any task.

## Hard rules

1. Fidelity: never generate or redraw clothing. Only use Vision masks and Core Image adjustments on the user's own pixels. A garment's color, shape, and proportions must stay as photographed. Never invent hidden parts.
2. Privacy: process photos on device. Never upload a photo unless a task explicitly says so. Faces and bodies must not appear in saved item images. Delete original outfit photos after extraction unless the user opts to keep them.
3. No secrets in the app or repository. API keys belong on a backend.
4. No third-party packages without asking first.

## Stack

Swift 5.9+, SwiftUI, SwiftData, iOS 17+, Swift concurrency, Observation, Vision, Core Image, Core ML, PhotosUI, and AVFoundation.

## Architecture

- `Features/` has one folder per feature; views have a view model each.
- `Core/` holds models, persistence, and services.
- Every service sits behind a protocol with a mock implementation.
- Dependencies are created in `App/DIContainer.swift` and injected through the SwiftUI environment.
- Views contain no business logic.

## Workflow

- One task at a time. Keep diffs small. Do not refactor unrelated code.
- Add or update unit tests for every service and view model.
- If builds cannot run locally, clearly state what was not verified and ensure the GitHub Actions configuration is reviewed carefully.
- Fix warnings introduced by a change.

## Style

- Small files, clear names, and no force unwraps.
- Use typed errors with user-facing messages.
- Add a SwiftUI preview for every screen using mock data.
- Support Dynamic Type and VoiceOver from the start.

## Github
-Upload every change to github wardrobe app repo https://github.com/Ssubh15/Wardrobe-app.git