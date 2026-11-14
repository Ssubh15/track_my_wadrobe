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
