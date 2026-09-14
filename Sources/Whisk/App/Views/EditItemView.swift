import SwiftUI

/// The in-panel editor for a card's text: replaces the rail while it is
/// open, so the panel keeps the keyboard. The text lives on the store, so
/// the panel's key router saves it on Return and lets Shift-Return break
/// the line; ⌘S and the button save too, Escape cancels through the
/// panel's cancel path.
struct EditItemView: View {
    @ObservedObject var store: HistoryViewStateStore
    let card: CardViewState
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    private var text: Binding<String> {
        Binding(get: { store.editingText }, set: { store.setEditingText($0) })
    }

    private var isBlank: Bool {
        store.editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: localized("Editing %@"), card.sourceLabel))
                        .font(.headline)
                    Text(localized("Return saves, Shift-Return breaks the line, Escape cancels."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(localized("Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(localized("Save")) { onSave(store.editingText) }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(isBlank)
            }
            TextEditor(text: text)
                .font(.system(size: 13, design: card.kindLabel == localized("code") ? .monospaced : .default))
                .scrollContentBackground(.hidden)
                .focused($focused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), cornerRadius: 14)
        }
        .padding(.horizontal, 16)
        .onAppear { focused = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localized("Editor"))
    }
}
