import AppKit
import SwiftUI

/// Paste-style panel pinned to the bottom of the main screen. Non-activating,
/// so the frontmost application keeps focus while the user picks an item.
final class PanelController {
    private let panel: FloatingPanel
    private let stateStore: HistoryViewStateStore
    private let actions: PanelActions
    private let keyBindings: KeyBindingsStore

    init(stateStore: HistoryViewStateStore, actions: PanelActions, keyBindings: KeyBindingsStore) {
        self.stateStore = stateStore
        self.actions = actions
        self.keyBindings = keyBindings
        panel = FloatingPanel()
        panel.contentView = NSHostingView(
            rootView: HistoryPanelView(store: stateStore, actions: actions)
        )
        panel.keyHandler = { [weak self] event in
            self?.handle(event) ?? false
        }
    }

    /// Routes panel keys through the user's bindings, intercepted ahead of
    /// the search field's caret.
    private func handle(_ event: NSEvent) -> Bool {
        let panelActions: [(KeyAction, () -> Void)] = [
            (.pasteSelection, { self.actions.activate() }),
            (.previousCard, { self.actions.navigate(.left) }),
            (.nextCard, { self.actions.navigate(.right) }),
            (.rowUp, { self.actions.navigate(.up) }),
            (.rowDown, { self.actions.navigate(.down) }),
            (.pinSelection, { self.actions.togglePinSelected() }),
            (.deleteSelection, { self.actions.deleteSelected() }),
        ]
        for (action, perform) in panelActions where keyBindings.binding(for: action).matches(event) {
            perform()
            return true
        }
        if let index = commandDigitIndex(of: event) {
            actions.activateCard(index)
            return true
        }
        // Keypad Enter always pastes, whatever Return is bound to.
        if event.specialKey == .enter {
            actions.activate()
            return true
        }
        return false
    }

    /// ⌘1…⌘9 → rail position 0…8, resolved by typed character first and by
    /// physical ANSI position for layouts whose digits live on shift.
    private func commandDigitIndex(of event: NSEvent) -> Int? {
        guard event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command else {
            return nil
        }
        if let character = event.charactersIgnoringModifiers?.first,
            let digit = character.wholeNumberValue, (1...9).contains(digit)
        {
            return digit - 1
        }
        let ansiDigits: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9]
        if let digit = ansiDigits[event.keyCode] {
            return digit - 1
        }
        return nil
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let screen = NSScreen.main else { return }
        // The full frame, not visibleFrame: the panel floats above the
        // Dock, flush with the physical bottom edge of the screen.
        let frame = screen.frame
        let height: CGFloat = 444
        panel.setFrame(
            NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: height),
            display: true
        )
        actions.panelWillShow()
        stateStore.requestSearchFocus()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }
}

final class FloatingPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }

    // Intercepted ahead of the responder chain: the field editor would
    // otherwise swallow arrow keys for caret movement.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyHandler?(event) == true {
            return
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }
}
