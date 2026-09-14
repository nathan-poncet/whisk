import Foundation

/// Type-erased history store: the composition root picks a gateway at
/// launch without changing the controller's type.
struct AnyHistoryStore: HistoryStore {
    private let loadItems: () throws -> [ClipboardItem]
    private let saveItems: ([ClipboardItem]) throws -> Void

    init<Store: HistoryStore>(_ store: Store) {
        loadItems = store.load
        saveItems = store.save
    }

    func load() throws -> [ClipboardItem] { try loadItems() }

    func save(_ items: [ClipboardItem]) throws { try saveItems(items) }
}

/// Opens the production history store without ever refusing to launch. A
/// database that will not open is set aside for inspection and a fresh
/// one takes its place; should that fail too, the session runs in memory.
enum HistoryStorage {
    static let databaseName = "history.sqlite"
    static let unreadableSuffix = ".unreadable"
    static let legacyIndexName = "history.json"
    static let retiredSuffix = ".migrated"

    static func open(
        in directory: URL,
        fileManager: FileManager = .default,
        log: (String) -> Void = { NSLog("Whisk: %@", $0) }
    ) -> AnyHistoryStore {
        let databaseURL = directory.appendingPathComponent(databaseName)
        let store: AnyHistoryStore
        do {
            store = AnyHistoryStore(try SQLiteHistoryStore(databaseURL: databaseURL))
        } catch {
            log("cannot open \(databaseName) — \(error); setting it aside")
            setAside(databaseURL, fileManager: fileManager)
            do {
                store = AnyHistoryStore(try SQLiteHistoryStore(databaseURL: databaseURL))
            } catch {
                log("cannot create a fresh \(databaseName) — \(error); history will not be saved this session")
                return AnyHistoryStore(VolatileHistoryStore())
            }
        }
        importLegacyHistory(in: directory, into: store, fileManager: fileManager, log: log)
        return store
    }

    /// Imports the JSON history of earlier versions, merging it behind
    /// whatever the database already holds. The legacy files are retired
    /// only once the import is stored: a failed import leaves them in
    /// place, so the next launch tries again instead of starting empty.
    private static func importLegacyHistory(
        in directory: URL, into store: AnyHistoryStore, fileManager: FileManager, log: (String) -> Void
    ) {
        let legacyIndex = directory.appendingPathComponent(legacyIndexName)
        guard fileManager.fileExists(atPath: legacyIndex.path) else { return }
        do {
            let legacy = try FileHistoryStore(directory: directory, fileManager: fileManager).load()
            let current = try store.load()
            let known = Set(current.map(\.id))
            try store.save(current + legacy.filter { !known.contains($0.id) })
        } catch {
            log("legacy history not imported — \(error); it stays in place for the next launch")
            return
        }
        do {
            try fileManager.moveItem(
                at: legacyIndex, to: directory.appendingPathComponent(legacyIndexName + retiredSuffix))
            let blobs = directory.appendingPathComponent("blobs", isDirectory: true)
            if fileManager.fileExists(atPath: blobs.path) {
                try fileManager.removeItem(at: blobs)
            }
        } catch {
            log("legacy history imported but not retired — \(error)")
        }
    }

    // Best effort by design: a move that fails leaves the file where the
    // retry will trip over it again, and that failure is the one logged.
    private static func setAside(_ databaseURL: URL, fileManager: FileManager) {
        for sidecar in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: databaseURL.path + sidecar)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destination = URL(fileURLWithPath: databaseURL.path + unreadableSuffix + sidecar)
            try? fileManager.removeItem(at: destination)
            try? fileManager.moveItem(at: source, to: destination)
        }
    }
}
