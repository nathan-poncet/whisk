import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let keyBindings = KeyBindingsStore()
    private let generalSettings = GeneralSettingsStore()
    private let loginItem = LoginItemManager()
    private let updateChecker = UpdateChecker()
    private var onboardingWindow: NSWindow?
    private var settingsObserver: AnyCancellable?
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var hotKey: HotKey?
    private var stackHotKey: HotKey?
    private var layoutObserver: NSObjectProtocol?
    private var bindingsObserver: AnyCancellable?
    private var settingsWindow: NSWindow?
    private var stateStore: HistoryViewStateStore?
    private var clipboard: ClipboardController<AppKitPasteboard, SystemClock, SQLiteHistoryStore>?
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store: SQLiteHistoryStore
        do {
            store = try Self.openStore()
        } catch {
            fputs("Whisk: cannot open storage — \(error)\n", stderr)
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
            activatePlain: { [weak self] in
                guard clipboard.activateFocused(plain: true) else { return }
                self?.panelController?.hide()
                PasteSimulator.paste()
            },
            activateCard: { [weak self] index in
                guard clipboard.activate(at: index) else { return }
                self?.panelController?.hide()
                PasteSimulator.paste()
            },
            navigate: { clipboard.navigate($0) },
            switchChipGroup: { clipboard.switchChipGroup() },
            toggleSourceFilter: { clipboard.toggleSourceFilter($0) },
            toggleCategoryFilter: { clipboard.toggleCategoryFilter($0) },
            focusSourceChip: { clipboard.focusSourceChip($0) },
            focusCategoryChip: { clipboard.focusCategoryChip($0) },
            togglePin: { clipboard.togglePin($0) },
            delete: { clipboard.delete($0) },
            togglePinSelected: { clipboard.togglePinSelected() },
            deleteSelected: { clipboard.deleteSelected() },
            stackSelected: { clipboard.stackSelected() },
            panelWillShow: { clipboard.panelWillShow() }
        )
        let panelController = PanelController(stateStore: stateStore, actions: actions, keyBindings: keyBindings)
        self.panelController = panelController

        configureStatusItem()
        registerHotKey()
        observeKeyboardLayoutChanges()
        // @Published emits on willSet: hop to the next main-queue cycle so
        // registerHotKey reads the binding after it has actually landed —
        // otherwise every recording applies the previous shortcut.
        bindingsObserver = keyBindings.$overrides
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.registerHotKey()
            }
        clipboard.applyRetention(generalSettings.policy)
        clipboard.applyExclusions(generalSettings.excludedBundleIDs)
        // willSet semantics again: hop to the next cycle so the policy is
        // read after the setting has landed.
        settingsObserver = generalSettings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.clipboard?.applyRetention(self.generalSettings.policy)
                self.clipboard?.applyExclusions(self.generalSettings.excludedBundleIDs)
            }
        startPolling(clipboard)

        if generalSettings.checkForUpdates {
            updateChecker.checkNow()
        }
        if !UserDefaults.standard.bool(forKey: "didShowOnboarding"),
            !CommandLine.arguments.contains("--smoke-test")
        {
            showOnboarding()
        }

        if CommandLine.arguments.contains("--show-panel") {
            panelController.show()
        }
        if CommandLine.arguments.contains("--exercise-panel") {
            exercisePanel(cycle: 0)
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

    /// Temporary diagnostics: opens and closes the panel in a loop with
    /// timing logs, no synthetic input needed.
    private func exercisePanel(cycle: Int) {
        guard cycle < 4 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            let s0 = CACurrentMediaTime()
            self?.panelController?.show()
            let s1 = CACurrentMediaTime()
            DispatchQueue.main.async {
                NSLog(
                    "WHISK-PERF exercise open %d: show=%.1fms turn=+%.1fms",
                    cycle, (s1 - s0) * 1000, (CACurrentMediaTime() - s0) * 1000)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                let t0 = CACurrentMediaTime()
                self?.panelController?.hide()
                let t1 = CACurrentMediaTime()
                DispatchQueue.main.async {
                    NSLog(
                        "WHISK-PERF exercise close %d: hide=%.1fms turn=+%.1fms",
                        cycle, (t1 - t0) * 1000, (CACurrentMediaTime() - t0) * 1000)
                }
                self?.exercisePanel(cycle: cycle + 1)
            }
        }
    }

    /// Opens the SQLite store, importing the legacy JSON history on first
    /// run after the upgrade.
    private static func openStore() throws -> SQLiteHistoryStore {
        let directory = try FileHistoryStore.defaultDirectory()
        let databaseURL = directory.appendingPathComponent("history.sqlite")
        let legacyIndex = directory.appendingPathComponent("history.json")
        let needsMigration =
            !FileManager.default.fileExists(atPath: databaseURL.path)
            && FileManager.default.fileExists(atPath: legacyIndex.path)
        let store = try SQLiteHistoryStore(databaseURL: databaseURL)
        if needsMigration {
            let legacy = FileHistoryStore(directory: directory)
            if let items = try? legacy.load(), !items.isEmpty {
                try? store.save(items)
            }
            try? FileManager.default.moveItem(
                at: legacyIndex, to: directory.appendingPathComponent("history.json.migrated"))
        }
        return store
    }

    /// The user's binding when one is recorded; otherwise ⇧⌘V wherever the
    /// current layout prints a V — Dvorak, AZERTY, … Re-registered on
    /// layout switches and on binding changes.
    private func registerHotKey() {
        hotKey = nil
        stackHotKey = nil
        let toggle = keyBindings.binding(for: .togglePanel)
        hotKey = HotKey(keyCode: UInt32(toggle.keyCode), modifiers: toggle.carbonModifiers) { [weak self] in
            self?.panelController?.toggle()
        }
        let stack = keyBindings.binding(for: .pasteNextFromStack)
        stackHotKey = HotKey(keyCode: UInt32(stack.keyCode), modifiers: stack.carbonModifiers) { [weak self] in
            guard self?.clipboard?.popStack() == true else { return }
            PasteSimulator.paste()
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

    private func startPolling(_ clipboard: ClipboardController<AppKitPasteboard, SystemClock, SQLiteHistoryStore>) {
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

    private var isPaused = false

    @objc private func togglePause() {
        isPaused.toggle()
        clipboard?.setPaused(isPaused)
        statusItem?.button?.image = NSImage(
            systemSymbolName: isPaused ? "pause.circle" : "doc.on.clipboard",
            accessibilityDescription: "Whisk"
        )
    }

    private func presentMenu() {
        let menu = NSMenu()
        menu.addItem(
            menuItem(
                title: String(format: localized("Show History (%@)"), keyBindings.label(for: .togglePanel)),
                action: #selector(showPanel)))
        menu.addItem(
            menuItem(
                title: isPaused ? localized("Resume Capture") : localized("Pause Capture"),
                action: #selector(togglePause)))
        menu.addItem(menuItem(title: localized("Clear Unpinned Items"), action: #selector(clearHistory)))
        if let version = updateChecker.availableVersion {
            menu.addItem(.separator())
            menu.addItem(
                menuItem(
                    title: String(format: localized("Update Available (v%@)…"), version),
                    action: #selector(openReleasesPage)))
        }
        menu.addItem(.separator())
        menu.addItem(menuItem(title: localized("Settings…"), action: #selector(openSettings)))
        menu.addItem(menuItem(title: localized("Quit Whisk"), action: #selector(quit)))
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

    @objc private func openReleasesPage() {
        if let url = UpdateChecker.releasesPage {
            NSWorkspace.shared.open(url)
        }
    }

    private func showOnboarding() {
        let hosting = NSHostingController(
            rootView: OnboardingView { [weak self] in
                UserDefaults.standard.set(true, forKey: "didShowOnboarding")
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
        )
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(hosting.view.fittingSize)
        window.styleMask.remove([.resizable, .miniaturizable])
        window.title = localized("Welcome")
        window.isReleasedWhenClosed = false
        onboardingWindow = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(store: keyBindings, general: generalSettings, loginItem: loginItem)
            )
            let window = NSWindow(contentViewController: hosting)
            // SwiftUI sizing is lazy: without this the window materializes
            // at 1×32 points and is effectively invisible.
            window.setContentSize(hosting.view.fittingSize)
            window.styleMask.remove([.resizable, .miniaturizable])
            window.title = localized("Whisk Settings")
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
