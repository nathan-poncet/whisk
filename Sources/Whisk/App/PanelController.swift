import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Paste-style panel pinned to the bottom of the main screen. Non-activating,
/// so the frontmost application keeps focus while the user picks an item.
final class PanelController {
    private let panel: FloatingPanel
    private let stateStore: HistoryViewStateStore
    private let actions: PanelActions
    private let keyBindings: KeyBindingsStore
    private var previewPanel: NSPanel?

    /// The blur veil lives in its own window behind the panel: the panel's
    /// closing animation shrinks its content, but the veil must hold
    /// perfectly still and only fade.
    private let veilPanel: NSPanel = {
        let veil = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        veil.isFloatingPanel = true
        veil.level = .statusBar
        veil.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        veil.backgroundColor = .clear
        veil.isOpaque = false
        veil.hasShadow = false
        veil.ignoresMouseEvents = true
        veil.contentView = NSHostingView(rootView: GradientBlurVeil())
        return veil
    }()

    /// Stale fade-out completions must never order out a veil that a
    /// newer show already brought back.
    private var veilGeneration = 0

    private let vimMode: () -> Bool
    private let vimBindings: VimBindingsStore

    init(
        stateStore: HistoryViewStateStore, actions: PanelActions, keyBindings: KeyBindingsStore,
        vimBindings: VimBindingsStore, vimMode: @escaping () -> Bool
    ) {
        self.stateStore = stateStore
        self.actions = actions
        self.keyBindings = keyBindings
        self.vimBindings = vimBindings
        self.vimMode = vimMode
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
            self?.fadeOutVeil()
            self?.stateStore.panelDidClose()
        }
        // In vim navigation Esc walks back one mode — SEARCH to NORMAL —
        // before it may close anything, and abandons the query on the way
        // out, exactly like Esc during a / search.
        panel.onCancel = { [weak self] in
            guard let self, stateStore.vimEnabled, stateStore.searchActive else { return false }
            actions.search("")
            stateStore.setSearchActive(false)
            return true
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

    /// A two-key vim sequence in flight (gg, dd) and when it started.
    private var vimPendingKey: (key: String, at: Date)?

    /// The vim layer: active only in normal mode, only for bare keys —
    /// chords fall through to the user's bindings. Bindings come from the
    /// editable keymap and are matched by what the keys type, so any
    /// layout works; digits ride the same rule (AZERTY reaches them with
    /// Shift, which stays allowed).
    private func handleVimNormal(_ event: NSEvent) -> Bool {
        guard stateStore.vimEnabled, !stateStore.searchActive else { return false }
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
            return false
        }
        guard let typed = event.charactersIgnoringModifiers, !typed.isEmpty else { return false }
        if event.keyCode == UInt16(kVK_Tab) {
            actions.switchChipGroup()
            return true
        }
        let pending = vimPendingKey
        vimPendingKey = nil
        let prefix = pending.flatMap { Date().timeIntervalSince($0.at) < 0.8 ? $0.key : nil }
        // The sequence first (gd is nothing, gg jumps), then the bare key,
        // then a fresh sequence start.
        if let prefix, let action = vimBindings.action(for: prefix + typed) {
            perform(action)
            return true
        }
        if let action = vimBindings.action(for: typed) {
            perform(action)
            return true
        }
        if vimBindings.isSequencePrefix(typed) {
            vimPendingKey = (typed, Date())
            return true
        }
        if typed == "/" {
            stateStore.setSearchActive(true)
            return true
        }
        if typed.count == 1, let digit = typed.first?.wholeNumberValue, (1...9).contains(digit) {
            actions.activateCard(digit - 1)
            return true
        }
        // Unmapped printable keys die silently, vim-style; control and
        // function keys continue to the user's bindings.
        guard let scalar = typed.unicodeScalars.first else { return false }
        return scalar.value >= 0x20 && scalar.value < 0xF700
    }

    private func perform(_ action: VimAction) {
        switch action {
        case .previousCard: actions.navigate(.left)
        case .nextCard: actions.navigate(.right)
        case .rowUp: actions.navigate(.up)
        case .rowDown: actions.navigate(.down)
        case .firstCard: actions.jumpToEdge(.start)
        case .lastCard: actions.jumpToEdge(.end)
        case .paste: actions.activate()
        case .pastePlain: actions.activatePlain()
        case .preview: togglePreview()
        case .stackToggle: actions.stackSelected()
        case .pinToggle: actions.togglePinSelected()
        case .deleteSelection: actions.deleteSelected()
        case .search: stateStore.setSearchActive(true)
        case .clearSearch: actions.search("")
        case .closePanel: hide()
        }
    }

    /// Routes panel keys through the user's bindings, intercepted ahead of
    /// the search field's caret.
    private func handle(_ event: NSEvent) -> Bool {
        // Vim's search commits like /: Return keeps the query and filter
        // and returns to normal mode — the paste stays one p away.
        if stateStore.vimEnabled, stateStore.searchActive,
            event.specialKey == .carriageReturn || event.specialKey == .enter
        {
            stateStore.setSearchActive(false)
            return true
        }
        if handleVimNormal(event) {
            return true
        }
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
        // Taller than the content: the top band is empty backdrop, so the
        // blur veil begins above the search capsule instead of at its edge.
        let height: CGFloat = 460
        panel.setFrame(
            NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: height),
            display: true
        )
        actions.panelWillShow()
        stateStore.configureInput(vim: vimMode(), searchKey: vimBindings.key(for: .search))
        stateStore.requestSearchFocus()
        panel.makeKeyAndOrderFront(nil)
        veilGeneration += 1
        veilPanel.setFrame(panel.frame, display: true)
        veilPanel.alphaValue = 0
        veilPanel.order(.below, relativeTo: panel.windowNumber)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            veilPanel.animator().alphaValue = 1
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func fadeOutVeil() {
        guard veilPanel.isVisible else { return }
        veilGeneration += 1
        let generation = veilGeneration
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                veilPanel.animator().alphaValue = 0
            },
            completionHandler: { [weak self] in
                guard let self, generation == veilGeneration else { return }
                veilPanel.orderOut(nil)
            }
        )
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
                // The veil clears too: the drop target may sit right
                // behind it.
                self.veilPanel.animator().alphaValue = 0
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
                y: frame.minY + 506,
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
    /// Gets the first shot at Esc; returning true keeps the panel open.
    var onCancel: (() -> Bool)?

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
        if onCancel?() == true {
            return
        }
        orderOut(nil)
    }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }
}
