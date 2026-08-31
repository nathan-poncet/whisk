/// What the system pasteboard held when a change was observed.
public struct PasteboardSnapshot: Equatable {
    public let payload: Payload
    public let source: SourceApp?

    public init(payload: Payload, source: SourceApp?) {
        self.payload = payload
        self.source = source
    }
}

/// Boundary to the system pasteboard.
public protocol Pasteboard {
    /// A snapshot when the pasteboard changed since the previous call, nil otherwise.
    func readIfChanged() -> PasteboardSnapshot?
    func write(_ payload: Payload)
}
