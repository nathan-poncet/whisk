/// Removes every unpinned item and persists the result.
public struct ClearHistory<Store: HistoryStore> {
    private let store: Store

    public init(store: Store) {
        self.store = store
    }

    public func callAsFunction(_ history: History) throws -> History {
        let next = history.clearingUnpinned()
        try store.save(next.items)
        return next
    }
}
