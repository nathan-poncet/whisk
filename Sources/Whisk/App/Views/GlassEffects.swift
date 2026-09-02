import SwiftUI

/// The panel's surfaces — cards, chips, search — are frosted material:
/// it blurs whatever sits behind them and follows the OS theme, never the
/// backdrop's luminance (glassEffect's per-pixel adaptivity made
/// neighboring chips flip light and dark depending on the window
/// underneath). Only an explicit tint — the active chip's accent — adds
/// color on top.
extension View {
    func liquidGlass(in shape: some Shape, tint: Color? = nil) -> some View {
        modifier(LiquidGlassModifier(shape: AnyShape(shape), tint: tint))
    }
}

private struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let shape: AnyShape
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.thinMaterial)
                    if let tint {
                        shape.fill(tint)
                    }
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
