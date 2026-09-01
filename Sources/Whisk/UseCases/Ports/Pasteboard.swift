import Foundation

/// What the system pasteboard held when a change was observed. Rich text
/// travels as opaque RTF bytes next to the plain payload.
struct PasteboardSnapshot: Equatable {
    let payload: Payload
    let source: SourceApp?
    let rtf: Data?

    init(payload: Payload, source: SourceApp?, rtf: Data? = nil) {
        self.payload = payload
        self.source = source
        self.rtf = rtf
    }
}

/// Boundary to the system pasteboard.
protocol Pasteboard {
    /// A snapshot when the pasteboard changed since the previous call, nil otherwise.
    func readIfChanged() -> PasteboardSnapshot?
    func write(_ payload: Payload, rtf: Data?)
}
