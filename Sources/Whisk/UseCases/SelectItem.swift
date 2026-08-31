import Foundation

/// Puts an item back on the pasteboard and refreshes its position.
struct SelectItem<Board: Pasteboard, Time: Clock, Store: HistoryStore> {
    private let pasteboard: Board
    private let clock: Time
    private let store: Store

    init(pasteboard: Board, clock: Time, store: Store) {
        self.pasteboard = pasteboard
        self.clock = clock
        self.store = store
    }

    func callAsFunction(_ id: UUID, in history: History) throws -> History {
        guard let item = history.items.first(where: { $0.id == id }) else { return history }
        pasteboard.write(item.payload)
        let next = history.selecting(id, at: clock.now())
        try store.save(next.items)
        return next
    }
}
