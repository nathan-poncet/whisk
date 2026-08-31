import Foundation

/// A single captured pasteboard entry.
public struct ClipboardItem: Equatable, Hashable, Identifiable {
    public let id: UUID
    public let payload: Payload
    public let source: SourceApp?
    public let copiedAt: Date
    public let isPinned: Bool

    public init(id: UUID, payload: Payload, source: SourceApp?, copiedAt: Date, isPinned: Bool) {
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
