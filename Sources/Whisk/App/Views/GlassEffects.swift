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

    private func tuneBlur() {
        guard !blurTuned else { return }
        blurTuned = BackdropBlurTuner.tune(layer, radius: Self.blurRadius)
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

/// The window server only honors its own filter class on backdrop layers —
/// public CIFilters are silently ignored — so the gaussian is swapped
/// through runtime lookup. Any failure leaves the stock material untouched.
enum BackdropBlurTuner {
    static func tune(_ layer: CALayer?, radius: Double) -> Bool {
        guard let backdrop = backdropLayer(in: layer) else { return false }
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return false }
        let selector = NSSelectorFromString("filterWithType:")
        guard filterClass.responds(to: selector),
            let blur = filterClass.perform(selector, with: "gaussianBlur")?
                .takeUnretainedValue() as? NSObject
        else { return false }
        blur.setValue(radius, forKey: "inputRadius")
        blur.setValue(true, forKey: "inputNormalizeEdges")
        backdrop.filters = [blur]
        #if DEBUG
            NSLog("WHISK-BLUR gaussian tuned to %.0f px", radius)
        #endif
        return true
    }

    static func backdropLayer(in layer: CALayer?) -> CALayer? {
        guard let layer else { return nil }
        if String(describing: type(of: layer)).contains("Backdrop") {
            return layer
        }
        for sublayer in layer.sublayers ?? [] {
            if let found = backdropLayer(in: sublayer) {
                return found
            }
        }
        return nil
    }
}

/// The panel's veil: a REAL behind-window blur — SwiftUI materials only
/// blur in-window content, which a transparent panel doesn't have — masked
/// by a vertical gradient: nothing at the top, the plateau from the first
/// quarter down. The plateau sits at FULL alpha: partial alpha only blends
/// sharp text with blur and stays readable — the strength dial is the
/// radius, never the mask.
struct GradientBlurVeil: NSViewRepresentable {
    func makeNSView(context: Context) -> GradientVeilView {
        let view = GradientVeilView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: GradientVeilView, context: Context) {}
}

final class GradientVeilView: NSVisualEffectView {
    static let blurRadius: Double = 5
    static let plateauAlpha: CGFloat = 1
    /// Fraction of the height, measured from the top, where the ramp ends.
    static let rampEnd: CGFloat = 0.25

    private var blurTuned = false
    private var maskKey = ""

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        tuneBlur()
    }

    override func updateLayer() {
        super.updateLayer()
        tuneBlur()
    }

    private func tuneBlur() {
        if !blurTuned {
            blurTuned = BackdropBlurTuner.tune(layer, radius: Self.blurRadius)
        }
        if blurTuned {
            hideTintLayers()
        }
    }

    /// The material composites color washes as SIBLINGS of the backdrop
    /// layer, one container down — two gray fills and a CAChameleonLayer.
    /// The veil wants the blur alone, so every sibling is hidden; the
    /// system re-adds them on appearance changes, hence on every
    /// updateLayer.
    private func hideTintLayers() {
        guard let backdrop = BackdropBlurTuner.backdropLayer(in: layer),
            let container = backdrop.superlayer
        else { return }
        for sublayer in container.sublayers ?? [] where sublayer !== backdrop {
            sublayer.isHidden = true
        }
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.height > 0 else { return }
        let key = "\(bounds.size)"
        guard key != maskKey else { return }
        maskKey = key
        let mask = NSImage(size: bounds.size)
        mask.lockFocus()
        // Unflipped image coordinates: location 0 is the bottom edge.
        NSGradient(
            colorsAndLocations: (NSColor.white.withAlphaComponent(Self.plateauAlpha), 0),
            (NSColor.white.withAlphaComponent(Self.plateauAlpha), 1 - Self.rampEnd),
            (NSColor.white.withAlphaComponent(0), 1)
        )?.draw(in: NSRect(origin: .zero, size: bounds.size), angle: 90)
        mask.unlockFocus()
        maskImage = mask
    }
}
