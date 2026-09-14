import Foundation
import Testing

@testable import Whisk

/// Writes the on-disk format of versions before SQLite — the JSON index
/// plus one blob file per image or RTF — so the reader is tested against
/// the format itself, not against a writer that no longer ships.
enum LegacyHistoryFixture {
    struct Entry: Encodable {
        var id = UUID()
        var kind: String
        var text: String?
        var link: String?
        var imageFile: String?
        var files: [String]?
        var sourceApp: String?
        var sourceBundleID: String?
        var rtfFile: String?
        var copiedAtMs: Int64 = 0
        var isPinned = false
    }

    static func write(_ items: [ClipboardItem], extraEntries: [Entry] = [], in directory: URL) throws {
        let blobsDirectory = directory.appendingPathComponent("blobs", isDirectory: true)
        try FileManager.default.createDirectory(at: blobsDirectory, withIntermediateDirectories: true)
        var entries: [Entry] = []
        for item in items {
            var entry = Entry(
                id: item.id, kind: "", sourceApp: item.source?.name, sourceBundleID: item.source?.bundleID,
                copiedAtMs: Int64((item.copiedAt.timeIntervalSince1970 * 1000).rounded()), isPinned: item.isPinned)
            switch item.payload {
            case .text(let value):
                entry.kind = "text"
                entry.text = value
            case .link(let url):
                entry.kind = "link"
                entry.link = url.absoluteString
            case .image(let data):
                entry.kind = "image"
                entry.imageFile = "\(item.id.uuidString).png"
                try data.write(to: blobsDirectory.appendingPathComponent("\(item.id.uuidString).png"))
            case .fileReferences(let paths):
                entry.kind = "files"
                entry.files = paths
            }
            if let rtf = item.rtf {
                entry.rtfFile = "\(item.id.uuidString).rtf"
                try rtf.write(to: blobsDirectory.appendingPathComponent("\(item.id.uuidString).rtf"))
            }
            entries.append(entry)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries + extraEntries).write(to: directory.appendingPathComponent("history.json"))
    }
}

@Suite struct LegacyJSONHistoryReading {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("whisk-legacy-\(UUID().uuidString)", isDirectory: true)
    }

    private func date(ms: Int64) -> Date {
        Date(timeIntervalSince1970: Double(ms) / 1000)
    }

    @Test func every_payload_kind_loads_back_from_the_index_and_its_blobs() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try #require(URL(string: "https://example.com/a?b=c"))
        let items = [
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
        try LegacyHistoryFixture.write(items, in: directory)

        #expect(try LegacyJSONHistory(directory: directory).load() == items)
    }

    @Test func a_missing_index_reads_as_an_empty_history() throws {
        let directory = temporaryDirectory()

        #expect(try LegacyJSONHistory(directory: directory).load().isEmpty)
    }

    @Test func an_entry_with_an_unknown_kind_is_skipped_not_fatal() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let valid = anItem(.text("valid"))
        try LegacyHistoryFixture.write(
            [valid], extraEntries: [LegacyHistoryFixture.Entry(kind: "hologram", text: "ghost")], in: directory)

        #expect(try LegacyJSONHistory(directory: directory).load() == [valid])
    }

    @Test func an_unparseable_index_fails_as_unreadable() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: directory.appendingPathComponent("history.json"))

        #expect(throws: HistoryStoreError.self) {
            try LegacyJSONHistory(directory: directory).load()
        }
    }
}
