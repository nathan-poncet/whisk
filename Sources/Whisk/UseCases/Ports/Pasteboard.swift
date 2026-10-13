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

/// Whether the system lets the app read the pasteboard on its own, outside
/// a paste the user performs.
enum PasteboardAccess: Equatable {
    /// Reads go through silently.
    case granted
    /// The system would ask the user at every read until the user allows
    /// the app for good in its settings.
    case requiresConsent
    /// The user refused; reads come back empty.
    case denied
}

/// Boundary to the system pasteboard.
protocol Pasteboard {
    var access: PasteboardAccess { get }
    /// A snapshot when the pasteboard changed since the previous call and
    /// the app may read it, nil otherwise.
    func readIfChanged() -> PasteboardSnapshot?
    func write(_ payload: Payload, rtf: Data?)
    /// The one deliberate read that makes the system ask the user, after
    /// which the app is listed in the pasteboard settings.
    func requestAccess()
}
