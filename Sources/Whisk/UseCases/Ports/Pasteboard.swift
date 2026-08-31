/// What the system pasteboard held when a change was observed.
struct PasteboardSnapshot: Equatable {
    let payload: Payload
    let source: SourceApp?

    init(payload: Payload, source: SourceApp?) {
        self.payload = payload
        self.source = source
    }
}

/// Boundary to the system pasteboard.
protocol Pasteboard {
    /// A snapshot when the pasteboard changed since the previous call, nil otherwise.
    func readIfChanged() -> PasteboardSnapshot?
    func write(_ payload: Payload)
}
