import AppKit
import Carbon.HIToolbox
import Testing

@testable import Whisk

/// The panel's windows, created but never ordered in: nothing here puts
/// anything on screen.
@MainActor
@Suite struct PanelWindowing {
    @Test func the_floating_panel_hands_keys_to_its_handler_and_closes_on_the_second_cancel() throws {
        _ = NSApplication.shared
        let panel = FloatingPanel()
        var handled: [UInt16] = []
        var cancels = 0
        var closes = 0
        panel.keyHandler = { event in
            handled.append(event.keyCode)
            return true
        }
        panel.onCancel = {
            cancels += 1
            return cancels == 1
        }
        panel.onClose = { closes += 1 }
        let press = try #require(aKeyEvent(kVK_ANSI_H, typing: "h"))

        panel.sendEvent(press)
        panel.cancelOperation(nil)
        panel.cancelOperation(nil)
        panel.resignKey()

        #expect(handled == [UInt16(kVK_ANSI_H)])
        #expect(panel.canBecomeKey)
        #expect(cancels == 2)
        #expect(closes == 0)
        #expect(!panel.isVisible)
    }

    @Test func the_panel_controller_hides_idempotently_and_ignores_drags_while_hidden() throws {
        _ = NSApplication.shared
        let sandbox = try IsolatedDefaults()
        let store = HistoryViewStateStore()
        let spy = PanelActionSpy()
        let controller = PanelController(
            stateStore: store, actions: spy.actions, keyBindings: KeyBindingsStore(defaults: sandbox.defaults),
            vimBindings: VimBindingsStore(defaults: sandbox.defaults), vimMode: { false })

        controller.hide()
        controller.dragDidBegin()
        controller.hide()

        #expect(spy.calls.isEmpty)
        #expect(store.closeRevision == 0)
    }
}
