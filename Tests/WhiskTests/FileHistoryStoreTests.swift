import Foundation
import Testing
@testable import Whisk

/// Contract suite for the `HistoryStore` port, run against the file adapter
/// in a fresh temporary directory per test.
@Suite struct FileHistoryStoreContract {
    private func makeStore() throws -> (FileHistoryStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisk-tests-\(UUID().uuidString)", isDirectory: true)
        return (FileHistoryStore(directory: directory), directory)
    }

    private func date(ms: Int64) -> Date {
        Date(timeIntervalSince1970: Double(ms) / 1000)
    }

    @Test func a_saved_history_loads_back_identically() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try #require(URL(string: "https://example.com/a?b=c"))
        let items = [
            ClipboardItem(
                id: UUID(), payload: .text("héllo\nworld"),
                source: SourceApp(name: "Safari", bundleID: "com.apple.Safari"), copiedAt: date(ms: 1_700_000_000_123),
                isPinned: true),
            ClipboardItem(
                id: UUID(), payload: .link(url), source: nil, copiedAt: date(ms: 1_700_000_001_456), isPinned: false),
            ClipboardItem(
                id: UUID(), payload: .image(Data([0x89, 0x50, 0x4E, 0x47])),
                source: SourceApp(name: "Preview", bundleID: "com.apple.Preview"),
                copiedAt: date(ms: 1_700_000_002_789), isPinned: false),
            ClipboardItem(
                id: UUID(), payload: .fileReferences(["/tmp/a.txt", "/tmp/b.txt"]),
                source: SourceApp(name: "Finder", bundleID: "com.apple.finder"), copiedAt: date(ms: 1_700_000_003_000),
                isPinned: true),
        ]

        try store.save(items)
        let loaded = try store.load()

        #expect(loaded == items)
    }

    @Test func loading_before_any_save_yields_no_items() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(try store.load().isEmpty)
    }

    @Test func a_blob_no_longer_referenced_is_removed_on_save() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = ClipboardItem(
            id: UUID(), payload: .image(Data([0x01])), source: nil, copiedAt: date(ms: 1_700_000_000_000),
            isPinned: false)
        let text = ClipboardItem(
            id: UUID(), payload: .text("survivor"), source: nil, copiedAt: date(ms: 1_700_000_001_000), isPinned: false)
        let blobs = directory.appendingPathComponent("blobs", isDirectory: true)

        try store.save([image, text])
        #expect(try FileManager.default.contentsOfDirectory(atPath: blobs.path).count == 1)

        try store.save([text])
        #expect(try FileManager.default.contentsOfDirectory(atPath: blobs.path).isEmpty)
    }

    @Test func a_stored_entry_with_an_unknown_kind_is_skipped_not_fatal() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try store.save([
            ClipboardItem(
                id: UUID(), payload: .text("valid"), source: nil, copiedAt: date(ms: 1_700_000_000_000), isPinned: false
            )
        ])
        let index = directory.appendingPathComponent("history.json")
        let corrupted = try String(contentsOf: index, encoding: .utf8)
            .replacingOccurrences(of: "\"text\",", with: "\"hologram\",")
        try corrupted.write(to: index, atomically: true, encoding: .utf8)

        #expect(try store.load().isEmpty)
    }
}
