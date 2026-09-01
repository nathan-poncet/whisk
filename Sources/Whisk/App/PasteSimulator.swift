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
            postCommandV()
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
        // Right after the global pop shortcut the user is still holding
        // ⌥⌘, and those hardware modifiers would merge into the synthetic
        // event — the app would receive ⌥⌘V and paste nothing. Suppressing
        // local keyboard events for the injection interval keeps the chord
        // clean, so the paste fires the instant the shortcut is pressed
        // (the technique Flycut and Maccy ship).
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
