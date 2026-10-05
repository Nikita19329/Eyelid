#!/usr/bin/env bash
# Renders the app icon and packs it: Resources/AppIcon.icns for the app, docs/images/icon.png for the README.
# Run it after changing scripts/render-icon.swift, and commit both files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift "$ROOT/scripts/render-icon.swift" "$WORK/icon-1024.png" >/dev/null

# Every size macOS asks an .icns for, each at 1x and 2x.
ICONSET="$WORK/AppIcon.iconset"
mkdir "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil --convert icns "$ICONSET" --output "$ROOT/Resources/AppIcon.icns"
sips -z 256 256 "$WORK/icon-1024.png" --out "$ROOT/docs/images/icon.png" >/dev/null
echo "==> Wrote Resources/AppIcon.icns and docs/images/icon.png"
