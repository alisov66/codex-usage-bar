#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_ARCH="${1:-native}"
case "$BUILD_ARCH" in
  native) BUILD_ARCHES=("$(uname -m)") ;;
  universal) BUILD_ARCHES=(arm64 x86_64) ;;
  *) echo "Usage: $0 [native|universal]" >&2; exit 1 ;;
esac

BUILD_SDK="$(xcrun --sdk macosx --show-sdk-path)"
BUILD_SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
if [ "${BUILD_SDK_VERSION%%.*}" -lt 26 ]; then
  echo "Build with Xcode 26 or newer to enable the current native macOS appearance." >&2
  exit 1
fi
# The Swift Build backend can record the deployment target as the SDK version.
# Build each architecture with the native backend, then combine, so AppKit sees
# the actual SDK version and enables modern controls (minimum OS remains 13).
BUILD_BINARIES=()
BIN_DIR=""
for architecture in "${BUILD_ARCHES[@]}"; do
  swift build --build-system native -c release --arch "$architecture" --sdk "$BUILD_SDK"
  architecture_dir="$(swift build --build-system native -c release --arch "$architecture" --sdk "$BUILD_SDK" --show-bin-path | tail -n 1)"
  BUILD_BINARIES+=("$architecture_dir/CodexUsageBar")
  if [ -z "$BIN_DIR" ]; then BIN_DIR="$architecture_dir"; fi
done
BUILD_STAGING="$(mktemp -d "${TMPDIR:-/tmp}/codex-usage-build.XXXXXX")"
trap 'rm -rf "$BUILD_STAGING"' EXIT
APP="$BUILD_STAGING/Codex Usage Bar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [ "${#BUILD_BINARIES[@]}" -eq 1 ]; then
  cp "${BUILD_BINARIES[0]}" "$APP/Contents/MacOS/CodexUsageBar"
else
  lipo -create "${BUILD_BINARIES[@]}" -output "$APP/Contents/MacOS/CodexUsageBar"
fi
BUILD_VERSION_INFO="$(vtool -show-build "$APP/Contents/MacOS/CodexUsageBar")"
if ! awk -v sdk="$BUILD_SDK_VERSION" '
  $1 == "sdk" { count++; if ($2 + 0 != sdk + 0) failed = 1 }
  $1 == "minos" && $2 != "13.0" { failed = 1 }
  END { exit(count == 0 || failed) }
' <<< "$BUILD_VERSION_INFO"; then
  echo "The binary must record SDK $BUILD_SDK_VERSION and minimum macOS 13.0." >&2
  exit 1
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"
shasum -a 256 -c Resources/AppIcon/source.sha256
shasum -a 256 -c Resources/PanelColors.sha256
cp Resources/AppIcon/Compiled/Assets.car "$APP/Contents/Resources/Assets.car"
cp Resources/AppIcon/Compiled/CodexAppIcon.icns "$APP/Contents/Resources/CodexAppIcon.icns"
for resource in "$BIN_DIR/"*.bundle; do
  if [ -d "$resource" ]; then cp -R "$resource" "$APP/Contents/Resources/"; fi
done
codesign --force --sign - "$APP"
mkdir -p dist
if [ -e "dist/Codex Usage Bar.app" ]; then
  mv "dist/Codex Usage Bar.app" "$BUILD_STAGING/previous.app"
fi
mv "$APP" "dist/Codex Usage Bar.app"
APP="dist/Codex Usage Bar.app"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Codex-Usage-Bar-macOS.zip"
(cd dist && shasum -a 256 Codex-Usage-Bar-macOS.zip > SHA256SUMS.txt)
echo "Built $APP"
