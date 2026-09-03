import AppKit
import SwiftUI

extension View {
    /// The pointing hand over anything that acts on click. PointerStyle
    /// arrived in macOS 15; earlier systems keep the arrow.
    @ViewBuilder func linkPointer() -> some View {
        if #available(macOS 15, *) {
            pointerStyle(.link)
        } else {
            self
        }
    }

    /// The open hand over anything that can be picked up and dragged.
    @ViewBuilder func grabPointer() -> some View {
        if #available(macOS 15, *) {
            pointerStyle(.grabIdle)
        } else {
            self
        }
    }
}

extension Color {
    /// The landing page's matcha accent: its pale green (#7fd8a4) glows on
    /// dark backdrops but washes out on light ones, so the light theme
    /// deepens to a darker leaf (#1e8248).
    static let matcha = Color(
        nsColor: NSColor(
            name: nil,
            dynamicProvider: { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 127 / 255, green: 216 / 255, blue: 164 / 255, alpha: 1)
                    : NSColor(srgbRed: 30 / 255, green: 130 / 255, blue: 72 / 255, alpha: 1)
            }
        )
    )
}
