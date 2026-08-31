import AppKit
import Carbon.HIToolbox
import HistoryStoreFile
import PasteboardAppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var hotKey: HotKey?
    private var viewModel: HistoryViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store: FileHistoryStore
        do {
            store = FileHistoryStore(directory: try FileHistoryStore.defaultDirectory())
        } catch {
            fputs("Whisk: cannot open storage directory — \(error)\n", stderr)
            NSApp.terminate(nil)
            return
        }

        let useCases = UseCaseBundle.live(pasteboard: AppKitPasteboard(), store: store, clock: SystemClock())
        let viewModel = HistoryViewModel(useCases: useCases)
        let panelController = PanelController(viewModel: viewModel)
        viewModel.onSelection = { [weak panelController] in
            panelController?.hide()
            PasteSimulator.pasteIfTrusted()
        }
        self.viewModel = viewModel
        self.panelController = panelController

        configureStatusItem()
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey)) { [weak panelController] in
            panelController?.toggle()
        }
        viewModel.startPolling()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Whisk")
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            presentMenu()
        } else {
            panelController?.toggle()
        }
    }

    private func presentMenu() {
        let menu = NSMenu()
        menu.addItem(menuItem(title: "Show History (⇧⌘V)", action: #selector(showPanel)))
        menu.addItem(menuItem(title: "Clear Unpinned Items", action: #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit Whisk", action: #selector(quit)))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func showPanel() {
        panelController?.show()
    }

    @objc private func clearHistory() {
        viewModel?.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
