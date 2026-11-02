import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var glassPanel: NSPanel?
    private let model: UsageModel = {
        let arguments = CommandLine.arguments
        let preview = arguments.firstIndex(of: "--panel-state").flatMap { index in
            arguments.indices.contains(index + 1) ? PanelPreviewScenario(rawValue: arguments[index + 1]) : nil
        }
        return UsageModel(demo: arguments.contains("--demo"), preview: preview,
                          expanded: arguments.contains("--settings-expanded"))
    }()
    private let renderer = MenuBarRenderer()
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.target = self
            button.action = #selector(togglePopover)
        }
        if #available(macOS 26.0, *) {
            glassPanel = GlassUsagePanel(model: model)
        } else {
            popover.behavior = .transient
            let content = NSHostingController(rootView: UsageView(model: model))
            content.sizingOptions = [.preferredContentSize]
            popover.contentViewController = content
        }
        model.onChange = { [weak self] in self?.updateStatus() }
        updateStatus()
        if !model.isDemo { model.refresh() }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.model.refresh() } }
        if model.isDemo { showPopover() }
    }

    private func updateStatus() {
        let indicator = model.indicator
        if let button = statusItem.button {
            let availableHeight = button.bounds.height > 0 ? button.bounds.height : NSStatusBar.system.thickness
            button.image = renderer.image(for: indicator, maximumHeight: availableHeight)
        }
        statusItem.button?.toolTip = indicator.accessibilityLabel
        statusItem.button?.setAccessibilityLabel(indicator.accessibilityLabel)
    }

    @objc private func togglePopover() {
        if #available(macOS 26.0, *), let panel = glassPanel as? GlassUsagePanel, panel.isVisible { panel.close() }
        else if popover.isShown { popover.performClose(nil) }
        else { showPopover(); model.refresh() }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 26.0, *), let panel = glassPanel as? GlassUsagePanel {
            panel.show(relativeTo: button)
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await model.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
