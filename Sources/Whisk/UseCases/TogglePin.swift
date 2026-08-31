import Foundation

/// Flips an item's pin and persists the result.
public struct TogglePin<Store: HistoryStore> {
    private let store: Store

    public init(store: Store) {
        self.store = store
    }

    public func callAsFunction(_ id: UUID, in history: History) throws -> History {
        let next = history.togglingPin(id)
        try store.save(next.items)
        return next
    }
}
