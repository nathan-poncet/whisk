import Foundation
import WhiskKernel

/// Deterministic doubles for the kernel's ports, shared by every test
/// target. Nothing here reads real time, the real pasteboard, or disk.

public final class FakeClock: Clock {
    private var current: Date

    public init(startingAt date: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        current = date
    }

    public func now() -> Date { current }

    public func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

public final class InMemoryHistoryStore: HistoryStore {
    public var stored: [ClipboardItem] = []
    public private(set) var saveCount = 0

    public init() {}

    public func load() throws -> [ClipboardItem] { stored }

    public func save(_ items: [ClipboardItem]) throws {
        stored = items
        saveCount += 1
    }
}

public final class FailingHistoryStore: HistoryStore {
    public init() {}

    public func load() throws -> [ClipboardItem] {
        throw HistoryStoreError.unreadable("failing store")
    }

    public func save(_ items: [ClipboardItem]) throws {
        throw HistoryStoreError.unwritable("failing store")
    }
}

public final class ScriptedPasteboard: Pasteboard {
    public var pendingSnapshots: [PasteboardSnapshot] = []
    public private(set) var written: [Payload] = []

    public init() {}

    public func readIfChanged() -> PasteboardSnapshot? {
        pendingSnapshots.isEmpty ? nil : pendingSnapshots.removeFirst()
    }

    public func write(_ payload: Payload) {
        written.append(payload)
    }
}

public func anItem(
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
