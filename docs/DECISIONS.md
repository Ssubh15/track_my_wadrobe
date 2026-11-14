# Open Decisions and Risks

The following questions must be answered before the affected implementation is finalized. They are deliberately recorded as questions rather than silently choosing product behavior.

1. What exact quality thresholds should trigger a retry for focus, exposure, framing, background complexity, and subject size, and may the user continue after a warning?
2. Does “one garment” in Product photo mode allow shoes, accessories, sets, or multiple pieces photographed together, or must those be separate items?
3. For Outfit photo mode, what should happen when the image contains zero people, multiple people, a mannequin, or a person whose garment boundaries are ambiguous?
4. Which garment classes are in scope for the first classifier, and what is the fallback behavior when confidence is low or the class is unsupported?
5. What precisely counts as a “face or body” that must be excluded from saved item images, and how should hair, hands, shoes, straps, or worn accessories be handled when they overlap a garment?
6. When a garment is occluded, should the app reject the extraction, save it as partial, or allow the user to save a manually bounded visible region? The fidelity rule prohibits inventing hidden portions.
7. Should the product-mode original be retained for comparison/revert indefinitely, for a user-configurable period, or only until the item is confirmed?
8. If an outfit save partially succeeds, should the app save successful garments immediately, keep all garments as drafts for retry, or roll back the complete operation?
9. What does “keep the original outfit photo” mean operationally: retain it only inside the app, leave it in Photos untouched, or both? What UI and confirmation are required?
10. Is manual mask editing required to work fully offline, and what minimum editing tools are expected (brush, erase, polygon, feather, undo/redo)?
11. Which deterministic Core Image adjustments are permitted, and what color-difference metric and maximum tolerance define “faithful” output?
12. Which Core ML models are approved for on-device distribution, what are their licenses and sizes, and what happens when a model is unavailable or fails to load?
13. What officially sourced brand/product data providers are permitted, what attribution format is required, and is external processing allowed only after explicit per-request consent?
14. Is brand lookup part of the MVP release or strictly later, given the MVP release sequence and the offline/local-operation requirement?
15. Which item attributes and enum values should be standardized for search, filters, statistics, and future sync? Are free-form values allowed alongside suggestions?
16. How should duplicate items be identified: user action only, metadata similarity, image similarity, or never automatically?
17. What archive/delete semantics are expected, including undo, permanent deletion, and deletion of associated image assets?
18. Is CloudKit sync required for the first shipped build or only planned, and what is the conflict-resolution policy for edits, deletes, and asset versions?
19. Is Sign in with Apple required for local-only use, required before sync/export, or optional? What data is tied to an account?
20. What data-export format and account-deletion guarantees are required, and must export include original sources, masks, revisions, and provenance metadata?
21. What analytics, if any, are allowed under the privacy promise, and may diagnostic events include image-derived metadata or model confidence?
22. Which accessibility labels and interaction alternatives are required for mask editing, camera framing, image comparison, and confidence suggestions?
23. What are the minimum supported device capabilities for Vision and Core ML, and what graceful degradation is required on older iOS 17 devices?
24. The PRD says “optional iCloud sync” and also names CloudKit in the technical direction: should persistence abstractions be designed for sync now while shipping local-only first, or should sync be implemented in the initial release?
25. The PRD mentions “the original detailed brief remains at the repository root,” but no filename is specified here. Which brief is authoritative if it conflicts with `docs/PRD.md`?
26. Outfit extraction currently uses `StubClothingParser`, a clearly labelled body-proportion baseline that creates temporary, editable candidate masks only. It is not semantically reliable enough to finalize garment boundaries. Which approved on-device Core ML clothing-parsing model (classes, license, size, and confidence/occlusion thresholds) will replace it before the feature ships?

## Status update: 2026-11-14 (additions only; the questions above are unchanged)

Recorded from the repository state at version 12.3.1. These notes do not replace or close any question above.

### Progress on existing questions

- **Question 26 (clothing-parsing model):** Outfit extraction no longer defaults to `StubClothingParser`. `OOTDSegmentationMode.defaultMode` is now `.clothSegformer`, which runs the on-device Core ML model `OOTDClothSegmenter_w8` (`Wardrobe/Features/AddItem/OutfitMode/Segmentation/`). The legacy stub remains as a fallback. The model's license, size, class list and confidence/occlusion thresholds are still not recorded here.
- **Question 25 (authoritative brief):** The detailed brief at the repository root appears to be `Wardrobe App Spec and Codex Build Guide.md`. Which document wins when it conflicts with `docs/PRD.md` is still unanswered.
- **Question 9 (keep original outfit photo):** Settings has a "Keep originals" toggle for outfit photos. The PRD default is to delete the original unless the user chooses otherwise. The confirmation UI and retention rules are not yet defined.

### Decisions stated by the project owner

- All photo processing happens on device and nothing leaves the phone.
- The public repository is `Ssubh15/track_my_wadrobe`. The original private repository is kept only as a backup.
- The baseline is the contents of `backup/working-ootd-2026-11-14` (version 12.2). That backup branch is not modified; further fine-tuning goes into the current version only.
- Versions are tracked by number (12.3, 12.3.1, ...) without git tags.

### Build status against the Codex Build Guide

- Prompts 0 to 11: implemented. Outfit mode (Prompts 10 and 11) is in the fine-tuning stage.
- Prompt 9 (brand lookup): code exists. The PRD lists brand lookup as post-MVP (question 14).
- Prompt 12 (settings, privacy, sync): only partly done. Missing are data export, delete all data, the privacy screen, category and tag management, and the CloudKit flag. Questions 18 to 20 are still open.
- Prompt 13 (Insights): not started. The screen is a placeholder.
- Prompt 14 (polish and release checklist): not started.

## Status update: version 12.4 (screens from the Claude Design mockups; additions only)

- Added: Onboarding (shown once), Insights charts, Privacy and your data, Categories and tags, and a regrouped Settings screen. No services, persistence, models, DIContainer or protected files were changed.
- Settings keeps every existing control: Keep original photos, all diagnostics rows and the diagnostic images switch, and the debug-only tools. The two dead "Privacy" and "Appearance" labels were replaced by real rows.
- Custom categories and tags are stored in UserDefaults (`CategoryTagStore`). Custom categories also appear in the "Choose category" sheet. Deleting a category moves its items to Other; renaming one updates its items. Tags are a managed list only and are not yet offered when reviewing an item.
- Export my data and Delete all data are shown as in the design but disabled ("Coming soon"). Question 20 stays open.
- The About row shows the app version, now set to 12.4 in `project.yml` (it was 1.0.0).
