import Foundation

/// Criteria narrowing the history; empty criteria match everything.
struct HistoryFilter: Equatable {
    var query: String
    var source: SourceApp?
    var category: ContentCategory?

    init(query: String = "", source: SourceApp? = nil, category: ContentCategory? = nil) {
        self.query = query
        self.source = source
        self.category = category
    }

    static let none = HistoryFilter()
}

/// Narrows the history by free-text query, source application, and content
/// category. Text matching is case-insensitive.
struct FilterHistory {
    init() {}

    func callAsFunction(_ history: History, filter: HistoryFilter) -> [ClipboardItem] {
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return history.items.filter { item in
            if let source = filter.source, !(item.source?.matches(source) ?? false) {
                return false
            }
            if let category = filter.category, item.payload.category != category {
                return false
            }
            if !query.isEmpty, !item.payload.matches(query) {
                return false
            }
            return true
        }
    }
}
