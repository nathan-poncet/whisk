/// Rebuilds the history from persistence, enforcing capacity.
struct LoadHistory<Store: HistoryStore> {
    private let store: Store
    private let capacity: HistoryCapacity

    init(store: Store, capacity: HistoryCapacity = .standard) {
        self.store = store
        self.capacity = capacity
    }

    func callAsFunction() throws -> History {
        History(items: try store.load(), capacity: capacity)
    }
}
