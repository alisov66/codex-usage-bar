# Figma menu bar assets

Source: https://www.figma.com/design/zCrkvUn8WyWUKH3YYn6QB0?node-id=9-1648

- `usage-icon.svg` is the original design-context export of Usage Icon (`9:1609`), with its 18 × 18 viewport unchanged.
- `usage-icon.pdf` is a PDF export of that same component via the Figma Plugin API, used by AppKit for native vector rendering. It preserves the badge's 25% alpha and the chart's solid alpha.
- `menu-bar-tokens.json` mirrors the Typography and Colors collections, the `Menu bar/Label` text style, and the indicator's auto-layout geometry.

The system-font family maps to the public AppKit system font when the separately installed SF Pro Text face is unavailable. The composed menu bar image is a template image: macOS supplies its contrast-appropriate foreground, and the exported alpha values retain the Figma two-tone treatment.

To review the same native rendering used by the status button:

```sh
swift run CodexUsageBar --render-indicators /tmp/codex-indicator-previews
```

This exports all three display modes in light and dark preview colors at Retina resolution, using synthetic data matching Figma (68% and 92%).
