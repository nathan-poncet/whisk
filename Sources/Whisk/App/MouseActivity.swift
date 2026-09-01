import Foundation

/// Scrolling slides content under a stationary pointer, which fires hover
/// events the user never asked for — arrowing to the rail's edge would
/// snap the selection right back to whatever lands under the mouse. Hover
/// may steal focus only when the pointer itself moved a moment ago.
enum MouseActivity {
    static var lastMove = Date.distantPast

    static var movedRecently: Bool {
        Date().timeIntervalSince(lastMove) < 0.2
    }
}
