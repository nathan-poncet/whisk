import Foundation
@testable import Whisk

/// Deterministic doubles for the kernel's ports, shared by every test
/// target. Nothing here reads real time, the real pasteboard, or disk.

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

    init() {}

    func load() throws -> [ClipboardItem] { stored }

    func save(_ items: [ClipboardItem]) throws {
        stored = items
        saveCount += 1
    }
}

final class FailingHistoryStore: HistoryStore {
    init() {}

    func load() throws -> [ClipboardItem] {
        throw HistoryStoreError.unreadable("failing store")
    }

    func save(_ items: [ClipboardItem]) throws {
        throw HistoryStoreError.unwritable("failing store")
    }
}

final class ScriptedPasteboard: Pasteboard {
    var pendingSnapshots: [PasteboardSnapshot] = []
    private(set) var written: [Payload] = []
    private(set) var writtenRTF: [Data?] = []

    init() {}

    func readIfChanged() -> PasteboardSnapshot? {
        pendingSnapshots.isEmpty ? nil : pendingSnapshots.removeFirst()
    }

    func write(_ payload: Payload, rtf: Data?) {
        written.append(payload)
        writtenRTF.append(rtf)
    }
}

func anItem(
    _ payload: Payload,
    from source: String? = "Tests",
    bundle: String? = nil,
    at date: Date = Date(timeIntervalSince1970: 1_700_000_000),
    pinned: Bool = false
) -> ClipboardItem {
    ClipboardItem(
        id: UUID(),
        payload: payload,
        source: SourceApp(name: source, bundleID: bundle),
        copiedAt: date,
        isPinned: pinned
    )
}
