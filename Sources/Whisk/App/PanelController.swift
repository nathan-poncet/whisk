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
    /// Where the panel and its preview go on the screen they rose on.
    private var layout: PanelLayout?

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
            self?.router.handle(event) ?? false
        }
        // The panel also closes behind the controller's back — Esc and
        // resignKey order it out directly — and the preview must never
        // outlive it.
        panel.onClose = { [weak self] in
            self?.stateStore.endEditing()
            self?.hidePreview()
            self?.fadeOutVeil()
            self?.stateStore.panelDidClose()
        }
        // In vim navigation Esc walks back one mode — SEARCH to NORMAL —
        // before it may close anything, and abandons the query on the way
        // out, exactly like Esc during a / search.
        panel.onCancel = { [weak self] in
            guard let self else { return false }
            if self.stateStore.editing != nil {
                self.stateStore.endEditing()
                return true
            }
            guard self.stateStore.vimEnabled, self.stateStore.searchActive else { return false }
            self.actions.search("")
            self.stateStore.setSearchActive(false)
            return true
        }
        // Hover-selection listens to this: only real pointer movement may
        // steal the keyboard selection (see MouseActivity).
        panel.acceptsMouseMovedEvents = true
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            // Local monitors are called on the main thread.
            MainActor.assumeIsolated { MouseActivity.lastMove = Date() }
            return event
        }
        // AppKit posts this on the main thread; a nil queue keeps the
        // hop out and the windows move in the same turn.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.screensDidChange()
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    private var mouseMonitor: Any?
    private var screenObserver: NSObjectProtocol?

    /// A display unplugged or rescaled under an open panel: the windows
    /// follow the screen the panel now sits on — macOS moves it onto a
    /// remaining one — or the pointer's when it sits on none.
    private func screensDidChange() {
        guard panel.isVisible else { return }
        let screens = NSScreen.screens
        let underPointer = Self.screenIndex(under: NSEvent.mouseLocation, frames: screens.map(\.frame))
        guard let screen = panel.screen ?? underPointer.map({ screens[$0] }) else { return }
        place(on: screen)
        if veilPanel.isVisible {
            veilPanel.setFrame(panel.frame, display: true)
        }
    }

    /// Every key press the panel receives goes through the router; the
    /// two things a key may do to windows come back as closures.
    private lazy var router = PanelKeyRouter(
        stateStore: stateStore,
        actions: actions,
        keyBindings: keyBindings,
        vimBindings: vimBindings,
        togglePreview: { [weak self] in self?.togglePreview() },
        closePanel: { [weak self] in self?.hide() }
    )

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    /// The screen the panel rises on: the one under the pointer, else the
    /// first — the primary display — when the pointer sits on no screen.
    static func screenIndex(under point: CGPoint, frames: [CGRect]) -> Int? {
        guard !frames.isEmpty else { return nil }
        return frames.firstIndex { $0.contains(point) } ?? 0
    }

    func show() {
        let screens = NSScreen.screens
        guard let index = Self.screenIndex(under: NSEvent.mouseLocation, frames: screens.map(\.frame)) else {
            return
        }
        let screen = screens[index]
        resetDragGhost()
        place(on: screen)
        actions.panelWillShow()
        stateStore.configureInput(vim: vimMode(), searchKey: vimBindings.key(for: .search))
        stateStore.requestSearchFocus()
        panel.makeKeyAndOrderFront(nil)
        // The veil is something to see through; Reduce Transparency asks
        // for exactly the opposite.
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency else { return }
        veilGeneration += 1
        veilPanel.setFrame(panel.frame, display: true)
        veilPanel.alphaValue = 0
        veilPanel.order(.below, relativeTo: panel.windowNumber)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration(0.22)
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            veilPanel.animator().alphaValue = 1
        }
    }

    /// Lays the panel out on the screen, and the preview with it when
    /// one is up.
    private func place(on screen: NSScreen) {
        let layout = PanelLayout(screen: PanelLayout.Screen(screen), cardSide: stateStore.cardSide)
        self.layout = layout
        panel.setFrame(layout.panel, display: true)
        if previewPanel?.isVisible == true {
            previewPanel?.setFrame(layout.preview, display: true)
        }
    }

    /// Reduce Motion turns every fade into a cut.
    private static func fadeDuration(_ nominal: TimeInterval) -> TimeInterval {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : nominal
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
                context.duration = Self.fadeDuration(0.22)
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
                context.duration = Self.fadeDuration(0.18)
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

    /// Quick-Look-style preview of the selected card, floating between
    /// the panel and the top of the screen.
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
            let hosting = NSHostingView(rootView: PreviewOverlayView(store: stateStore))
            // The window's frame is the one measure of the preview; the
            // view fills it rather than asking for a size of its own.
            hosting.sizingOptions = []
            preview.contentView = hosting
            previewPanel = preview
        }
        guard let preview = previewPanel, let layout else { return }
        preview.setFrame(layout.preview, display: true)
        preview.orderFront(nil)
    }

    private func hidePreview() {
        previewPanel?.orderOut(nil)
    }
}

extension PanelLayout.Screen {
    init(_ screen: NSScreen) {
        self.init(frame: screen.frame, visibleFrame: screen.visibleFrame, notchHeight: screen.safeAreaInsets.top)
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
