/// Puts a remembered history back and persists it — the undo of a
/// deletion, a clear or an edit.
struct RestoreHistory<Store: HistoryStore> {
    private let store: Store

    init(store: Store) {
        self.store = store
    }

    func callAsFunction(_ history: History) throws -> History {
        try store.save(history.items)
        return history
    }
}
