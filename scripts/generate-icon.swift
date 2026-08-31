// Regenerates Assets/AppIcon.icns. Run from the repository root:
//   swift scripts/generate-icon.swift
import AppKit

let masterSize: CGFloat = 1024

func drawMaster() -> NSImage {
    let image = NSImage(size: NSSize(width: masterSize, height: masterSize))
    image.lockFocus()

    // Apple's icon grid keeps roughly a tenth of the canvas as margin.
    let inset: CGFloat = 100
    let plate = NSRect(x: inset, y: inset, width: masterSize - inset * 2, height: masterSize - inset * 2)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185)
    NSGradient(
        starting: NSColor(srgbRed: 0.38, green: 0.36, blue: 0.94, alpha: 1),
        ending: NSColor(srgbRed: 0.17, green: 0.64, blue: 0.90, alpha: 1)
    )?.draw(in: platePath, angle: -70)

    if let symbol = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 420, weight: .medium))
    {
        let glyphBox = NSRect(x: masterSize * 0.27, y: masterSize * 0.26, width: masterSize * 0.46, height: masterSize * 0.48)
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.draw(in: glyphBox, from: .zero, operation: .sourceOver, fraction: 1)
    }

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
