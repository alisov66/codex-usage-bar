import AppKit
import SwiftUI

/// A menu-bar presentation using Apple's glass, rather than a painted approximation.
@available(macOS 26.0, *)
@MainActor
final class GlassUsagePanel: NSPanel {
    private let host: NSHostingController<UsageView>
    private weak var anchor: NSStatusBarButton?
    private var sizeObservation: NSKeyValueObservation?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var deactivateObserver: NSObjectProtocol?
    private var openedAt: TimeInterval = 0

    init(model: UsageModel) {
        host = NSHostingController(rootView: UsageView(model: model))
        host.sizingOptions = [.preferredContentSize]
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        title = "Codex Usage"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // Dismiss explicitly below, after activation has settled.
        hidesOnDeactivate = false
        level = .popUpMenu
        animationBehavior = .utilityWindow
        collectionBehavior = [.transient, .fullScreenAuxiliary]

        contentView = PanelShell.make(content: host.view)
        sizeObservation = host.observe(\.preferredContentSize, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.resizeToContent() }
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(relativeTo button: NSStatusBarButton) {
        openedAt = ProcessInfo.processInfo.systemUptime
        anchor = button
        resizeToContent()
        makeKeyAndOrderFront(nil)
        // The remote menu-bar host can finish assigning its screen after ordering.
        DispatchQueue.main.async { [weak self] in self?.resizeToContent() }
        startDismissalMonitoring()
    }

    private func resizeToContent() {
        guard let anchor, let window = anchor.window else { return }
        let target = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        guard let screen = window.screen
                ?? NSScreen.screens.first(where: { $0.frame.intersects(target) })
                ?? NSScreen.main else { return }
        let preferred = host.preferredContentSize
        let size = preferred.width > 0 && preferred.height > 0 ? preferred : host.view.fittingSize
        guard size.width > 0 && size.height > 0 else { return }
        let available = screen.visibleFrame.insetBy(dx: 8, dy: 0)
        let hasPosition = !target.isEmpty && screen.frame.intersects(target)
        let center = hasPosition ? target.midX : available.maxX - size.width / 2
        let left = min(max(center - size.width / 2, available.minX), available.maxX - size.width)
        let top = (hasPosition ? min(target.minY, available.maxY) : available.maxY) - 4
        setFrame(NSRect(x: left, y: max(available.minY, top - size.height),
                        width: size.width, height: size.height), display: true)
    }

    private func startDismissalMonitoring() {
        stopDismissalMonitoring()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.timestamp > self.openedAt,
               event.window !== self, event.window !== self.anchor?.window { self.close() }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, event.timestamp > self.openedAt else { return }
            self.close()
        }
        deactivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // An older activation notification may be delivered after reopening.
                if !NSApp.isActive { self?.close() }
            }
        }
    }

    private func stopDismissalMonitoring() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let deactivateObserver { NotificationCenter.default.removeObserver(deactivateObserver) }
        localMonitor = nil
        globalMonitor = nil
        deactivateObserver = nil
    }

    override func cancelOperation(_ sender: Any?) { close() }

    override func close() {
        stopDismissalMonitoring()
        orderOut(nil)
    }
}

@MainActor
enum PanelShell {
    static func make(content: NSView) -> NSView {
        let shell: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 20
            glass.contentView = content
            shell = glass
        } else {
            let material = NSVisualEffectView()
            material.material = .popover
            material.blendingMode = .behindWindow
            material.state = .active
            material.addSubview(content)
            shell = material
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: shell.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: shell.trailingAnchor),
            content.topAnchor.constraint(equalTo: shell.topAnchor),
            content.bottomAnchor.constraint(equalTo: shell.bottomAnchor)
        ])
        return shell
    }
}
