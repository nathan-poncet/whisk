import Foundation
import PasteurKernel

final class FakeClock: Clock {
    private var current: Date

    init(startingAt date: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        current = date
    }

    func now() -> Date { current }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

final class InMemoryHistoryStore: HistoryStore {
    var stored: [ClipboardItem] = []
    private(set) var saveCount = 0

    func load() throws -> [ClipboardItem] { stored }

    func save(_ items: [ClipboardItem]) throws {
        stored = items
        saveCount += 1
    }
}

final class ScriptedPasteboard: Pasteboard {
    var pendingSnapshots: [PasteboardSnapshot] = []
    private(set) var written: [Payload] = []

    func readIfChanged() -> PasteboardSnapshot? {
        pendingSnapshots.isEmpty ? nil : pendingSnapshots.removeFirst()
    }

    func write(_ payload: Payload) {
        written.append(payload)
    }
}

func anItem(
    _ payload: Payload,
    at date: Date = Date(timeIntervalSince1970: 1_700_000_000),
    pinned: Bool = false
) -> ClipboardItem {
    ClipboardItem(id: UUID(), payload: payload, sourceApp: "Tests", copiedAt: date, isPinned: pinned)
}
