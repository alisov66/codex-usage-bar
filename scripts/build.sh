#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_ARCH="${1:-native}"
case "$BUILD_ARCH" in
  native) SWIFT_ARCH_ARGS=() ;;
  universal) SWIFT_ARCH_ARGS=(--arch arm64 --arch x86_64) ;;
  *) echo "Usage: $0 [native|universal]" >&2; exit 1 ;;
esac

swift build -c release "${SWIFT_ARCH_ARGS[@]}"
BIN_DIR="$(swift build -c release "${SWIFT_ARCH_ARGS[@]}" --show-bin-path)"
APP="dist/Codex Usage Bar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CodexUsageBar" "$APP/Contents/MacOS/CodexUsageBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Codex-Usage-Bar-macOS.zip"
shasum -a 256 "dist/Codex-Usage-Bar-macOS.zip" > dist/SHA256SUMS.txt
echo "Built $APP"
