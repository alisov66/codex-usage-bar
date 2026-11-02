import AppKit
import SwiftUI

@MainActor
enum PanelPreviewRenderer {
    static func writePreviews(to directory: URL) throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        try PanelDesign.verifyResources()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var metadata: [[String: Any]] = []
        for scenario in PanelPreviewScenario.allCases {
            let settingsOptions = [.codexMissing, .signInRequired].contains(scenario) ? [false] : [false, true]
            for expanded in settingsOptions {
                for dark in [false, true] {
                    let model = UsageModel(preview: scenario, expanded: expanded)
                    let host = NSHostingView(rootView: UsageView(model: model)
                        .environment(\.colorScheme, dark ? .dark : .light)
                        .environment(\.controlActiveState, .key))
                    let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
                    let size = host.fittingSize
                    host.frame = NSRect(origin: .zero, size: size)
                    let window = NSWindow(contentRect: host.frame, styleMask: .borderless,
                                          backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.appearance = appearance
                    window.backgroundColor = .windowBackgroundColor
                    // The review canvas uses Apple's material; the live app uses NSPopover's own shell.
                    let material = NSVisualEffectView(frame: host.frame)
                    material.material = .popover
                    material.blendingMode = .withinWindow
                    material.state = .active
                    window.contentView = material
                    material.addSubview(host)
                    material.layoutSubtreeIfNeeded()
                    window.displayIfNeeded()
                    guard let bitmap = material.bitmapImageRepForCachingDisplay(in: material.bounds) else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    material.cacheDisplay(in: material.bounds, to: bitmap)
                    let filename = "panel-\(scenario.rawValue)-\(expanded ? "expanded" : "collapsed")-\(dark ? "dark" : "light").png"
                    guard let data = bitmap.representation(using: .png, properties: [:]) else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    try data.write(to: directory.appendingPathComponent(filename))
                    metadata.append(["file": filename, "width": size.width, "height": size.height,
                                     "phase": model.phase.rawValue, "hasData": model.hasPanelData,
                                     "settingsExpanded": expanded, "appearance": dark ? "Dark" : "Light"])
                    window.close()
                }
            }
        }
        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("geometry.json"))
    }
}
