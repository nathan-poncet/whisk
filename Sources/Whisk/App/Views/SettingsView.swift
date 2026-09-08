import AppKit
import SwiftUI

/// The Settings window: general housekeeping plus one recorder per
/// keyboard action.
struct SettingsView: View {
    @ObservedObject var store: KeyBindingsStore
    @ObservedObject var general: GeneralSettingsStore
    @ObservedObject var loginItem: LoginItemManager
    @ObservedObject var vimBindings: VimBindingsStore

    var body: some View {
        // The window is created once and never resized; the grouped form
        // scrolls, so the vim section can appear and disappear freely.
        Form {
            generalSection
            historySection
            excludedSection
            vimSection
            shortcutsSection
            restoreSection
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 720)
    }

    private var generalSection: some View {
        Section {
            Toggle(isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) })) {
                SettingsRowLabel(localized("Launch Whisk at login"), symbol: "power", tint: .green)
            }
            .toggleStyle(.switch)
            if let error = loginItem.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Toggle(isOn: $general.checkForUpdates) {
                SettingsRowLabel(
                    localized("Check for updates at launch"), symbol: "arrow.triangle.2.circlepath", tint: .blue)
            }
            .toggleStyle(.switch)
        }
    }

    private var historySection: some View {
        Section {
            Picker(selection: $general.retentionPeriod) {
                ForEach(RetentionPeriodOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            } label: {
                SettingsRowLabel(localized("Keep history for"), symbol: "clock", tint: .orange)
            }
            Picker(selection: $general.capacity) {
                ForEach(GeneralSettingsStore.capacityChoices, id: \.self) { choice in
                    Text(GeneralSettingsStore.capacityLabel(choice)).tag(choice)
                }
            } label: {
                SettingsRowLabel(localized("History capacity"), symbol: "tray.full", tint: .purple)
            }
        } footer: {
            Text(localized("Pinned items are never expired or evicted."))
        }
    }

    private var excludedSection: some View {
        Section {
            ForEach(general.excludedApps) { app in
                HStack(spacing: 9) {
                    if let icon = SourceAppStyle.resolve(bundleID: app.bundleID).icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 22, height: 22)
                    }
                    Text(app.name)
                    Spacer()
                    Button {
                        general.excludedApps.removeAll { $0.bundleID == app.bundleID }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button {
                addExcludedApp()
            } label: {
                SettingsRowLabel(localized("Add App…"), symbol: "hand.raised.fill", tint: .red)
            }
            .buttonStyle(.plain)
        } header: {
            Text(localized("Excluded apps"))
        } footer: {
            Text(localized("Copies from excluded apps are never recorded."))
        }
    }

    private var vimSection: some View {
        Section {
            Toggle(isOn: $general.vimNavigation) {
                SettingsRowLabel(localized("Vim navigation in the panel"), symbol: "keyboard", tint: .matcha)
            }
            .toggleStyle(.switch)
            if general.vimNavigation {
                ForEach(VimAction.allCases) { action in
                    HStack(spacing: 10) {
                        Text(action.displayName)
                        Spacer()
                        if vimBindings.duplicatedActions.contains(action) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .help(localized("This shortcut is used by another action"))
                        }
                        VimKeyField(action: action, store: vimBindings)
                        Button {
                            vimBindings.reset(action)
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(.borderless)
                        .disabled(!vimBindings.isCustomized(action))
                        .help(localized("Reset to default"))
                    }
                }
            }
        } header: {
            Text(localized("Vim Keybindings"))
        } footer: {
            if general.vimNavigation {
                Text(
                    localized(
                        "One or two characters — a two-character binding like gg runs on the double tap. Esc, Tab, / and 1–9 are fixed."
                    )
                )
            } else {
                Text(
                    String(
                        format: localized(
                            "The panel opens with letters as commands: %@ to search, %@ to move, %@ to paste, %@ to preview, %@ to close."
                        ),
                        vimBindings.key(for: .search),
                        vimBindings.key(for: .previousCard) + vimBindings.key(for: .rowDown)
                            + vimBindings.key(for: .rowUp) + vimBindings.key(for: .nextCard),
                        vimBindings.key(for: .paste),
                        vimBindings.key(for: .preview),
                        vimBindings.key(for: .closePanel)
                    )
                )
            }
        }
    }

    private var shortcutsSection: some View {
        Section {
            ForEach(KeyAction.allCases) { action in
                HStack(spacing: 10) {
                    Text(action.displayName)
                    if action.isGlobal {
                        Text(localized("global"))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.quaternary))
                    }
                    Spacer()
                    if store.duplicatedActions.contains(action) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .help(localized("This shortcut is used by another action"))
                    }
                    ShortcutRecorder(action: action, store: store)
                    Button {
                        store.reset(action)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!store.isCustomized(action))
                    .help(localized("Reset to default"))
                }
            }
        } header: {
            Text(localized("Keyboard Shortcuts"))
        } footer: {
            VStack(alignment: .leading, spacing: 3) {
                Text(localized("Click a shortcut to record a new one — press Escape to cancel recording."))
                Text(localized("⌘1…⌘9 paste the matching card directly."))
                if !store.duplicatedActions.isEmpty {
                    Label(
                        localized("Two actions share the same shortcut."),
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.yellow)
                }
            }
        }
    }

    private var restoreSection: some View {
        Section {
            Button(role: .destructive) {
                store.resetAll()
                vimBindings.resetAll()
            } label: {
                Text(localized("Restore Defaults"))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { continue }
            let name =
                (bundle.infoDictionary?["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent
            guard !general.excludedApps.contains(where: { $0.bundleID == bundleID }) else { continue }
            general.excludedApps.append(ExcludedApp(bundleID: bundleID, name: name))
        }
    }
}

/// The iOS-Settings row anatomy: the symbol on its rounded color tile,
/// the title beside it.
private struct SettingsRowLabel: View {
    let title: String
    let symbol: String
    let tint: Color

    init(_ title: String, symbol: String, tint: Color) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 25, height: 25)
                .background(RoundedRectangle(cornerRadius: 6.5, style: .continuous).fill(tint))
            Text(title)
        }
    }
}

/// A vim binding is typed, not recorded: one or two plain characters,
/// committed on Return or when the focus leaves; junk falls back to the
/// action's default.
private struct VimKeyField: View {
    let action: VimAction
    @ObservedObject var store: VimBindingsStore
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .multilineTextAlignment(.center)
            .frame(width: 44)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.quaternary))
            .focused($focused)
            .onAppear { text = store.key(for: action) }
            .onSubmit { commit() }
            .onChange(of: focused) { _, isFocused in
                if !isFocused {
                    commit()
                }
            }
            .onChange(of: store.keys) { _, _ in
                if !focused {
                    text = store.key(for: action)
                }
            }
    }

    private func commit() {
        store.set(text, for: action)
        text = store.key(for: action)
    }
}

/// Click to arm, then the next key press becomes the binding. Recording
/// state lives in the store, so at most one recorder is armed at a time.
private struct ShortcutRecorder: View {
    let action: KeyAction
    @ObservedObject var store: KeyBindingsStore

    private var isRecording: Bool {
        store.recordingAction == action
    }

    var body: some View {
        Button {
            isRecording ? store.endRecording() : store.beginRecording(action)
        } label: {
            Text(isRecording ? localized("Type shortcut…") : store.label(for: action))
                .font(.system(.body, design: .rounded).weight(.medium))
                .frame(minWidth: 76)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isRecording ? Color.matcha.opacity(0.25) : Color(nsColor: .tertiarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isRecording ? Color.matcha : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .onDisappear {
            if isRecording {
                store.endRecording()
            }
        }
    }
}
