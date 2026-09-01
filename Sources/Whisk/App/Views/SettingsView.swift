import AppKit
import SwiftUI

/// The Settings window: general housekeeping plus one recorder per
/// keyboard action.
struct SettingsView: View {
    @ObservedObject var store: KeyBindingsStore
    @ObservedObject var general: GeneralSettingsStore
    @ObservedObject var loginItem: LoginItemManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("General")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Toggle(
                    "Launch Whisk at login",
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
                Picker("Keep history for", selection: $general.retentionPeriod) {
                    ForEach(RetentionPeriodOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                Picker("History capacity", selection: $general.capacity) {
                    ForEach(GeneralSettingsStore.capacityChoices, id: \.self) { choice in
                        Text("\(choice) items").tag(choice)
                    }
                }
                Text("Pinned items are never expired or evicted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .quaternarySystemFill))
            )

            Divider()

            Text("Keyboard Shortcuts")
                .font(.title3.weight(.semibold))
            Text("Click a shortcut to record a new one — press Escape to cancel recording.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 2) {
                ForEach(KeyAction.allCases) { action in
                    HStack(spacing: 10) {
                        Text(action.displayName)
                        if action.isGlobal {
                            Text("global")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.quaternary))
                        }
                        Spacer()
                        if store.duplicatedActions.contains(action) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .help("This shortcut is used by another action")
                        }
                        ShortcutRecorder(action: action, store: store)
                        Button {
                            store.reset(action)
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(.borderless)
                        .disabled(!store.isCustomized(action))
                        .help("Reset to default")
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
                }
            }

            Text("⌘1…⌘9 paste the matching card directly.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if !store.duplicatedActions.isEmpty {
                    Label("Two actions share the same shortcut.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Button("Restore Defaults") {
                    store.resetAll()
                }
            }
        }
        .padding(20)
        .frame(width: 460)
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
            Text(isRecording ? "Type shortcut…" : store.label(for: action))
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
