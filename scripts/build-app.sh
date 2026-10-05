#!/usr/bin/env bash
# Builds build/Eyelid.app without an Xcode project: SwiftPM for the app, CMake for mediaremote-adapter.
#
# Usage: scripts/build-app.sh [debug|release]   (default: release)
set -euo pipefail

CONFIGURATION="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADAPTER_SRC="$ROOT/Vendor/mediaremote-adapter"
ADAPTER_BUILD="$ROOT/.build/adapter"
APP="$ROOT/build/Eyelid.app"

cd "$ROOT"

if [[ ! -f "$ADAPTER_SRC/CMakeLists.txt" ]]; then
  echo "==> Fetching submodules"
  git submodule update --init --recursive
fi

command -v cmake >/dev/null || { echo "error: cmake not found, install it with 'brew install cmake'" >&2; exit 1; }

echo "==> Building mediaremote-adapter"
cmake -S "$ADAPTER_SRC" -B "$ADAPTER_BUILD" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$ADAPTER_BUILD" --target MediaRemoteAdapter >/dev/null

echo "==> Building Eyelid ($CONFIGURATION)"
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources/Licenses"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN_DIR/Eyelid" "$APP/Contents/MacOS/Eyelid"
cp "$ADAPTER_SRC/bin/mediaremote-adapter.pl" "$APP/Contents/Resources/"
cp -R "$ADAPTER_BUILD/MediaRemoteAdapter.framework" "$APP/Contents/Frameworks/"
cp "$ADAPTER_SRC/LICENSE" "$APP/Contents/Resources/Licenses/mediaremote-adapter.txt"

echo "==> Signing (ad hoc)"
codesign --force --sign - "$APP/Contents/Frameworks/MediaRemoteAdapter.framework"
codesign --force --sign - "$APP"

echo "==> Done: $APP"
