import ApplicationServices
import Carbon.HIToolbox
import Foundation

/// Sends ⌘V to the frontmost application. The first attempt without
/// Accessibility access shows the system prompt once; until access is
/// granted, a selection still lands on the pasteboard for a manual paste.
enum PasteSimulator {
    private static var didPromptForAccess = false

    static func paste() {
        guard trusted() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            postCommandVWhenChordReleased(attempt: 0)
        }
    }

    /// Right after the global pop shortcut the user is still holding ⌥ —
    /// a ⌘V posted at that instant reaches the app as ⌥⌘V and pastes
    /// nothing. Wait for ⌥/⇧/⌃ to lift before posting; ⌘ may stay held,
    /// it is part of the chord being sent.
    private static func postCommandVWhenChordReleased(attempt: Int) {
        let held = CGEventSource.flagsState(.combinedSessionState)
        let conflicting: CGEventFlags = [.maskAlternate, .maskShift, .maskControl]
        if held.intersection(conflicting).isEmpty || attempt >= 40 {
            postCommandV()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            postCommandVWhenChordReleased(attempt: attempt + 1)
        }
    }

    private static func trusted() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        guard !didPromptForAccess else { return false }
        didPromptForAccess = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func postCommandV() {
        let keyCode = KeyboardLayout.keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
