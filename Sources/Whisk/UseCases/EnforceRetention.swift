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
        // A capacity that merely changed is adopted without a write: only
        // the items decide whether the store has anything new to hold.
        guard next.items != history.items else { return next }
        try store.save(next.items)
        return next
    }
}
