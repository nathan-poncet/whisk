/// Removes every unpinned item a predicate selects — all the cards from
/// one application — and persists the result. Pins survive, as they do
/// everything else.
struct DeleteMatching<Store: HistoryStore> {
    private let store: Store

    init(store: Store) {
        self.store = store
    }

    func callAsFunction(_ matches: (ClipboardItem) -> Bool, in history: History) throws -> History {
        let next = history.deletingUnpinned(where: matches)
        try store.save(next.items)
        return next
    }
}
