import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite-backed history store using the system library — no package
/// dependency. Immutable content (including image and RTF blobs) is
/// inserted once per item; only the small ordering table is rewritten on
/// each save, all inside one transaction. The JSON store rewrote every
/// blob on every copy, which stopped scaling with an unlimited history.
final class SQLiteHistoryStore: HistoryStore {
    private var db: OpaquePointer?

    init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            throw HistoryStoreError.unwritable("cannot open \(databaseURL.lastPathComponent)")
        }
        try execute("PRAGMA journal_mode=WAL")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS content (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                text TEXT,
                link TEXT,
                image BLOB,
                rtf BLOB,
                files TEXT,
                source_app TEXT,
                source_bundle TEXT
            )
            """)
        try execute(
            """
            CREATE TABLE IF NOT EXISTS ordering (
                id TEXT PRIMARY KEY,
                position INTEGER NOT NULL,
                copied_at_ms INTEGER NOT NULL,
                is_pinned INTEGER NOT NULL
            )
            """)
    }

    deinit {
        sqlite3_close(db)
    }

    func load() throws -> [ClipboardItem] {
        let sql = """
            SELECT c.id, c.kind, c.text, c.link, c.image, c.rtf, c.files, c.source_app, c.source_bundle,
                   o.copied_at_ms, o.is_pinned
            FROM ordering o JOIN content c ON c.id = o.id
            ORDER BY o.position ASC
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.unreadable(lastMessage())
        }
        defer { sqlite3_finalize(statement) }
        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = item(from: statement) {
                items.append(item)
            }
        }
        return items
    }

    func save(_ items: [ClipboardItem]) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            let ids = items.map { $0.id.uuidString }
            for item in items {
                try insertContentIfNeeded(item)
            }
            try execute("DELETE FROM ordering")
            try insertOrdering(items)
            try deleteContent(notIn: ids)
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Rows

    private func insertContentIfNeeded(_ item: ClipboardItem) throws {
        let sql = """
            INSERT OR IGNORE INTO content
            (id, kind, text, link, image, rtf, files, source_app, source_bundle)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.unwritable(lastMessage())
        }
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, item.id.uuidString)
        switch item.payload {
        case .text(let value):
            bindText(statement, 2, "text")
            bindText(statement, 3, value)
        case .link(let url):
            bindText(statement, 2, "link")
            bindText(statement, 4, url.absoluteString)
        case .image(let data):
            bindText(statement, 2, "image")
            bindBlob(statement, 5, data)
        case .fileReferences(let paths):
            bindText(statement, 2, "files")
            if let encoded = try? JSONEncoder().encode(paths) {
                bindText(statement, 7, String(decoding: encoded, as: UTF8.self))
            }
        }
        if let rtf = item.rtf {
            bindBlob(statement, 6, rtf)
        }
        if let name = item.source?.name {
            bindText(statement, 8, name)
        }
        if let bundleID = item.source?.bundleID {
            bindText(statement, 9, bundleID)
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw HistoryStoreError.unwritable(lastMessage())
        }
    }

    private func insertOrdering(_ items: [ClipboardItem]) throws {
        let sql = "INSERT INTO ordering (id, position, copied_at_ms, is_pinned) VALUES (?, ?, ?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.unwritable(lastMessage())
        }
        defer { sqlite3_finalize(statement) }
        for (position, item) in items.enumerated() {
            sqlite3_reset(statement)
            bindText(statement, 1, item.id.uuidString)
            sqlite3_bind_int64(statement, 2, Int64(position))
            sqlite3_bind_int64(statement, 3, Int64((item.copiedAt.timeIntervalSince1970 * 1000).rounded()))
            sqlite3_bind_int64(statement, 4, item.isPinned ? 1 : 0)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw HistoryStoreError.unwritable(lastMessage())
            }
        }
    }

    private func deleteContent(notIn ids: [String]) throws {
        let placeholders = ids.isEmpty ? "" : String(repeating: "?,", count: ids.count - 1) + "?"
        let sql =
            ids.isEmpty
            ? "DELETE FROM content"
            : "DELETE FROM content WHERE id NOT IN (\(placeholders))"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.unwritable(lastMessage())
        }
        defer { sqlite3_finalize(statement) }
        for (index, id) in ids.enumerated() {
            bindText(statement, Int32(index + 1), id)
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw HistoryStoreError.unwritable(lastMessage())
        }
    }

    private func item(from statement: OpaquePointer?) -> ClipboardItem? {
        guard let idText = columnText(statement, 0), let id = UUID(uuidString: idText),
            let kind = columnText(statement, 1)
        else { return nil }
        let payload: Payload
        switch kind {
        case "text":
            guard let text = columnText(statement, 2) else { return nil }
            payload = .text(text)
        case "link":
            guard let link = columnText(statement, 3), let url = URL(string: link) else { return nil }
            payload = .link(url)
        case "image":
            guard let data = columnBlob(statement, 4) else { return nil }
            payload = .image(data)
        case "files":
            guard let encoded = columnText(statement, 6),
                let paths = try? JSONDecoder().decode([String].self, from: Data(encoded.utf8))
            else { return nil }
            payload = .fileReferences(paths)
        default:
            return nil
        }
        return ClipboardItem(
            id: id,
            payload: payload,
            source: SourceApp(name: columnText(statement, 7), bundleID: columnText(statement, 8)),
            copiedAt: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 9)) / 1000),
            isPinned: sqlite3_column_int64(statement, 10) == 1,
            rtf: columnBlob(statement, 5)
        )
    }

    // MARK: - SQLite helpers

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw HistoryStoreError.unwritable(lastMessage())
        }
    }

    private func bindText(_ statement: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private func bindBlob(_ statement: OpaquePointer?, _ index: Int32, _ data: Data) {
        data.withUnsafeBytes { buffer in
            _ = sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), sqliteTransient)
        }
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func columnBlob(_ statement: OpaquePointer?, _ index: Int32) -> Data? {
        guard let pointer = sqlite3_column_blob(statement, index) else { return nil }
        return Data(bytes: pointer, count: Int(sqlite3_column_bytes(statement, index)))
    }

    private func lastMessage() -> String {
        db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite error"
    }
}
