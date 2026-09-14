import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private typealias Controller = ClipboardController<AppKitPasteboard, SystemClock, AnyHistoryStore, ConsoleLogger>

    private let logger = ConsoleLogger()
    private let keyBindings = KeyBindingsStore()
    private let generalSettings = GeneralSettingsStore()
    private let vimKeymap = VimBindingsStore()
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
    private var clipboard: Controller?
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = openStore()
        let stateStore = HistoryViewStateStore()
        let clipboard = ClipboardController(
            pasteboard: AppKitPasteboard(),
            store: store,
            clock: SystemClock(),
            retention: generalSettings.policy,
            logger: logger
        ) { state in
            stateStore.update(state)
        }
        self.stateStore = stateStore
        self.clipboard = clipboard

        // Filtering re-renders a screenful of glass cards, so keystrokes
        // coalesce: only the last query of a typing burst runs.
        let actions = PanelWiring.actions(
            for: clipboard,
            searchDebounce: Debouncer(delay: 0.18),
            hidePanel: { [weak self] in self?.panelController?.hide() },
            paste: { PasteSimulator.paste() },
            dragBegan: { [weak self] in self?.panelController?.dragDidBegin() },
            system: PanelWiring.SystemActions(
                openLink: { NSWorkspace.shared.open($0) },
                revealFiles: { paths in
                    NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
                },
                saveToDisk: { SaveToDisk.present($0) },
                excludeSource: { [weak self] bundleID, name in
                    guard let self, !self.generalSettings.excludedApps.contains(where: { $0.bundleID == bundleID })
                    else { return }
                    self.generalSettings.excludedApps.append(ExcludedApp(bundleID: bundleID, name: name))
                }
            )
        )
        let panelController = PanelController(
            stateStore: stateStore, actions: actions, keyBindings: keyBindings,
            vimBindings: vimKeymap,
            vimMode: { [weak self] in self?.generalSettings.vimNavigation ?? false }
        )
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
        LinkPreviewStore.shared.setEnabled(generalSettings.linkPreviews)
        stateStore.configureCards(side: generalSettings.cardSize.side)
        clipboard.setLayoutDirection(
            NSApp.userInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        // willSet semantics again: hop to the next cycle so the policy is
        // read after the setting has landed.
        settingsObserver = generalSettings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.clipboard?.applyRetention(self.generalSettings.policy)
                self.clipboard?.applyExclusions(self.generalSettings.excludedBundleIDs)
                LinkPreviewStore.shared.setEnabled(self.generalSettings.linkPreviews)
                self.stateStore?.configureCards(side: self.generalSettings.cardSize.side)
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

    /// Launch never fails on storage: HistoryStorage recovers from a
    /// database that will not open, and an unreachable Application
    /// Support leaves the session running in memory.
    private func openStore() -> AnyHistoryStore {
        do {
            return HistoryStorage.open(in: try HistoryStorage.defaultDirectory(), log: logger.log)
        } catch {
            logger.log("Application Support unavailable — \(error); history will not be saved this session")
            return AnyHistoryStore(VolatileHistoryStore())
        }
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

    private func startPolling(_ clipboard: Controller) {
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
            rootView: OnboardingView(toggleShortcut: keyBindings.label(for: .togglePanel)) { [weak self] in
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
                rootView: SettingsView(
                    store: keyBindings, general: generalSettings, loginItem: loginItem,
                    vimBindings: vimKeymap)
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
