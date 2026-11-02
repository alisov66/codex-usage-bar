import AppKit

/// Exercises the live AppKit window, rather than only rendering its content offscreen.
@MainActor
enum PanelPresentationVerifier {
    static func run() async throws {
        guard #available(macOS 26.0, *) else {
            throw failure("Live glass verification requires macOS 26 or newer.")
        }
        try AppResources.verifyPackagedLocation()
        print("Resources: \(AppResources.bundle.bundleURL.path)")
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(item) }
        guard let button = item.button else { throw failure("No status button.") }
        button.title = "Usage test"
        let model = UsageModel(demo: true)
        let panel = GlassUsagePanel(model: model)
        defer { panel.close() }
        try await Task.sleep(nanoseconds: 200_000_000)
        print("Screens: \(NSScreen.screens.map { $0.visibleFrame }), status window: \(String(describing: button.window?.frame)), status screen: \(String(describing: button.window?.screen))")
        NSApp.activate(ignoringOtherApps: true)
        panel.show(relativeTo: button)
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Initial panel: \(panel.frame), visible: \(panel.isVisible), key: \(panel.isKeyWindow), active: \(NSApp.isActive)")
        guard panel.isVisible, panel.frame.width == 302, panel.frame.height >= 300,
              NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) else {
            throw failure("Panel did not open with visible content on screen.")
        }
        // A status-item click can be forwarded after activation/presentation.
        // It belongs to the opening interaction and must not dismiss the panel.
        let openingClick = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
                                             modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime - 1,
                                             windowNumber: 0, context: nil, eventNumber: 0,
                                             clickCount: 1, pressure: 1)!
        NSApp.postEvent(openingClick, atStart: false)
        try await Task.sleep(nanoseconds: 100_000_000)
        guard panel.isVisible else { throw failure("The delayed opening click dismissed the panel.") }
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        try await Task.sleep(nanoseconds: 100_000_000)
        guard panel.isVisible else { throw failure("An outdated activation notification dismissed the active panel.") }
        let collapsed = panel.frame
        model.showSettings = true
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Expanded panel: \(panel.frame), visible: \(panel.isVisible)")
        guard panel.isVisible, panel.frame.width == collapsed.width,
              panel.frame.height > collapsed.height, abs(panel.frame.maxY - collapsed.maxY) < 1 else {
            throw failure("Panel did not expand while keeping its top edge anchored.")
        }
        model.showSettings = false
        try await Task.sleep(nanoseconds: 300_000_000)
        guard panel.frame.size == collapsed.size else { throw failure("Panel did not collapse.") }
        panel.cancelOperation(nil)
        guard !panel.isVisible else { throw failure("Escape did not dismiss the panel.") }
        panel.show(relativeTo: button)
        try await Task.sleep(nanoseconds: 200_000_000)
        guard panel.isVisible, panel.frame.size == collapsed.size else { throw failure("Panel did not reopen.") }
        let outsideClick = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
                                             modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                             windowNumber: 0, context: nil, eventNumber: 1,
                                             clickCount: 1, pressure: 1)!
        NSApp.postEvent(outsideClick, atStart: false)
        try await Task.sleep(nanoseconds: 100_000_000)
        guard !panel.isVisible else { throw failure("A new outside click did not dismiss the panel.") }
        print("Panel presentation verification passed.")
    }

    private static func failure(_ message: String) -> Error {
        NSError(domain: "PanelPresentationVerification", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
