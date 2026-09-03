import Foundation

/// Criteria narrowing the history; empty criteria match everything.
/// Several sources or categories may be selected at once — an item
/// matches when it belongs to any of them (OR within a facet, AND
/// across facets).
struct HistoryFilter: Equatable {
    var query: String
    var sources: [SourceApp]
    var categories: Set<ContentCategory>
    var pinnedOnly: Bool

    init(
        query: String = "",
        sources: [SourceApp] = [],
        categories: Set<ContentCategory> = [],
        pinnedOnly: Bool = false
    ) {
        self.query = query
        self.sources = sources
        self.categories = categories
        self.pinnedOnly = pinnedOnly
    }

    static let none = HistoryFilter()
}

/// Narrows the history by query, source applications, and content
/// categories. The query understands `app:` and `type:` operators; free
/// words fuzzy-match the content or the source application name — every
/// word must land somewhere (AND) — and a live query ranks by match
/// quality, recency breaking the ties.
struct FilterHistory {
    init() {}

    func callAsFunction(_ history: History, filter: HistoryFilter) -> [ClipboardItem] {
        let query = ParsedQuery(filter.query)
        var scored: [(item: ClipboardItem, score: Int, recency: Int)] = []
        for (recency, item) in history.items.enumerated() {
            if filter.pinnedOnly, !item.isPinned {
                continue
            }
            if !filter.sources.isEmpty,
                !filter.sources.contains(where: { item.source?.matches($0) ?? false })
            {
                continue
            }
            if !filter.categories.isEmpty, !filter.categories.contains(item.category) {
                continue
            }
            guard let score = query.score(item) else { continue }
            scored.append((item, score, recency))
        }
        if !query.words.isEmpty {
            scored.sort {
                $0.score == $1.score ? $0.recency < $1.recency : $0.score > $1.score
            }
        }
        return scored.map(\.item)
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

    /// nil means no match; a larger score ranks earlier. Operators are
    /// gates; each free word contributes its best fuzzy score across the
    /// content and the source application.
    func score(_ item: ClipboardItem) -> Int? {
        for term in appTerms where !sourceMatches(item, term) {
            return nil
        }
        for term in typeTerms where !item.category.rawValue.hasPrefix(term) {
            return nil
        }
        var total = 0
        for word in words {
            let content = item.payload.searchableText
                .flatMap { FuzzyMatch.score(pattern: word, in: $0) }
            let source = sourceText(item)
                .flatMap { FuzzyMatch.score(pattern: word, in: $0) }
            guard let best = [content, source].compactMap({ $0 }).max() else { return nil }
            total += best
        }
        return total
    }

    private func sourceText(_ item: ClipboardItem) -> String? {
        guard let source = item.source else { return nil }
        let parts = [source.name, source.bundleID].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func sourceMatches(_ item: ClipboardItem, _ term: String) -> Bool {
        guard let source = item.source else { return false }
        if let name = source.name, name.localizedCaseInsensitiveContains(term) { return true }
        if let bundleID = source.bundleID, bundleID.localizedCaseInsensitiveContains(term) { return true }
        return false
    }
}
