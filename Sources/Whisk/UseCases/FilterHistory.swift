import Foundation

/// Criteria narrowing the history; empty criteria match everything.
struct HistoryFilter: Equatable {
    var query: String
    var source: SourceApp?
    var category: ContentCategory?
    var pinnedOnly: Bool

    init(
        query: String = "",
        source: SourceApp? = nil,
        category: ContentCategory? = nil,
        pinnedOnly: Bool = false
    ) {
        self.query = query
        self.source = source
        self.category = category
        self.pinnedOnly = pinnedOnly
    }

    static let none = HistoryFilter()
}

/// Narrows the history by query, source application, and content category.
/// The query understands `app:` and `type:` operators; free words match
/// the content or the source application name, all case-insensitively,
/// and every word must match (AND).
struct FilterHistory {
    init() {}

    func callAsFunction(_ history: History, filter: HistoryFilter) -> [ClipboardItem] {
        let query = ParsedQuery(filter.query)
        return history.items.filter { item in
            if filter.pinnedOnly, !item.isPinned {
                return false
            }
            if let source = filter.source, !(item.source?.matches(source) ?? false) {
                return false
            }
            if let category = filter.category, item.category != category {
                return false
            }
            return query.matches(item)
        }
    }
}

/// `app:slack type:code keyboard` → app terms, type terms, free words.
struct ParsedQuery: Equatable {
    private(set) var appTerms: [String] = []
    private(set) var typeTerms: [String] = []
    private(set) var words: [String] = []

    init(_ raw: String) {
        for token in raw.split(separator: " ") {
            let lowered = token.lowercased()
            if lowered.hasPrefix("app:") {
                let term = String(lowered.dropFirst(4))
                if !term.isEmpty { appTerms.append(term) }
            } else if lowered.hasPrefix("type:") || lowered.hasPrefix("kind:") {
                let term = String(lowered.drop(while: { $0 != ":" }).dropFirst())
                if !term.isEmpty { typeTerms.append(term) }
            } else {
                words.append(String(token))
            }
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        for term in appTerms where !sourceMatches(item, term) {
            return false
        }
        for term in typeTerms where !item.category.rawValue.hasPrefix(term) {
            return false
        }
        for word in words where !item.payload.matches(word) && !sourceMatches(item, word) {
            return false
        }
        return true
    }

    private func sourceMatches(_ item: ClipboardItem, _ term: String) -> Bool {
        guard let source = item.source else { return false }
        if let name = source.name, name.localizedCaseInsensitiveContains(term) { return true }
        if let bundleID = source.bundleID, bundleID.localizedCaseInsensitiveContains(term) { return true }
        return false
    }
}
