#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

TASK_ICON_DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
TASK_ICON_ACTOOL="$TASK_ICON_DEVELOPER_DIR/usr/bin/actool"
if [ ! -x "$TASK_ICON_ACTOOL" ]; then
  TASK_ICON_ACTOOL="/Applications/Xcode.app/Contents/Developer/usr/bin/actool"
fi
if [ ! -x "$TASK_ICON_ACTOOL" ]; then
  echo "Rebuilding the app icon requires Xcode with Icon Composer support." >&2
  exit 1
fi

mkdir -p Resources/AppIcon/Compiled
"$TASK_ICON_ACTOOL" Resources/AppIcon/CodexAppIcon.icon \
  --compile Resources/AppIcon/Compiled \
  --platform macosx \
  --minimum-deployment-target 13.0 \
  --app-icon CodexAppIcon \
  --output-partial-info-plist Resources/AppIcon/Compiled/icon-info.plist \
  --output-format human-readable-text

shasum -a 256 \
  Resources/AppIcon/app-icon.svg \
  Resources/AppIcon/app-icon-master.png \
  Resources/AppIcon/CodexAppIcon.icon/icon.json \
  Resources/AppIcon/CodexAppIcon.icon/Assets/codex-app-icon.svg \
  > Resources/AppIcon/source.sha256
