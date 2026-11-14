# Wardrobe App — Product Requirements

## Overview

Wardrobe is an iOS personal wardrobe app. Users can add clothes from a single product photo or extract several visible garments from an outfit photo. The app must preserve the photographed garment faithfully: no generated pixels, altered color, shape, print, texture, or invented hidden portions.

## Goals

- Add a garment in under 60 seconds.
- Build a digital wardrobe from both garment and outfit photos.
- Create clean, faithful cut-outs and assist with category and attribute entry.
- Keep the user in control before any item is saved.
- Browse and manage a complete wardrobe.

## Non-goals for v1

- Generative imagery, virtual models, social, marketplace, shopping, Android, and web apps.

## Core flows

### Product photo

Capture or import one garment; run quality checks; remove its background; apply only reversible deterministic enhancement; compare original, cut-out, and enhanced versions; review attributes and optional brand-photo results; then confirm saving.

### Outfit photo

Capture or import one-person OOTD or mirror-selfie photo; detect visible garments; let the user select, deselect, add, or repair outlines; cut out only existing garment pixels; mark partial items; step through review; then save selected garments independently. Delete the original by default unless the user chooses otherwise.

## Functional requirements

- In-app camera and photo-library import, framing guidance, and quality checks.
- Background removal, manual mask editing, consistent transparent PNG output, and before/after revert.
- AI-assisted category, color, pattern, sleeve length, fit, and season suggestions with confidence and editable fields.
- Brand entry and optional officially sourced product-photo lookup with attribution; the user image remains the fallback.
- Wardrobe grid, search, filters, sort, details, edit, favorites, archive, duplicate, delete, bulk actions, and basic stats.
- On-device photo processing and local/offline operation for capture, enhancement, and browsing.
- Optional iCloud sync, Sign in with Apple, data export, and account deletion.

## Technical direction

Use Swift/SwiftUI, SwiftData or Core Data, CloudKit, Vision foreground/person masking, Core Image deterministic enhancement, Core ML classification, and PhotosUI/AVFoundation. The target is iOS 17+. Cloud builds use GitHub Actions macOS runners and XcodeGen; generated `.xcodeproj` files are not committed.

## Quality, privacy, and accessibility

Preserve garment fidelity, process photos on device by default, never retain faces or bodies in saved item images, disclose external processing, support Dynamic Type and VoiceOver, and measure color difference against the original.

## Release sequence

MVP: capture, faithful cut-out/enhancement, categorization, review/edit, wardrobe management, local storage, and one-person outfit extraction. Later: brand lookup, iCloud sync, filters/stats, outfit builder, diary, wear tracking, packing, and recommendations.

This document captures the product requirements supplied on 2 November 2026. The original detailed brief remains at the repository root for reference.
