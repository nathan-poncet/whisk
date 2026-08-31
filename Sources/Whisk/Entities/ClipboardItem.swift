import Foundation

/// A single captured pasteboard entry.
struct ClipboardItem: Equatable, Hashable, Identifiable {
    let id: UUID
    let payload: Payload
    let source: SourceApp?
    let copiedAt: Date
    let isPinned: Bool

    init(id: UUID, payload: Payload, source: SourceApp?, copiedAt: Date, isPinned: Bool) {
        self.id = id
        self.payload = payload
        self.source = source
        self.copiedAt = copiedAt
        self.isPinned = isPinned
    }

    func copied(at date: Date) -> ClipboardItem {
        ClipboardItem(id: id, payload: payload, source: source, copiedAt: date, isPinned: isPinned)
    }

    func pinToggled() -> ClipboardItem {
        ClipboardItem(id: id, payload: payload, source: source, copiedAt: copiedAt, isPinned: !isPinned)
    }
}
