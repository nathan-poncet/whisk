/// Rebuilds the history from persistence, enforcing capacity.
public struct LoadHistory<Store: HistoryStore> {
    private let store: Store
    private let capacity: HistoryCapacity

    public init(store: Store, capacity: HistoryCapacity = .standard) {
        self.store = store
        self.capacity = capacity
    }

    public func callAsFunction() throws -> History {
        History(items: try store.load(), capacity: capacity)
    }
}
