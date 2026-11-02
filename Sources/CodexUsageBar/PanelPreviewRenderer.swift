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
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    // Share the live glass container. Offscreen snapshots cannot sample wallpaper.
                    let material = PanelShell.make(content: host)
                    material.frame = NSRect(origin: .zero, size: size)
                    window.contentView = material
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
                                     "settingsExpanded": expanded, "appearance": dark ? "Dark" : "Light",
                                     "shell": String(describing: type(of: material))])
                    window.close()
                }
            }
        }
        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("geometry.json"))
    }
}
