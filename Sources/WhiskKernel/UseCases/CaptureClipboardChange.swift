/// Records a pasteboard change into the history and persists the result.
public struct CaptureClipboardChange<Board: Pasteboard, Time: Clock, Store: HistoryStore> {
    private let pasteboard: Board
    private let clock: Time
    private let store: Store

    public init(pasteboard: Board, clock: Time, store: Store) {
        self.pasteboard = pasteboard
        self.clock = clock
        self.store = store
    }

    public func callAsFunction(into history: History) throws -> History {
        guard let snapshot = pasteboard.readIfChanged() else { return history }
        let next = history.recording(snapshot.payload, from: snapshot.source, at: clock.now())
        try store.save(next.items)
        return next
    }
}
