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

    static func open(
        in directory: URL,
        fileManager: FileManager = .default,
        log: (String) -> Void = { NSLog("Whisk: %@", $0) }
    ) -> AnyHistoryStore {
        let databaseURL = directory.appendingPathComponent(databaseName)
        let legacyIndex = directory.appendingPathComponent("history.json")
        let needsMigration =
            !fileManager.fileExists(atPath: databaseURL.path)
            && fileManager.fileExists(atPath: legacyIndex.path)
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
        if needsMigration {
            let legacy = FileHistoryStore(directory: directory, fileManager: fileManager)
            if let items = try? legacy.load(), !items.isEmpty {
                try? store.save(items)
            }
            try? fileManager.moveItem(
                at: legacyIndex, to: directory.appendingPathComponent("history.json.migrated"))
        }
        return store
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
