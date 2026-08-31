/// What the system pasteboard held when a change was observed.
public struct PasteboardSnapshot: Equatable {
    public let payload: Payload
    public let sourceApp: String?

    public init(payload: Payload, sourceApp: String?) {
        self.payload = payload
        self.sourceApp = sourceApp
    }
}

/// Boundary to the system pasteboard.
public protocol Pasteboard {
    /// A snapshot when the pasteboard changed since the previous call, nil otherwise.
    func readIfChanged() -> PasteboardSnapshot?
    func write(_ payload: Payload)
}
