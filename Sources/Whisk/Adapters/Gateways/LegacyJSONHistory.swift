import Foundation

/// Reads the history format of versions before SQLite — a JSON index plus
/// one blob file per image or RTF — for the one-time import at launch.
/// Nothing writes this format anymore.
struct LegacyJSONHistory {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
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

    private var indexFile: URL { directory.appendingPathComponent("history.json") }
    private var blobsDirectory: URL { directory.appendingPathComponent("blobs", isDirectory: true) }

    private struct StoredItem: Decodable {
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
}
