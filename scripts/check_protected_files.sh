#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/protected_files.sha256"

hash_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        echo "Error: sha256sum or shasum is required to check protected files." >&2
        exit 2
    fi
}

protected_files=(
    "Wardrobe/Features/AddItem/ProductMode/ProductPhotoProcessingView.swift"
    "Wardrobe/Features/AddItem/Capture/CaptureView.swift"
    "Wardrobe/Features/AddItem/Capture/CameraService.swift"
    "Wardrobe/Features/AddItem/Shared/MaskEditorView.swift"
    "Wardrobe/Core/Services/Imaging/BackgroundRemovalService.swift"
    "Wardrobe/Core/Services/Imaging/MaskEditingService.swift"
    "Wardrobe/Core/Services/Imaging/ImageEnhancementService.swift"
    "Wardrobe/Core/Services/Imaging/FidelityChecker.swift"
    "Wardrobe/Core/Services/Imaging/ImageQualityChecker.swift"
    "Wardrobe/App/DIContainer.swift"
)

if [[ "${1:-}" == "--update" ]]; then
    : > "$MANIFEST"
    for relative_path in "${protected_files[@]}"; do
        file="$REPO_ROOT/$relative_path"
        if [[ ! -f "$file" ]]; then
            echo "Error: protected file is missing: $relative_path" >&2
            exit 1
        fi
        printf '%s  %s\n' "$(hash_file "$file")" "$relative_path" >> "$MANIFEST"
    done
    echo "Updated protected-file SHA-256 baseline: $MANIFEST"
    exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: protected-file manifest is missing: $MANIFEST (run with --update to create it)." >&2
    exit 1
fi

failed=0
for relative_path in "${protected_files[@]}"; do
    file="$REPO_ROOT/$relative_path"
    if [[ ! -f "$file" ]]; then
        echo "PROTECTED FILE MISSING: $relative_path" >&2
        failed=1
        continue
    fi
    expected="$(awk -v path="$relative_path" '$2 == path {print $1}' "$MANIFEST")"
    if [[ -z "$expected" ]]; then
        echo "PROTECTED FILE NOT IN BASELINE: $relative_path" >&2
        failed=1
        continue
    fi
    actual="$(hash_file "$file")"
    if [[ "$actual" != "$expected" ]]; then
        echo "PROTECTED FILE CHANGED: $relative_path" >&2
        failed=1
    fi
done

if [[ "$failed" -ne 0 ]]; then
    echo "Protected-file check failed. Restore the file or explicitly review and update the baseline." >&2
    exit 1
fi

echo "Protected-file check passed."
