// Regenerates Assets/AppIcon.icns. Run from the repository root:
//   swift scripts/generate-icon.swift
import AppKit

let masterSize: CGFloat = 1024

// A chasen — the bamboo matcha whisk the app is named after: handle on
// top, thread binding, tines fanning down into a bell.
func drawMaster() -> NSImage {
    let image = NSImage(size: NSSize(width: masterSize, height: masterSize))
    image.lockFocus()

    // Apple's icon grid keeps roughly a tenth of the canvas as margin.
    let inset: CGFloat = 100
    let plate = NSRect(x: inset, y: inset, width: masterSize - inset * 2, height: masterSize - inset * 2)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185)
    NSGradient(
        starting: NSColor(srgbRed: 0.58, green: 0.74, blue: 0.44, alpha: 1),
        ending: NSColor(srgbRed: 0.25, green: 0.42, blue: 0.22, alpha: 1)
    )?.draw(in: platePath, angle: -70)

    let cx = masterSize / 2
    NSColor.white.set()

    for i in -4...4 {
        let offset = CGFloat(i)
        let tine = NSBezierPath()
        tine.lineWidth = 16
        tine.lineCapStyle = .round
        tine.move(to: NSPoint(x: cx + offset * 11, y: 520))
        tine.curve(
            to: NSPoint(x: cx + offset * 41, y: 240 + abs(offset) * 10),
            controlPoint1: NSPoint(x: cx + offset * 17, y: 460),
            controlPoint2: NSPoint(x: cx + offset * 38, y: 320)
        )
        tine.stroke()
    }

    let binding = NSBezierPath(
        roundedRect: NSRect(x: cx - 68, y: 500, width: 136, height: 58),
        xRadius: 24,
        yRadius: 24
    )
    binding.fill()

    let handle = NSBezierPath(
        roundedRect: NSRect(x: cx - 47, y: 540, width: 94, height: 230),
        xRadius: 42,
        yRadius: 42
    )
    handle.fill()

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
