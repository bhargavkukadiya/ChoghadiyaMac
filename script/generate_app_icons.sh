#!/usr/bin/env bash
set -euo pipefail

TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_SOURCE="$TASK_ROOT/Design/Icons/AppIcon.png"
TASK_OUTPUT="$TASK_ROOT/App/Resources/Assets.xcassets/AppIcon.appiconset"

for size in 16 32 128 256 512; do
    for scale in 1 2; do
        pixels=$((size * scale))
        sips -z "$pixels" "$pixels" "$TASK_SOURCE" \
            --out "$TASK_OUTPUT/icon_${size}x${size}@${scale}x.png" >/dev/null
    done
done
echo "Generated all ten macOS app icon representations."
