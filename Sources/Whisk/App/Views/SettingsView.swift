import AppKit
import SwiftUI

/// The Settings window: one recorder per keyboard action.
struct SettingsView: View {
    @ObservedObject var store: KeyBindingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

/// Click to arm, then the next key press becomes the binding.
private struct ShortcutRecorder: View {
    let action: KeyAction
    @ObservedObject var store: KeyBindingsStore

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
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
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer { stopRecording() }
            if event.keyCode != UInt16(53) {
                store.set(KeyBinding(event: event), for: action)
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
    }
}
