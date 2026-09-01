import Foundation

/// Applies a retention policy — capacity bound and optional maximum age —
/// and persists only when something actually changed.
struct EnforceRetention<Store: HistoryStore> {
    private let store: Store

    init(store: Store) {
        self.store = store
    }

    func callAsFunction(_ history: History, policy: RetentionPolicy, now: Date) throws -> History {
        var next = History(items: history.items, capacity: policy.capacity)
        if let maxAge = policy.maxAge {
            next = next.removingUnpinned(olderThan: now.addingTimeInterval(-maxAge))
        }
        guard next != history else { return history }
        try store.save(next.items)
        return next
    }
}
