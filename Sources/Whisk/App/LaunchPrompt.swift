import Foundation

/// The window a launch opens on its own. Asking for the pasteboard comes
/// first and at every launch: nothing is recorded without it, and a
/// welcome seen on an earlier launch says nothing about a permission
/// still missing.
enum LaunchPrompt: Equatable {
    case clipboardAccess
    case welcome

    /// `accessWasAsked` holds from the moment the access window asked
    /// until the user saw it confirm. System Settings offers to quit and
    /// reopen the app when the setting changes: the launch that follows
    /// is where the confirmation is seen.
    static func atLaunch(access: PasteboardAccess, welcomeSeen: Bool, accessWasAsked: Bool) -> LaunchPrompt? {
        if access != .granted || accessWasAsked {
            return .clipboardAccess
        }
        return welcomeSeen ? nil : .welcome
    }

    /// What follows the access window once it closes.
    static func afterClipboardAccess(welcomeSeen: Bool) -> LaunchPrompt? {
        welcomeSeen ? nil : .welcome
    }
}
