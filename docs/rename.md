# Watch the Limits rename

The project, previously called **Codex Usage Bar**, is now **Watch the Limits**.

## Names and links

- Repository: <https://github.com/alisov66/watch-the-limits>
- App: `Watch the Limits.app`
- Swift package, executable target, and binary: `WatchTheLimits`
- New release archive: `Watch-the-Limits-macOS.zip`
- Codex app-server client name: `watch_the_limits`

Version **v0.5.0** is the first release prepared under the new name. Publication still requires the owner's release approval. Historical releases through v0.4.1 retain their original asset names and installation instructions.

## Updating an existing installation

Quit the old app before installing the renamed one. Move `Watch the Limits.app` to Applications and remove the old `Codex Usage Bar.app` after verifying the new copy works. Keeping both copies can make macOS choose the wrong copy when opening the app or starting it at login.

The app deliberately keeps its existing bundle identifier, `com.alisov.codex-usage-bar`, and preference keys (`menuBarDisplay` and `codexPath`). This preserves the preference domain and launch-at-login identity. No settings reset or separate app identity is introduced by the rename. After moving the new app to Applications, check Launch at login and re-enable it there if macOS still references the previous app path.

The internal compiled panel-color bundle also retains its existing identifier. These compatibility identifiers are not the product's displayed name.
