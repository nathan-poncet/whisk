import Foundation

/// A single captured pasteboard entry. The category is classified once at
/// creation — the payload is immutable and classification runs regexes.
struct ClipboardItem: Equatable, Hashable, Identifiable {
    let id: UUID
    let payload: Payload
    let source: SourceApp?
    let copiedAt: Date
    let isPinned: Bool
    let category: ContentCategory
    let rtf: Data?

    init(id: UUID, payload: Payload, source: SourceApp?, copiedAt: Date, isPinned: Bool, rtf: Data? = nil) {
        self.init(
            id: id, payload: payload, source: source, copiedAt: copiedAt, isPinned: isPinned,
            category: payload.category, rtf: rtf)
    }

    private init(
        id: UUID, payload: Payload, source: SourceApp?, copiedAt: Date, isPinned: Bool,
        category: ContentCategory, rtf: Data?
    ) {
        self.id = id
        self.payload = payload
        self.source = source
        self.copiedAt = copiedAt
        self.isPinned = isPinned
        self.category = category
        self.rtf = rtf
    }

    func copied(at date: Date) -> ClipboardItem {
        ClipboardItem(
            id: id, payload: payload, source: source, copiedAt: date, isPinned: isPinned,
            category: category, rtf: rtf)
    }

    func pinToggled() -> ClipboardItem {
        ClipboardItem(
            id: id, payload: payload, source: source, copiedAt: copiedAt, isPinned: !isPinned,
            category: category, rtf: rtf)
    }
}
