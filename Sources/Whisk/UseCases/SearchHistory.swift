import Foundation

/// Filters the history by a case-insensitive query; an empty query matches everything.
struct SearchHistory {
    init() {}

    func callAsFunction(_ history: History, query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return history.items }
        return history.items.filter { $0.payload.matches(trimmed) }
    }
}
