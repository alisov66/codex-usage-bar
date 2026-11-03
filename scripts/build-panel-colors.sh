#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

TASK_PANEL_DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
TASK_PANEL_ACTOOL="$TASK_PANEL_DEVELOPER_DIR/usr/bin/actool"
if [ ! -x "$TASK_PANEL_ACTOOL" ]; then
  TASK_PANEL_ACTOOL="/Applications/Xcode.app/Contents/Developer/usr/bin/actool"
fi
"$TASK_PANEL_ACTOOL" Resources/PanelColors.xcassets \
  --compile Sources/WatchTheLimits/Resources/PanelColors.bundle \
  --platform macosx --minimum-deployment-target 13.0 --output-format human-readable-text

rg --files Resources/PanelColors.xcassets | sort | xargs shasum -a 256 > Resources/PanelColors.sha256
