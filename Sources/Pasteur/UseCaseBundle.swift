import Foundation
import HistoryStoreFile
import PasteboardAppKit
import PasteurKernel

/// Concrete use cases wired by the composition root, type-erased for the UI.
struct UseCaseBundle {
    let load: () throws -> History
    let capture: (History) throws -> History
    let select: (UUID, History) throws -> History
    let togglePin: (UUID, History) throws -> History
    let delete: (UUID, History) throws -> History
    let clear: (History) throws -> History

    static func live(pasteboard: AppKitPasteboard, store: FileHistoryStore, clock: SystemClock) -> UseCaseBundle {
        let load = LoadHistory(store: store)
        let capture = CaptureClipboardChange(pasteboard: pasteboard, clock: clock, store: store)
        let select = SelectItem(pasteboard: pasteboard, clock: clock, store: store)
        let togglePin = TogglePin(store: store)
        let delete = DeleteItem(store: store)
        let clear = ClearHistory(store: store)
        return UseCaseBundle(
            load: { try load() },
            capture: { try capture(into: $0) },
            select: { try select($0, in: $1) },
            togglePin: { try togglePin($0, in: $1) },
            delete: { try delete($0, in: $1) },
            clear: { try clear($0) }
        )
    }
}
