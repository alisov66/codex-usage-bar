import AppKit
import UsageCore

@main
@MainActor
enum EntryPoint {
static func main() {
signal(SIGPIPE, SIG_IGN)
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
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { application.run() }
}
}
}
