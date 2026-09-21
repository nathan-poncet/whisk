import CoreGraphics

/// The Settings window is never resized by hand, so its size is decided
/// when it opens, from the screen it opens on: the form's full height
/// where the screen has room, what the screen leaves otherwise — the
/// grouped form scrolls.
enum SettingsWindowSize {
    static let width: CGFloat = 560
    static let height: CGFloat = 720
    /// Below this the form would show little more than one section.
    static let minimumHeight: CGFloat = 360
    /// Breathing room above and below the window.
    static let margin: CGFloat = 24

    /// - Parameters:
    ///   - visibleHeight: the screen's height less the menu bar and the Dock.
    ///   - chromeHeight: the window's title bar.
    static func content(visibleHeight: CGFloat, chromeHeight: CGFloat) -> CGSize {
        let room = visibleHeight - chromeHeight - 2 * margin
        return CGSize(width: width, height: min(height, max(minimumHeight, room)))
    }
}
