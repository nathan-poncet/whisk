import Testing

@testable import Whisk

@Suite struct LaunchPrompts {
    @Test func a_launch_without_clipboard_access_asks_for_it_however_often_whisk_was_opened() {
        for access in [PasteboardAccess.requiresConsent, .denied] {
            for welcomeSeen in [false, true] {
                #expect(
                    LaunchPrompt.atLaunch(access: access, welcomeSeen: welcomeSeen, accessWasAsked: false)
                        == .clipboardAccess)
            }
        }
    }

    @Test func access_allowed_between_two_launches_is_confirmed_at_the_next() {
        #expect(LaunchPrompt.atLaunch(access: .granted, welcomeSeen: true, accessWasAsked: true) == .clipboardAccess)
        #expect(LaunchPrompt.atLaunch(access: .granted, welcomeSeen: false, accessWasAsked: true) == .clipboardAccess)
    }

    @Test func a_first_launch_with_the_clipboard_open_shows_the_welcome() {
        #expect(LaunchPrompt.atLaunch(access: .granted, welcomeSeen: false, accessWasAsked: false) == .welcome)
    }

    @Test func a_later_launch_with_the_clipboard_open_shows_nothing() {
        #expect(LaunchPrompt.atLaunch(access: .granted, welcomeSeen: true, accessWasAsked: false) == nil)
    }

    @Test func the_welcome_follows_the_access_window_on_a_first_launch_only() {
        #expect(LaunchPrompt.afterClipboardAccess(welcomeSeen: false) == .welcome)
        #expect(LaunchPrompt.afterClipboardAccess(welcomeSeen: true) == nil)
    }
}
