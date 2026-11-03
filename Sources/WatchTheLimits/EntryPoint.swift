import AppKit
import UsageCore

@main
@MainActor
enum EntryPoint {
    static func main() {
        signal(SIGPIPE, SIG_IGN)
        if CommandLine.arguments.contains("--verify-panel") {
            let application = NSApplication.shared
            application.setActivationPolicy(.accessory)
            Task { @MainActor in
                do {
                    try await PanelPresentationVerifier.run()
                    exit(0)
                } catch {
                    fputs("Panel verification failed: \(error.localizedDescription)\n", stderr)
                    exit(1)
                }
            }
            application.run()
            return
        }
        if let flag = CommandLine.arguments.firstIndex(of: "--render-panels") {
            guard CommandLine.arguments.indices.contains(flag + 1) else {
                fputs("Usage: WatchTheLimits --render-panels OUTPUT_DIRECTORY\n", stderr)
                exit(1)
            }
            do {
                try PanelPreviewRenderer.writePreviews(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1], isDirectory: true))
                exit(0)
            } catch {
                fputs("Could not render panel previews: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        if let flag = CommandLine.arguments.firstIndex(of: "--render-indicators") {
            guard CommandLine.arguments.indices.contains(flag + 1) else {
                fputs("Usage: WatchTheLimits --render-indicators OUTPUT_DIRECTORY\n", stderr)
                exit(1)
            }
            do {
                let directory = URL(fileURLWithPath: CommandLine.arguments[flag + 1], isDirectory: true)
                try MenuBarRenderer().writePreviews(to: directory)
                exit(0)
            } catch {
                fputs("Could not render indicator previews: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        if CommandLine.arguments.contains("--check") {
            Task {
                guard let path = CodexExecutable.locate() else {
                    fputs("Codex executable not found.\n", stderr)
                    exit(1)
                }
                let client = CodexClient()
                do {
                    let snapshot = try await client.readLimits(executablePath: path)
                    for entry in snapshot.entries {
                        for window in entry.bucket.windows {
                            print("\(entry.title) · \(window.title): \(window.remainingPercent)% remaining")
                        }
                    }
                    await client.shutdown()
                    exit(snapshot.windows.isEmpty ? 2 : 0)
                } catch {
                    fputs("\(error.localizedDescription)\n", stderr)
                    await client.shutdown()
                    exit(1)
                }
            }
            dispatchMain()
        } else {
            if let flag = CommandLine.arguments.firstIndex(of: "--panel-state") {
                guard CommandLine.arguments.indices.contains(flag + 1),
                      PanelPreviewScenario(rawValue: CommandLine.arguments[flag + 1]) != nil else {
                    fputs("Unknown panel preview state.\n", stderr)
                    exit(1)
                }
            }
            let application = NSApplication.shared
            let delegate = AppDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { application.run() }
        }
    }
}
