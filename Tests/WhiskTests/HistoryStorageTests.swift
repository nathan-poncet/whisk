import Foundation
import SQLite3
import Testing

@testable import Whisk

/// The launch-time storage bootstrap, exercised in a fresh temporary
/// directory per test.
@Suite struct HistoryStorageBootstrap {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("whisk-storage-\(UUID().uuidString)", isDirectory: true)
    }

    private func silently(_ directory: URL) -> AnyHistoryStore {
        HistoryStorage.open(in: directory, log: { _ in })
    }

    @Test func a_fresh_directory_gets_a_database_that_persists_across_opens() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = anItem(.text("kept"))

        try HistoryStorage.open(in: directory).save([item])

        #expect(try silently(directory).load() == [item])
    }

    @Test func the_default_directory_is_whisk_under_application_support() throws {
        let directory = try HistoryStorage.defaultDirectory(environment: [:])

        #expect(directory.lastPathComponent == "Whisk")
        #expect(directory.deletingLastPathComponent().lastPathComponent == "Application Support")
    }

    @Test func the_environment_can_point_the_data_directory_elsewhere() throws {
        let elsewhere = try HistoryStorage.defaultDirectory(environment: ["WHISK_DATA_DIR": "/tmp/whisk-under-test"])
        let blank = try HistoryStorage.defaultDirectory(environment: ["WHISK_DATA_DIR": ""])

        #expect(elsewhere.path == "/tmp/whisk-under-test")
        #expect(blank.lastPathComponent == "Whisk")
    }

    @Test func a_legacy_import_that_cannot_be_retired_is_logged_and_the_index_stays() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let old = anItem(.text("from json"))
        try LegacyHistoryFixture.write([old], in: directory)
        // Something already sits where the retired index would go.
        try Data().write(to: directory.appendingPathComponent("history.json.migrated"))
        var logged: [String] = []

        let store = HistoryStorage.open(in: directory) { logged.append($0) }

        #expect(try store.load() == [old])
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("history.json").path))
        #expect(logged.count == 1)
    }

    @Test func an_unreadable_database_is_set_aside_and_a_fresh_one_takes_its_place() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = directory.appendingPathComponent("history.sqlite")
        let garbage = Data(repeating: 0x42, count: 8192)
        try garbage.write(to: database)
        try Data([0x01]).write(to: URL(fileURLWithPath: database.path + "-wal"))
        try Data([0x01]).write(to: URL(fileURLWithPath: database.path + "-shm"))
        var logged: [String] = []

        let store = HistoryStorage.open(in: directory) { logged.append($0) }

        #expect(try store.load().isEmpty)
        #expect(!logged.isEmpty)
        let setAside = directory.appendingPathComponent("history.sqlite.unreadable")
        #expect(try Data(contentsOf: setAside) == garbage)

        let item = anItem(.text("after recovery"))
        try store.save([item])
        #expect(try SQLiteHistoryStore(databaseURL: database).load() == [item])
    }

    @Test func without_a_log_of_its_own_the_bootstrap_still_recovers_and_writes_to_the_console() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 8192).write(to: directory.appendingPathComponent("history.sqlite"))

        let store = HistoryStorage.open(in: directory)

        #expect(try store.load().isEmpty)
    }

    @Test func a_database_that_opens_but_will_not_load_is_set_aside_too() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = directory.appendingPathComponent("history.sqlite")
        var raw: OpaquePointer?
        defer { sqlite3_close(raw) }
        try #require(sqlite3_open(database.path, &raw) == SQLITE_OK)
        // A content table from another era: it exists, so it is not
        // recreated, and it lacks the columns a load asks for.
        try #require(
            sqlite3_exec(raw, "CREATE TABLE content (id TEXT PRIMARY KEY, kind TEXT NOT NULL)", nil, nil, nil)
                == SQLITE_OK)
        var logged: [String] = []

        let store = HistoryStorage.open(in: directory) { logged.append($0) }

        #expect(try store.load().isEmpty)
        #expect(logged.count == 1)
        #expect(FileManager.default.fileExists(atPath: database.path + ".unreadable"))
        try store.save([anItem(.text("after recovery"))])
        #expect(try SQLiteHistoryStore(databaseURL: database).load().count == 1)
    }

    @Test func when_no_database_can_be_created_the_session_runs_in_memory() throws {
        let blocker = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: blocker) }
        try Data().write(to: blocker)
        let directory = blocker.appendingPathComponent("Whisk", isDirectory: true)
        var logged: [String] = []

        let store = HistoryStorage.open(in: directory) { logged.append($0) }
        let item = anItem(.text("volatile"))
        try store.save([item])

        #expect(try store.load() == [item])
        #expect(!logged.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func a_legacy_json_history_is_imported_once_and_its_files_retired() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let items = [anItem(.image(Data([0x89, 0x50, 0x4E, 0x47]))), anItem(.text("from json"))]
        try LegacyHistoryFixture.write(items, in: directory)
        let blobs = directory.appendingPathComponent("blobs", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: blobs.path))

        let store = silently(directory)

        #expect(try store.load() == items)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("history.json").path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("history.json.migrated").path))
        #expect(!FileManager.default.fileExists(atPath: blobs.path))
    }

    @Test func a_legacy_import_merges_behind_what_the_database_already_holds() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recent = anItem(.text("captured meanwhile"))
        try silently(directory).save([recent])
        let old = anItem(.text("from json"))
        try LegacyHistoryFixture.write([old], in: directory)

        #expect(try silently(directory).load() == [recent, old])
    }

    @Test func an_unreadable_legacy_history_stays_in_place_for_the_next_launch() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let index = directory.appendingPathComponent("history.json")
        try Data("{ not json".utf8).write(to: index)
        var logged: [String] = []

        let store = HistoryStorage.open(in: directory) { logged.append($0) }

        #expect(try store.load().isEmpty)
        #expect(FileManager.default.fileExists(atPath: index.path))
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("history.json.migrated").path))
        #expect(!logged.isEmpty)
    }
}
