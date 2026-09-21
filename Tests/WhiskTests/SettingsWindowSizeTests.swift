import CoreGraphics
import Testing

@testable import Whisk

/// The Settings window is never resized by hand, so what it gets when it
/// opens must already fit the screen it opens on.
@Suite struct SettingsWindowSizing {
    private let titleBar: CGFloat = 28

    @Test func the_settings_window_keeps_its_full_height_where_the_screen_has_room() {
        let onBuiltIn = SettingsWindowSize.content(visibleHeight: 1084, chromeHeight: titleBar)
        let onUltraWide = SettingsWindowSize.content(visibleHeight: 1440, chromeHeight: titleBar)

        #expect(onBuiltIn == CGSize(width: 560, height: 720))
        #expect(onUltraWide == CGSize(width: 560, height: 720))
    }

    @Test func a_short_screen_trims_the_settings_window_to_what_it_can_show() {
        // A 16-inch laptop at its largest-text scaling, Dock at the bottom:
        // 755 points less a 22-point menu bar and a 70-point Dock.
        let size = SettingsWindowSize.content(visibleHeight: 663, chromeHeight: titleBar)

        #expect(size.width == 560)
        #expect(size.height == 663 - titleBar - 2 * SettingsWindowSize.margin)
        #expect(size.height + titleBar + 2 * SettingsWindowSize.margin <= 663)
    }

    @Test func the_settings_window_never_shrinks_below_a_usable_height() {
        let size = SettingsWindowSize.content(visibleHeight: 300, chromeHeight: titleBar)

        #expect(size.height == SettingsWindowSize.minimumHeight)
        #expect(SettingsWindowSize.minimumHeight < SettingsWindowSize.height)
    }
}
