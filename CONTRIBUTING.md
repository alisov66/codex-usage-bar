# Contributing

Use macOS 13 or newer with Swift 5.9 or newer. The app is a Swift package without external package dependencies.

```sh
swift test
bash scripts/build.sh
```

`UsageCore` contains quota decoding and the local Codex protocol client. `CodexUsageBar` contains the menu bar interface and preferences.

Keep usage values in tests synthetic. Do not attach your `~/.codex` folder, authentication files, full app-server responses, or private logs to an issue. Include your macOS version, Codex version, and the visible error text when reporting a connection problem, after checking for personal information.

Quota fields may be absent. Preserve that distinction from zero usage, support multiple quota buckets, and never assume a quota has reset merely because its timestamp passed.

For interface changes, inspect both light and dark appearances. Use `--demo` for screenshots so they contain only sample data.
