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
}
