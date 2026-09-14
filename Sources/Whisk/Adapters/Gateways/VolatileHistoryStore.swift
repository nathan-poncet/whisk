/// Keeps the history in memory only — the last resort when no database
/// can be opened, so the session still works even though nothing
/// survives quitting.
final class VolatileHistoryStore: HistoryStore {
    private var items: [ClipboardItem] = []

    init() {}

    func load() throws -> [ClipboardItem] { items }

    func save(_ items: [ClipboardItem]) throws {
        self.items = items
    }
}
