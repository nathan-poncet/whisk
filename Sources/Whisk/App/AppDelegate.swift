import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var hotKey: HotKey?
    private var layoutObserver: NSObjectProtocol?
    private var stateStore: HistoryViewStateStore?
    private var clipboard: ClipboardController<AppKitPasteboard, SystemClock, FileHistoryStore>?
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store: FileHistoryStore
        do {
            store = FileHistoryStore(directory: try FileHistoryStore.defaultDirectory())
        } catch {
            fputs("Whisk: cannot open storage directory — \(error)\n", stderr)
            NSApp.terminate(nil)
            return
        }

        let stateStore = HistoryViewStateStore()
        let clipboard = ClipboardController(
            pasteboard: AppKitPasteboard(),
            store: store,
            clock: SystemClock()
        ) { state in
            stateStore.update(state)
        }
        self.stateStore = stateStore
        self.clipboard = clipboard

        let actions = PanelActions(
            search: { clipboard.search($0) },
            select: { [weak self] id in
                clipboard.select(id)
                self?.panelController?.hide()
                PasteSimulator.paste()
            },
            highlight: { clipboard.highlight($0) },
            activate: { [weak self] in
                guard clipboard.activateFocused() else { return }
                self?.panelController?.hide()
                PasteSimulator.paste()
            },
            navigate: { clipboard.navigate($0) },
            toggleSourceFilter: { clipboard.toggleSourceFilter($0) },
            toggleCategoryFilter: { clipboard.toggleCategoryFilter($0) },
            focusSourceChip: { clipboard.focusSourceChip($0) },
            focusCategoryChip: { clipboard.focusCategoryChip($0) },
            togglePin: { clipboard.togglePin($0) },
            delete: { clipboard.delete($0) },
            panelWillShow: { clipboard.panelWillShow() }
        )
        let panelController = PanelController(stateStore: stateStore, actions: actions)
        self.panelController = panelController

        configureStatusItem()
        registerHotKey()
        observeKeyboardLayoutChanges()
        startPolling(clipboard)

        if CommandLine.arguments.contains("--show-panel") {
            panelController.show()
        }
    }

    /// ⇧⌘V wherever the current layout prints a V — Dvorak, AZERTY, … —
    /// falling back to the physical ANSI position for layouts without one.
    private func registerHotKey() {
        hotKey = nil
        let keyCode = KeyboardLayout.keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
        hotKey = HotKey(keyCode: UInt32(keyCode), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.panelController?.toggle()
        }
    }

    private func observeKeyboardLayoutChanges() {
        layoutObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerHotKey()
        }
    }

    private func startPolling(_ clipboard: ClipboardController<AppKitPasteboard, SystemClock, FileHistoryStore>) {
        let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
            clipboard.pollTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
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
        clipboard?.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
