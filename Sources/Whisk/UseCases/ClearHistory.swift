/// Removes every unpinned item and persists the result.
struct ClearHistory<Store: HistoryStore> {
    private let store: Store

    init(store: Store) {
        self.store = store
    }

    func callAsFunction(_ history: History) throws -> History {
        let next = history.clearingUnpinned()
        try store.save(next.items)
        return next
    }
}
