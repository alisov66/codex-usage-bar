import AppKit
import UsageCore

/// Typography and colors mirror Figma; layout includes the requested icon-size override.
private struct MenuBarDesign: Decodable {
    struct Typography: Decodable {
        let family: String
        let weight: String
        let size: CGFloat
        let lineHeight: CGFloat
        let letterSpacing: CGFloat
        enum CodingKeys: String, CodingKey {
            case family = "font-family/system"
            case weight = "menu-bar/label/font-weight"
            case size = "menu-bar/label/font-size"
            case lineHeight = "menu-bar/label/line-height"
            case letterSpacing = "letter-spacing"
        }
    }

    struct Layout: Decodable {
        let iconWidth: CGFloat
        let iconHeight: CGFloat
        let itemSpacing: CGFloat
        let quotaSpacing: CGFloat
        let separator: String
        enum CodingKeys: String, CodingKey {
            case iconWidth = "icon-width", iconHeight = "icon-height"
            case itemSpacing = "item-spacing", quotaSpacing = "quota-spacing"
            case separator
        }
    }

    struct Color: Decodable {
        let r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat
        var native: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
    }

    let typography: Typography
    let layout: Layout
    let colors: [String: [String: Color]]
}

@MainActor
final class MenuBarRenderer {
    private let design: MenuBarDesign
    private let icon: NSImage
    private let font: NSFont

    init() {
        let tokensURL = AppResources.bundle.url(forResource: "menu-bar-tokens", withExtension: "json", subdirectory: "Figma")!
        design = try! JSONDecoder().decode(MenuBarDesign.self, from: Data(contentsOf: tokensURL))
        let iconURL = AppResources.bundle.url(forResource: "usage-icon", withExtension: "pdf", subdirectory: "Figma")!
        icon = NSImage(contentsOf: iconURL)!
        let typography = design.typography
        // Use the explicit face when installed, otherwise obtain San Francisco through
        // AppKit's public system-font API. Never distribute Apple's font files.
        font = NSFont(name: typography.family.replacingOccurrences(of: " ", with: "") + "-" + typography.weight,
                      size: typography.size)
            ?? NSFont.systemFont(ofSize: typography.size, weight: .medium)
    }

    func image(for indicator: MenuBarIndicator, maximumHeight: CGFloat? = nil) -> NSImage {
        let layout = design.layout
        let typography = design.typography
        let iconScale = maximumHeight.map { min(1, max(typography.lineHeight, $0) / layout.iconHeight) } ?? 1
        let iconWidth = layout.iconWidth * iconScale
        let iconHeight = layout.iconHeight * iconScale
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = typography.lineHeight
        paragraph.maximumLineHeight = typography.lineHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor.black,
            .kern: typography.letterSpacing, .paragraphStyle: paragraph
        ]
        var fragments: [(text: NSAttributedString, x: CGFloat, width: CGFloat)] = []
        var x = iconWidth + layout.itemSpacing
        func append(_ text: String) {
            let string = NSAttributedString(string: text, attributes: attributes)
            let width = ceil(string.size().width)
            fragments.append((string, x, width))
            x += width
        }
        for (index, quota) in indicator.quotas.enumerated() {
            if index > 0 {
                x += layout.itemSpacing
                append(layout.separator)
                x += layout.itemSpacing
            }
            append(quota.label)
            x += layout.quotaSpacing
            append(quota.value)
        }
        let size = NSSize(width: x, height: max(iconHeight, typography.lineHeight))
        let artwork = icon
        let result = NSImage(size: size, flipped: false) { _ in
            artwork.draw(in: NSRect(x: 0, y: (size.height - iconHeight) / 2,
                                   width: iconWidth, height: iconHeight))
            for fragment in fragments {
                fragment.text.draw(in: NSRect(x: fragment.x, y: (size.height - typography.lineHeight) / 2,
                                             width: fragment.width, height: typography.lineHeight))
            }
            return true
        }
        // Alpha carries the Figma badge's 25% opacity. macOS supplies the foreground
        // tint for wallpaper contrast, appearances, and the selected status item.
        result.isTemplate = true
        result.accessibilityDescription = indicator.accessibilityLabel
        return result
    }

    /// Renders the same artwork used by the live status button for design review.
    func writePreviews(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = UsageSnapshot.menuBarPreview
        var metadata: [[String: Any]] = []
        for mode in MenuBarDisplay.allCases {
            let indicator = MenuBarIndicator(snapshot: snapshot, display: mode, isStale: false)
            let rendered = image(for: indicator)
            rendered.isTemplate = false
            for appearance in ["Light", "Dark"] {
                let foreground = design.colors[appearance]!["menu-bar/foreground"]!.native
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(rendered.size.width * 2),
                                              pixelsHigh: Int(rendered.size.height * 2), bitsPerSample: 8,
                                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                bitmap.size = rendered.size
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                rendered.draw(in: NSRect(origin: .zero, size: rendered.size))
                foreground.setFill()
                NSRect(origin: .zero, size: rendered.size).fill(using: .sourceIn)
                NSGraphicsContext.restoreGraphicsState()
                let filename = "indicator-\(mode.rawValue)-\(appearance.lowercased()).png"
                try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(filename))
                metadata.append(["file": filename, "width": rendered.size.width, "height": rendered.size.height,
                                 "scale": 2, "font": font.fontName, "fontSize": font.pointSize])
            }
        }
        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("geometry.json"))
    }
}
