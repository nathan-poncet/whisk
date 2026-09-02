import AppKit
import SwiftUI

/// Per-application visual identity — icon and dominant tint — resolved from
/// a bundle identifier through NSWorkspace, so it stays in the frameworks
/// ring. Cached; call from the main thread only.
enum SourceAppStyle {
    struct Resolved {
        let icon: NSImage?
        let tint: Color
        let darkSurfaceTint: Color
        let lightSurfaceTint: Color

        /// The frosted-surface wash: the app color leaning darker on the
        /// dark theme, lighter and softer on the light one, translucent so
        /// the behind-window blur still reads through.
        func surfaceTint(dark: Bool) -> Color {
            dark ? darkSurfaceTint : lightSurfaceTint
        }
    }

    private static var cache: [String: Resolved] = [:]
    private static let fallback = resolved(icon: nil, base: .systemGray)

    static func resolve(bundleID: String?) -> Resolved {
        guard let bundleID else { return fallback }
        if let cached = cache[bundleID] {
            return cached
        }
        let resolved = compute(bundleID: bundleID)
        cache[bundleID] = resolved
        return resolved
    }

    private static func compute(bundleID: String) -> Resolved {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return fallback
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return resolved(icon: icon, base: dominantColor(of: icon) ?? .systemGray)
    }

    private static func resolved(icon: NSImage?, base: NSColor) -> Resolved {
        Resolved(
            icon: icon,
            tint: Color(nsColor: base),
            darkSurfaceTint: Color(nsColor: shifted(base, saturation: 1, brightness: 0.6)).opacity(0.38),
            lightSurfaceTint: Color(nsColor: shifted(base, saturation: 0.55, brightness: 1.55)).opacity(0.45)
        )
    }

    private static func shifted(_ color: NSColor, saturation: CGFloat, brightness: CGFloat) -> NSColor {
        let base = color.usingColorSpace(.sRGB) ?? color
        return NSColor(
            hue: base.hueComponent,
            saturation: min(1, base.saturationComponent * saturation),
            brightness: min(1, base.brightnessComponent * brightness),
            alpha: 1
        )
    }

    private static func dominantColor(of image: NSImage) -> NSColor? {
        guard let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0 else { return nil }
        let step = max(1, min(width, height) / 24)
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var weight = 0.0
        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                guard let sample = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                    sample.alphaComponent > 0.5
                else { continue }
                // Colorful pixels dominate so white and gray chrome doesn't
                // wash the tint out.
                let pixelWeight = 0.15 + sample.saturationComponent
                red += sample.redComponent * pixelWeight
                green += sample.greenComponent * pixelWeight
                blue += sample.blueComponent * pixelWeight
                weight += pixelWeight
            }
        }
        guard weight > 0 else { return nil }
        let average = NSColor(srgbRed: red / weight, green: green / weight, blue: blue / weight, alpha: 1)
        return tamed(average)
    }

    /// Enough saturation to feel branded, bounded brightness so vibrant
    /// text stays legible on the glass.
    private static func tamed(_ color: NSColor) -> NSColor {
        NSColor(
            hue: color.hueComponent,
            saturation: min(max(color.saturationComponent, 0.35), 0.75),
            brightness: min(max(color.brightnessComponent, 0.45), 0.72),
            alpha: 1
        )
    }
}
