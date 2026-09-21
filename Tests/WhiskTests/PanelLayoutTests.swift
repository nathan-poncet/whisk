import CoreGraphics
import Testing

@testable import Whisk

/// A screen as macOS reports it, in points: the frame, what is left once
/// the menu bar and the Dock are taken out, and the notch.
struct Display: CustomTestStringConvertible {
    let name: String
    let screen: PanelLayout.Screen

    var testDescription: String { name }

    /// The highest point free of the menu bar and the notch.
    var ceiling: CGFloat {
        min(screen.visibleFrame.maxY, screen.frame.maxY - screen.notchHeight)
    }

    init(
        _ name: String, x: CGFloat = 0, y: CGFloat = 0, width: CGFloat, height: CGFloat,
        menuBar: CGFloat, notch: CGFloat = 0, dockBelow: CGFloat = 0, dockLeft: CGFloat = 0
    ) {
        self.name = name
        let frame = CGRect(x: x, y: y, width: width, height: height)
        screen = PanelLayout.Screen(
            frame: frame,
            visibleFrame: CGRect(
                x: frame.minX + dockLeft, y: frame.minY + dockBelow,
                width: frame.width - dockLeft, height: frame.height - dockBelow - menuBar),
            notchHeight: notch)
    }
}

/// Every shape a Mac screen comes in: notched laptops at each scaling,
/// an older Air, externals from Full HD to an ultra-wide and a Pro
/// Display XDR, a portrait monitor, an iPad over Sidecar, secondary
/// screens with offset origins, and a hidden menu bar over a notch.
private let displays: [Display] = [
    Display("MacBook Air 13-inch (M2)", width: 1470, height: 956, menuBar: 32, notch: 32, dockBelow: 70),
    Display("MacBook Pro 14-inch", width: 1512, height: 982, menuBar: 37, notch: 37, dockBelow: 70),
    Display("MacBook Pro 16-inch", width: 1728, height: 1117, menuBar: 33, notch: 32, dockBelow: 70),
    Display("MacBook Pro 16-inch, larger text", width: 1496, height: 967, menuBar: 28, notch: 28),
    Display("MacBook Pro 16-inch, largest text", width: 1168, height: 755, menuBar: 22, notch: 22),
    Display("MacBook Air 13-inch (2020)", width: 1440, height: 900, menuBar: 24, dockBelow: 70),
    Display("Full HD at 1x, Dock on the left", width: 1920, height: 1080, menuBar: 24, dockLeft: 70),
    Display("27-inch 5K", width: 2560, height: 1440, menuBar: 24, dockBelow: 90),
    Display("Ultra-wide 34-inch left of the primary", x: -3440, y: -271, width: 3440, height: 1440, menuBar: 0),
    Display("Pro Display XDR", width: 3008, height: 1692, menuBar: 24),
    Display("Portrait Full HD above the primary", y: 1117, width: 1080, height: 1920, menuBar: 24),
    Display("iPad over Sidecar", x: 1728, y: 0, width: 1024, height: 768, menuBar: 24),
    Display("Notched laptop, menu bar hidden", width: 1512, height: 982, menuBar: 0, notch: 37),
]

/// The screens tall enough for the full-size preview: every external
/// monitor and the 16-inch laptop at its default scaling.
private let roomy = displays.filter {
    $0.screen.frame.height >= 1080 && !$0.name.contains("text")
}
private let sides = CardSize.allCases.map(\.side)

private func within(_ tolerance: CGFloat, _ a: CGFloat, _ b: CGFloat) -> Bool {
    abs(a - b) <= tolerance
}

@Suite struct PanelLayoutOnEveryScreen {
    @Test(arguments: displays, sides)
    func the_panel_spans_the_bottom_edge_of_its_screen(_ display: Display, side: CGFloat) {
        let layout = PanelLayout(screen: display.screen, cardSide: side)
        let frame = display.screen.frame

        #expect(layout.panel.minX == frame.minX)
        #expect(layout.panel.width == frame.width)
        #expect(layout.panel.minY == frame.minY)
        #expect(layout.panel.height == PanelLayout.panelHeight(forCardSide: side))
    }

    @Test(arguments: displays, sides)
    func the_preview_stays_inside_the_screen_clear_of_the_menu_bar_and_the_notch(_ display: Display, side: CGFloat) {
        let layout = PanelLayout(screen: display.screen, cardSide: side)

        #expect(display.screen.frame.insetBy(dx: -1, dy: -1).contains(layout.preview))
        #expect(layout.preview.maxY <= display.ceiling - PanelLayout.previewMargin + 0.5)
    }

    @Test(arguments: displays, sides)
    func the_preview_keeps_its_proportions_and_the_screens_horizontal_center(_ display: Display, side: CGFloat) {
        let layout = PanelLayout(screen: display.screen, cardSide: side)
        let nominal = PanelLayout.previewSize

        #expect(within(0.01, layout.preview.width / layout.preview.height, nominal.width / nominal.height))
        #expect(layout.preview.width <= nominal.width)
        #expect(layout.preview.height <= nominal.height)
        #expect(within(0.5, layout.preview.midX, display.screen.frame.midX))
    }

    @Test(arguments: roomy, sides)
    func the_preview_keeps_its_full_size_where_there_is_room(_ display: Display, side: CGFloat) {
        let layout = PanelLayout(screen: display.screen, cardSide: side)

        #expect(layout.preview.size == PanelLayout.previewSize)
    }

    @Test(arguments: roomy, sides)
    func the_preview_floats_midway_between_the_panel_and_the_top_of_the_screen(_ display: Display, side: CGFloat) {
        let layout = PanelLayout(screen: display.screen, cardSide: side)
        let below = layout.preview.minY - (layout.panel.maxY + PanelLayout.previewGap)
        let above = (display.ceiling - PanelLayout.previewMargin) - layout.preview.maxY

        #expect(below > 0)
        #expect(within(1, below, above))
    }

    @Test func a_short_screen_shrinks_the_preview_to_the_room_it_has() throws {
        let air = try #require(displays.first { $0.name == "MacBook Air 13-inch (2020)" })
        let layout = PanelLayout(screen: air.screen, cardSide: CardSize.medium.side)
        let floor = layout.panel.maxY + PanelLayout.previewGap
        let ceiling = air.ceiling - PanelLayout.previewMargin

        #expect(layout.preview.height == ceiling - floor)
        #expect(layout.preview.height == 384)
        #expect(layout.preview.width == 560)
        #expect(layout.preview.minY == floor)
        #expect(layout.preview.maxY == ceiling)
    }

    @Test func a_cramped_screen_keeps_the_preview_legible_and_lets_it_lean_on_the_panels_empty_band() throws {
        let cramped = try #require(displays.first { $0.name == "MacBook Pro 16-inch, largest text" })
        let layout = PanelLayout(screen: cramped.screen, cardSide: CardSize.large.side)
        let floor = layout.panel.maxY + PanelLayout.previewGap

        #expect(layout.preview.height == PanelLayout.previewMinimumHeight)
        #expect(layout.preview.width == 350)
        #expect(layout.preview.maxY == cramped.ceiling - PanelLayout.previewMargin)
        #expect(layout.preview.minY < floor)
        #expect(layout.preview.minY > layout.panel.maxY - PanelLayout.panelTopBand)
    }

    @Test func a_hidden_menu_bar_still_keeps_the_preview_out_of_the_notch() throws {
        let hidden = try #require(displays.first { $0.name == "Notched laptop, menu bar hidden" })
        let layout = PanelLayout(screen: hidden.screen, cardSide: CardSize.medium.side)

        #expect(hidden.screen.visibleFrame.maxY == hidden.screen.frame.maxY)
        #expect(layout.preview.maxY <= hidden.screen.frame.maxY - 37 - PanelLayout.previewMargin)
    }

    /// The report this settles: one Mac, a 16-inch built-in display and
    /// an ultra-wide to its left. Pinned to the bottom edge the preview
    /// crowded the menu bar on one and sat low in a sea of empty space on
    /// the other; now both screens get the same balance.
    @Test func the_built_in_display_and_the_ultra_wide_balance_the_preview_alike() throws {
        let builtIn = try #require(displays.first { $0.name == "MacBook Pro 16-inch" })
        let ultraWide = try #require(displays.first { $0.name.hasPrefix("Ultra-wide") })
        let side = CardSize.medium.side

        let onBuiltIn = PanelLayout(screen: builtIn.screen, cardSide: side)
        let onUltraWide = PanelLayout(screen: ultraWide.screen, cardSide: side)

        #expect(onBuiltIn.preview == CGRect(x: 514, y: 532, width: 700, height: 480))
        #expect(onUltraWide.preview == CGRect(x: -2070, y: 439, width: 700, height: 480))
        #expect(ultraWide.screen.frame.contains(onUltraWide.panel))
        #expect(ultraWide.screen.frame.contains(onUltraWide.preview))
    }

    @Test func the_panel_height_follows_the_card_side() {
        #expect(PanelLayout.panelHeight(forCardSide: 160) == 390)
        #expect(PanelLayout.panelHeight(forCardSide: 200) == 430)
        #expect(PanelLayout.panelHeight(forCardSide: 250) == 480)
    }

    @Test func the_layout_never_fails_on_an_absurd_screen() {
        let tiny = PanelLayout.Screen(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            visibleFrame: CGRect(x: 0, y: 0, width: 400, height: 276), notchHeight: 0)
        let layout = PanelLayout(screen: tiny, cardSide: CardSize.large.side)

        #expect(layout.preview.width > 0)
        #expect(layout.preview.height > 0)
        #expect(layout.preview.maxY <= 276 - PanelLayout.previewMargin)
        #expect(layout.preview.width <= 400 - 2 * PanelLayout.previewMargin)
    }
}
