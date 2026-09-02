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
        // The window is created once and never resized: the scroll absorbs
        // the vim section appearing and disappearing with its toggle.
        ScrollView {
            content
        }
        .frame(width: 500, height: 640)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("General"))
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Toggle(
                    localized("Launch Whisk at login"),
                    isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    )
                )
                if let error = loginItem.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Picker(localized("Keep history for"), selection: $general.retentionPeriod) {
                    ForEach(RetentionPeriodOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                Picker(localized("History capacity"), selection: $general.capacity) {
                    ForEach(GeneralSettingsStore.capacityChoices, id: \.self) { choice in
                        Text(GeneralSettingsStore.capacityLabel(choice)).tag(choice)
                    }
                }
                Text(localized("Pinned items are never expired or evicted."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(localized("Check for updates at launch"), isOn: $general.checkForUpdates)
                Toggle(localized("Vim navigation in the panel"), isOn: $general.vimNavigation)
                Text(
                    localized(
                        "The panel opens with letters as commands: s to search, hjkl to move, p to paste, v to preview, q to close."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Text(localized("Excluded apps"))
                    Spacer()
                    Button(localized("Add App…")) {
                        addExcludedApp()
                    }
                }
                if general.excludedApps.isEmpty {
                    Text(localized("Copies from excluded apps are never recorded."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(general.excludedApps) { app in
                        HStack(spacing: 8) {
                            if let icon = SourceAppStyle.resolve(bundleID: app.bundleID).icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
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
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .quaternarySystemFill))
            )

            Divider()

            Text(localized("Keyboard Shortcuts"))
                .font(.title3.weight(.semibold))
            Text(localized("Click a shortcut to record a new one — press Escape to cancel recording."))
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 2) {
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
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
                }
            }

            Text(localized("⌘1…⌘9 paste the matching card directly."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if general.vimNavigation {
                Divider()

                Text(localized("Vim Keybindings"))
                    .font(.title3.weight(.semibold))
                Text(
                    localized(
                        "One or two characters — a two-character binding like gg runs on the double tap. Esc, Tab, / and 1–9 are fixed."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                VStack(spacing: 2) {
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
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .quaternarySystemFill))
                        )
                    }
                }
            }

            HStack {
                if !store.duplicatedActions.isEmpty {
                    Label(localized("Two actions share the same shortcut."), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Button(localized("Restore Defaults")) {
                    store.resetAll()
                }
            }
        }
        .padding(20)
        .frame(width: 460)
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
                        .fill(isRecording ? Color.accentColor.opacity(0.25) : Color(nsColor: .tertiarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isRecording ? Color.accentColor : .clear, lineWidth: 1.5)
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
