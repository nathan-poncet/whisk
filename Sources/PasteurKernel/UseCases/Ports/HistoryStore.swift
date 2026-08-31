/// Failure surfaced by a history store adapter.
public enum HistoryStoreError: Error, Equatable {
    case unreadable(String)
    case unwritable(String)
}

/// Persistence boundary for clipboard items, newest first.
public protocol HistoryStore {
    func load() throws -> [ClipboardItem]
    func save(_ items: [ClipboardItem]) throws
}
