// Regenerates Assets/AppIcon.icns. Run from the repository root:
//   swift scripts/generate-icon.swift
import AppKit

let masterSize: CGFloat = 1024

// The same mark as the landing page: the matcha bowl emoji on the
// site's dark ground, lit by its green glow.
func drawMaster() -> NSImage {
    let image = NSImage(size: NSSize(width: masterSize, height: masterSize))
    image.lockFocus()

    // Apple's icon grid keeps roughly a tenth of the canvas as margin.
    let inset: CGFloat = 100
    let plate = NSRect(x: inset, y: inset, width: masterSize - inset * 2, height: masterSize - inset * 2)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185)
    NSColor(srgbRed: 0.043, green: 0.059, blue: 0.051, alpha: 1).set()
    platePath.fill()

    NSGraphicsContext.current?.saveGraphicsState()
    platePath.addClip()
    NSGradient(
        starting: NSColor(srgbRed: 0.498, green: 0.847, blue: 0.643, alpha: 0.38),
        ending: NSColor(srgbRed: 0.498, green: 0.847, blue: 0.643, alpha: 0)
    )?.draw(
        fromCenter: NSPoint(x: masterSize * 0.32, y: masterSize * 0.72), radius: 0,
        toCenter: NSPoint(x: masterSize * 0.32, y: masterSize * 0.72), radius: masterSize * 0.62,
        options: []
    )
    NSGradient(
        starting: NSColor(srgbRed: 0.247, green: 0.616, blue: 0.408, alpha: 0.30),
        ending: NSColor(srgbRed: 0.247, green: 0.616, blue: 0.408, alpha: 0)
    )?.draw(
        fromCenter: NSPoint(x: masterSize * 0.74, y: masterSize * 0.30), radius: 0,
        toCenter: NSPoint(x: masterSize * 0.74, y: masterSize * 0.30), radius: masterSize * 0.55,
        options: []
    )
    NSGraphicsContext.current?.restoreGraphicsState()

    let glyph = NSAttributedString(
        string: "\u{1F375}",
        attributes: [.font: NSFont.systemFont(ofSize: 560)]
    )
    let size = glyph.size()
    glyph.draw(
        at: NSPoint(x: (masterSize - size.width) / 2, y: (masterSize - size.height) / 2)
    )

    image.unlockFocus()
    return image
}

func png(of master: NSImage, pixels: Int) -> Data? {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    master.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let master = drawMaster()
let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: "Assets/AppIcon.iconset")
let output = URL(fileURLWithPath: "Assets/AppIcon.icns")
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let suffix = scale == 2 ? "@2x" : ""
        guard let data = png(of: master, pixels: pixels) else {
            fputs("could not render \(pixels)px\n", stderr)
            exit(1)
        }
        try data.write(to: iconset.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? fileManager.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else {
    fputs("iconutil failed\n", stderr)
    exit(1)
}
print("wrote \(output.path)")
