import Foundation
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

        try silently(directory).save([item])

        #expect(try silently(directory).load() == [item])
    }

    @Test func an_unreadable_database_is_set_aside_and_a_fresh_one_takes_its_place() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = directory.appendingPathComponent("history.sqlite")
        let garbage = Data(repeating: 0x42, count: 8192)
        try garbage.write(to: database)
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
        try FileHistoryStore(directory: directory).save(items)
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
        try FileHistoryStore(directory: directory).save([old])

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
