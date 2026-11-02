# Codex Usage Bar

A small native macOS app that keeps your remaining Codex quota in the menu bar.

**`5h 68% · 7d 92%`** — click to see each usage window and its reset time.

- Remaining quota and reset countdowns for your account's Codex limit windows.
- Automatic refresh every minute, on opening the popover, and after waking your Mac.
- Optional launch at login.
- Choose both limits, five-hour only, or weekly only in Settings.
- Original Figma artwork and typography, with a 24-point icon target that fits shorter menu bars and system-tinted two-tone artwork.
- Native interface that follows your Mac's light or dark appearance.
- Figma-designed panel with native macOS background effects and launch-at-login switch, plus explicit loading, retry, and setup states.
- Free and open source under the [MIT license](LICENSE).

Independent community project. Not affiliated with or endorsed by OpenAI.

## Download

Get **Codex-Usage-Bar-macOS.zip** from the [latest release](https://github.com/alisov66/codex-usage-bar/releases/latest), unzip it, and move **Codex Usage Bar.app** to Applications.

Requires **macOS 13 Ventura or newer**. Release builds include both Apple Silicon and Intel support. You also need a local Codex installation signed in with your ChatGPT account.

Early releases are ad-hoc signed, without Apple notarization. macOS may block a downloaded copy. After checking that you trust the release, use **System Settings → Privacy & Security → Open Anyway**, when available. No scripts that disable Gatekeeper are needed. You can also build the app from source.

## Setup

1. Install [Codex CLI](https://developers.openai.com/codex/cli), or use the executable bundled with a supported Codex desktop installation.
2. Sign in with your ChatGPT account:

   ```sh
   codex login
   ```

3. Open Codex Usage Bar. Its icon appears in the menu bar.

The app looks in your environment's PATH, standard Homebrew locations, and known desktop-app locations. If it cannot find Codex, click **Locate Codex**, or **Settings → Codex location → Choose**, and select the `codex` executable. For version-managed Node installations, select the executable inside your active Node version's bin directory.

An API-key-only login does not provide your ChatGPT subscription quota. Usage windows vary by account; the app displays what Codex returns rather than assuming a particular plan or quota.

## What the percentage means

The menu bar shows **remaining quota** for your five-hour (`5h`) and weekly (`7d`) limits. By default both are visible. Open the panel, expand Settings, and use **Menu bar** to show either limit on its own. Your selection is saved across launches.

These are account quota percentages, not token counts or dollar spending. Reset times come from Codex. The menu bar shows a dash when readings are stale or unavailable. The panel retains older readings with a last-update timestamp and offers **Try again** after a failed refresh. Once a reset time passes, that quota shows a dash and **Awaiting refresh** until a new reading arrives. Missing data never appears as 0% or 100% remaining. The panel and menu bar use the same Codex account bucket.

## Privacy

The app starts a local `codex app-server` process and calls only the initialization handshake and `account/rateLimits/read`. Codex handles authentication and contacts its own service to retrieve your limits.

The app does not open your authentication files, run model prompts, inspect your projects or conversations, or upload usage to a separate server. There is no app analytics or third-party library dependency. Its saved settings contain an optional Codex executable path and your menu bar display choice; launch-at-login is managed by macOS. Codex itself still uses its existing local configuration and storage.

The integration uses the [documented Codex app-server protocol](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt). That interface may evolve; update Codex if you encounter an unsupported response.

## Build from source

Install Xcode with Swift 5.9 or newer and finish its first-launch setup, then:

```sh
git clone https://github.com/alisov66/codex-usage-bar.git
cd codex-usage-bar
swift test
bash scripts/build.sh
open "dist/Codex Usage Bar.app"
```

Build for both Apple Silicon and Intel:

```sh
bash scripts/build.sh universal
```

The script creates a locally signed app, a zip archive, and SHA-256 checksums in `dist/`.

Command Line Tools alone can build the app, but running the XCTest suite requires Xcode's test frameworks.

Preview the interface using sample data:

```sh
swift run CodexUsageBar --demo
```

Check the live connection without opening the interface:

```sh
swift run CodexUsageBar --check
```

## Contributing

Issues and pull requests are welcome. Run `swift test` and build the app before submitting changes. Please use synthetic quota examples in tests and screenshots, and keep account IDs, credentials, and private Codex files out of issues and commits. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Releases

GitHub Actions tests and builds a universal app on pushes and pull requests. Releases require the owner's separate confirmation and curated notes in `docs/releases/vX.Y.Z.md`. After approval and successful checks, pushing the matching `v*` tag publishes the release with those notes, the app zip, and checksums. The build has read-only repository permissions; only the release job receives permission to publish release assets.
