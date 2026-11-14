#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_IMAGES="$ROOT/tools/ootd_model/test_images"
SOURCE_GOLDENS="$ROOT/tools/ootd_model/golden"
TARGET_ROOT="$ROOT/Wardrobe/Resources/Debug"

if [[ ! -d "$SOURCE_IMAGES" ]] || ! find "$SOURCE_IMAGES" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit | grep -q .; then
    # Test photos are deliberately excluded from the public repo; skip debug staging.
    echo "No OOTD test images found under tools/ootd_model/test_images; skipping debug asset staging." >&2
    if [[ -n "${GITHUB_ENV:-}" ]]; then echo "OOTD_DEBUG_ASSETS=0" >> "$GITHUB_ENV"; fi
    exit 0
fi

rm -rf "$TARGET_ROOT/OOTDTestImages" "$TARGET_ROOT/golden"
mkdir -p "$TARGET_ROOT/OOTDTestImages" "$TARGET_ROOT/golden"
find "$SOURCE_IMAGES" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -exec cp -p {} "$TARGET_ROOT/OOTDTestImages/" \;
if [[ -d "$SOURCE_GOLDENS" ]]; then
    find "$SOURCE_GOLDENS" -maxdepth 1 -type f -iname '*.png' -exec cp -p {} "$TARGET_ROOT/golden/" \;
fi

IMAGE_COUNT="$(find "$TARGET_ROOT/OOTDTestImages" -maxdepth 1 -type f | wc -l | tr -d ' ')"
GOLDEN_COUNT="$(find "$TARGET_ROOT/golden" -maxdepth 1 -type f -iname '*.png' | wc -l | tr -d ' ')"
if [[ "$GOLDEN_COUNT" -eq 0 ]]; then
    echo "No golden masks found under tools/ootd_model/golden; DEBUG agreement scores will be unavailable." >&2
    exit 1
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then echo "OOTD_DEBUG_ASSETS=1" >> "$GITHUB_ENV"; fi
echo "Staged $IMAGE_COUNT test images and $GOLDEN_COUNT golden masks for Debug."
