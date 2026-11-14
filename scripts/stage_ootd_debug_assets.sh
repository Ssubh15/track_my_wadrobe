#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_IMAGES="$ROOT/tools/ootd_model/test_images"
SOURCE_GOLDENS="$ROOT/tools/ootd_model/golden"
TARGET_ROOT="$ROOT/Wardrobe/Resources/Debug"

if [[ ! -d "$SOURCE_IMAGES" ]] || ! find "$SOURCE_IMAGES" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit | grep -q .; then
    # Test photos are not committed (they may show real people). The Debug evaluation
    # screen simply has nothing to show until you add your own images locally.
    echo "Warning: no OOTD test images found under tools/ootd_model/test_images; skipping Debug evaluation assets." >&2
    rm -rf "$ROOT/Wardrobe/Resources/Debug/OOTDTestImages" "$ROOT/Wardrobe/Resources/Debug/golden"
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
    # Goldens are optional: they are generated locally by tools/ootd_model/convert.py.
    # Without them the Debug screen still runs the model but shows no agreement score.
    echo "Warning: no golden masks found under tools/ootd_model/golden; DEBUG agreement scores will be unavailable." >&2
fi
echo "Staged $IMAGE_COUNT test images and $GOLDEN_COUNT golden masks for Debug."
