import Foundation
import SQLite3
import Testing

@testable import Whisk

/// Every gateway of the `HistoryStore` port. The contract below runs
/// against each of them in a fresh temporary directory; what is specific
/// to one format has its own suite further down.
enum StoreGateway: CaseIterable {
    case file
    case sqlite
    case volatile

    /// Gateways whose history outlives the instance that saved it.
    static let persistent: [StoreGateway] = [.file, .sqlite]
}

private struct StoreHarness {
    let gateway: StoreGateway
    let directory: URL

    init(_ gateway: StoreGateway) {
        self.gateway = gateway
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisk-tests-\(UUID().uuidString)", isDirectory: true)
    }

    var databaseURL: URL { directory.appendingPathComponent("history.sqlite") }

    /// A store over this harness's files; a second call models a relaunch.
    func makeStore() throws -> any HistoryStore {
        switch gateway {
        case .file: return FileHistoryStore(directory: directory)
        case .sqlite: return try SQLiteHistoryStore(databaseURL: databaseURL)
        case .volatile: return VolatileHistoryStore()
        }
    }

    func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }
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

@Suite struct HistoryStoreContract {
    @Test(arguments: StoreGateway.allCases)
    func a_saved_history_loads_back_identically(_ gateway: StoreGateway) throws {
        let harness = StoreHarness(gateway)
        defer { harness.tearDown() }
        let store = try harness.makeStore()
        let items = try sampleItems()

        try store.save(items)
        #expect(try store.load() == items)

        let reordered = [items[2], items[0]]
        try store.save(reordered)
        #expect(try store.load() == reordered)
    }

    @Test(arguments: StoreGateway.allCases)
    func loading_before_any_save_yields_no_items(_ gateway: StoreGateway) throws {
        let harness = StoreHarness(gateway)
        defer { harness.tearDown() }

        #expect(try harness.makeStore().load().isEmpty)
    }

    @Test(arguments: StoreGateway.allCases)
    func saving_a_subset_forgets_the_rest(_ gateway: StoreGateway) throws {
        let harness = StoreHarness(gateway)
        defer { harness.tearDown() }
        let store = try harness.makeStore()
        let items = try sampleItems()

        try store.save(items)
        try store.save([items[0]])

        #expect(try store.load() == [items[0]])
    }

    @Test(arguments: StoreGateway.persistent)
    func a_saved_history_survives_a_relaunch(_ gateway: StoreGateway) throws {
        let harness = StoreHarness(gateway)
        defer { harness.tearDown() }
        let items = try sampleItems()

        try harness.makeStore().save(items)

        #expect(try harness.makeStore().load() == items)
    }
}

@Suite struct FileHistoryStoreSpecifics {
    @Test func a_blob_no_longer_referenced_is_removed_on_save() throws {
        let harness = StoreHarness(.file)
        defer { harness.tearDown() }
        let store = try harness.makeStore()
        let image = ClipboardItem(
            id: UUID(), payload: .image(Data([0x01])), source: nil, copiedAt: date(ms: 1_700_000_000_000),
            isPinned: false)
        let text = ClipboardItem(
            id: UUID(), payload: .text("survivor"), source: nil, copiedAt: date(ms: 1_700_000_001_000),
            isPinned: false)
        let blobs = harness.directory.appendingPathComponent("blobs", isDirectory: true)

        try store.save([image, text])
        #expect(try FileManager.default.contentsOfDirectory(atPath: blobs.path).count == 1)

        try store.save([text])
        #expect(try FileManager.default.contentsOfDirectory(atPath: blobs.path).isEmpty)
    }

    @Test func a_stored_entry_with_an_unknown_kind_is_skipped_not_fatal() throws {
        let harness = StoreHarness(.file)
        defer { harness.tearDown() }
        let store = try harness.makeStore()
        try store.save([
            ClipboardItem(
                id: UUID(), payload: .text("valid"), source: nil, copiedAt: date(ms: 1_700_000_000_000),
                isPinned: false)
        ])
        let index = harness.directory.appendingPathComponent("history.json")
        let corrupted = try String(contentsOf: index, encoding: .utf8)
            .replacingOccurrences(of: "\"text\",", with: "\"hologram\",")
        try corrupted.write(to: index, atomically: true, encoding: .utf8)

        #expect(try store.load().isEmpty)
    }
}

@Suite struct SQLiteHistoryStoreSpecifics {
    @Test func a_row_with_an_unknown_kind_is_skipped_not_fatal() throws {
        let harness = StoreHarness(.sqlite)
        defer { harness.tearDown() }
        let valid = anItem(.text("valid"))
        try harness.makeStore().save([valid])
        try insertRow(kind: "hologram", into: harness.databaseURL)

        #expect(try harness.makeStore().load() == [valid])
    }

    @Test func a_file_that_is_not_a_database_fails_to_open() throws {
        let harness = StoreHarness(.sqlite)
        defer { harness.tearDown() }
        try FileManager.default.createDirectory(at: harness.directory, withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 8192).write(to: harness.databaseURL)

        #expect(throws: HistoryStoreError.self) {
            try SQLiteHistoryStore(databaseURL: harness.databaseURL)
        }
    }

    private struct RawSQLFailure: Error {}

    private func insertRow(kind: String, into database: URL) throws {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open(database.path, &db) == SQLITE_OK else { throw RawSQLFailure() }
        let id = UUID().uuidString
        let sql = """
            INSERT INTO content (id, kind, text) VALUES ('\(id)', '\(kind)', 'ghost');
            INSERT INTO ordering (id, position, copied_at_ms, is_pinned) VALUES ('\(id)', 1, 0, 0);
            """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw RawSQLFailure() }
    }
}
