import Foundation
import Testing

@testable import Whisk

/// Contract for the `HistoryStore` port, run against every gateway in a
/// fresh temporary directory per test.
private struct StoreHarness {
    let store: HistoryStore
    let directory: URL

    func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }
}

private func makeFileHarness() -> StoreHarness {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("whisk-tests-\(UUID().uuidString)", isDirectory: true)
    return StoreHarness(store: FileHistoryStore(directory: directory), directory: directory)
}

private func makeSQLiteHarness() throws -> StoreHarness {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("whisk-tests-\(UUID().uuidString)", isDirectory: true)
    let store = try SQLiteHistoryStore(databaseURL: directory.appendingPathComponent("history.sqlite"))
    return StoreHarness(store: store, directory: directory)
}

private func date(ms: Int64) -> Date {
    Date(timeIntervalSince1970: Double(ms) / 1000)
}

private func sampleItems() throws -> [ClipboardItem] {
    let url = try #require(URL(string: "https://example.com/a?b=c"))
    return [
        ClipboardItem(
            id: UUID(), payload: .text("héllo\nworld"),
            source: SourceApp(name: "Safari", bundleID: "com.apple.Safari"),
            copiedAt: date(ms: 1_700_000_000_123), isPinned: true, rtf: Data("rich".utf8)),
        ClipboardItem(
            id: UUID(), payload: .link(url), source: nil,
            copiedAt: date(ms: 1_700_000_001_456), isPinned: false),
        ClipboardItem(
            id: UUID(), payload: .image(Data([0x89, 0x50, 0x4E, 0x47])),
            source: SourceApp(name: "Preview", bundleID: "com.apple.Preview"),
            copiedAt: date(ms: 1_700_000_002_789), isPinned: false),
        ClipboardItem(
            id: UUID(), payload: .fileReferences(["/tmp/a.txt", "/tmp/b.txt"]),
            source: SourceApp(name: "Finder", bundleID: "com.apple.finder"),
            copiedAt: date(ms: 1_700_000_003_000), isPinned: true),
    ]
}

private func assertRoundTrip(_ harness: StoreHarness) throws {
    defer { harness.tearDown() }
    let items = try sampleItems()

    try harness.store.save(items)
    let loaded = try harness.store.load()

    #expect(loaded == items)

    let reordered = [items[2], items[0]]
    try harness.store.save(reordered)
    #expect(try harness.store.load() == reordered)
}

private func assertEmptyLoad(_ harness: StoreHarness) throws {
    defer { harness.tearDown() }
    #expect(try harness.store.load().isEmpty)
}

@Suite struct FileHistoryStoreContract {
    @Test func a_saved_history_loads_back_identically() throws {
        try assertRoundTrip(makeFileHarness())
    }

    @Test func loading_before_any_save_yields_no_items() throws {
        try assertEmptyLoad(makeFileHarness())
    }

    @Test func a_blob_no_longer_referenced_is_removed_on_save() throws {
        let harness = makeFileHarness()
        defer { harness.tearDown() }
        let image = ClipboardItem(
            id: UUID(), payload: .image(Data([0x01])), source: nil, copiedAt: date(ms: 1_700_000_000_000),
            isPinned: false)
        let text = ClipboardItem(
            id: UUID(), payload: .text("survivor"), source: nil, copiedAt: date(ms: 1_700_000_001_000),
            isPinned: false)
        let blobs = harness.directory.appendingPathComponent("blobs", isDirectory: true)

        try harness.store.save([image, text])
        #expect(try FileManager.default.contentsOfDirectory(atPath: blobs.path).count == 1)

        try harness.store.save([text])
        #expect(try FileManager.default.contentsOfDirectory(atPath: blobs.path).isEmpty)
    }

    @Test func a_stored_entry_with_an_unknown_kind_is_skipped_not_fatal() throws {
        let harness = makeFileHarness()
        defer { harness.tearDown() }
        try harness.store.save([
            ClipboardItem(
                id: UUID(), payload: .text("valid"), source: nil, copiedAt: date(ms: 1_700_000_000_000),
                isPinned: false)
        ])
        let index = harness.directory.appendingPathComponent("history.json")
        let corrupted = try String(contentsOf: index, encoding: .utf8)
            .replacingOccurrences(of: "\"text\",", with: "\"hologram\",")
        try corrupted.write(to: index, atomically: true, encoding: .utf8)

        #expect(try harness.store.load().isEmpty)
    }
}

@Suite struct SQLiteHistoryStoreContract {
    @Test func a_saved_history_loads_back_identically() throws {
        try assertRoundTrip(try makeSQLiteHarness())
    }

    @Test func loading_before_any_save_yields_no_items() throws {
        try assertEmptyLoad(try makeSQLiteHarness())
    }

    @Test func content_of_removed_items_is_deleted() throws {
        let harness = try makeSQLiteHarness()
        defer { harness.tearDown() }
        let items = try sampleItems()

        try harness.store.save(items)
        try harness.store.save([items[0]])

        #expect(try harness.store.load() == [items[0]])
    }
}
