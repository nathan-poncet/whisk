import AppKit
import SwiftUI

/// Paste-style panel pinned to the bottom of the main screen. Non-activating,
/// so the frontmost application keeps focus while the user picks an item.
final class PanelController {
    private let panel: FloatingPanel
    private let stateStore: HistoryViewStateStore
    private let actions: PanelActions

    init(stateStore: HistoryViewStateStore, actions: PanelActions) {
        self.stateStore = stateStore
        self.actions = actions
        panel = FloatingPanel()
        panel.contentView = NSHostingView(
            rootView: HistoryPanelView(store: stateStore, actions: actions)
        )
        panel.keyHandler = { [weak self] event in
            self?.handle(event) ?? false
        }
    }

    /// Arrows step the selection and Return pastes it, even while the
    /// search field owns the caret.
    private func handle(_ event: NSEvent) -> Bool {
        switch event.specialKey {
        case .some(.leftArrow), .some(.upArrow):
            actions.moveSelection(.previous)
            return true
        case .some(.rightArrow), .some(.downArrow):
            actions.moveSelection(.next)
            return true
        case .some(.carriageReturn), .some(.enter):
            actions.activateSelected()
            return true
        default:
            return false
        }
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
        let frame = screen.visibleFrame
        let height: CGFloat = 340
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
