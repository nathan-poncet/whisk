import AppKit
import SwiftUI

/// Per-application visual identity — icon and dominant tint — resolved from
/// a bundle identifier through NSWorkspace, so it stays in the frameworks
/// ring. Cached; call from the main thread only.
enum SourceAppStyle {
    struct Resolved {
        let icon: NSImage?
        let tint: Color
    }

    private static var cache: [String: Resolved] = [:]
    private static let fallback = Resolved(icon: nil, tint: Color(nsColor: .systemGray))

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
        let tint = dominantColor(of: icon).map { Color(nsColor: $0) } ?? fallback.tint
        return Resolved(icon: icon, tint: tint)
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
