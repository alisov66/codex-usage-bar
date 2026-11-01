#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_ARCH="${1:-native}"
case "$BUILD_ARCH" in
  native) SWIFT_ARCH_ARGS=(--arch "$(uname -m)") ;;
  universal) SWIFT_ARCH_ARGS=(--arch arm64 --arch x86_64) ;;
  *) echo "Usage: $0 [native|universal]" >&2; exit 1 ;;
esac

swift build -c release "${SWIFT_ARCH_ARGS[@]}"
BIN_DIR="$(swift build -c release "${SWIFT_ARCH_ARGS[@]}" --show-bin-path)"
APP="dist/Codex Usage Bar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/CodexUsageBar" "$APP/Contents/MacOS/CodexUsageBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
shasum -a 256 -c Resources/AppIcon/source.sha256
cp Resources/AppIcon/Compiled/Assets.car "$APP/Contents/Resources/Assets.car"
cp Resources/AppIcon/Compiled/CodexAppIcon.icns "$APP/Contents/Resources/CodexAppIcon.icns"
for resource in "$BIN_DIR/"*.bundle; do
  if [ -d "$resource" ]; then cp -R "$resource" "$APP/Contents/Resources/"; fi
done
codesign --force --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Codex-Usage-Bar-macOS.zip"
(cd dist && shasum -a 256 Codex-Usage-Bar-macOS.zip > SHA256SUMS.txt)
echo "Built $APP"
