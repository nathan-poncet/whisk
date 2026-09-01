/// Records a pasteboard change into the history and persists the result.
struct CaptureClipboardChange<Board: Pasteboard, Time: Clock, Store: HistoryStore> {
    private let pasteboard: Board
    private let clock: Time
    private let store: Store

    init(pasteboard: Board, clock: Time, store: Store) {
        self.pasteboard = pasteboard
        self.clock = clock
        self.store = store
    }

    /// Records a change unless its source application is excluded; an
    /// excluded change is still consumed so it is never captured later.
    func callAsFunction(into history: History, excluding excludedBundleIDs: Set<String> = []) throws -> History {
        guard let snapshot = pasteboard.readIfChanged() else { return history }
        if let bundleID = snapshot.source?.bundleID, excludedBundleIDs.contains(bundleID) {
            return history
        }
        let next = history.recording(snapshot.payload, from: snapshot.source, rtf: snapshot.rtf, at: clock.now())
        try store.save(next.items)
        return next
    }
}
