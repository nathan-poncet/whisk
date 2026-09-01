import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let keyBindings = KeyBindingsStore()
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var hotKey: HotKey?
    private var layoutObserver: NSObjectProtocol?
    private var bindingsObserver: AnyCancellable?
    private var settingsWindow: NSWindow?
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
            togglePinSelected: { clipboard.togglePinSelected() },
            deleteSelected: { clipboard.deleteSelected() },
            panelWillShow: { clipboard.panelWillShow() }
        )
        let panelController = PanelController(stateStore: stateStore, actions: actions, keyBindings: keyBindings)
        self.panelController = panelController

        configureStatusItem()
        registerHotKey()
        observeKeyboardLayoutChanges()
        bindingsObserver = keyBindings.$overrides
            .dropFirst()
            .sink { [weak self] _ in
                self?.registerHotKey()
            }
        startPolling(clipboard)

        if CommandLine.arguments.contains("--show-panel") {
            panelController.show()
        }
        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.async { [weak self] in
                self?.openSettings()
            }
        }

        // Exercised by the release pipeline against the packaged app: the
        // full wiring above ran (SwiftUI evaluated the panel, resources
        // resolved), so reaching this line is the pass signal.
        if CommandLine.arguments.contains("--smoke-test") {
            print("smoke test passed")
            NSApp.terminate(nil)
        }
    }

    /// The user's binding when one is recorded; otherwise ⇧⌘V wherever the
    /// current layout prints a V — Dvorak, AZERTY, … Re-registered on
    /// layout switches and on binding changes.
    private func registerHotKey() {
        hotKey = nil
        let binding = keyBindings.binding(for: .togglePanel)
        hotKey = HotKey(keyCode: UInt32(binding.keyCode), modifiers: binding.carbonModifiers) { [weak self] in
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
        menu.addItem(
            menuItem(title: "Show History (\(keyBindings.label(for: .togglePanel)))", action: #selector(showPanel)))
        menu.addItem(menuItem(title: "Clear Unpinned Items", action: #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Settings…", action: #selector(openSettings)))
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

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(store: keyBindings))
            let window = NSWindow(contentViewController: hosting)
            // SwiftUI sizing is lazy: without this the window materializes
            // at 1×32 points and is effectively invisible.
            window.setContentSize(hosting.view.fittingSize)
            window.styleMask.remove([.resizable, .miniaturizable])
            window.title = "Whisk Settings"
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func clearHistory() {
        clipboard?.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
