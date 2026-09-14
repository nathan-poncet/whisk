import SwiftUI

/// The in-panel editor for a card's text: replaces the rail while it is
/// open, so the panel keeps the keyboard. ⌘S saves, Escape cancels
/// through the panel's cancel path.
struct EditItemView: View {
    let card: CardViewState
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @State private var text: String
    @FocusState private var focused: Bool

    init(card: CardViewState, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.card = card
        self.onSave = onSave
        self.onCancel = onCancel
        _text = State(initialValue: Self.initialText(of: card))
    }

    /// What the editor starts from: the card's text, or a link's address.
    static func initialText(of card: CardViewState) -> String {
        switch card.dragPayload {
        case .text(let value): return value
        case .link(let url): return url.absoluteString
        case .image, .files: return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: localized("Editing %@"), card.sourceLabel))
                    .font(.headline)
                Spacer()
                Button(localized("Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(localized("Save")) { onSave(text) }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            TextEditor(text: $text)
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
