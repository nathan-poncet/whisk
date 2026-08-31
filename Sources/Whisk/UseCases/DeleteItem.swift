import Foundation

/// Removes an item and persists the result.
struct DeleteItem<Store: HistoryStore> {
    private let store: Store

    init(store: Store) {
        self.store = store
    }

    func callAsFunction(_ id: UUID, in history: History) throws -> History {
        let next = history.deleting(id)
        try store.save(next.items)
        return next
    }
}
