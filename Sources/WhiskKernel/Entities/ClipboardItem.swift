import Foundation

/// A single captured pasteboard entry.
public struct ClipboardItem: Equatable, Hashable, Identifiable {
    public let id: UUID
    public let payload: Payload
    public let sourceApp: String?
    public let copiedAt: Date
    public let isPinned: Bool

    public init(id: UUID, payload: Payload, sourceApp: String?, copiedAt: Date, isPinned: Bool) {
        self.id = id
        self.payload = payload
        self.sourceApp = sourceApp
        self.copiedAt = copiedAt
        self.isPinned = isPinned
    }

    func copied(at date: Date) -> ClipboardItem {
        ClipboardItem(id: id, payload: payload, sourceApp: sourceApp, copiedAt: date, isPinned: isPinned)
    }

    func pinToggled() -> ClipboardItem {
        ClipboardItem(id: id, payload: payload, sourceApp: sourceApp, copiedAt: copiedAt, isPinned: !isPinned)
    }
}
