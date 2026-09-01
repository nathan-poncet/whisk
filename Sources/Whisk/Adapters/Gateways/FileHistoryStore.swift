import Foundation

/// Stores the history as a JSON index plus one blob file per image.
/// Dates are pinned to whole milliseconds so a saved history loads back
/// byte-identical.
final class FileHistoryStore: HistoryStore {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    /// `~/Library/Application Support/Whisk`, created by the first save.
    static func defaultDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("Whisk", isDirectory: true)
    }

    func load() throws -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: indexFile.path) else { return [] }
        let data: Data
        do {
            data = try Data(contentsOf: indexFile)
        } catch {
            throw HistoryStoreError.unreadable("index: \(error.localizedDescription)")
        }
        let stored: [StoredItem]
        do {
            stored = try JSONDecoder().decode([StoredItem].self, from: data)
        } catch {
            throw HistoryStoreError.unreadable("index: \(error.localizedDescription)")
        }
        return stored.compactMap(item)
    }

    func save(_ items: [ClipboardItem]) throws {
        do {
            try fileManager.createDirectory(at: blobsDirectory, withIntermediateDirectories: true)
            let stored = try items.map(storedItem)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(stored)
            try data.write(to: indexFile, options: .atomic)
            let referenced = Set(stored.compactMap(\.imageFile)).union(stored.compactMap(\.rtfFile))
            try removeOrphanedBlobs(keeping: referenced)
        } catch let error as HistoryStoreError {
            throw error
        } catch {
            throw HistoryStoreError.unwritable("\(error.localizedDescription)")
        }
    }

    private var indexFile: URL { directory.appendingPathComponent("history.json") }
    private var blobsDirectory: URL { directory.appendingPathComponent("blobs", isDirectory: true) }

    private struct StoredItem: Codable {
        var id: UUID
        var kind: String
        var text: String?
        var link: String?
        var imageFile: String?
        var files: [String]?
        var sourceApp: String?
        var sourceBundleID: String?
        var rtfFile: String?
        var copiedAtMs: Int64
        var isPinned: Bool
    }

    private func storedItem(for item: ClipboardItem) throws -> StoredItem {
        var stored = StoredItem(
            id: item.id,
            kind: "",
            sourceApp: item.source?.name,
            sourceBundleID: item.source?.bundleID,
            copiedAtMs: Int64((item.copiedAt.timeIntervalSince1970 * 1000).rounded()),
            isPinned: item.isPinned
        )
        switch item.payload {
        case .text(let value):
            stored.kind = "text"
            stored.text = value
        case .link(let url):
            stored.kind = "link"
            stored.link = url.absoluteString
        case .image(let data):
            stored.kind = "image"
            stored.imageFile = try writeBlob(data, for: item.id)
        case .fileReferences(let paths):
            stored.kind = "files"
            stored.files = paths
        }
        if let rtf = item.rtf {
            stored.rtfFile = try writeBlob(rtf, named: "\(item.id.uuidString).rtf")
        }
        return stored
    }

    private func item(from stored: StoredItem) -> ClipboardItem? {
        guard let payload = payload(from: stored) else { return nil }
        var rtf: Data?
        if let name = stored.rtfFile {
            rtf = try? Data(contentsOf: blobsDirectory.appendingPathComponent(name))
        }
        return ClipboardItem(
            id: stored.id,
            payload: payload,
            source: SourceApp(name: stored.sourceApp, bundleID: stored.sourceBundleID),
            copiedAt: Date(timeIntervalSince1970: Double(stored.copiedAtMs) / 1000),
            isPinned: stored.isPinned,
            rtf: rtf
        )
    }

    private func payload(from stored: StoredItem) -> Payload? {
        switch stored.kind {
        case "text":
            guard let text = stored.text else { return nil }
            return .text(text)
        case "link":
            guard let link = stored.link, let url = URL(string: link) else { return nil }
            return .link(url)
        case "image":
            guard let name = stored.imageFile,
                let data = try? Data(contentsOf: blobsDirectory.appendingPathComponent(name))
            else { return nil }
            return .image(data)
        case "files":
            guard let files = stored.files else { return nil }
            return .fileReferences(files)
        default:
            return nil
        }
    }

    private func writeBlob(_ data: Data, for id: UUID) throws -> String {
        try writeBlob(data, named: "\(id.uuidString).png")
    }

    private func writeBlob(_ data: Data, named name: String) throws -> String {
        let destination = blobsDirectory.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: destination.path) {
            try data.write(to: destination, options: .atomic)
        }
        return name
    }

    private func removeOrphanedBlobs(keeping referenced: Set<String>) throws {
        guard fileManager.fileExists(atPath: blobsDirectory.path) else { return }
        let existing = try fileManager.contentsOfDirectory(at: blobsDirectory, includingPropertiesForKeys: nil)
        for blob in existing where !referenced.contains(blob.lastPathComponent) {
            try fileManager.removeItem(at: blob)
        }
    }
}
