import SwiftUI

/// Liquid Glass where the OS provides it (macOS 26+), translucent material
/// otherwise, so the app still runs back to macOS 14. Glass layers are
/// never scaled or shadowed here: transforming glass forces it to
/// re-rasterize every frame, which reads as flashing.
extension View {
    @ViewBuilder
    func liquidGlass(in shape: some Shape, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(liquidGlassStyle(tint: tint), in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}

@available(macOS 26.0, *)
private func liquidGlassStyle(tint: Color?) -> Glass {
    var glass = Glass.regular
    if let tint {
        glass = glass.tint(tint)
    }
    return glass
}
