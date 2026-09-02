import AppKit
import SwiftUI

/// The panel's surfaces — cards, chips, search — are frosted glass over
/// whatever sits behind the WINDOW: SwiftUI materials only blur in-window
/// content (nothing, in a transparent panel), so the blur comes from an
/// NSVisualEffectView blending behind the window. Backdrop layers do not
/// survive SwiftUI masks or opacity groups — the system silently drops
/// the blur — so the rounding happens on the effect view's own layer.
/// A nil corner radius means capsule (half the height).
extension View {
    func liquidGlass(
        in shape: some Shape, cornerRadius: CGFloat? = nil, tint: Color? = nil
    ) -> some View {
        modifier(
            LiquidGlassModifier(shape: AnyShape(shape), cornerRadius: cornerRadius, tint: tint)
        )
    }
}

private struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let shape: AnyShape
    let cornerRadius: CGFloat?
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BehindWindowBlur(cornerRadius: cornerRadius)
                    shape.fill(
                        tint
                            ?? (scheme == .dark
                                ? Color.black.opacity(0.25) : Color.white.opacity(0.3))
                    )
                }
            }
            // A plain hairline in the theme's inverse color keeps dark
            // surfaces legible on dark backdrops and light on light.
            .overlay(
                shape.stroke(
                    scheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.28),
                    lineWidth: 0.5
                )
            )
    }
}

/// Blurs the content behind the window itself — other applications, the
/// desktop — which in-window SwiftUI materials cannot reach.
private struct BehindWindowBlur: NSViewRepresentable {
    let cornerRadius: CGFloat?

    func makeNSView(context: Context) -> BackdropView {
        let view = BackdropView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        view.wantsLayer = true
        view.cornerRadius = cornerRadius
        return view
    }

    func updateNSView(_ view: BackdropView, context: Context) {
        view.cornerRadius = cornerRadius
    }
}

final class BackdropView: NSVisualEffectView {
    /// The blur radius in pixels — the dial the public API never exposes:
    /// the system's own gaussian (~30 px, all or nothing) is swapped for a
    /// Core Image one on the backdrop layer. If the layer tree changes in
    /// a future macOS, the swap silently fails and the stock material
    /// remains — degraded, never broken.
    static let blurRadius: Double = 16

    var cornerRadius: CGFloat? {
        didSet { needsLayout = true }
    }

    private var maskKey = ""

    private var blurTuned = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        tuneBlur()
    }

    override func updateLayer() {
        super.updateLayer()
        tuneBlur()
    }

    /// The window server only honors its own filter class on backdrop
    /// layers — public CIFilters are silently ignored — so the gaussian is
    /// swapped through runtime lookup. Any failure leaves the stock
    /// material untouched.
    private func tuneBlur() {
        guard !blurTuned, let backdrop = Self.findBackdropLayer(in: layer) else { return }
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return }
        let selector = NSSelectorFromString("filterWithType:")
        guard filterClass.responds(to: selector),
            let blur = filterClass.perform(selector, with: "gaussianBlur")?
                .takeUnretainedValue() as? NSObject
        else { return }
        blur.setValue(Self.blurRadius, forKey: "inputRadius")
        blur.setValue(true, forKey: "inputNormalizeEdges")
        backdrop.filters = [blur]
        blurTuned = true
        #if DEBUG
            NSLog("WHISK-BLUR gaussian tuned to %.0f px", Self.blurRadius)
        #endif
    }

    private static func findBackdropLayer(in layer: CALayer?) -> CALayer? {
        guard let layer else { return nil }
        if String(describing: type(of: layer)).contains("Backdrop") {
            return layer
        }
        for sublayer in layer.sublayers ?? [] {
            if let found = findBackdropLayer(in: sublayer) {
                return found
            }
        }
        return nil
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.height > 0 else { return }
        let radius = cornerRadius ?? bounds.height / 2
        let key = "\(bounds.size)-\(radius)"
        guard key != maskKey else { return }
        maskKey = key
        let mask = NSImage(size: bounds.size)
        mask.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: bounds.size),
            xRadius: radius,
            yRadius: radius
        ).fill()
        mask.unlockFocus()
        maskImage = mask
    }
}
