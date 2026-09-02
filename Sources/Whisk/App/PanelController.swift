import AppKit
import SwiftUI

/// Paste-style panel pinned to the bottom of the main screen. Non-activating,
/// so the frontmost application keeps focus while the user picks an item.
final class PanelController {
    private let panel: FloatingPanel
    private let stateStore: HistoryViewStateStore
    private let actions: PanelActions
    private let keyBindings: KeyBindingsStore
    private var previewPanel: NSPanel?

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
        // The panel also closes behind the controller's back — Esc and
        // resignKey order it out directly — and the preview must never
        // outlive it.
        panel.onClose = { [weak self] in
            self?.hidePreview()
            self?.stateStore.panelDidClose()
        }
        // Hover-selection listens to this: only real pointer movement may
        // steal the keyboard selection (see MouseActivity).
        panel.acceptsMouseMovedEvents = true
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            MouseActivity.lastMove = Date()
            return event
        }
    }

    private var mouseMonitor: Any?

    /// Routes panel keys through the user's bindings, intercepted ahead of
    /// the search field's caret.
    private func handle(_ event: NSEvent) -> Bool {
        let panelActions: [(KeyAction, () -> Void)] = [
            (.pastePlain, { self.actions.activatePlain() }),
            (.pasteSelection, { self.actions.activate() }),
            (.previousCard, { self.actions.navigate(.left) }),
            (.nextCard, { self.actions.navigate(.right) }),
            (.rowUp, { self.actions.navigate(.up) }),
            (.rowDown, { self.actions.navigate(.down) }),
            (.switchChipGroup, { self.actions.switchChipGroup() }),
            (.pinSelection, { self.actions.togglePinSelected() }),
            (.deleteSelection, { self.actions.deleteSelected() }),
            (.stackSelection, { self.actions.stackSelected() }),
        ]
        for (action, perform) in panelActions where keyBindings.binding(for: action).matches(event) {
            perform()
            return true
        }
        if let index = commandDigitIndex(of: event) {
            actions.activateCard(index)
            return true
        }
        // If the user rebinds preview to the bare space bar, a space while
        // a query is being typed must stay a space.
        if keyBindings.binding(for: .previewSelection).matches(event) {
            if event.keyCode == UInt16(49), !stateStore.state.query.isEmpty {
                return false
            }
            togglePreview()
            return true
        }
        // Keypad Enter always pastes, whatever Return is bound to.
        if event.specialKey == .enter {
            actions.activate()
            return true
        }
        return false
    }

    /// ⌘ + the digit the user actually typed → rail position 0…8. Shift is
    /// allowed and applied, so layouts whose digits live on shift
    /// (Programmer Dvorak, AZERTY) use their real digit keys — never the
    /// physical QWERTY positions.
    private func commandDigitIndex(of event: NSEvent) -> Int? {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers == .command || modifiers == [.command, .shift] else { return nil }
        let typed =
            modifiers.contains(.shift)
            ? event.characters(byApplyingModifiers: .shift)
            : event.charactersIgnoringModifiers
        guard let character = typed?.first,
            let digit = character.wholeNumberValue,
            (1...9).contains(digit)
        else { return nil }
        return digit - 1
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
        resetDragGhost()
        // The full frame, not visibleFrame: the panel floats above the
        // Dock, flush with the physical bottom edge of the screen.
        let frame = screen.frame
        let height: CGFloat = 414
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

    private var ghostFadeTimer: Timer?
    private var dragEndWatcher: Timer?

    /// A drag needs the whole screen: the panel fades out and lets events
    /// through, so the item can land on whatever it was covering. The
    /// window itself must survive — ordering it out would kill the drag
    /// session it hosts — so it only closes for real once the button is
    /// released. Timers ride the .common run-loop modes because a drag
    /// session runs the tracking mode, where default-mode timers stall.
    func dragDidBegin() {
        guard panel.isVisible, dragEndWatcher == nil else { return }
        hidePreview()
        // One beat after session start, so the system has already
        // snapshotted the drag image from the still-opaque card.
        let fade = Timer(timeInterval: 0.03, repeats: false) { [weak self] _ in
            guard let self else { return }
            panel.ignoresMouseEvents = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.panel.animator().alphaValue = 0
            }
        }
        ghostFadeTimer = fade
        RunLoop.main.add(fade, forMode: .common)
        // SwiftUI's onDrag never reports the session's end; the mouse
        // button is the signal — released means dropped or cancelled.
        let watcher = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            if NSEvent.pressedMouseButtons & 1 == 0 {
                self?.dragDidEnd()
            }
        }
        dragEndWatcher = watcher
        RunLoop.main.add(watcher, forMode: .common)
    }

    /// Dropping consumes the selection like Return does: the panel closes
    /// rather than reappearing over the freshly dropped item.
    private func dragDidEnd() {
        panel.orderOut(nil)
        resetDragGhost()
    }

    private func resetDragGhost() {
        ghostFadeTimer?.invalidate()
        ghostFadeTimer = nil
        dragEndWatcher?.invalidate()
        dragEndWatcher = nil
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
    }

    /// Quick-Look-style preview of the selected card, centered above the
    /// panel.
    private func togglePreview() {
        if previewPanel?.isVisible == true {
            hidePreview()
            return
        }
        if previewPanel == nil {
            let preview = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            preview.isFloatingPanel = true
            preview.level = .statusBar
            preview.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            preview.backgroundColor = .clear
            preview.isOpaque = false
            preview.hasShadow = false
            preview.contentView = NSHostingView(rootView: PreviewOverlayView(store: stateStore))
            previewPanel = preview
        }
        guard let preview = previewPanel, let screen = NSScreen.main else { return }
        let size = NSSize(width: 700, height: 480)
        let frame = screen.frame
        preview.setFrame(
            NSRect(
                x: frame.midX - size.width / 2,
                y: frame.minY + 460,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        preview.orderFront(nil)
    }

    private func hidePreview() {
        previewPanel?.orderOut(nil)
    }
}

final class FloatingPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?
    var onClose: (() -> Void)?

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

    override func orderOut(_ sender: Any?) {
        // resignKey and cancelOperation both funnel here: only a window
        // that was actually visible notifies, once.
        let wasVisible = isVisible
        super.orderOut(sender)
        if wasVisible {
            onClose?()
        }
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }
}
