import Foundation

/// Replaces what a card holds with text the user rewrote, in place: same
/// identity, position, pin and source. A rewrite that reads as a web
/// address becomes a link again; formatting is dropped, since it no
/// longer matches the words. Blank text is refused rather than stored.
struct EditItem<Store: HistoryStore> {
    private let store: Store

    init(store: Store) {
        self.store = store
    }

    func callAsFunction(_ id: UUID, text: String, in history: History) throws -> History {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return history }
        let next = history.replacingPayload(of: id, with: Self.payload(for: text))
        guard next != history else { return history }
        try store.save(next.items)
        return next
    }

    /// One bare http(s) address is a link; anything else is text.
    static func payload(for text: String) -> Payload {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        {
            return .link(url)
        }
        return .text(text)
    }
}
